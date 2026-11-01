import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/core/utils/result.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/devices/domain/repositories/device_repository.dart';
import 'package:it_network_monitor/features/devices/domain/entities/inventory_import_preview.dart';
import 'package:it_network_monitor/features/network_discovery/data/repositories/discovery_repository_impl.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/classification_confidence.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/device_category.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/discovered_device_entity.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/discovery_evidence_item.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/discovery_scan_job.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/network_range.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/reachability_status.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/review_state.dart';
import 'package:it_network_monitor/features/network_discovery/domain/repositories/discovery_repository.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/device_classification_engine.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/discovery_coordinator.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/mac_vendor_lookup.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/network_range_validator.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/arp_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/dns_hostname_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/icmp_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/mdns_ssdp_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/onvif_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/tcp_probe_discovery_strategy.dart';

// --- In-Memory Fake Device Repository for Testing ---
class FakeDeviceRepository implements DeviceRepository {
  final List<DeviceEntity> _devices = [];

  FakeDeviceRepository(List<DeviceEntity> initialDevices) {
    _devices.addAll(initialDevices);
  }

  @override
  Future<Result<List<DeviceEntity>>> getDevices({String? factoryId}) async {
    if (factoryId != null) {
      return Result.success(
        _devices.where((d) => d.factoryId == factoryId).toList(),
      );
    }
    return Result.success(List.from(_devices));
  }

  @override
  Future<Result<DeviceEntity>> getDeviceById(int id) async {
    final dev = _devices.where((d) => d.id == id).firstOrNull;
    if (dev != null) return Result.success(dev);
    return Result.failure(
      Exception('Device not found with ID: $id') as dynamic,
    );
  }

  @override
  Future<Result<DeviceEntity>> addDevice(DeviceEntity device) async {
    final newId = _devices.length + 1;
    final saved = device.copyWith(id: newId);
    _devices.add(saved);
    return Result.success(saved);
  }

  @override
  Future<Result<DeviceEntity>> updateDevice(DeviceEntity device) async {
    final idx = _devices.indexWhere((d) => d.id == device.id);
    if (idx != -1) _devices[idx] = device;
    return Result.success(device);
  }

  @override
  Future<Result<DeviceEntity>> assignDeviceOwner({
    required int deviceId,
    required String ownerName,
    String? adminUsername,
  }) async {
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx != -1) {
      final updated = _devices[idx].copyWith(ownerName: ownerName);
      _devices[idx] = updated;
      return Result.success(updated);
    }
    return Result.failure(
      Exception('Device not found with ID: $deviceId') as dynamic,
    );
  }

  @override
  Future<Result<void>> deleteDevice(int id) async {
    _devices.removeWhere((d) => d.id == id);
    return Result.success(null);
  }

  @override
  Future<Result<void>> toggleDeviceMonitoring({
    required int deviceId,
    required bool isEnabled,
  }) async {
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx != -1) {
      _devices[idx] = _devices[idx].copyWith(isEnabled: isEnabled);
    }
    return Result.success(null);
  }

  @override
  Future<Result<InventoryImportPreview>> parseAndValidateImport(
    List<int> bytes,
    String filename,
  ) async {
    return Result.success(
      const InventoryImportPreview(
        validDevices: [],
        excludedDuplicateIps: [],
        invalidRecords: [],
        totalRowsProcessed: 0,
      ),
    );
  }

  @override
  Future<Result<int>> commitImport(List<DeviceEntity> validDevices) async {
    _devices.addAll(validDevices);
    return Result.success(validDevices.length);
  }

  @override
  Future<Result<int>> bootstrapApprovedInventory({bool force = false}) async {
    return Result.success(_devices.length);
  }

  @override
  Future<Result<int>> reassignDevicesFactory({
    required List<int> deviceIds,
    required String targetFactoryId,
    String? adminUsername,
  }) async {
    int updatedCount = 0;
    for (int i = 0; i < _devices.length; i++) {
      if (deviceIds.contains(_devices[i].id)) {
        _devices[i] = _devices[i].copyWith(factoryId: targetFactoryId);
        updatedCount++;
      }
    }
    return Result.success(updatedCount);
  }

  @override
  Future<Result<int>> deleteDevices(List<int> deviceIds) async {
    final before = _devices.length;
    _devices.removeWhere((d) => deviceIds.contains(d.id));
    return Result.success(before - _devices.length);
  }

  @override
  Future<Result<int>> bulkUpdateDevices({
    required List<int> deviceIds,
    DeviceType? type,
    String? department,
    String? officeLocation,
    String? vendor,
    bool? isMonitored,
    bool? isEnabled,
  }) async {
    int updatedCount = 0;
    for (int i = 0; i < _devices.length; i++) {
      if (deviceIds.contains(_devices[i].id)) {
        _devices[i] = _devices[i].copyWith(
          department: department ?? _devices[i].department,
          officeLocation: officeLocation ?? _devices[i].officeLocation,
          type: type ?? _devices[i].type,
          vendor: vendor ?? _devices[i].vendor,
          isMonitored: isMonitored ?? _devices[i].isMonitored,
          isEnabled: isEnabled ?? _devices[i].isEnabled,
        );
        updatedCount++;
      }
    }
    return Result.success(updatedCount);
  }
}

