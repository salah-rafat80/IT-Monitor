import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:injectable/injectable.dart';

import '../../../../core/config/app_run_mode.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/ipv4_utils.dart';
import '../../../../core/utils/result.dart';
import '../../../monitoring/data/datasources/monitoring_service_client.dart';
import '../../data/datasources/excel_inventory_parser.dart';
import '../../domain/entities/device_entity.dart';
import '../../domain/entities/device_import_commit_payload.dart';
import '../../domain/entities/inventory_import_preview.dart';
import '../../domain/repositories/device_repository.dart';
import '../../domain/services/inventory_validator.dart';

@LazySingleton(as: DeviceRepository)
class DeviceRepositoryImpl implements DeviceRepository {
  final AppDatabase _db;
  final MonitoringServiceClient? _serviceClient;

  DeviceRepositoryImpl(this._db, [this._serviceClient]);

  bool get _useAuthoritativeService {
    if (AppConfig.isProductionClient) return true;
    if (AppConfig.isStandaloneDevelopment) return false;
    return _serviceClient != null;
  }

  MonitoringServiceClient? get _effectiveClient =>
      _serviceClient ??
      (getIt.isRegistered<MonitoringServiceClient>()
          ? getIt<MonitoringServiceClient>()
          : null);

  @override
  Future<Result<List<DeviceEntity>>> getDevices({String? factoryId}) async {
    if (_useAuthoritativeService) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
      final res = await client.getDevices(factoryId: factoryId);
      if (res.isSuccess && res.data != null) {
        final list = res.data!.map((item) {
          final devMap = item['device'] as Map<String, dynamic>;
          return DeviceEntity.fromJson(devMap);
        }).toList();
        return Result.success(list);
      } else {
        return Result.failure(
          NetworkFailure(
            'Authoritative monitoring service is unreachable (${res.errorMessage}). '
            'Ensure IT Network Monitor Service is running.',
          ),
        );
      }
    }

