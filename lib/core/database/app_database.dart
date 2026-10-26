import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/ipv4_utils.dart';

part 'app_database.g.dart';

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get username => text().unique().withLength(min: 3, max: 50)();
  TextColumn get passwordHash => text()();
  TextColumn get role =>
      text().withDefault(const Constant('viewer'))(); // 'admin' or 'viewer'
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get lastLoginAt => dateTime().nullable()();
}

class AuditLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().nullable()();
  TextColumn get username => text()();
  TextColumn get action =>
      text()(); // e.g., 'USER_CREATED', 'INVENTORY_IMPORTED'
  TextColumn get details => text().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

class Locations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get description => text().nullable()();
}

class Devices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text().withDefault(
    const Constant('pc'),
  )(); // DeviceType value (e.g. 'pc', 'laptop', 'printer', 'switch', etc.)
  TextColumn get ip => text()();
  TextColumn get ownerName => text()();
  TextColumn get department => text()();
  TextColumn get officeLocation => text().nullable()();
  IntColumn get parentSwitchId => integer().nullable()();
  TextColumn get parentSwitchName => text().nullable()();
  TextColumn get vendor => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get mac => text().nullable()();
  TextColumn get hostname => text().nullable()();
  TextColumn get operatingSystem => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isMonitored => boolean().withDefault(const Constant(true))();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

@DataClassName('CheckResultData')
class CheckResults extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get deviceId => integer()();
  TextColumn get assetId => text().nullable()();
  TextColumn get targetIp => text()();
  TextColumn get checkType => text().withDefault(const Constant('icmp'))();
  BoolColumn get isSuccess => boolean()();
  IntColumn get latencyMs => integer().nullable()();
  RealColumn get packetLossPercent => real().nullable()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('DeviceStatusData')
class DeviceStatuses extends Table {
  IntColumn get deviceId => integer()();
  TextColumn get status => text().withDefault(const Constant('unknown'))();
  DateTimeColumn get lastSeen => dateTime().nullable()();
  DateTimeColumn get lastCheckAt => dateTime().nullable()();
  IntColumn get lastLatencyMs => integer().nullable()();
  IntColumn get lastSuccessfulLatencyMs => integer().nullable()();
  TextColumn get lastFailureReason => text().nullable()();
  IntColumn get consecutiveFailures =>
      integer().withDefault(const Constant(0))();
  IntColumn get consecutiveSuccesses =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get statusChangedAt =>
      dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isMaintenance =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {deviceId};
}

@DataClassName('IncidentData')
class Incidents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get deviceId => integer()();
  TextColumn get deviceName => text()();
  TextColumn get ownerName => text()();
  TextColumn get department => text()();
  TextColumn get location => text().nullable()();
  TextColumn get deviceIp => text()();
  TextColumn get incidentType =>
      text()(); // 'device_down', 'high_latency', 'network_down'
  TextColumn get severity => text().withDefault(
    const Constant('critical'),
  )(); // 'critical', 'high', 'medium', 'low'
  TextColumn get status => text().withDefault(
    const Constant('active'),
  )(); // 'active', 'acknowledged', 'resolved'
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  DateTimeColumn get acknowledgedAt => dateTime().nullable()();
  TextColumn get acknowledgedBy => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get correlationMessage => text().nullable()();
}

@DataClassName('DiscoveryConfigurationData')
class DiscoveryConfigurations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get authorizedRangesJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get enabledStrategiesJson => text().withDefault(
    const Constant('["icmp","arp","dns","tcp_probe","onvif","mdns"]'),
  )();
  IntColumn get maxConcurrency => integer().withDefault(const Constant(20))();
  IntColumn get timeoutSeconds => integer().withDefault(const Constant(2))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('DiscoveryScanData')