// --- Mock Strategies for Deterministic Testing ---
class MockIcmpStrategy extends IcmpDiscoveryStrategy {
  final Set<String> responsiveIps;
  MockIcmpStrategy(this.responsiveIps);

  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async {
    if (responsiveIps.contains(targetIp)) {
      return StrategyProbeResult.success(
        strategyName: name,
        targetIp: targetIp,
        evidenceDetails: 'ICMP echo reply in 4ms',
      );
    }
    return StrategyProbeResult.failure(
      strategyName: name,
      targetIp: targetIp,
      errorMessage: 'Request timed out',
    );
  }
}

class MockArpStrategy extends ArpDiscoveryStrategy {
  final Map<String, String> ipToMac;
  MockArpStrategy(this.ipToMac, MacVendorLookup vendorLookup)
    : super(vendorLookup);

  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async {
    if (ipToMac.containsKey(targetIp)) {
      return StrategyProbeResult.success(
        strategyName: name,
        targetIp: targetIp,
        evidenceDetails: 'Dynamic ARP entry: ${ipToMac[targetIp]}',
        mac: ipToMac[targetIp],
      );
    }
    return StrategyProbeResult.failure(
      strategyName: name,
      targetIp: targetIp,
      errorMessage: 'No ARP entry',
    );
  }
}

class MockDnsStrategy extends DnsHostnameStrategy {
  final Map<String, String> ipToHost;
  MockDnsStrategy(this.ipToHost);

  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async {
    if (ipToHost.containsKey(targetIp)) {
      return StrategyProbeResult.success(
        strategyName: name,
        targetIp: targetIp,
        evidenceDetails: 'PTR record: ${ipToHost[targetIp]}',
        hostname: ipToHost[targetIp],
      );
    }
    return StrategyProbeResult.failure(
      strategyName: name,
      targetIp: targetIp,
      errorMessage: 'DNS resolution failed',
    );
  }
}

class MockTcpStrategy extends TcpProbeDiscoveryStrategy {
  final Map<String, List<int>> ipToPorts;
  MockTcpStrategy(this.ipToPorts);

  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async {
    if (ipToPorts.containsKey(targetIp)) {
      final ports = ipToPorts[targetIp]!;
      return StrategyProbeResult.success(
        strategyName: name,
        targetIp: targetIp,
        evidenceDetails: 'Open TCP ports: ${ports.join(", ")}',
        observedServices: ports.map((p) => 'port:$p').toList(),
      );
    }
    return StrategyProbeResult.failure(
      strategyName: name,
      targetIp: targetIp,
      errorMessage: 'No open ports',
    );
  }
}

class MockOnvifStrategy extends OnvifDiscoveryStrategy {
  final Set<String> cameraIps;
  MockOnvifStrategy(this.cameraIps);

  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async {
    if (cameraIps.contains(targetIp)) {
      return StrategyProbeResult.success(
        strategyName: name,
        targetIp: targetIp,
        evidenceDetails:
            'ONVIF WS-Discovery probe responded; RTSP port 554 active',
        observedServices: ['onvif:8000', 'rtsp:554'],
      );
    }
    return StrategyProbeResult.failure(
      strategyName: name,
      targetIp: targetIp,
      errorMessage: 'ONVIF probe failed',
    );
  }
}