    try {
      var query = _db.select(_db.devices);
      if (factoryId != null && factoryId.isNotEmpty) {
        query = query..where((d) => d.factoryId.equals(factoryId));
      }
      final rows = await query.get();
      final entities = rows
          .map(
            (r) => DeviceEntity(
              id: r.id,
              factoryId: r.factoryId,
              name: r.name,
              type: DeviceType.fromString(r.type),
              ip: r.ip,
              ownerName: r.ownerName,
              department: r.department,
              officeLocation: r.officeLocation,
              parentSwitchId: r.parentSwitchId,
              parentSwitchName: r.parentSwitchName,
              vendor: r.vendor,
              model: r.model,
              mac: r.mac,
              hostname: r.hostname,
              operatingSystem: r.operatingSystem,
              notes: r.notes,
              isMonitored: r.isMonitored,
              isEnabled: r.isEnabled,
              createdAt: r.createdAt,
              updatedAt: r.updatedAt,
            ),
          )
          .toList();
      return Result.success(entities);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to load devices: $e'));
    }
  }

  @override
  Future<Result<DeviceEntity>> getDeviceById(int id) async {
    if (_useAuthoritativeService) {
      final allRes = await getDevices();
      if (allRes.isFailure) {
        return Result.failure(allRes.failureOrNull!);
      }
      final match = allRes.dataOrNull!.where((d) => d.id == id).firstOrNull;
      if (match == null) {
        return Result.failure(const NotFoundFailure('Device not found.'));
      }
      return Result.success(match);
    }

    try {
      final r = await (_db.select(
        _db.devices,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (r == null) {
        return Result.failure(const NotFoundFailure('Device not found.'));
      }
      return Result.success(
        DeviceEntity(
          id: r.id,
          factoryId: r.factoryId,
          name: r.name,
          type: DeviceType.fromString(r.type),
          ip: r.ip,
          ownerName: r.ownerName,
          department: r.department,
          officeLocation: r.officeLocation,
          parentSwitchId: r.parentSwitchId,
          parentSwitchName: r.parentSwitchName,
          vendor: r.vendor,
          model: r.model,
          mac: r.mac,
          hostname: r.hostname,
          operatingSystem: r.operatingSystem,
          notes: r.notes,
          isMonitored: r.isMonitored,
          isEnabled: r.isEnabled,
          createdAt: r.createdAt,
          updatedAt: r.updatedAt,
        ),
      );
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to get device details: $e'),
      );
    }
  }

  bool _isUniqueConstraintViolation(Object error) {
    if (error is SqliteException) {
      return error.extendedResultCode == 2067 ||
          (error.resultCode == 19 &&
              error.message.toLowerCase().contains('unique'));
    }
    final errStr = error.toString().toLowerCase();
    return errStr.contains('2067') ||
        (errStr.contains('unique') && errStr.contains('failed'));
  }

  @override
  Future<Result<DeviceEntity>> addDevice(DeviceEntity device) async {
    if (_useAuthoritativeService) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
      final res = await client.addDevice(device.toJson());
      if (res.isSuccess && res.data != null) {
        final devMap =
            res.data!['device'] as Map<String, dynamic>? ?? res.data!;
        return Result.success(DeviceEntity.fromJson(devMap));
      } else {
        return Result.failure(
          NetworkFailure(
            'Failed to add device via service API: ${res.errorMessage}',
          ),
        );
      }
    }

    try {
      final canonicalIp = InventoryValidator.canonicalizeIpv4(device.ip);
      if (canonicalIp == null) {
        return Result.failure(
          ValidationFailure(
            'Invalid or malformed IPv4 address: "${device.ip}".',
          ),
        );
      }

      final existingIp =
          await (_db.select(_db.devices)..where(
                (t) =>
                    t.factoryId.equals(device.factoryId) &
                    t.ip.equals(canonicalIp),
              ))
              .getSingleOrNull();
      if (existingIp != null) {
        return Result.failure(
          ValidationFailure(
            'Device with IP $canonicalIp already exists in factory ${device.factoryId} (${existingIp.name}).',
          ),
        );
      }

      final existingInfraIp =
          await (_db.select(_db.infrastructureDevices)..where(
                (t) =>
                    t.factoryId.equals(device.factoryId) &
                    t.ip.equals(canonicalIp),
              ))
              .getSingleOrNull();
      if (existingInfraIp != null) {
        return Result.failure(
          ValidationFailure(
            'IP $canonicalIp is already assigned to infrastructure device "${existingInfraIp.name}" in factory ${device.factoryId}.',
          ),
        );
      }

      final now = DateTime.now();
      final id = await _db
          .into(_db.devices)
          .insert(
            DevicesCompanion.insert(
              factoryId: Value(device.factoryId),
              name: device.name.trim(),
              type: Value(device.type.toValue()),
              ip: canonicalIp,
              ownerName: device.ownerName.trim(),
              department: device.department.trim(),
              officeLocation: Value(device.officeLocation?.trim()),
              parentSwitchId: Value(device.parentSwitchId),
              parentSwitchName: Value(device.parentSwitchName?.trim()),
              vendor: Value(device.vendor?.trim()),
              model: Value(device.model?.trim()),
              mac: Value(device.mac?.trim()),
              hostname: Value(device.hostname?.trim()),
              operatingSystem: Value(device.operatingSystem?.trim()),
              notes: Value(device.notes?.trim()),
              isMonitored: Value(device.isMonitored),
              isEnabled: Value(device.isEnabled),
              createdAt: Value(now),
            ),
          );

      await _db
          .into(_db.deviceStatuses)
          .insert(
            DeviceStatusesCompanion.insert(
              deviceId: Value(id),
              status: const Value('unknown'),
              statusChangedAt: Value(now),
            ),
            mode: InsertMode.insertOrIgnore,
          );

      final added = device.copyWith(id: id, ip: canonicalIp, createdAt: now);

      return Result.success(added);
    } catch (e) {
      if (_isUniqueConstraintViolation(e)) {
        return Result.failure(
          ValidationFailure('Device with IP ${device.ip} already exists.'),
        );
      }
      return Result.failure(DatabaseFailure('Failed to add device: $e'));
    }
  }

  @override
  Future<Result<DeviceEntity>> updateDevice(DeviceEntity device) async {
    if (_useAuthoritativeService) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
      final res = await client.updateDevice(device.toJson());
      if (res.isSuccess && res.data != null) {
        final devMap =
            res.data!['device'] as Map<String, dynamic>? ?? res.data!;
        return Result.success(DeviceEntity.fromJson(devMap));
      } else {
        return Result.failure(
          NetworkFailure(
            'Failed to update device via service API: ${res.errorMessage}',
          ),
        );
      }
    }

    try {
      final canonicalIp = InventoryValidator.canonicalizeIpv4(device.ip);
      if (canonicalIp == null) {
        return Result.failure(
          ValidationFailure(
            'Invalid or malformed IPv4 address: "${device.ip}".',
          ),
        );
      }

      final conflicting =
          await (_db.select(_db.devices)..where(
                (t) =>
                    t.factoryId.equals(device.factoryId) &
                    t.ip.equals(canonicalIp) &
                    t.id.equals(device.id).not(),
              ))
              .getSingleOrNull();
      if (conflicting != null) {
        return Result.failure(
          ValidationFailure(
            'Device with IP $canonicalIp already exists in factory ${device.factoryId} (${conflicting.name}).',
          ),
        );
      }

      final conflictingInfra =
          await (_db.select(_db.infrastructureDevices)..where(
                (t) =>
                    t.factoryId.equals(device.factoryId) &
                    t.ip.equals(canonicalIp),
              ))
              .getSingleOrNull();
      if (conflictingInfra != null) {
        return Result.failure(
          ValidationFailure(
            'IP $canonicalIp is already assigned to infrastructure device "${conflictingInfra.name}" in factory ${device.factoryId}.',
          ),
        );
      }

      final now = DateTime.now();
      await (_db.update(
        _db.devices,
      )..where((t) => t.id.equals(device.id))).write(
        DevicesCompanion(
          factoryId: Value(device.factoryId),
          name: Value(device.name.trim()),
          type: Value(device.type.toValue()),
          ip: Value(canonicalIp),
          ownerName: Value(device.ownerName.trim()),
          department: Value(device.department.trim()),
          officeLocation: Value(device.officeLocation?.trim()),
          parentSwitchId: Value(device.parentSwitchId),
          parentSwitchName: Value(device.parentSwitchName?.trim()),
          vendor: Value(device.vendor?.trim()),
          model: Value(device.model?.trim()),
          mac: Value(device.mac?.trim()),
          hostname: Value(device.hostname?.trim()),
          operatingSystem: Value(device.operatingSystem?.trim()),
          notes: Value(device.notes?.trim()),
          isMonitored: Value(device.isMonitored),
          isEnabled: Value(device.isEnabled),
          updatedAt: Value(now),
        ),
      );

      final updated = device.copyWith(ip: canonicalIp, updatedAt: now);

      return Result.success(updated);
    } catch (e) {
      if (_isUniqueConstraintViolation(e)) {
        return Result.failure(
          ValidationFailure('Device with IP ${device.ip} already exists.'),
        );
      }
      return Result.failure(DatabaseFailure('Failed to update device: $e'));
    }
  }

  @override
  Future<Result<DeviceEntity>> assignDeviceOwner({
    required int deviceId,
    required String ownerName,
    String? adminUsername,
  }) async {
    if (_useAuthoritativeService) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
      final res = await client.assignDeviceOwner(
        deviceId: deviceId,
        ownerName: ownerName,
      );
      if (res.isSuccess && res.data != null) {
        final devMap = res.data!['device'] as Map<String, dynamic>;
        return Result.success(DeviceEntity.fromJson(devMap));
      } else {
        return Result.failure(
          NetworkFailure(
            'Failed to assign owner via service API: ${res.errorMessage}',
          ),
        );
      }
    }

    try {
      // Fetch existing device
      final deviceRes = await getDeviceById(deviceId);
      if (deviceRes.isFailure) {
        return deviceRes;
      }
      final existing = deviceRes.dataOrNull!;

      // 3. Normalize owner name (preserve empty/unassigned as 'Unassigned')
      final trimmed = ownerName.trim();
      final cleanOwner =
          (trimmed.isEmpty || trimmed.toLowerCase() == 'unassigned')
          ? 'Unassigned'
          : trimmed;

      // 4. If no change, return existing
      if (existing.ownerName == cleanOwner) {
        return Result.success(existing);
      }

      final now = DateTime.now();

      // 5. Update device in database (strictly preserving existing IP and other metadata)
      await (_db.update(
        _db.devices,
      )..where((t) => t.id.equals(deviceId))).write(
        DevicesCompanion(ownerName: Value(cleanOwner), updatedAt: Value(now)),
      );

      // 6. Update active incidents for this device so display remains consistent
      try {
        await (_db.update(_db.incidents)
              ..where((t) => t.deviceId.equals(deviceId)))
            .write(IncidentsCompanion(ownerName: Value(cleanOwner)));
      } catch (_) {}

      final updated = existing.copyWith(ownerName: cleanOwner, updatedAt: now);

      return Result.success(updated);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to assign device owner: $e'),
      );
    }
  }

  @override
  Future<Result<void>> deleteDevice(int id) async {
    if (_useAuthoritativeService) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
      final res = await client.deleteDevice(id);
      if (res.isSuccess) {
        return Result.success(null);
      } else {
        return Result.failure(
          NetworkFailure(
            'Failed to delete device via service API: ${res.errorMessage}',
          ),
        );
      }
    }

    try {
      await (_db.delete(_db.devices)..where((t) => t.id.equals(id))).go();

      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to delete device: $e'));
    }
  }

  @override
  Future<Result<void>> toggleDeviceMonitoring({
    required int deviceId,
    required bool isEnabled,
  }) async {
    if (_useAuthoritativeService) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
      final res = await client.toggleDeviceMonitoring(deviceId, isEnabled);
      if (res.isSuccess) {
        return Result.success(null);
      } else {
        return Result.failure(
          NetworkFailure(
            'Failed to toggle device monitoring via service API: ${res.errorMessage}',
          ),
        );
      }
    }

    try {
      final now = DateTime.now();
      await (_db.update(
        _db.devices,
      )..where((t) => t.id.equals(deviceId))).write(
        DevicesCompanion(isEnabled: Value(isEnabled), updatedAt: Value(now)),
      );

      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to toggle monitoring: $e'));
    }
  }

  @override
  Future<Result<InventoryImportPreview>> parseAndValidateImport(
    List<int> bytes,
    String filename,
  ) async {
    try {
      final rawRows = ExcelInventoryParser.parseFile(bytes, filename);
      final Set<String> existingIps;
      if (_useAuthoritativeService) {
        final devRes = await getDevices();
        if (devRes.isFailure) {
          return Result.failure(devRes.failureOrNull!);
        }
        existingIps = devRes.dataOrNull!.map((d) => d.ip.trim()).toSet();
      } else {
        final existingDevices = await _db.select(_db.devices).get();
        existingIps = existingDevices.map((d) => d.ip.trim()).toSet();
      }

      final preview = InventoryValidator.validateRows(
        rows: rawRows,
        existingDatabaseIps: existingIps,
      );

      return Result.success(preview);
    } catch (e) {
      return Result.failure(
        ImportFailure('Failed to parse inventory file: $e'),
      );
    }
  }

  @override
  Future<Result<int>> commitImportPayload(
    DeviceImportCommitPayload payload,
  ) async {
    if (_useAuthoritativeService) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
      final res = await client.importDevicesPayload(payload.toJson());
      if (res.isSuccess) {
        return Result.success(res.data ?? 0);
      } else {
        return Result.failure(
          NetworkFailure(
            'Failed to commit inventory import via service API: ${res.errorMessage}',
          ),
        );
      }
    }

    try {
      final now = DateTime.now();
      final targetFactoryId = payload.targetFactoryId.trim().toLowerCase();
      if (targetFactoryId.isEmpty) {
        return Result.failure(
          ValidationFailure(
            'Target factory ID must be specified for inventory import.',
          ),
        );
      }

      // Execute import as an atomic safe database transaction
      return await _db.transaction(() async {
        // 1. Revalidate duplicate IP addresses within the incoming payload
        final allIncomingIps = <String>{};
        for (final dev in [...payload.inserts, ...payload.updates]) {
          final canon = Ipv4Utils.canonicalizeIpv4(dev.ip);
          if (canon != null) {
            if (allIncomingIps.contains(canon)) {
              throw Exception(
                'Duplicate IP "$canon" present multiple times within import payload.',
              );
            }
            allIncomingIps.add(canon);
          }
        }

        // 2. Fetch all existing devices in targetFactoryId for conflict checking
        final existingFactoryDevices = await (_db.select(
          _db.devices,
        )..where((t) => t.factoryId.equals(targetFactoryId))).get();
        final existingIpMap = <String, int>{}; // canonicalIp -> deviceId
        for (final d in existingFactoryDevices) {
          final canon = Ipv4Utils.canonicalizeIpv4(d.ip);
          if (canon != null) existingIpMap[canon] = d.id;
        }

        // 3. Validate & Execute UPDATES
        int updatedCount = 0;
        for (final dev in payload.updates) {
          if (dev.id <= 0) {
            throw Exception(
              'Cannot update device without a valid database ID (got ID ${dev.id}).',
            );
          }
          final existing = await (_db.select(
            _db.devices,
          )..where((t) => t.id.equals(dev.id))).getSingleOrNull();

          if (existing == null) {
            throw Exception(
              'Device #${dev.id} ("${dev.name}") was not found in database to update.',
            );
          }

          // Validate device belongs to target factory; reject IDs belonging to another factory
          if (existing.factoryId.toLowerCase() != targetFactoryId) {
            throw Exception(
              'Device #${dev.id} ("${dev.name}") belongs to factory "${existing.factoryId}", '
              'which cannot be updated under target factory "$targetFactoryId".',
            );
          }

          final canonIp = Ipv4Utils.canonicalizeIpv4(dev.ip);
          if (canonIp != null) {
            final conflictingId = existingIpMap[canonIp];
            if (conflictingId != null && conflictingId != dev.id) {
              throw Exception(
                'Cannot update device #${dev.id}: IP $canonIp is already in use by existing device #$conflictingId in factory "$targetFactoryId".',
              );
            }
            existingIpMap[canonIp] = dev.id;
          }

          // Perform UPDATE: strictly preserve ID, factoryId, and createdAt.
          // Do not overwrite existing fields with empty spreadsheet cells unless explicitly present.
          await (_db.update(
            _db.devices,
          )..where((t) => t.id.equals(dev.id))).write(
            DevicesCompanion(
              name: Value(dev.name),
              type: Value(dev.type.toValue()),
              ip: Value(canonIp ?? dev.ip),
              ownerName: Value(dev.ownerName),
              department: Value(dev.department),
              officeLocation: dev.officeLocation?.isNotEmpty == true
                  ? Value(dev.officeLocation)
                  : Value(existing.officeLocation),
              parentSwitchId: Value(
                dev.parentSwitchId ?? existing.parentSwitchId,
              ),
              parentSwitchName: dev.parentSwitchName?.isNotEmpty == true
                  ? Value(dev.parentSwitchName)
                  : Value(existing.parentSwitchName),
              vendor: dev.vendor?.isNotEmpty == true
                  ? Value(dev.vendor)
                  : Value(existing.vendor),
              model: dev.model?.isNotEmpty == true
                  ? Value(dev.model)
                  : Value(existing.model),
              mac: dev.mac?.isNotEmpty == true
                  ? Value(dev.mac)
                  : Value(existing.mac),
              hostname: dev.hostname?.isNotEmpty == true
                  ? Value(dev.hostname)
                  : Value(existing.hostname),
              operatingSystem: dev.operatingSystem?.isNotEmpty == true
                  ? Value(dev.operatingSystem)
                  : Value(existing.operatingSystem),
              notes: dev.notes?.isNotEmpty == true
                  ? Value(dev.notes)
                  : Value(existing.notes),
              isMonitored: Value(dev.isMonitored),
              isEnabled: Value(dev.isEnabled),
              updatedAt: Value(now),
            ),
          );
          updatedCount++;
        }

        // 4. Validate & Execute INSERTS
        int insertedCount = 0;
        final newInsertedIds = <int>[];
        for (final dev in payload.inserts) {
          final canonIp = Ipv4Utils.canonicalizeIpv4(dev.ip);
          if (canonIp != null && existingIpMap.containsKey(canonIp)) {
            final existingId = existingIpMap[canonIp]!;
            throw Exception(
              'Cannot insert device "${dev.name}": IP $canonIp already exists in factory "$targetFactoryId" (device #$existingId).',
            );
          }

          final newId = await _db
              .into(_db.devices)
              .insert(
                DevicesCompanion.insert(
                  factoryId: Value(targetFactoryId),
                  name: dev.name,
                  type: Value(dev.type.toValue()),
                  ip: canonIp ?? dev.ip,
                  ownerName: dev.ownerName,
                  department: dev.department,
                  officeLocation: Value(dev.officeLocation),
                  parentSwitchId: Value(dev.parentSwitchId),
                  parentSwitchName: Value(dev.parentSwitchName),
                  vendor: Value(dev.vendor),
                  model: Value(dev.model),
                  mac: Value(dev.mac),
                  hostname: Value(dev.hostname),
                  operatingSystem: Value(dev.operatingSystem),
                  notes: Value(dev.notes),
                  isMonitored: Value(dev.isMonitored),
                  isEnabled: Value(dev.isEnabled),
                  createdAt: Value(now),
                ),
              );
          if (canonIp != null) existingIpMap[canonIp] = newId;
          newInsertedIds.add(newId);
          insertedCount++;
        }

        // 5. Ensure initial status in device_statuses for newly inserted devices
        for (final newId in newInsertedIds) {
          await _db
              .into(_db.deviceStatuses)
              .insert(
                DeviceStatusesCompanion.insert(
                  deviceId: Value(newId),
                  status: const Value('unknown'),
                  statusChangedAt: Value(now),
                ),
                mode: InsertMode.insertOrIgnore,
              );
        }

        return Result.success(insertedCount + updatedCount);
      });
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to commit inventory import: $e'),
      );
    }
  }

  @override
  Future<Result<int>> commitImport(List<DeviceEntity> validDevices) async {
    if (validDevices.isEmpty) return Result.success(0);

    // Group incoming devices strictly by their designated factoryId
    final grouped = <String, List<DeviceEntity>>{};
    for (final dev in validDevices) {
      final fid = dev.factoryId.trim().isEmpty ? 'unassigned' : dev.factoryId.trim().toLowerCase();
      grouped.putIfAbsent(fid, () => []).add(dev);
    }

    int totalCommitted = 0;
    for (final entry in grouped.entries) {
      final inserts = entry.value.where((d) => d.id <= 0).toList();
      final updates = entry.value.where((d) => d.id > 0).toList();
      final res = await commitImportPayload(
        DeviceImportCommitPayload(
          inserts: inserts,
          updates: updates,
          targetFactoryId: entry.key,
        ),
      );
      if (res.isFailure) return res;
      totalCommitted += (res.dataOrNull ?? 0);
    }
    return Result.success(totalCommitted);
  }

  @override
  Future<Result<int>> bootstrapApprovedInventory({bool force = false}) async {
    if (_useAuthoritativeService) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
    }
    // Zero data fabrication: No automatic seed rows are injected into the database.
    // Inventory enters the system strictly through user-imported spreadsheets.
    return Result.success(0);
  }

  @override
  Future<Result<int>> reassignDevicesFactory({
    required List<int> deviceIds,
    required String targetFactoryId,
    String? adminUsername,
  }) async {
    if (deviceIds.isEmpty) return Result.success(0);

    if (_useAuthoritativeService) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
      final res = await client.reassignDevicesFactory(
        deviceIds: deviceIds,
        targetFactoryId: targetFactoryId,
      );
      if (res.isSuccess) {
        return Result.success(res.data ?? deviceIds.length);
      } else {
        return Result.failure(
          NetworkFailure(res.errorMessage ?? 'Failed to reassign devices.'),
        );
      }
    }

    try {
      final now = DateTime.now();
      int updatedCount = 0;

      await _db.transaction(() async {
        for (final id in deviceIds) {
          final currentDev = await (_db.select(
            _db.devices,
          )..where((d) => d.id.equals(id))).getSingleOrNull();
          if (currentDev == null) continue;

          final canonIp = Ipv4Utils.canonicalizeIpv4(currentDev.ip);
          if (canonIp != null && canonIp.isNotEmpty) {
            final conflicting =
                await (_db.select(_db.devices)..where(
                      (t) =>
                          t.factoryId.equals(targetFactoryId) &
                          t.ip.equals(canonIp) &
                          t.id.equals(id).not(),
                    ))
                    .getSingleOrNull();
            if (conflicting != null) {
              throw Exception(
                'Cannot assign device #${currentDev.id} (${currentDev.name}): IP $canonIp already exists in factory $targetFactoryId (${conflicting.name}).',
              );
            }
          }

          // Update device factory_id, preserving all metadata and ID
          await (_db.update(_db.devices)..where((d) => d.id.equals(id))).write(
            DevicesCompanion(
              factoryId: Value(targetFactoryId),
              updatedAt: Value(now),
            ),
          );

          // Update check_results factory_id
          await (_db.update(_db.checkResults)
                ..where((r) => r.deviceId.equals(id)))
              .write(CheckResultsCompanion(factoryId: Value(targetFactoryId)));

          // Update incidents factory_id
          await (_db.update(_db.incidents)..where((i) => i.deviceId.equals(id)))
              .write(IncidentsCompanion(factoryId: Value(targetFactoryId)));

          updatedCount++;
        }
      });

      return Result.success(updatedCount);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to reassign factory: $e'));
    }
  }

  @override
  Future<Result<int>> deleteDevices(List<int> deviceIds) async {
    if (deviceIds.isEmpty) return Result.success(0);

    if (_useAuthoritativeService) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
      final res = await client.deleteDevices(deviceIds);
      if (res.isSuccess) {
        return Result.success(res.data ?? deviceIds.length);
      } else {
        return Result.failure(
          NetworkFailure(res.errorMessage ?? 'Failed to delete devices.'),
        );
      }
    }

    try {
      int deletedCount = 0;
      await _db.transaction(() async {
        for (final id in deviceIds) {
          final res = await deleteDevice(id);
          if (res.isSuccess) {
            deletedCount++;
          }
        }
      });
      return Result.success(deletedCount);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to delete devices: $e'));
    }
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
    if (deviceIds.isEmpty) return Result.success(0);

    if (_useAuthoritativeService) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
      final res = await client.bulkUpdateDevices(
        deviceIds: deviceIds,
        type: type?.toValue(),
        department: department,
        officeLocation: officeLocation,
        vendor: vendor,
        isMonitored: isMonitored,
        isEnabled: isEnabled,
      );
      if (res.isSuccess) {
        return Result.success(res.data ?? deviceIds.length);
      } else {
        return Result.failure(
          NetworkFailure(res.errorMessage ?? 'Failed to bulk update devices.'),
        );
      }
    }

    try {
      final now = DateTime.now();
      int count = 0;
      await _db.transaction(() async {
        for (final id in deviceIds) {
          final current = await (_db.select(
            _db.devices,
          )..where((d) => d.id.equals(id))).getSingleOrNull();
          if (current == null) continue;

          await (_db.update(_db.devices)..where((d) => d.id.equals(id))).write(
            DevicesCompanion(
              type: type != null ? Value(type.toValue()) : const Value.absent(),
              department: department != null
                  ? Value(department.trim())
                  : const Value.absent(),
              officeLocation: officeLocation != null
                  ? Value(officeLocation.trim())
                  : const Value.absent(),
              vendor: vendor != null
                  ? Value(vendor.trim())
                  : const Value.absent(),
              isMonitored: isMonitored != null
                  ? Value(isMonitored)
                  : const Value.absent(),
              isEnabled: isEnabled != null
                  ? Value(isEnabled)
                  : const Value.absent(),
              updatedAt: Value(now),
            ),
          );
          count++;
        }
      });

      return Result.success(count);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to bulk update devices: $e'),
      );
    }
  }
}