class DiscoveryScans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  TextColumn get rangesJson => text()();
  TextColumn get enabledStrategiesJson => text().withDefault(
    const Constant('["icmp","arp","dns","tcp_probe","onvif","mdns"]'),
  )();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get targetsEnumerated => integer().withDefault(const Constant(0))();
  IntColumn get targetsAttempted => integer().withDefault(const Constant(0))();
  IntColumn get responsesReceived => integer().withDefault(const Constant(0))();
  IntColumn get classifiedCount => integer().withDefault(const Constant(0))();
  IntColumn get unknownCount => integer().withDefault(const Constant(0))();
  IntColumn get failureCount => integer().withDefault(const Constant(0))();
  TextColumn get diagnosticSummary => text().nullable()();
}

@DataClassName('DiscoveredDeviceData')
class DiscoveredDevices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get scanId => integer()();
  TextColumn get ip => text()();
  TextColumn get mac => text().nullable()();
  TextColumn get hostname => text().nullable()();
  TextColumn get vendor => text().nullable()();
  TextColumn get observedServicesJson => text().nullable()();
  TextColumn get predictedCategory =>
      text().withDefault(const Constant('unknown'))();
  TextColumn get confidence => text().withDefault(const Constant('unknown'))();
  TextColumn get evidenceJson => text().nullable()();
  TextColumn get classificationMethod =>
      text().withDefault(const Constant('multi_evidence_v1'))();
  DateTimeColumn get firstSeen => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastSeen => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastSuccessfulProbe => dateTime().nullable()();
  TextColumn get lastProbeFailureReason => text().nullable()();
  TextColumn get reviewState =>
      text().withDefault(const Constant('pending_review'))();
  TextColumn get adminConfirmedCategory => text().nullable()();
  IntColumn get adminReviewerId => integer().nullable()();
  DateTimeColumn get adminReviewTimestamp => dateTime().nullable()();
  IntColumn get associatedDeviceId => integer().nullable()();
}

@DataClassName('DiscoveryEvidenceData')
class DiscoveryEvidences extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get discoveredDeviceId => integer()();
  TextColumn get strategyName => text()();
  TextColumn get probeTarget => text()();
  BoolColumn get isSuccess => boolean()();
  TextColumn get details => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('InfrastructureDeviceData')
class InfrastructureDevices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get ip => text().unique()();
  TextColumn get mac => text().nullable()();
  TextColumn get role => text().withDefault(
    const Constant('other_unknown'),
  )(); // 'gateway', 'controller', 'switch', 'ap', 'other_unknown'
  TextColumn get location => text().nullable()();
  BoolColumn get isCriticalInfrastructure =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get requiresAdminConfirmation =>
      boolean().withDefault(const Constant(true))();
  TextColumn get linkedSubnetsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get controllerUrl => text().nullable()();
  TextColumn get siteName => text().withDefault(const Constant('default'))();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get isReadOnly => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