class MockMdnsStrategy extends MdnsSsdpDiscoveryStrategy {
  final Map<String, List<String>> ipToServices;
  MockMdnsStrategy(this.ipToServices);

  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async {
    if (ipToServices.containsKey(targetIp)) {
      return StrategyProbeResult.success(
        strategyName: name,
        targetIp: targetIp,
        evidenceDetails: 'mDNS services: ${ipToServices[targetIp]!.join(", ")}',
        observedServices: ipToServices[targetIp]!,
      );
    }
    return StrategyProbeResult.failure(
      strategyName: name,
      targetIp: targetIp,
      errorMessage: 'No mDNS advertisements',
    );
  }
}

void main() {
  group('Network Discovery & Device Classification Tests', () {
    late AppDatabase db;
    late DiscoveryRepository discoveryRepo;
    late MacVendorLookup vendorLookup;
    late DeviceClassificationEngine classifier;
    late NetworkRangeValidator rangeValidator;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      discoveryRepo = DiscoveryRepositoryImpl(db);
      vendorLookup = MacVendorLookup();
      classifier = DeviceClassificationEngine(vendorLookup);
      rangeValidator = NetworkRangeValidator();
    });

    tearDown(() async {
      await db.close();
    });

    group('1. CIDR Parsing and Usable Target Enumeration', () {
      test('1.1 Initial authorized ranges parse correctly', () {
        final r1 = NetworkRange.parse('192.168.27.0/24');
        expect(r1, isNotNull);
        expect(r1!.baseIp, equals('192.168.27.0'));
        expect(r1.prefixLength, equals(24));
        expect(r1.usableHostsCount, equals(254));

        final r2 = NetworkRange.parse('192.168.22.0/24');
        expect(r2, isNotNull);
        expect(r2!.baseIp, equals('192.168.22.0'));
        expect(r2.prefixLength, equals(24));
        expect(r2.usableHostsCount, equals(254));
      });

      test(
        '1.2 Usable host enumeration yields exactly 254 addresses and excludes .0 and .255',
        () {
          final r = NetworkRange.parse('192.168.27.0/24')!;
          final hosts = r.enumerateUsableHosts();

          expect(hosts.length, equals(254));
          expect(hosts.first, equals('192.168.27.1'));
          expect(hosts.last, equals('192.168.27.254'));
          expect(
            hosts.contains('192.168.27.0'),
            isFalse,
            reason: 'Network address must be excluded',
          );
          expect(
            hosts.contains('192.168.27.255'),
            isFalse,
            reason: 'Broadcast address must be excluded',
          );
        },
      );

      test(
        '1.3 Combined initial ranges enumerate exactly 508 total candidate targets',
        () {
          final r1 = NetworkRange.parse('192.168.27.0/24')!;
          final r2 = NetworkRange.parse('192.168.22.0/24')!;
          final allHosts = [
            ...r1.enumerateUsableHosts(),
            ...r2.enumerateUsableHosts(),
          ];

          expect(allHosts.length, equals(508));
          expect(
            allHosts.toSet().length,
            equals(508),
            reason: 'All candidate targets must be distinct',
          );
        },
      );

      test(
        '1.4 Out-of-scope and invalid CIDRs are correctly identified and rejected',
        () {
          expect(NetworkRange.parse('invalid_string'), isNull);
          expect(NetworkRange.parse('999.1.1.1/24'), isNull);
          expect(NetworkRange.parse('192.168.1.1/33'), isNull);
          expect(NetworkRange.parse('192.168.1.1/0'), isNull);

          final r = NetworkRange.parse('192.168.27.0/24')!;
          expect(r.containsIp('192.168.27.50'), isTrue);
          expect(r.containsIp('192.168.22.50'), isFalse);
          expect(r.containsIp('10.0.0.1'), isFalse);
        },
      );

      test(
        '1.5 NetworkRangeValidator calculates totals and checks reachability states',
        () {
          final validRanges = rangeValidator.validateRanges([
            '192.168.27.0/24',
            '192.168.22.0/24',
            'invalid',
          ]);
          expect(validRanges.length, equals(2));
          expect(
            rangeValidator.calculateTotalUsableHosts(validRanges),
            equals(508),
          );

          expect(
            rangeValidator.isIpInScope('192.168.27.64', validRanges),
            isTrue,
          );
          expect(rangeValidator.isIpInScope('10.0.0.1', validRanges), isFalse);

          final reachReachable = rangeValidator.evaluateSubnetReachability(
            range: validRanges[0],
            hasAnyResponse: true,
            routingError: false,
          );
          expect(reachReachable, equals(ReachabilityStatus.reachable));

          final reachInaccessible = rangeValidator.evaluateSubnetReachability(
            range: validRanges[1],
            hasAnyResponse: false,
            routingError: true,
          );
          expect(reachInaccessible, equals(ReachabilityStatus.inaccessible));
        },
      );
    });

    group('2. MAC Vendor Lookup', () {
      test(
        '2.1 Recognizes prominent enterprise and consumer vendors from MAC OUI',
        () {
          expect(
            vendorLookup.lookupVendor('00:00:0c:11:22:33'),
            contains('Cisco'),
          );
          expect(
            vendorLookup.lookupVendor('d4:61:9d:aa:bb:cc'),
            contains('MikroTik'),
          );
          expect(
            vendorLookup.lookupVendor('24:a4:3c:01:02:03'),
            contains('Ubiquiti'),
          );
          expect(
            vendorLookup.lookupVendor('00:14:22:99:88:77'),
            contains('Dell'),
          );
          expect(
            vendorLookup.lookupVendor('3c:d9:2b:11:22:33'),
            contains('HP'),
          );
          expect(
            vendorLookup.lookupVendor('bc:54:51:44:55:66'),
            contains('Hikvision'),
          );
          expect(
            vendorLookup.lookupVendor('3c:ef:8c:77:88:99'),
            contains('Dahua'),
          );
          expect(
            vendorLookup.lookupVendor('f8:75:a4:12:34:56'),
            contains('Apple'),
          );
        },
      );

      test(
        '2.2 Handles unknown and locally administered MAC addresses gracefully',
        () {
          expect(vendorLookup.lookupVendor(null), isNull);
          expect(vendorLookup.lookupVendor(''), isNull);
          expect(
            vendorLookup.lookupVendor('02:00:00:11:22:33'),
            equals('Locally Administered / Randomized MAC'),
          );
          expect(
            vendorLookup.lookupVendor('00:01:02:03:04:05'),
            isNull,
            reason: 'Globally unique unknown vendor OUI',
          );
        },
      );
    });

    group('3. Deterministic Device Classification Engine', () {
      test(
        '3.1 Classifies IP Camera with high confidence from ONVIF/RTSP probe evidence',
        () {
          final decision = classifier.classify(
            ip: '192.168.27.80',
            mac: 'bc:54:51:11:22:33', // Hikvision
            hostname: null,
            observedServices: ['onvif:8000', 'rtsp:554', 'port:8000'],
            evidence: [
              DiscoveryEvidenceItem(
                strategyName: 'onvif',
                probeTarget: '192.168.27.80',
                isSuccess: true,
                details: 'ONVIF WS-Discovery probe responded',
                timestamp: DateTime.now(),
              ),
            ],
          );

          expect(decision.category, equals(DeviceCategory.ipCamera));
          expect(decision.confidence, equals(ClassificationConfidence.high));
          expect(
            decision.reasons.any(
              (r) => r.contains('ONVIF') || r.contains('camera'),
            ),
            isTrue,
          );
        },
      );

      test(
        '3.2 Classifies Printer with high confidence from port 9100/631 or vendor',
        () {
          final decision = classifier.classify(
            ip: '192.168.27.150',
            mac: '3c:d9:2b:11:22:33', // HP Printer
            hostname: 'HP-LaserJet-M404',
            observedServices: ['port:9100', 'port:631'],
          );

          expect(decision.category, equals(DeviceCategory.printer));
          expect(decision.confidence, equals(ClassificationConfidence.high));
        },
      );

      test(
        '3.3 Classifies Switch / Router from hostname and network manufacturer',
        () {
          final switchDec = classifier.classify(
            ip: '192.168.27.2',
            mac: '00:00:0c:11:22:33', // Cisco
            hostname: 'SW-CORE-FLOOR1',
            observedServices: ['port:22', 'port:80'],
          );
          expect(switchDec.category, equals(DeviceCategory.switchDevice));
          expect(switchDec.confidence, equals(ClassificationConfidence.high));

          final routerDec = classifier.classify(
            ip: '192.168.27.1',
            mac: 'd4:61:9d:11:22:33', // MikroTik
            hostname: 'GW-FIREWALL-MAIN',
            observedServices: ['port:80', 'port:443'],
          );
          expect(routerDec.category, equals(DeviceCategory.router));
          expect(routerDec.confidence, equals(ClassificationConfidence.high));
        },
      );

      test(
        '3.4 Classifies Server from server hostname pattern and virtualization stack',
        () {
          final serverDec = classifier.classify(
            ip: '192.168.27.10',
            mac: '00:50:56:11:22:33', // VMware
            hostname: 'SRV-FILE-01',
            observedServices: ['port:445', 'port:22'],
          );
          expect(serverDec.category, equals(DeviceCategory.server));
          expect(serverDec.confidence, equals(ClassificationConfidence.high));
        },
      );

      test(
        '3.5 Classifies PC and Laptop from client workstation naming and vendor',
        () {
          final pcDec = classifier.classify(
            ip: '192.168.27.64',
            mac: '00:14:22:11:22:33', // Dell
            hostname: 'PC-ADMIN-SALAH',
            observedServices: ['port:445'],
          );
          expect(pcDec.category, equals(DeviceCategory.pc));
          expect(pcDec.confidence, equals(ClassificationConfidence.high));

          final laptopDec = classifier.classify(
            ip: '192.168.27.65',
            mac: '54:ee:75:11:22:33', // Lenovo
            hostname: 'LT-ENGINEERING-02',
            observedServices: [],
          );
          expect(laptopDec.category, equals(DeviceCategory.laptop));
          expect(laptopDec.confidence, equals(ClassificationConfidence.high));
        },
      );

      test(
        '3.6 Returns Unknown with low confidence when evidence is insufficient (no guessing)',
        () {
          final silentDec = classifier.classify(
            ip: '192.168.27.99',
            mac: null,
            hostname: null,
            observedServices: [],
          );
          expect(silentDec.category, equals(DeviceCategory.unknown));
          expect(
            silentDec.confidence,
            equals(ClassificationConfidence.unknown),
          );
        },
      );

      test('3.7 Manual Admin override takes absolute precedence', () {
        final overrideDec = classifier.classify(
          ip: '192.168.27.150',
          mac: '3c:d9:2b:11:22:33',
          hostname: 'HP-LaserJet-M404',
          observedServices: ['port:9100'],
          adminOverride: DeviceCategory.server,
        );
        expect(overrideDec.category, equals(DeviceCategory.server));
        expect(overrideDec.confidence, equals(ClassificationConfidence.high));
        expect(overrideDec.reasons.first, contains('Admin user confirmed'));
      });
    });

    group(
      '4. Duplicate Detection & Existing Production Inventory Protection',
      () {
        test(
          '4.1 Discovered device matching an existing approved device is marked AlreadyKnown',
          () async {
            final existingDevices = [
              DeviceEntity(
                id: 1,
                name: 'PC-FIN-01',
                type: DeviceType.pc,
                ip: '192.168.27.50',
                ownerName: 'Accounting Lead',
                department: 'Finance',
                createdAt: DateTime.now(),
              ),
              DeviceEntity(
                id: 2,
                name: 'LT-HR-02',
                type: DeviceType.laptop,
                ip: '192.168.27.51',
                ownerName: 'HR Recruiter',
                department: 'HR',
                createdAt: DateTime.now(),
              ),
            ];

            final fakeDeviceRepo = FakeDeviceRepository(existingDevices);

            final mockIcmp = MockIcmpStrategy({
              '192.168.27.50',
              '192.168.27.99',
            });
            final mockArp = MockArpStrategy({
              '192.168.27.50': '00:14:22:aa:bb:cc',
              '192.168.27.99': 'bc:54:51:11:22:33',
            }, vendorLookup);
            final mockDns = MockDnsStrategy({'192.168.27.50': 'PC-FIN-01.lan'});
            final mockTcp = MockTcpStrategy({});
            final mockOnvif = MockOnvifStrategy({'192.168.27.99'});
            final mockMdns = MockMdnsStrategy({});

            final coordinator = DiscoveryCoordinator(
              discoveryRepo,
              fakeDeviceRepo,
              rangeValidator,
              classifier,
              vendorLookup,
              mockIcmp,
              mockArp,
              mockDns,
              mockTcp,
              mockOnvif,
              mockMdns,
            );

            // Run scan on subset
            final startRes = await coordinator.startScan(
              requestedRanges: ['192.168.27.0/24'],
              enabledStrategies: ['icmp', 'arp', 'dns', 'onvif'],
            );

            expect(startRes.isSuccess, isTrue);

            // Wait for scan pipeline completion
            await Future.delayed(const Duration(milliseconds: 300));

            final devicesRes = await discoveryRepo.getDiscoveredDevices();
            expect(devicesRes.isSuccess, isTrue);
            final devices = devicesRes.dataOrNull!;
            expect(devices.length, equals(2));

            // 192.168.27.50 matches existing device #1
            final knownDev = devices.firstWhere((d) => d.ip == '192.168.27.50');
            expect(knownDev.reviewState, equals(ReviewState.alreadyKnown));
            expect(knownDev.associatedDeviceId, equals(1));

            // 192.168.27.99 is brand new Camera -> pendingReview
            final newCam = devices.firstWhere((d) => d.ip == '192.168.27.99');
            expect(newCam.reviewState, equals(ReviewState.pendingReview));
            expect(newCam.predictedCategory, equals(DeviceCategory.ipCamera));
          },
        );
      },
    );

    group('5. Discovery Coordinator Lifecycle & Cancellation', () {
      test('5.1 Scan progression completes and records metrics', () async {
        final fakeDeviceRepo = FakeDeviceRepository([]);
        final mockIcmp = MockIcmpStrategy({'192.168.27.10', '192.168.27.11'});
        final mockArp = MockArpStrategy({
          '192.168.27.10': '00:14:22:11:22:33',
        }, vendorLookup);
        final mockDns = MockDnsStrategy({'192.168.27.10': 'SRV-BACKUP'});
        final mockTcp = MockTcpStrategy({
          '192.168.27.10': [22, 445],
        });
        final mockOnvif = MockOnvifStrategy({});
        final mockMdns = MockMdnsStrategy({});

        final coordinator = DiscoveryCoordinator(
          discoveryRepo,
          fakeDeviceRepo,
          rangeValidator,
          classifier,
          vendorLookup,
          mockIcmp,
          mockArp,
          mockDns,
          mockTcp,
          mockOnvif,
          mockMdns,
        );

        final startRes = await coordinator.startScan(
          requestedRanges: ['192.168.27.0/24'],
          enabledStrategies: ['icmp', 'arp', 'dns', 'tcp_probe'],
        );

        expect(startRes.isSuccess, isTrue);
        expect(coordinator.isScanning, isTrue);

        await Future.delayed(const Duration(milliseconds: 300));

        final scanRes = await discoveryRepo.getScanJob(startRes.dataOrNull!.id);
        expect(scanRes.isSuccess, isTrue);
        expect(scanRes.dataOrNull!.status, equals(ScanJobStatus.completed));
        expect(scanRes.dataOrNull!.responsesReceived, equals(2));
      });

      test(
        '5.2 Cancellation stops scan and updates job status to cancelled',
        () async {
          final fakeDeviceRepo = FakeDeviceRepository([]);
          final mockIcmp = MockIcmpStrategy({'192.168.27.1'});
          final mockArp = MockArpStrategy({}, vendorLookup);
          final mockDns = MockDnsStrategy({});
          final mockTcp = MockTcpStrategy({});
          final mockOnvif = MockOnvifStrategy({});
          final mockMdns = MockMdnsStrategy({});

          final coordinator = DiscoveryCoordinator(
            discoveryRepo,
            fakeDeviceRepo,
            rangeValidator,
            classifier,
            vendorLookup,
            mockIcmp,
            mockArp,
            mockDns,
            mockTcp,
            mockOnvif,
            mockMdns,
          );

          final startRes = await coordinator.startScan(
            requestedRanges: ['192.168.27.0/24'], // 254 hosts
            enabledStrategies: ['icmp'],
          );
          expect(startRes.isSuccess, isTrue);

          // Cancel immediately
          final cancelRes = await coordinator.cancelScan();
          expect(cancelRes.isSuccess, isTrue);
          expect(coordinator.isScanning, isFalse);

          final scanRes = await discoveryRepo.getScanJob(
            startRes.dataOrNull!.id,
          );
          expect(scanRes.dataOrNull!.status, equals(ScanJobStatus.cancelled));
        },
      );
    });

    group('6. Admin Approval Workflow & Asset Segregation', () {
      test(
        '6.1 Approving a discovered PC adds it to DeviceRepository with required owner & department',
        () async {
          final fakeDeviceRepo = FakeDeviceRepository([]);

          final saveRes = await discoveryRepo.saveDiscoveredDevice(
            DiscoveredDeviceEntity(
              scanId: 1,
              ip: '192.168.27.77',
              mac: '00:14:22:99:88:77',
              hostname: 'PC-SALES-NEW',
              vendor: 'Dell Inc.',
              observedServices: const ['port:445'],
              predictedCategory: DeviceCategory.pc,
              confidence: ClassificationConfidence.high,
              firstSeen: DateTime.now(),
              lastSeen: DateTime.now(),
              reviewState: ReviewState.pendingReview,
            ),
          );
          expect(saveRes.isSuccess, isTrue);
          final devId = saveRes.dataOrNull!;

          // Admin approves as PC
          final addRes = await fakeDeviceRepo.addDevice(
            DeviceEntity(
              id: 0,
              name: 'PC-SALES-NEW',
              type: DeviceType.pc,
              ip: '192.168.27.77',
              ownerName: 'Khaled Hassan',
              department: 'Sales',
              createdAt: DateTime.now(),
            ),
          );
          expect(addRes.isSuccess, isTrue);

          await discoveryRepo.updateDeviceReview(
            deviceId: devId,
            state: ReviewState.approved,
            confirmedCategory: DeviceCategory.pc,
            reviewerId: 1,
          );

          // Verify discovered record updated
          final updatedRes = await discoveryRepo.getDiscoveredDeviceByIp(
            '192.168.27.77',
          );
          expect(
            updatedRes.dataOrNull!.reviewState,
            equals(ReviewState.approved),
          );
          expect(
            updatedRes.dataOrNull!.adminConfirmedCategory,
            equals(DeviceCategory.pc),
          );

          // Verify monitoring repository contains device
          final allDevsRes = await fakeDeviceRepo.getDevices();
          expect(
            allDevsRes.dataOrNull!.any((d) => d.ip == '192.168.27.77'),
            isTrue,
          );
        },
      );

      test(
        '6.2 Approving an IP Camera or Network Device keeps it as asset only (not added to PC monitoring)',
        () async {
          final fakeDeviceRepo = FakeDeviceRepository([]);

          final saveRes = await discoveryRepo.saveDiscoveredDevice(
            DiscoveredDeviceEntity(
              scanId: 1,
              ip: '192.168.27.199',
              mac: 'bc:54:51:11:22:33',
              hostname: 'CAM-WAREHOUSE-01',
              vendor: 'Hikvision Digital Technology',
              observedServices: const ['onvif:8000', 'rtsp:554'],
              predictedCategory: DeviceCategory.ipCamera,
              confidence: ClassificationConfidence.high,
              firstSeen: DateTime.now(),
              lastSeen: DateTime.now(),
              reviewState: ReviewState.pendingReview,
            ),
          );
          expect(saveRes.isSuccess, isTrue);
          final devId = saveRes.dataOrNull!;

          // Admin approves as IP Camera (asset only)
          await discoveryRepo.updateDeviceReview(
            deviceId: devId,
            state: ReviewState.approved,
            confirmedCategory: DeviceCategory.ipCamera,
            reviewerId: 1,
          );

          // Discovered record is approved
          final updatedRes = await discoveryRepo.getDiscoveredDeviceByIp(
            '192.168.27.199',
          );
          expect(
            updatedRes.dataOrNull!.reviewState,
            equals(ReviewState.approved),
          );
          expect(
            updatedRes.dataOrNull!.adminConfirmedCategory,
            equals(DeviceCategory.ipCamera),
          );

          // CRITICAL CHECK: PC/Laptop monitoring inventory is untouched (0 devices)
          final monitoredDevs = await fakeDeviceRepo.getDevices();
          expect(
            monitoredDevs.dataOrNull!.isEmpty,
            isTrue,
            reason:
                'Non-PC/Laptop assets must never be added to PC monitoring inventory',
          );
        },
      );

      test(
        '6.3 Admin rejection updates review state to rejected and leaves inventory untouched',
        () async {
          final fakeDeviceRepo = FakeDeviceRepository([]);

          final saveRes = await discoveryRepo.saveDiscoveredDevice(
            DiscoveredDeviceEntity(
              scanId: 1,
              ip: '192.168.27.240',
              mac: null,
              hostname: 'GUEST-PHONE-UNKNOWN',
              vendor: null,
              observedServices: const [],
              predictedCategory: DeviceCategory.mobile,
              confidence: ClassificationConfidence.low,
              firstSeen: DateTime.now(),
              lastSeen: DateTime.now(),
              reviewState: ReviewState.pendingReview,
            ),
          );
          final devId = saveRes.dataOrNull!;

          await discoveryRepo.updateDeviceReview(
            deviceId: devId,
            state: ReviewState.rejected,
            reviewerId: 1,
          );

          final updatedRes = await discoveryRepo.getDiscoveredDeviceByIp(
            '192.168.27.240',
          );
          expect(
            updatedRes.dataOrNull!.reviewState,
            equals(ReviewState.rejected),
          );

          final allDevs = await fakeDeviceRepo.getDevices();
          expect(allDevs.dataOrNull!.isEmpty, isTrue);
        },
      );
    });

    group('7. Drift Persistence & Schema V5', () {
      test(
        '7.1 Configuration can be retrieved and updated dynamically',
        () async {
          final initialConfigRes = await discoveryRepo.getConfig();
          expect(initialConfigRes.isSuccess, isTrue);
          final initial = initialConfigRes.dataOrNull!;
          expect(initial.authorizedRanges, isEmpty);

          final updatedConfig = initial.copyWith(
            networkRanges: [NetworkRange.parse('10.10.20.0/24')!],
            maxConcurrency: 35,
            timeoutSeconds: 3,
          );
          final saveRes = await discoveryRepo.saveConfig(updatedConfig);
          expect(saveRes.isSuccess, isTrue);

          final reloadedRes = await discoveryRepo.getConfig();
          expect(reloadedRes.dataOrNull!.maxConcurrency, equals(35));
          expect(reloadedRes.dataOrNull!.timeoutSeconds, equals(3));
          expect(
            reloadedRes.dataOrNull!.authorizedRanges,
            contains('10.10.20.0/24'),
          );
        },
      );

      test(
        '7.2 Detailed evidence items are saved and retrievable by device ID',
        () async {
          final devRes = await discoveryRepo.saveDiscoveredDevice(
            DiscoveredDeviceEntity(
              scanId: 1,
              ip: '192.168.27.4',
              firstSeen: DateTime.now(),
              lastSeen: DateTime.now(),
            ),
          );
          final devId = devRes.dataOrNull!;

          await discoveryRepo.saveEvidence(
            devId,
            DiscoveryEvidenceItem(
              strategyName: 'icmp',
              probeTarget: '192.168.27.4',
              isSuccess: true,
              details: 'ICMP echo reply received in 2ms',
              timestamp: DateTime.now(),
            ),
          );
          await discoveryRepo.saveEvidence(
            devId,
            DiscoveryEvidenceItem(
              strategyName: 'arp',
              probeTarget: '192.168.27.4',
              isSuccess: true,
              details: 'Dynamic ARP mapping: 00:14:22:01:02:03',
              timestamp: DateTime.now(),
            ),
          );

          final evidenceRes = await discoveryRepo.getEvidenceForDevice(devId);
          expect(evidenceRes.isSuccess, isTrue);
          expect(evidenceRes.dataOrNull!.length, equals(2));
        },
      );
    });
  });
}
