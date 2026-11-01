import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:it_network_monitor/core/config/app_run_mode.dart';
import 'package:it_network_monitor/core/database/app_database.dart';

class _RawV12ExecutorUser extends QueryExecutorUser {
  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}

  @override
  int get schemaVersion => 12;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Issue 5: Real SQLite Database Migration Regression Test (v12 to v13)', () {
    late File testDbFile;

    setUp(() {
      AppConfig.enforceReleaseModeSecurity = false;
      AppConfig.resetForTesting(mode: AppRunMode.standaloneDevelopment);

      final tempDir = Directory.systemTemp.path;
      final uniqueName =
          'v12_to_v13_migration_${DateTime.now().microsecondsSinceEpoch}.db';
      testDbFile = File('$tempDir/$uniqueName');
    });

    tearDown(() async {
      if (testDbFile.existsSync()) {
        try {
          testDbFile.deleteSync();
        } catch (_) {}
      }
    });

    test(
      'Genuine v12 SQLite database upgraded to v13 schema preserving all data and relationships',
      () async {
        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final originalCreatedAt = nowSec - 86400; // 1 day ago

        // ──────────────────────────────────────────────────────────────────────────
        // Step 1: Create a SQLite database using the PREVIOUS v12 schema
        // ──────────────────────────────────────────────────────────────────────────
        final rawV12Db = NativeDatabase(testDbFile);
        await rawV12Db.ensureOpen(_RawV12ExecutorUser());

        // 1. Factories table (v12 schema WITHOUT network columns)
        await rawV12Db.runCustom('''
        CREATE TABLE factories (
          id TEXT NOT NULL PRIMARY KEY,
          code TEXT NOT NULL UNIQUE,
          name TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER
        );
      ''');

        // 2. Users table
        await rawV12Db.runCustom('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL UNIQUE,
          password_hash TEXT NOT NULL,
          role TEXT NOT NULL DEFAULT 'viewer',
          is_enabled INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER,
          last_login_at INTEGER
        );
      ''');

        // 3. Audit logs
        await rawV12Db.runCustom('''
        CREATE TABLE audit_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER,
          username TEXT NOT NULL,
          action TEXT NOT NULL,
          details TEXT,
          timestamp INTEGER NOT NULL
        );
      ''');

        // 4. Locations table
        await rawV12Db.runCustom('''
        CREATE TABLE locations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          description TEXT
        );
      ''');

        // 5. Devices table (v12 has factory_id column and factory-scoped index)
        await rawV12Db.runCustom('''
        CREATE TABLE devices (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          factory_id TEXT NOT NULL DEFAULT 'unassigned',
          name TEXT NOT NULL,
          type TEXT NOT NULL DEFAULT 'pc',
          ip TEXT NOT NULL,
          owner_name TEXT NOT NULL,
          department TEXT NOT NULL,
          office_location TEXT,
          parent_switch_id INTEGER,
          parent_switch_name TEXT,
          vendor TEXT,
          model TEXT,
          mac TEXT,
          hostname TEXT,
          operating_system TEXT,
          notes TEXT,
          is_monitored INTEGER NOT NULL DEFAULT 1,
          is_enabled INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER
        );
      ''');
        await rawV12Db.runCustom('''
        CREATE UNIQUE INDEX idx_devices_factory_ip ON devices(factory_id, ip) WHERE ip != '' AND ip IS NOT NULL;
      ''');

        // 6. Check results (v12 has factory_id column)
        await rawV12Db.runCustom('''
        CREATE TABLE check_results (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          factory_id TEXT NOT NULL DEFAULT 'unassigned',
          device_id INTEGER NOT NULL,
          asset_id TEXT,
          target_ip TEXT NOT NULL,
          check_type TEXT NOT NULL DEFAULT 'icmp',
          is_success INTEGER NOT NULL,
          latency_ms INTEGER,
          packet_loss_percent REAL,
          error_message TEXT,
          timestamp INTEGER NOT NULL
        );
      ''');

        // 7. Device statuses
        await rawV12Db.runCustom('''
        CREATE TABLE device_statuses (
          device_id INTEGER PRIMARY KEY,
          status TEXT NOT NULL DEFAULT 'unknown',
          last_seen INTEGER,
          last_check_at INTEGER,
          last_latency_ms INTEGER,
          last_successful_latency_ms INTEGER,
          last_failure_reason TEXT,
          consecutive_failures INTEGER NOT NULL DEFAULT 0,
          consecutive_successes INTEGER NOT NULL DEFAULT 0,
          status_changed_at INTEGER NOT NULL,
          is_maintenance INTEGER NOT NULL DEFAULT 0
        );
      ''');

        // 8. Incidents (v12 has factory_id column)
        await rawV12Db.runCustom('''
        CREATE TABLE incidents (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          factory_id TEXT NOT NULL DEFAULT 'unassigned',
          device_id INTEGER NOT NULL,
          device_name TEXT NOT NULL,
          owner_name TEXT NOT NULL,
          department TEXT NOT NULL,
          location TEXT,
          device_ip TEXT NOT NULL,
          incident_type TEXT NOT NULL,
          severity TEXT NOT NULL DEFAULT 'critical',
          status TEXT NOT NULL DEFAULT 'active',
          started_at INTEGER NOT NULL,
          resolved_at INTEGER,
          acknowledged_at INTEGER,
          acknowledged_by TEXT,
          notes TEXT,
          correlation_message TEXT
        );
      ''');

        // 9. Discovery configurations
        await rawV12Db.runCustom('''
        CREATE TABLE discovery_configurations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          authorized_ranges_json TEXT NOT NULL DEFAULT '[]',
          enabled_strategies_json TEXT NOT NULL DEFAULT '["icmp","arp","dns","tcp_probe","onvif","mdns"]',
          max_concurrency INTEGER NOT NULL DEFAULT 20,
          timeout_seconds INTEGER NOT NULL DEFAULT 2,
          updated_at INTEGER NOT NULL
        );
      ''');

        // 10. Discovery scans
        await rawV12Db.runCustom('''
        CREATE TABLE discovery_scans (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          factory_id TEXT NOT NULL DEFAULT 'unassigned',
          status TEXT NOT NULL DEFAULT 'draft',
          ranges_json TEXT NOT NULL,
          enabled_strategies_json TEXT NOT NULL DEFAULT '["icmp","arp","dns","tcp_probe","onvif","mdns"]',
          started_at INTEGER NOT NULL,
          completed_at INTEGER,
          targets_enumerated INTEGER NOT NULL DEFAULT 0,
          targets_attempted INTEGER NOT NULL DEFAULT 0,
          responses_received INTEGER NOT NULL DEFAULT 0,
          classified_count INTEGER NOT NULL DEFAULT 0,
          unknown_count INTEGER NOT NULL DEFAULT 0,
          failure_count INTEGER NOT NULL DEFAULT 0,
          diagnostic_summary TEXT
        );
      ''');

        // 11. Discovered devices
        await rawV12Db.runCustom('''
        CREATE TABLE discovered_devices (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          scan_id INTEGER NOT NULL,
          factory_id TEXT NOT NULL DEFAULT 'unassigned',
          ip TEXT NOT NULL,
          mac TEXT,
          hostname TEXT,
          vendor TEXT,
          observed_services_json TEXT,
          predicted_category TEXT NOT NULL DEFAULT 'unknown',
          confidence TEXT NOT NULL DEFAULT 'unknown',
          evidence_json TEXT,
          classification_method TEXT NOT NULL DEFAULT 'multi_evidence_v1',
          first_seen INTEGER NOT NULL,
          last_seen INTEGER NOT NULL,
          last_successful_probe INTEGER,
          last_probe_failure_reason TEXT,
          review_state TEXT NOT NULL DEFAULT 'pending_review',
          admin_confirmed_category TEXT,
          admin_reviewer_id INTEGER,
          admin_review_timestamp INTEGER,
          associated_device_id INTEGER
        );
      ''');

        // 12. Discovery evidences
        await rawV12Db.runCustom('''
        CREATE TABLE discovery_evidences (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          discovered_device_id INTEGER NOT NULL,
          strategy_name TEXT NOT NULL,
          probe_target TEXT NOT NULL,
          is_success INTEGER NOT NULL,
          details TEXT NOT NULL,
          timestamp INTEGER NOT NULL
        );
      ''');

        // 13. Infrastructure devices
        await rawV12Db.runCustom('''
        CREATE TABLE infrastructure_devices (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          factory_id TEXT NOT NULL DEFAULT 'unassigned',
          name TEXT NOT NULL,
          ip TEXT NOT NULL,
          mac TEXT,
          role TEXT NOT NULL DEFAULT 'other_unknown',
          location TEXT,
          is_critical_infrastructure INTEGER NOT NULL DEFAULT 0,
          requires_admin_confirmation INTEGER NOT NULL DEFAULT 1,
          linked_subnets_json TEXT NOT NULL DEFAULT '[]',
          controller_url TEXT,
          site_name TEXT NOT NULL DEFAULT 'default',
          is_enabled INTEGER NOT NULL DEFAULT 1,
          is_read_only INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER
        );
      ''');

        // Set user_version to 12
        await rawV12Db.runCustom('PRAGMA user_version = 12;');

        // ──────────────────────────────────────────────────────────────────────────
        // Step 2-4: Insert representative v12 records
        // ──────────────────────────────────────────────────────────────────────────
        // Representative factories (WITHOUT gateway_ip, subnet_mask, expected_cidr)
        await rawV12Db.runCustom('''
        INSERT INTO factories (id, code, name, is_active, created_at)
        VALUES ('rnf', 'RNF', 'RNF Factory', 1, $nowSec);
      ''');
        await rawV12Db.runCustom('''
        INSERT INTO factories (id, code, name, is_active, created_at)
        VALUES ('bnf', 'BNF', 'BNF Factory', 1, $nowSec);
      ''');
        await rawV12Db.runCustom('''
        INSERT INTO factories (id, code, name, is_active, created_at)
        VALUES ('unassigned', 'UNASSIGNED', 'Unassigned / Needs Recovery', 1, $nowSec);
      ''');

        // Representative devices: RNF, BNF, and Unassigned
        await rawV12Db.runCustom('''
        INSERT INTO devices (id, factory_id, name, type, ip, owner_name, department, office_location, vendor, model, mac, hostname, operating_system, notes, is_monitored, is_enabled, created_at)
        VALUES (101, 'rnf', 'RNF-CORE-SWITCH', 'switch', '192.168.22.10', 'Ahmed Zaki', 'IT Infrastructure', 'Server Room A', 'Cisco', 'Catalyst 2960', '00:1A:2B:3C:4D:5E', 'rnf-sw-core', 'IOS', 'Critical rack switch', 1, 1, $originalCreatedAt);
      ''');

        await rawV12Db.runCustom('''
        INSERT INTO devices (id, factory_id, name, type, ip, owner_name, department, office_location, vendor, model, mac, hostname, operating_system, notes, is_monitored, is_enabled, created_at)
        VALUES (102, 'bnf', 'BNF-PACKAGING-PC', 'pc', '192.168.21.55', 'Sarah Connor', 'Production', 'Line 3 Station', 'Dell', 'OptiPlex 7090', '00:14:22:01:23:45', 'bnf-line3-pc', 'Windows 11', 'Packaging terminal', 1, 1, $originalCreatedAt);
      ''');

        await rawV12Db.runCustom('''
        INSERT INTO devices (id, factory_id, name, type, ip, owner_name, department, office_location, vendor, model, mac, hostname, operating_system, notes, is_monitored, is_enabled, created_at)
        VALUES (103, 'unassigned', 'LEGACY-ASSET-404', 'printer', '10.50.0.12', 'Unassigned Asset', 'Finance', 'Old Wing', 'HP', 'LaserJet M404', '00:1E:68:AA:BB:CC', 'hp-m404', 'Firmware', 'Needs factory physical audit', 1, 1, $originalCreatedAt);
      ''');

        // Check results for devices 101 and 102
        await rawV12Db.runCustom('''
        INSERT INTO check_results (id, factory_id, device_id, target_ip, check_type, is_success, latency_ms, packet_loss_percent, timestamp)
        VALUES (1, 'rnf', 101, '192.168.22.10', 'icmp', 1, 2, 0.0, $nowSec);
      ''');
        await rawV12Db.runCustom('''
        INSERT INTO check_results (id, factory_id, device_id, target_ip, check_type, is_success, latency_ms, packet_loss_percent, timestamp)
        VALUES (2, 'bnf', 102, '192.168.21.55', 'icmp', 1, 5, 0.0, $nowSec);
      ''');

        // Device statuses for devices 101, 102, 103
        await rawV12Db.runCustom('''
        INSERT INTO device_statuses (device_id, status, last_seen, last_check_at, last_latency_ms, last_successful_latency_ms, consecutive_failures, consecutive_successes, status_changed_at)
        VALUES (101, 'up', $nowSec, $nowSec, 2, 2, 0, 50, $nowSec);
      ''');
        await rawV12Db.runCustom('''
        INSERT INTO device_statuses (device_id, status, last_seen, last_check_at, last_latency_ms, last_successful_latency_ms, consecutive_failures, consecutive_successes, status_changed_at)
        VALUES (102, 'up', $nowSec, $nowSec, 5, 5, 0, 30, $nowSec);
      ''');
        await rawV12Db.runCustom('''
        INSERT INTO device_statuses (device_id, status, last_seen, last_check_at, last_latency_ms, last_successful_latency_ms, consecutive_failures, consecutive_successes, status_changed_at)
        VALUES (103, 'unknown', NULL, NULL, NULL, NULL, 0, 0, $nowSec);
      ''');

        // Incident referencing device 101
        await rawV12Db.runCustom('''
        INSERT INTO incidents (id, factory_id, device_id, device_name, owner_name, department, location, device_ip, incident_type, severity, status, started_at, notes)
        VALUES (1, 'rnf', 101, 'RNF-CORE-SWITCH', 'Ahmed Zaki', 'IT Infrastructure', 'Server Room A', '192.168.22.10', 'high_latency', 'medium', 'active', $nowSec, 'Temporary high jitter on port 4');
      ''');

        // Verify PRAGMA user_version is indeed 12 prior to upgrade
        final rawVersionResult = await rawV12Db.runSelect(
          'PRAGMA user_version;',
          [],
        );
        final preVersion = rawVersionResult.first['user_version'] as int;
        expect(
          preVersion,
          equals(12),
          reason: 'Database must start at v12 schema',
        );

        // Close raw database connection cleanly before opening with AppDatabase
        await rawV12Db.close();

        // ──────────────────────────────────────────────────────────────────────────
        // Step 5: Open the database using the new v13 application schema
        // ──────────────────────────────────────────────────────────────────────────
        final appDb = AppDatabase.forTesting(NativeDatabase(testDbFile));

        // Trigger schema upgrade by running a query
        final upgradedVersionRows = await appDb
            .customSelect('PRAGMA user_version;')
            .get();
        final upgradedVersion = upgradedVersionRows.first.read<int>(
          'user_version',
        );

        // ──────────────────────────────────────────────────────────────────────────
        // Step 6: Verify migration completes successfully and version is 13
        // ──────────────────────────────────────────────────────────────────────────
        expect(
          upgradedVersion,
          equals(13),
          reason: 'Database schema must be upgraded to v13',
        );

        // ──────────────────────────────────────────────────────────────────────────
        // Step 7: Verify all original device records still exist
        // ──────────────────────────────────────────────────────────────────────────
        final devices = await (appDb.select(
          appDb.devices,
        )..orderBy([(t) => OrderingTerm(expression: t.id)])).get();
        expect(
          devices.length,
          equals(3),
          reason: 'All 3 original devices must be retained',
        );

        // ──────────────────────────────────────────────────────────────────────────
        // Step 8: Verify IDs, IPs, owner, notes, timestamps, factoryIds remain unchanged
        // ──────────────────────────────────────────────────────────────────────────
        // Device 101 (RNF)
        final dev101 = devices.firstWhere((d) => d.id == 101);
        expect(dev101.id, equals(101));
        expect(dev101.factoryId, equals('rnf'));
        expect(dev101.name, equals('RNF-CORE-SWITCH'));
        expect(dev101.ip, equals('192.168.22.10'));
        expect(dev101.ownerName, equals('Ahmed Zaki'));
        expect(dev101.department, equals('IT Infrastructure'));
        expect(dev101.officeLocation, equals('Server Room A'));
        expect(dev101.vendor, equals('Cisco'));
        expect(dev101.model, equals('Catalyst 2960'));
        expect(dev101.mac, equals('00:1A:2B:3C:4D:5E'));
        expect(dev101.hostname, equals('rnf-sw-core'));
        expect(dev101.operatingSystem, equals('IOS'));
        expect(dev101.notes, equals('Critical rack switch'));
        expect(dev101.isMonitored, isTrue);
        expect(
          dev101.createdAt.millisecondsSinceEpoch ~/ 1000,
          equals(originalCreatedAt),
        );

        // Device 102 (BNF)
        final dev102 = devices.firstWhere((d) => d.id == 102);
        expect(dev102.id, equals(102));
        expect(dev102.factoryId, equals('bnf'));
        expect(dev102.name, equals('BNF-PACKAGING-PC'));
        expect(dev102.ip, equals('192.168.21.55'));
        expect(dev102.ownerName, equals('Sarah Connor'));
        expect(dev102.department, equals('Production'));
        expect(dev102.officeLocation, equals('Line 3 Station'));
        expect(dev102.vendor, equals('Dell'));
        expect(dev102.model, equals('OptiPlex 7090'));
        expect(dev102.mac, equals('00:14:22:01:23:45'));
        expect(dev102.hostname, equals('bnf-line3-pc'));
        expect(dev102.operatingSystem, equals('Windows 11'));
        expect(dev102.notes, equals('Packaging terminal'));
        expect(dev102.isMonitored, isTrue);
        expect(
          dev102.createdAt.millisecondsSinceEpoch ~/ 1000,
          equals(originalCreatedAt),
        );

        // Device 103 (Unassigned)
        final dev103 = devices.firstWhere((d) => d.id == 103);
        expect(dev103.id, equals(103));
        expect(dev103.factoryId, equals('unassigned'));
        expect(dev103.name, equals('LEGACY-ASSET-404'));
        expect(dev103.ip, equals('10.50.0.12'));
        expect(dev103.ownerName, equals('Unassigned Asset'));
        expect(dev103.department, equals('Finance'));
        expect(dev103.officeLocation, equals('Old Wing'));
        expect(dev103.vendor, equals('HP'));
        expect(dev103.model, equals('LaserJet M404'));
        expect(dev103.mac, equals('00:1E:68:AA:BB:CC'));
        expect(dev103.notes, equals('Needs factory physical audit'));

        // Check results relationship preserved
        final checks = await (appDb.select(
          appDb.checkResults,
        )..orderBy([(t) => OrderingTerm(expression: t.id)])).get();
        expect(checks.length, equals(2));
        expect(checks[0].deviceId, equals(101));
        expect(checks[0].factoryId, equals('rnf'));
        expect(checks[0].targetIp, equals('192.168.22.10'));
        expect(checks[1].deviceId, equals(102));
        expect(checks[1].factoryId, equals('bnf'));
        expect(checks[1].targetIp, equals('192.168.21.55'));

        // Device statuses relationship preserved
        final statuses = await (appDb.select(
          appDb.deviceStatuses,
        )..orderBy([(t) => OrderingTerm(expression: t.deviceId)])).get();
        expect(statuses.length, equals(3));
        expect(
          statuses.firstWhere((s) => s.deviceId == 101).status,
          equals('up'),
        );
        expect(
          statuses.firstWhere((s) => s.deviceId == 102).status,
          equals('up'),
        );
        expect(
          statuses.firstWhere((s) => s.deviceId == 103).status,
          equals('unknown'),
        );

        // Incident relationship preserved
        final incidents = await appDb.select(appDb.incidents).get();
        expect(incidents.length, equals(1));
        expect(incidents.first.deviceId, equals(101));
        expect(incidents.first.factoryId, equals('rnf'));
        expect(incidents.first.status, equals('active'));
        expect(incidents.first.severity, equals('medium'));

        // ──────────────────────────────────────────────────────────────────────────
        // Step 9: Verify factory network configuration is correct
        // ──────────────────────────────────────────────────────────────────────────
        final factories = await (appDb.select(
          appDb.factories,
        )..orderBy([(t) => OrderingTerm(expression: t.id)])).get();
        expect(factories.length, greaterThanOrEqualTo(3));

        final rnf = factories.firstWhere((f) => f.id == 'rnf');
        expect(rnf.gatewayIp, equals('192.168.22.1'));
        expect(rnf.subnetMask, equals('255.255.255.0'));
        expect(rnf.expectedCidr, equals('192.168.22.0/24'));

        final bnf = factories.firstWhere((f) => f.id == 'bnf');
        expect(bnf.gatewayIp, equals('192.168.21.1'));
        expect(bnf.subnetMask, equals('255.255.255.0'));
        expect(bnf.expectedCidr, equals('192.168.21.0/24'));

        final unassigned = factories.firstWhere((f) => f.id == 'unassigned');
        expect(unassigned.id, equals('unassigned'));

        // ──────────────────────────────────────────────────────────────────────────
        // Step 10: Verify no inventory records were silently removed or reassigned
        // ──────────────────────────────────────────────────────────────────────────
        final rnfDevices = devices.where((d) => d.factoryId == 'rnf').toList();
        final bnfDevices = devices.where((d) => d.factoryId == 'bnf').toList();
        final unassignedDevices = devices
            .where((d) => d.factoryId == 'unassigned')
            .toList();

        expect(rnfDevices.length, equals(1));
        expect(rnfDevices.first.id, equals(101));
        expect(bnfDevices.length, equals(1));
        expect(bnfDevices.first.id, equals(102));
        expect(unassignedDevices.length, equals(1));
        expect(unassignedDevices.first.id, equals(103));

        await appDb.close();
      },
    );
  });
}
