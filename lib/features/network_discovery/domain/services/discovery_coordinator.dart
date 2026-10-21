import 'dart:async';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../devices/domain/entities/device_entity.dart';
import '../../../devices/domain/repositories/device_repository.dart';
import '../../../infrastructure/domain/entities/unifi_device_entity.dart';
import '../../../infrastructure/domain/repositories/infrastructure_repository.dart';
import '../entities/classification_confidence.dart';
import '../entities/device_category.dart';
import '../entities/discovered_device_entity.dart';
import '../entities/discovery_config_entity.dart';
import '../entities/discovery_evidence_item.dart';
import '../entities/discovery_progress.dart';
import '../entities/discovery_scan_job.dart';
import '../entities/review_state.dart';
import '../repositories/discovery_repository.dart';
import '../../data/datasources/strategies/arp_discovery_strategy.dart';
import '../../data/datasources/strategies/dns_hostname_strategy.dart';
import '../../data/datasources/strategies/icmp_discovery_strategy.dart';
import '../../data/datasources/strategies/mdns_ssdp_discovery_strategy.dart';
import '../../data/datasources/strategies/onvif_discovery_strategy.dart';
import '../../data/datasources/strategies/tcp_probe_discovery_strategy.dart';
import 'device_classification_engine.dart';
import 'discovery_strategy.dart';
import 'mac_vendor_lookup.dart';
import 'network_range_validator.dart';

@lazySingleton
class DiscoveryCoordinator {
  final DiscoveryRepository _discoveryRepo;
  final DeviceRepository _deviceRepo;
  final NetworkRangeValidator _rangeValidator;
  final DeviceClassificationEngine _classifier;
  final MacVendorLookup _vendorLookup;
  final List<DiscoveryStrategy> _strategies;
  final InfrastructureRepository? _infrastructureRepo;

  bool _isScanning = false;
  bool _isCancelled = false;
  int? _activeScanId;

  final StreamController<DiscoveryProgress> _progressController =
      StreamController<DiscoveryProgress>.broadcast();

  DiscoveryCoordinator(
    this._discoveryRepo,
    this._deviceRepo,
    this._rangeValidator,
    this._classifier,
    this._vendorLookup,
    IcmpDiscoveryStrategy icmp,
    ArpDiscoveryStrategy arp,
    DnsHostnameStrategy dns,
    TcpProbeDiscoveryStrategy tcp,
    OnvifDiscoveryStrategy onvif,
    MdnsSsdpDiscoveryStrategy mdns, [
    this._infrastructureRepo,
  ]) : _strategies = [icmp, arp, dns, tcp, onvif, mdns];

  bool get isScanning => _isScanning;
  int? get activeScanId => _activeScanId;
  Stream<DiscoveryProgress> get progressStream => _progressController.stream;

  /// Starts a managed discovery scan over the specified CIDR ranges.
  Future<Result<DiscoveryScanJob>> startScan({
    List<String>? requestedRanges,
    List<String>? enabledStrategies,
    int? maxConcurrency,
    int? timeoutSeconds,
  }) async {
    if (_isScanning) {
      return Result.failure(
        ValidationFailure(
          'A network discovery scan is already active (Scan ID: $_activeScanId)',
        ),
      );
    }

    _isScanning = true;
    _isCancelled = false;

    // 1. Fetch current configuration & validate ranges
    final configRes = await _discoveryRepo.getConfig();
    final config = configRes.dataOrNull ?? DiscoveryConfigEntity.initial();

    final rangesToScan = requestedRanges ?? config.authorizedRanges;
    final validRanges = _rangeValidator.validateRanges(rangesToScan);

    if (validRanges.isEmpty) {
      _isScanning = false;
      return Result.failure(
        ValidationFailure(
          'No valid authorized CIDR ranges provided for discovery',
        ),
      );
    }

    // 2. Enumerate candidate targets
    final candidateHosts = <String>[];
    for (final r in validRanges) {
      candidateHosts.addAll(r.enumerateUsableHosts());
    }

    // 3. Create Scan Job record
    final activeStrategies = enabledStrategies ?? config.enabledStrategies;
    var job = DiscoveryScanJob(
      status: ScanJobStatus.validating,
      targetRanges: validRanges.map((r) => r.cidr).toList(),
      enabledStrategies: activeStrategies,
      startedAt: DateTime.now(),
      targetsEnumerated: candidateHosts.length,
    );

    final createRes = await _discoveryRepo.createScanJob(job);
    if (createRes.isFailure) {
      _isScanning = false;
      return Result.failure(createRes.failureOrNull!);
    }

    final scanId = createRes.dataOrNull!;
    _activeScanId = scanId;
    job = job.copyWith(id: scanId, status: ScanJobStatus.running);
    await _discoveryRepo.updateScanJob(job);

    // 4. Launch asynchronous execution loop without blocking UI
    unawaited(
      _executeScanPipeline(
        job: job,
        targets: candidateHosts,
        concurrency: maxConcurrency ?? config.maxConcurrency,
        timeout: Duration(seconds: timeoutSeconds ?? config.timeoutSeconds),
      ),
    );

    return Result.success(job);
  }

