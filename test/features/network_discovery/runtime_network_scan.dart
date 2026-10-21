// ignore_for_file: avoid_print, unused_import
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/features/devices/data/datasources/approved_inventory_seed.dart';
import 'package:it_network_monitor/features/devices/domain/repositories/device_repository.dart';
import 'package:it_network_monitor/features/devices/domain/services/inventory_validator.dart';
import 'package:it_network_monitor/features/network_discovery/data/repositories/discovery_repository_impl.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/device_category.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/discovery_scan_job.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/network_range.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/device_classification_engine.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/discovery_coordinator.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/mac_vendor_lookup.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/network_range_validator.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/arp_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/dns_hostname_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/icmp_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/mdns_ssdp_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/onvif_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/tcp_probe_discovery_strategy.dart';
import 'network_discovery_test.dart'; // Uses FakeDeviceRepository

void main() {
  test('Execute Real Network Discovery Scan on Authorized Corporate Ranges', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final discoveryRepo = DiscoveryRepositoryImpl(db);

    // Bootstrap approved 37 devices so duplicate & alreadyKnown logic is active
    final approvedRows = ApprovedInventorySeed.getApprovedRawRows();
    final preview = InventoryValidator.validateRows(rows: approvedRows);
    final approved37Devices = preview.validDevices;
    final deviceRepo = FakeDeviceRepository(approved37Devices);
    final existingMonitoredRes = await deviceRepo.getDevices();
    final existingCount = existingMonitoredRes.dataOrNull?.length ?? 0;
    print(
      'Initial Monitored Production Devices in DB: $existingCount (Expected 37)',
    );
    expect(existingCount, equals(37));

    final vendorLookup = MacVendorLookup();
    final classifier = DeviceClassificationEngine(vendorLookup);
    final rangeValidator = NetworkRangeValidator();

    // Instantiate real production discovery strategies
    final icmp = IcmpDiscoveryStrategy();
    final arp = ArpDiscoveryStrategy(vendorLookup);
    final dns = DnsHostnameStrategy();
    final tcp = TcpProbeDiscoveryStrategy();
    final onvif = OnvifDiscoveryStrategy();
    final mdns = MdnsSsdpDiscoveryStrategy();

    final coordinator = DiscoveryCoordinator(
      discoveryRepo,
      deviceRepo,
      rangeValidator,
      classifier,
      vendorLookup,
      icmp,
      arp,
      dns,
      tcp,
      onvif,
      mdns,
    );

    // Target authorized scopes: 192.168.27.0/24 and 192.168.22.0/24
    // 508 total candidate targets
    print(
      '--- Starting Real Discovery Scan on 192.168.27.0/24 and 192.168.22.0/24 ---',
    );
    final stopwatch = Stopwatch()..start();

    // To scan cleanly without overloading the network, we scan 192.168.27.0/24 with concurrency 30
    final startRes = await coordinator.startScan(
      requestedRanges: ['192.168.27.0/24', '192.168.22.0/24'],
      enabledStrategies: ['icmp', 'arp', 'dns', 'tcp_probe'],
      maxConcurrency: 30,
      timeoutSeconds: 1,
    );

    expect(
      startRes.isSuccess,
      isTrue,
      reason: 'Scan job must start successfully',
    );
    final scanJob = startRes.dataOrNull!;
    print(
      'Scan Job Started with ID: ${scanJob.id}, Targets: ${scanJob.targetsEnumerated}',
    );

    // Monitor progress until finished
    await for (final progress in coordinator.progressStream) {
      if (progress.status.isFinished) {
        print('Scan Job Finished with Status: ${progress.status.displayName}');
        break;
      }
    }

    stopwatch.stop();
    print(
      'Scan Duration: ${stopwatch.elapsedMilliseconds} ms (${stopwatch.elapsed.inSeconds} seconds)',
    );

    // Fetch and analyze all discovered records
    final devicesRes = await discoveryRepo.getDiscoveredDevices(
      scanId: scanJob.id,
    );
    expect(devicesRes.isSuccess, isTrue);
    final devices = devicesRes.dataOrNull ?? [];

    print('=== REAL DISCOVERY SCAN RESULTS ===');
    print('Total Targets Enumerated: 508');
    print('Total Devices Responding: ${devices.length}');

    final categoryCounts = <DeviceCategory, int>{};
    int alreadyKnownCount = 0;
    int pendingReviewCount = 0;

    for (final dev in devices) {
      categoryCounts[dev.predictedCategory] =
          (categoryCounts[dev.predictedCategory] ?? 0) + 1;
      if (dev.reviewState.toValue() == 'already_known') {
        alreadyKnownCount++;
      } else {
        pendingReviewCount++;
      }
      print(
        'Discovered: IP=${dev.ip}, MAC=${dev.mac ?? 'N/A'}, Host=${dev.hostname ?? 'N/A'}, Vendor=${dev.vendor ?? 'N/A'}, Category=${dev.predictedCategory.displayName}, State=${dev.reviewState.displayName}, Conf=${dev.confidence.displayName}',
      );
    }

    print('Category Distribution: $categoryCounts');
    print('Already Known in Inventory: $alreadyKnownCount');
    print('Pending Review for Admin: $pendingReviewCount');

    // Confirm that the initial approved inventory was untouched
    final postScanMonitoredRes = await deviceRepo.getDevices();
    final postCount = postScanMonitoredRes.dataOrNull?.length ?? 0;
    expect(
      postCount,
      equals(existingCount),
      reason:
          'Discovery must never modify monitored inventory without explicit Admin approval',
    );
    print(
      'Post-Scan Monitored Production Devices in DB: $postCount (Unchanged!)',
    );

    await db.close();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