@lazySingleton
@DriftDatabase(
  tables: [
    Users,
    AuditLogs,
    Locations,
    Devices,
    CheckResults,
    DeviceStatuses,
    Incidents,
    DiscoveryConfigurations,
    DiscoveryScans,
    DiscoveredDevices,
    DiscoveryEvidences,
    InfrastructureDevices,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.createTable(locations);
          await m.createTable(devices);
        }
        if (from < 3) {
          await m.createTable(checkResults);
          await m.createTable(deviceStatuses);
        }
        if (from < 4) {
          await m.createTable(incidents);
        }
        if (from < 5) {
          await m.createTable(discoveryConfigurations);
          await m.createTable(discoveryScans);
          await m.createTable(discoveredDevices);
          await m.createTable(discoveryEvidences);
        }
        if (from < 6) {
          final tableCheck = await customSelect(
            "SELECT count(*) as c FROM sqlite_master WHERE type='table' AND name='infrastructure_devices'",
          ).getSingle();
          if (tableCheck.read<int>('c') == 0) {
            await m.createTable(infrastructureDevices);
          }
        }
        if (from < 7) {
          try {
            final columns = await customSelect(
              "PRAGMA table_info('infrastructure_devices')",
            ).get();
            final hasLocation = columns.any(
              (row) => row.read<String>('name') == 'location',
            );
            if (!hasLocation) {
              await m.addColumn(
                infrastructureDevices,
                infrastructureDevices.location,
              );
            }
          } catch (e, st) {
            if (!_isDuplicateColumnError(e)) {
              _logMigrationDiagnostic('from < 7: addColumn location', e, st);
              rethrow;
            }
          }
        }
        if (from < 8) {
          try {
            final columns = await customSelect(
              "PRAGMA table_info('device_statuses')",
            ).get();
            final hasLatency = columns.any(
              (row) => row.read<String>('name') == 'last_successful_latency_ms',
            );
            if (!hasLatency) {
              await m.addColumn(
                deviceStatuses,
                deviceStatuses.lastSuccessfulLatencyMs,
              );
            }
            final hasFailure = columns.any(
              (row) => row.read<String>('name') == 'last_failure_reason',
            );
            if (!hasFailure) {
              await m.addColumn(
                deviceStatuses,
                deviceStatuses.lastFailureReason,
              );
            }
          } catch (e, st) {
            if (!_isDuplicateColumnError(e)) {
              _logMigrationDiagnostic(
                'from < 8: addColumns device_statuses',
                e,
                st,
              );
              rethrow;
            }
          }
        }
        if (from < 9) {
          try {
            final columns = await customSelect(
              "PRAGMA table_info('devices')",
            ).get();
            final colNames = columns
                .map((row) => row.read<String>('name'))
                .toSet();
            if (!colNames.contains('mac')) {
              await m.addColumn(devices, devices.mac);
            }
            if (!colNames.contains('hostname')) {
              await m.addColumn(devices, devices.hostname);
            }
            if (!colNames.contains('operating_system')) {
              await m.addColumn(devices, devices.operatingSystem);
            }
            if (!colNames.contains('notes')) {
              await m.addColumn(devices, devices.notes);
            }
            if (!colNames.contains('is_monitored')) {
              await m.addColumn(devices, devices.isMonitored);
            }
          } catch (e, st) {
            if (!_isDuplicateColumnError(e)) {
              _logMigrationDiagnostic('from < 9: addColumns devices', e, st);
              rethrow;
            }
          }
        }
        if (from < 10) {
          try {
            await transaction(() async {
              // 1. Process all inventory devices: normalize whitespace and canonicalize IPv4
              final allDevices = await select(devices).get();
              final infraDevicesList = await select(
                infrastructureDevices,
              ).get();
              final infraIps = infraDevicesList
                  .map((d) => d.ip.trim())
                  .where((ip) => ip.isNotEmpty)
                  .toSet();

              final seenCanonicalIps =
                  <String, int>{}; // canonicalIp -> firstDeviceId

              for (final row in allDevices) {
                final rawIp = row.ip.trim();

                if (rawIp.isEmpty) {
                  // Blank or empty IP: represent as unassigned, disable monitoring
                  await (update(
                    devices,
                  )..where((t) => t.id.equals(row.id))).write(
                    DevicesCompanion(
                      ip: const Value(''),
                      isMonitored: const Value(false),
                      isEnabled: const Value(false),
                      notes: Value(
                        '${row.notes ?? ''}\n[MIGRATION_UNASSIGNED_IP]: Blank IP detected during schema v10 migration. Preserved asset record; monitoring disabled pending assignment.',
                      ),
                    ),
                  );
                  continue;
                }

                final canonicalIp = Ipv4Utils.canonicalizeIpv4(rawIp);
                if (canonicalIp == null) {
                  // Malformed or invalid IPv4: do not fabricate fake string; clear to unassigned
                  await (update(
                    devices,
                  )..where((t) => t.id.equals(row.id))).write(
                    DevicesCompanion(
                      ip: const Value(''),
                      isMonitored: const Value(false),
                      isEnabled: const Value(false),
                      notes: Value(
                        '${row.notes ?? ''}\n[MIGRATION_MALFORMED_IP]: Invalid IP "$rawIp" detected during schema v10 migration. Preserved asset record; monitoring disabled pending manual correction.',
                      ),
                    ),
                  );
                  continue;
                }

                // Check cross-table conflict with authoritative infrastructure devices
                if (infraIps.contains(canonicalIp)) {
                  final conflictingInfra = infraDevicesList.firstWhere(
                    (d) => d.ip.trim() == canonicalIp,
                  );
                  await (update(
                    devices,
                  )..where((t) => t.id.equals(row.id))).write(
                    DevicesCompanion(
                      ip: const Value(''),
                      isMonitored: const Value(false),
                      isEnabled: const Value(false),
                      notes: Value(
                        '${row.notes ?? ''}\n[MIGRATION_CROSS_TABLE_CONFLICT]: IP $canonicalIp conflicts with authoritative infrastructure asset "${conflictingInfra.name}" (ID #${conflictingInfra.id}). IP cleared to unassigned; monitoring disabled pending manual resolution.',
                      ),
                    ),
                  );
                  continue;
                }

                // Check duplicate IPs within devices inventory
                if (seenCanonicalIps.containsKey(canonicalIp)) {
                  final firstDevId = seenCanonicalIps[canonicalIp]!;
                  await (update(
                    devices,
                  )..where((t) => t.id.equals(row.id))).write(
                    DevicesCompanion(
                      ip: const Value(''),
                      isMonitored: const Value(false),
                      isEnabled: const Value(false),
                      notes: Value(
                        '${row.notes ?? ''}\n[MIGRATION_CONFLICT]: Duplicate IP $canonicalIp detected during schema v10 migration (originally assigned to Device #$firstDevId). IP cleared to unassigned; monitoring disabled pending manual resolution.',
                      ),
                    ),
                  );
                } else {
                  seenCanonicalIps[canonicalIp] = row.id;
                  // Update to canonical IP if it had leading zeros or whitespace
                  if (row.ip != canonicalIp) {
                    await (update(devices)..where((t) => t.id.equals(row.id)))
                        .write(DevicesCompanion(ip: Value(canonicalIp)));
                  }
                }
              }

              // 2. Add asset_id column to check_results if not present
              final checkCols = await customSelect(
                "PRAGMA table_info('check_results')",
              ).get();
              final hasAssetId = checkCols.any(
                (r) => r.read<String>('name') == 'asset_id',
              );
              if (!hasAssetId) {
                try {
                  await m.addColumn(checkResults, checkResults.assetId);
                } catch (e, st) {
                  if (!_isDuplicateColumnError(e)) {
                    _logMigrationDiagnostic(
                      'from < 10: addColumn asset_id',
                      e,
                      st,
                    );
                    rethrow;
                  }
                }
              }

              // 3. Drop any old non-partial index and create partial unique index
              await customStatement('DROP INDEX IF EXISTS idx_devices_ip;');
              await customStatement(
                'CREATE UNIQUE INDEX IF NOT EXISTS idx_devices_ip ON devices(ip) WHERE ip != \'\' AND ip IS NOT NULL;',
              );
            });
          } catch (e, st) {
            _logMigrationDiagnostic(
              'from < 10: atomic migration transaction',
              e,
              st,
            );
            rethrow;
          }
        }
        if (from < 11) {
          try {
            await transaction(() async {
              // Normalize legacy status strings to canonical states in device_statuses
              await customStatement(
                "UPDATE device_statuses SET status = 'down' WHERE LOWER(TRIM(status)) IN ('disconnected', 'offline');",
              );
              await customStatement(
                "UPDATE device_statuses SET status = 'up' WHERE LOWER(TRIM(status)) IN ('connected', 'online');",
              );
            });
          } catch (e, st) {
            _logMigrationDiagnostic(
              'from < 11: normalize legacy device statuses',
              e,
              st,
            );
            rethrow;
          }
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON;');
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_devices_ip ON devices(ip) WHERE ip != \'\' AND ip IS NOT NULL;',
        );
      },
    );
  }

  static bool _isDuplicateColumnError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('duplicate column name') ||
        msg.contains('already exists');
  }

  static void _logMigrationDiagnostic(
    String step,
    Object error,
    StackTrace stack,
  ) {
    // Structured diagnostic logging for unexpected migration failures (no credentials logged)
    // ignore: avoid_print
    print('*** [DATABASE MIGRATION FAILURE] Step: $step | Error: $error ***');
    // ignore: avoid_print
    print(stack);
  }
}