  /// Cancels an in-flight discovery scan
  Future<Result<void>> cancelScan() async {
    final scanId = _activeScanId;
    if (!_isScanning || scanId == null) {
      return Result.success(null);
    }

    _isCancelled = true;
    _isScanning = false;
    _activeScanId = null;

    final scanRes = await _discoveryRepo.getScanJob(scanId);
    if (scanRes.isSuccess && scanRes.dataOrNull != null) {
      final updated = scanRes.dataOrNull!.copyWith(
        status: ScanJobStatus.cancelled,
        completedAt: DateTime.now(),
        diagnosticSummary: 'Scan cancelled by user.',
      );
      await _discoveryRepo.updateScanJob(updated);
    }

    if (!_progressController.isClosed) {
      _progressController.add(
        DiscoveryProgress(
          scanId: scanId,
          status: ScanJobStatus.cancelled,
          targetsEnumerated: 0,
          targetsAttempted: 0,
          responsesReceived: 0,
          devicesFound: 0,
          classifiedCount: 0,
          unknownCount: 0,
          message: 'Discovery scan cancelled.',
        ),
      );
    }

    return Result.success(null);
  }

  Future<void> _executeScanPipeline({
    required DiscoveryScanJob job,
    required List<String> targets,
    required int concurrency,
    required Duration timeout,
  }) async {
    int attempted = 0;
    int responses = 0;
    int classified = 0;
    int unknowns = 0;
    int failures = 0;

    // Load existing approved production inventory and infrastructure to prevent duplicates and detect AlreadyKnown
    final devicesRes = await _deviceRepo.getDevices();
    final existingDevices = devicesRes.dataOrNull ?? [];
    final knownIpMap = <String, dynamic>{
      for (final d in existingDevices) d.ip.trim(): d,
    };

    if (_infrastructureRepo != null) {
      final infraRes = await _infrastructureRepo.getInfrastructureDevices();
      final infraDevices = infraRes.dataOrNull ?? [];
      for (final infra in infraDevices) {
        if (infra.ip.trim().isNotEmpty) {
          knownIpMap[infra.ip.trim()] = infra;
        }
      }
    }

    // Filter active strategies
    final strategyMap = {for (final s in _strategies) s.name: s};
    final activeStrategyList = job.enabledStrategies
        .map((n) => strategyMap[n])
        .whereType<DiscoveryStrategy>()
        .toList();

    // Work queue with bounded concurrency
    final queue = List<String>.from(targets);
    final activeFutures = <Future<void>>{};

    while (queue.isNotEmpty && !_isCancelled) {
      while (activeFutures.length < concurrency &&
          queue.isNotEmpty &&
          !_isCancelled) {
        final targetIp = queue.removeAt(0);

        final future =
            _probeTarget(
                  scanId: job.id,
                  targetIp: targetIp,
                  strategies: activeStrategyList,
                  timeout: timeout,
                  knownIpMap: knownIpMap,
                )
                .then((discoveredDevice) async {
                  attempted++;
                  if (discoveredDevice != null) {
                    responses++;
                    if (discoveredDevice.predictedCategory !=
                            DeviceCategory.unknown &&
                        discoveredDevice.confidence !=
                            ClassificationConfidence.unknown) {
                      classified++;
                    } else {
                      unknowns++;
                    }
                  }

                  if (!_progressController.isClosed) {
                    _progressController.add(
                      DiscoveryProgress(
                        scanId: job.id,
                        status: ScanJobStatus.running,
                        targetsEnumerated: targets.length,
                        targetsAttempted: attempted,
                        responsesReceived: responses,
                        devicesFound: responses,
                        classifiedCount: classified,
                        unknownCount: unknowns,
                        latestDevice: discoveredDevice,
                        message:
                            'Probing $targetIp ($attempted of ${targets.length})',
                      ),
                    );
                  }
                })
                .catchError((_) {
                  attempted++;
                  failures++;
                });

        activeFutures.add(future);
        future.whenComplete(() => activeFutures.remove(future));
      }

      if (activeFutures.isNotEmpty) {
        await Future.any(activeFutures);
      }
    }

    // Await all remaining active workers
    await Future.wait(activeFutures);

    final finalStatus = _isCancelled
        ? ScanJobStatus.cancelled
        : (failures > 0
              ? ScanJobStatus.completedWithErrors
              : ScanJobStatus.completed);

    final completedJob = job.copyWith(
      status: finalStatus,
      completedAt: DateTime.now(),
      targetsAttempted: attempted,
      responsesReceived: responses,
      classifiedCount: classified,
      unknownCount: unknowns,
      failureCount: failures,
      diagnosticSummary:
          'Scan finished. $responses active devices discovered across ${job.targetRanges.join(', ')}.',
    );

    await _discoveryRepo.updateScanJob(completedJob);

    if (!_progressController.isClosed) {
      _progressController.add(
        DiscoveryProgress(
          scanId: job.id,
          status: finalStatus,
          targetsEnumerated: targets.length,
          targetsAttempted: attempted,
          responsesReceived: responses,
          devicesFound: responses,
          classifiedCount: classified,
          unknownCount: unknowns,
          message: completedJob.diagnosticSummary,
        ),
      );
    }

    _isScanning = false;
    _activeScanId = null;
  }

