import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:injectable/injectable.dart';

import '../../../../core/config/app_run_mode.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../monitoring/data/datasources/monitoring_service_client.dart';
import '../../../users/domain/repositories/audit_log_repository.dart';
import '../../data/datasources/approved_inventory_seed.dart';
import '../../data/datasources/excel_inventory_parser.dart';
import '../../domain/entities/device_entity.dart';
import '../../domain/entities/inventory_import_preview.dart';
import '../../domain/repositories/device_repository.dart';
import '../../domain/services/inventory_validator.dart';

@LazySingleton(as: DeviceRepository)
class DeviceRepositoryImpl implements DeviceRepository {
  final AppDatabase _db;
  final AuditLogRepository _auditLogRepo;
  final AuthRepository _authRepo;
  final MonitoringServiceClient? _serviceClient;

  DeviceRepositoryImpl(
    this._db,
    this._auditLogRepo,
    this._authRepo, [
    this._serviceClient,
  ]);

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

  Future<String> _getActiveUsername() async {
    final res = await _authRepo.getCurrentUser();
    return res.dataOrNull?.username ??
        'Local Administrator (No Interactive Login)';
  }

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
      final username = await _getActiveUsername();
      await _auditLogRepo.recordLog(
        username: username,
        action: 'DEVICE_ADDED',
        details:
            'Added device ${added.name} (${added.ip}) [${added.type.displayName}] owned by ${added.ownerName}.',
      );

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
      final username = await _getActiveUsername();
      await _auditLogRepo.recordLog(
        username: username,
        action: 'DEVICE_MODIFIED',
        details:
            'Updated device ${updated.name} (${updated.ip}) [${updated.type.displayName}].',
      );

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
      // 1. Permission check: Admin only
      final currentUserRes = await _authRepo.getCurrentUser();
      final currentUser = currentUserRes.dataOrNull;
      if (currentUser != null && currentUser.role != UserRole.admin) {
        return Result.failure(
          const UnauthorizedFailure(
            'Admin privileges required to assign device owners.',
          ),
        );
      }

      // 2. Fetch existing device
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
      final previousOwner = existing.displayOwner;

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

      // 7. Audit log creation: Action and details
      final String auditAction;
      if (cleanOwner == 'Unassigned') {
        auditAction = 'DEVICE_OWNER_CLEARED';
      } else if (!existing.isOwnerAssigned) {
        auditAction = 'DEVICE_OWNER_ASSIGNED';
      } else {
        auditAction = 'DEVICE_OWNER_MODIFIED';
      }

      final actingUsername = adminUsername ?? currentUser?.username ?? 'admin';
      final actingUserId = currentUser?.id;

      await _auditLogRepo.recordLog(
        userId: actingUserId,
        username: actingUsername,
        action: auditAction,
        details:
            'Device ID: $deviceId (${existing.name}, IP: ${existing.ip}). Owner changed from "$previousOwner" to "$cleanOwner".',
      );

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
      final deviceRes = await getDeviceById(id);
      final device = deviceRes.dataOrNull;

      await (_db.delete(_db.devices)..where((t) => t.id.equals(id))).go();

      if (device != null) {
        final username = await _getActiveUsername();
        await _auditLogRepo.recordLog(
          username: username,
          action: 'DEVICE_DELETED',
          details: 'Deleted device ${device.name} (${device.ip}).',
        );
      }

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

      final username = await _getActiveUsername();
      await _auditLogRepo.recordLog(
        username: username,
        action: 'DEVICE_TOGGLED',
        details:
            '${isEnabled ? "Enabled" : "Disabled"} monitoring for device ID $deviceId.',
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
  Future<Result<int>> commitImport(List<DeviceEntity> validDevices) async {
    if (_useAuthoritativeService) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
      final res = await client.importDevices(
        validDevices.map((d) => d.toJson()).toList(),
      );
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
      int count = 0;
      final now = DateTime.now();

      await _db.batch((batch) {
        for (final device in validDevices) {
          batch.insert(
            _db.devices,
            DevicesCompanion.insert(
              factoryId: Value(device.factoryId),
              name: device.name,
              type: Value(device.type.toValue()),
              ip: device.ip,
              ownerName: device.ownerName,
              department: device.department,
              officeLocation: Value(device.officeLocation),
              parentSwitchId: Value(device.parentSwitchId),
              parentSwitchName: Value(device.parentSwitchName),
              vendor: Value(device.vendor),
              model: Value(device.model),
              mac: Value(device.mac),
              hostname: Value(device.hostname),
              operatingSystem: Value(device.operatingSystem),
              notes: Value(device.notes),
              isMonitored: Value(device.isMonitored),
              isEnabled: const Value(true),
              createdAt: Value(now),
            ),
          );
          count++;
        }
      });

      // Ensure every device has a corresponding initial status record in device_statuses
      final uninitializedRows = await _db
          .customSelect(
            'SELECT d.id FROM devices d LEFT JOIN device_statuses s ON d.id = s.device_id WHERE s.device_id IS NULL',
          )
          .get();
      if (uninitializedRows.isNotEmpty) {
        await _db.batch((batch) {
          for (final row in uninitializedRows) {
            final devId = row.read<int>('id');
            batch.insert(
              _db.deviceStatuses,
              DeviceStatusesCompanion.insert(
                deviceId: Value(devId),
                status: const Value('unknown'),
                statusChangedAt: Value(now),
              ),
              mode: InsertMode.insertOrIgnore,
            );
          }
        });
      }

      final username = await _getActiveUsername();
      await _auditLogRepo.recordLog(
        username: username,
        action: 'INVENTORY_IMPORTED',
        details: 'Imported $count monitored end-user devices from inventory.',
      );

      return Result.success(count);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to commit inventory import: $e'),
      );
    }
  }

  @override
  Future<Result<int>> bootstrapApprovedInventory({bool force = false}) async {
    if (AppConfig.isProductionClient) {
      return Result.failure(
        NetworkFailure(
          'Inventory bootstrap is restricted to the authoritative service daemon.',
        ),
      );
    }

    try {
      final existingDevices = await _db.select(_db.devices).get();
      if (existingDevices.isNotEmpty && !force) {
        return Result.success(0);
      }

      final rawRows = ApprovedInventorySeed.getApprovedRawRows();
      final existingIps = existingDevices.map((d) => d.ip.trim()).toSet();

      final preview = InventoryValidator.validateRows(
        rows: rawRows,
        existingDatabaseIps: existingIps,
      );

      final countRes = await commitImport(preview.validDevices);
      if (countRes.isFailure) return countRes;

      final username = await _getActiveUsername();
      await _auditLogRepo.recordLog(
        username: username,
        action: 'APPROVED_INVENTORY_BOOTSTRAPPED',
        details:
            'Bootstrapped ${preview.validDevices.length} approved devices. Excluded ${preview.excludedDuplicateIps.length} duplicate IPs and ${preview.invalidRecords.length} invalid/switch rows.',
      );

      return Result.success(preview.validDevices.length);
    } catch (e) {
      return Result.failure(DatabaseFailure('Bootstrap failed: $e'));
    }
  }
}