class DatabaseConfig {
  static String? customDataDir;
  static bool isDevelopment = false;

  static void verifyClientAccessAllowed({required bool canWriteProd}) {
    if (!canWriteProd &&
        !isDevelopment &&
        Platform.environment['IT_MONITOR_DEV_MODE'] != 'true') {
      throw StateError(
        'Authoritative database in ProgramData is inaccessible to direct client access. '
        'Direct database access is restricted to the LocalSystem service. '
        'Desktop clients must connect via the authoritative Monitoring Service API.',
      );
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    Directory targetDir;
    final customDataDir =
        DatabaseConfig.customDataDir ??
        Platform.environment['IT_MONITOR_DATA_DIR'];
    if (customDataDir != null && customDataDir.trim().isNotEmpty) {
      // Explicit override (installed service path, test path, etc.)
      targetDir = Directory(customDataDir.trim());
    } else if (Platform.isWindows) {
      // Try ProgramData first (production installed service).
      // If the file already exists there and is writable, use it.
      // Otherwise fall back to AppData\Local ONLY in explicit development / test mode.
      final programData = Platform.environment['ProgramData'];
      final prodDir = programData != null && programData.trim().isNotEmpty
          ? Directory(p.join(programData.trim(), 'ITNetworkMonitor'))
          : Directory(p.join(r'C:\ProgramData', 'ITNetworkMonitor'));

      final prodFile = File(p.join(prodDir.path, 'it_network_monitor.sqlite'));

      bool canAccessProd = false;
      try {
        if (prodFile.existsSync()) {
          final raf = prodFile.openSync(mode: FileMode.read);
          raf.closeSync();
          canAccessProd = true;
        }
      } catch (_) {
        canAccessProd = false;
      }

      if (canAccessProd) {
        // Authoritative production database already exists in ProgramData and is accessible.
        // Always bind to ProgramData when accessible to prevent client and service from using different databases.
        targetDir = prodDir;
      } else {
        bool canWriteProd = false;
        if (prodDir.existsSync()) {
          try {
            // Test directory create/delete capability (needed for initial DB and WAL/SHM creation)
            final probe = File(
              p.join(
                prodDir.path,
                '.probe_${DateTime.now().millisecondsSinceEpoch}.tmp',
              ),
            );
            await probe.writeAsString('probe');
            await probe.delete();
            canWriteProd = true;
          } catch (_) {
            canWriteProd = false;
          }
        }

        if (canWriteProd) {
          targetDir = prodDir;
        } else {
          // In production, prevent silent creation of a divergent per-user database!
          DatabaseConfig.verifyClientAccessAllowed(canWriteProd: canWriteProd);

          // Fall back to per-user AppData\Local for standalone dev / debug if ProgramData is unavailable.
          final localAppData = Platform.environment['LOCALAPPDATA'];
          targetDir = localAppData != null && localAppData.trim().isNotEmpty
              ? Directory(p.join(localAppData.trim(), 'ITNetworkMonitor'))
              : Directory(
                  p.join(
                    Platform.environment['USERPROFILE'] ?? r'C:\Users\Default',
                    'AppData',
                    'Local',
                    'ITNetworkMonitor',
                  ),
                );
        }
      }
    } else {
      try {
        targetDir = await getApplicationSupportDirectory();
      } catch (_) {
        targetDir = Directory.current;
      }
    }

    if (!targetDir.existsSync()) {
      try {
        targetDir.createSync(recursive: true);
      } catch (_) {}
    }

    final file = File(p.join(targetDir.path, 'it_network_monitor.sqlite'));
    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        try {
          rawDb.execute('PRAGMA journal_mode = WAL;');
          rawDb.execute('PRAGMA busy_timeout = 5000;');
          rawDb.execute('PRAGMA synchronous = NORMAL;');
        } catch (_) {}
      },
    );
  });
}