  Future<DiscoveredDeviceEntity?> _probeTarget({
    required int scanId,
    required String targetIp,
    required List<DiscoveryStrategy> strategies,
    required Duration timeout,
    required Map<String, dynamic> knownIpMap,
  }) async {
    final evidenceItems = <DiscoveryEvidenceItem>[];
    String? resolvedMac;
    String? resolvedHostname;
    final observedServices = <String>[];
    bool hadResponse = false;
    DateTime? lastSuccess;

    // Strategy 1: ICMP
    final icmpStrategy = strategies.firstWhere(
      (s) => s.name == 'icmp',
      orElse: () => strategies.first,
    );
    final icmpRes = await icmpStrategy.probe(targetIp, timeout);
    if (icmpRes.isSuccess) {
      hadResponse = true;
      lastSuccess = icmpRes.timestamp;
      evidenceItems.add(
        DiscoveryEvidenceItem(
          strategyName: 'icmp',
          probeTarget: targetIp,
          isSuccess: true,
          details: icmpRes.evidenceDetails ?? 'ICMP ping responded',
          timestamp: icmpRes.timestamp,
        ),
      );
    }

    // Strategy 2: ARP Cache (Layer 2 MAC)
    final arpStrategy = strategies.where((s) => s.name == 'arp').firstOrNull;
    if (arpStrategy != null) {
      final arpRes = await arpStrategy.probe(targetIp, timeout);
      if (arpRes.isSuccess && arpRes.mac != null) {
        hadResponse = true;
        resolvedMac = arpRes.mac;
        evidenceItems.add(
          DiscoveryEvidenceItem(
            strategyName: 'arp',
            probeTarget: targetIp,
            isSuccess: true,
            details: arpRes.evidenceDetails ?? 'MAC: ${arpRes.mac}',
            timestamp: arpRes.timestamp,
          ),
        );
      }
    }

    // If device responded to either ICMP or ARP, proceed with deeper fingerprinting
    if (hadResponse) {
      // Strategy 3: DNS PTR Hostname
      final dnsStrategy = strategies.where((s) => s.name == 'dns').firstOrNull;
      if (dnsStrategy != null) {
        final dnsRes = await dnsStrategy.probe(targetIp, timeout);
        if (dnsRes.isSuccess && dnsRes.hostname != null) {
          resolvedHostname = dnsRes.hostname;
          evidenceItems.add(
            DiscoveryEvidenceItem(
              strategyName: 'dns',
              probeTarget: targetIp,
              isSuccess: true,
              details: dnsRes.evidenceDetails ?? 'Hostname: ${dnsRes.hostname}',
              timestamp: dnsRes.timestamp,
            ),
          );
        }
      }

      // Strategy 4: TCP Probes
      final tcpStrategy = strategies
          .where((s) => s.name == 'tcp_probe')
          .firstOrNull;
      if (tcpStrategy != null) {
        final tcpRes = await tcpStrategy.probe(targetIp, timeout);
        if (tcpRes.isSuccess) {
          observedServices.addAll(tcpRes.observedServices);
          evidenceItems.add(
            DiscoveryEvidenceItem(
              strategyName: 'tcp_probe',
              probeTarget: targetIp,
              isSuccess: true,
              details:
                  tcpRes.evidenceDetails ??
                  'Services: ${tcpRes.observedServices.join(', ')}',
              timestamp: tcpRes.timestamp,
            ),
          );
        }
      }

      // Strategy 5: ONVIF / RTSP Camera Probe
      final onvifStrategy = strategies
          .where((s) => s.name == 'onvif')
          .firstOrNull;
      if (onvifStrategy != null) {
        final onvifRes = await onvifStrategy.probe(targetIp, timeout);
        if (onvifRes.isSuccess) {
          observedServices.addAll(onvifRes.observedServices);
          evidenceItems.add(
            DiscoveryEvidenceItem(
              strategyName: 'onvif',
              probeTarget: targetIp,
              isSuccess: true,
              details:
                  onvifRes.evidenceDetails ??
                  'Camera RTSP streaming port detected',
              timestamp: onvifRes.timestamp,
            ),
          );
        }
      }

      // Strategy 6: mDNS / SSDP
      final mdnsStrategy = strategies
          .where((s) => s.name == 'mdns')
          .firstOrNull;
      if (mdnsStrategy != null) {
        final mdnsRes = await mdnsStrategy.probe(targetIp, timeout);
        if (mdnsRes.isSuccess) {
          observedServices.addAll(mdnsRes.observedServices);
          evidenceItems.add(
            DiscoveryEvidenceItem(
              strategyName: 'mdns',
              probeTarget: targetIp,
              isSuccess: true,
              details:
                  mdnsRes.evidenceDetails ??
                  'mDNS/SSDP service broadcast detected',
              timestamp: mdnsRes.timestamp,
            ),
          );
        }
      }

      // Vendor Lookup
      final vendor = _vendorLookup.lookupVendor(resolvedMac);
      if (vendor != null) {
        evidenceItems.add(
          DiscoveryEvidenceItem(
            strategyName: 'mac_vendor',
            probeTarget: resolvedMac ?? targetIp,
            isSuccess: true,
            details: 'Manufacturer OUI identified: $vendor',
            timestamp: DateTime.now(),
          ),
        );
      }

      // Check if known in inventory or infrastructure
      final isAlreadyKnown = knownIpMap.containsKey(targetIp);
      final existingDev = knownIpMap[targetIp];
      final isInfra = existingDev is UniFiDeviceEntity;

      int? associatedId;
      String? knownHostname;
      if (isAlreadyKnown) {
        if (existingDev is UniFiDeviceEntity) {
          associatedId = 10000 + existingDev.id;
          knownHostname = existingDev.name;
        } else if (existingDev is DeviceEntity) {
          associatedId = existingDev.id;
          knownHostname = existingDev.name;
        }
      }

      // Run Classification Engine
      final decision = _classifier.classify(
        ip: targetIp,
        mac: resolvedMac,
        hostname: resolvedHostname ?? knownHostname,
        observedServices: observedServices,
        evidence: evidenceItems,
        isKnownInventoryDevice: isAlreadyKnown,
      );

      final reviewState = isAlreadyKnown
          ? ReviewState.alreadyKnown
          : ReviewState.pendingReview;

      final category = isInfra
          ? DeviceCategory.wirelessAccessPoint
          : decision.category;

      final discoveredEntity = DiscoveredDeviceEntity(
        scanId: scanId,
        ip: targetIp,
        mac: resolvedMac,
        hostname: resolvedHostname ?? knownHostname,
        vendor: vendor,
        observedServices: observedServices,
        predictedCategory: category,
        confidence: isInfra
            ? ClassificationConfidence.high
            : decision.confidence,
        evidence: evidenceItems,
        firstSeen: DateTime.now(),
        lastSeen: DateTime.now(),
        lastSuccessfulProbe: lastSuccess,
        reviewState: reviewState,
        associatedDeviceId: associatedId,
      );

      // Persist to Drift DB
      final devId = await _discoveryRepo.saveDiscoveredDevice(discoveredEntity);
      if (devId.isSuccess) {
        for (final ev in evidenceItems) {
          await _discoveryRepo.saveEvidence(devId.dataOrNull!, ev);
        }
      }

      return discoveredEntity;
    }

    return null;
  }

  void dispose() {
    _isCancelled = true;
    if (!_progressController.isClosed) {
      _progressController.close();
    }
  }
}
