import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/config/app_run_mode.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../monitoring/data/datasources/monitoring_service_client.dart';
import '../../domain/entities/unifi_device_entity.dart';
import '../../domain/repositories/infrastructure_repository.dart';

@LazySingleton(as: InfrastructureRepository)
class InfrastructureRepositoryImpl implements InfrastructureRepository {
  final AppDatabase _db;
  final MonitoringServiceClient? _serviceClient;
  StreamSubscription? _serviceEventSub;

  final StreamController<List<UniFiDeviceEntity>> _devicesController =
      StreamController<List<UniFiDeviceEntity>>.broadcast();

  InfrastructureRepositoryImpl(this._db, [this._serviceClient]) {
    _initServiceEventSubscription();
  }

  MonitoringServiceClient? get _effectiveClient =>
      _serviceClient ??
      (getIt.isRegistered<MonitoringServiceClient>()
          ? getIt<MonitoringServiceClient>()
          : null);

  void _initServiceEventSubscription() {
    final client = _effectiveClient;
    if (client != null) {
      _serviceEventSub?.cancel();
      _serviceEventSub = client.eventStream.listen((event) {
        if (event['event'] == 'infrastructure_updated' ||
            event['event'] == 'infrastructure_deleted') {
          _notifyChanged();
        }
      });
    }
  }

  @override
  Future<Result<List<UniFiDeviceEntity>>> getInfrastructureDevices({
    String? factoryId,
  }) async {
    if (AppConfig.isProductionClient) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
      final res = await client.getInfrastructureDevices(factoryId: factoryId);
      if (res.isSuccess && res.data != null) {
        final list = res.data!
            .map((item) => UniFiDeviceEntity.fromJson(item))
            .toList();
        return Result.success(list);
      } else {
        return Result.failure(
          NetworkFailure(
            'Authoritative monitoring service is unreachable (${res.errorMessage}).',
          ),
        );
      }
    }

    try {
      var query = _db.select(_db.infrastructureDevices);
      if (factoryId != null && factoryId.isNotEmpty) {
        query = query..where((t) => t.factoryId.equals(factoryId));
      }
      final rows = await query.get();
      final entities = rows.map(_mapToEntity).toList();
      return Result.success(entities);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to fetch infrastructure devices: $e'),
      );
    }
  }

  @override
  Future<Result<UniFiDeviceEntity?>> getDeviceById(int id) async {
    if (AppConfig.isProductionClient) {
      final allRes = await getInfrastructureDevices();
      if (allRes.isFailure) {
        return Result.failure(allRes.failureOrNull!);
      }
      final match = allRes.dataOrNull!.where((d) => d.id == id).firstOrNull;
      return Result.success(match);
    }

    try {
      final query = _db.select(_db.infrastructureDevices)
        ..where((t) => t.id.equals(id));
      final rows = await query.get();
      if (rows.isEmpty) return Result.success(null);
      return Result.success(_mapToEntity(rows.first));
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to fetch device by id: $e'),
      );
    }
  }

  @override
  Future<Result<UniFiDeviceEntity?>> getDeviceByIp(
    String ip, {
    String? factoryId,
  }) async {
    if (AppConfig.isProductionClient) {
      final allRes = await getInfrastructureDevices(factoryId: factoryId);
      if (allRes.isFailure) {
        return Result.failure(allRes.failureOrNull!);
      }
      final match = allRes.dataOrNull!
          .where((d) => d.ip.trim() == ip.trim())
          .firstOrNull;
      return Result.success(match);
    }

    try {
      var query = _db.select(_db.infrastructureDevices)
        ..where((t) => t.ip.equals(ip.trim()));
      if (factoryId != null && factoryId.isNotEmpty) {
        query = query..where((t) => t.factoryId.equals(factoryId));
      }
      final rows = await query.get();
      if (rows.isEmpty) return Result.success(null);
      return Result.success(_mapToEntity(rows.first));
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to fetch device by ip: $e'),
      );
    }
  }

  @override
  Future<Result<UniFiDeviceEntity>> saveInfrastructureDevice(
    UniFiDeviceEntity device,
  ) async {
    if (AppConfig.isProductionClient) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
      final res = await client.saveInfrastructureDevice(device.toJson());
      if (res.isSuccess && res.data != null) {
        final devJson =
            res.data!['device'] as Map<String, dynamic>? ?? res.data!;
        _notifyChanged();
        return Result.success(
          device.copyWith(id: devJson['id'] as int? ?? device.id),
        );
      } else {
        return Result.failure(
          NetworkFailure(
            'Failed to save infrastructure device via service API: ${res.errorMessage}',
          ),
        );
      }
    }

    try {
      final existingByIp = await getDeviceByIp(
        device.ip,
        factoryId: device.factoryId,
      );
      final existingDevice = existingByIp.dataOrNull;

      if (device.id == 0 && existingDevice != null) {
        return Result.failure(
          ValidationFailure(
            'A device with IP ${device.ip} already exists in factory ${device.factoryId}',
          ),
        );
      }

      int savedId = device.id;
      final subnetsJson = jsonEncode(device.linkedSubnets);

      if (device.id == 0) {
        savedId = await _db
            .into(_db.infrastructureDevices)
            .insert(
              InfrastructureDevicesCompanion.insert(
                factoryId: Value(device.factoryId),
                name: device.name,
                ip: device.ip.trim(),
                mac: Value(device.mac),
                role: Value(device.role.toValue()),
                location: Value(device.location),
                isCriticalInfrastructure: Value(
                  device.isCriticalInfrastructure,
                ),
                requiresAdminConfirmation: Value(
                  device.requiresAdminConfirmation,
                ),
                linkedSubnetsJson: Value(subnetsJson),
                controllerUrl: Value(device.controllerUrl),
                siteName: Value(device.siteName),
                isEnabled: Value(device.isEnabled),
                isReadOnly: const Value(true), // Strictly read-only
                createdAt: Value(device.createdAt),
                updatedAt: Value(DateTime.now()),
              ),
            );
      } else {
        await (_db.update(
          _db.infrastructureDevices,
        )..where((t) => t.id.equals(device.id))).write(
          InfrastructureDevicesCompanion(
            name: Value(device.name),
            ip: Value(device.ip.trim()),
            mac: Value(device.mac),
            role: Value(device.role.toValue()),
            location: Value(device.location),
            isCriticalInfrastructure: Value(device.isCriticalInfrastructure),
            requiresAdminConfirmation: Value(device.requiresAdminConfirmation),
            linkedSubnetsJson: Value(subnetsJson),
            controllerUrl: Value(device.controllerUrl),
            siteName: Value(device.siteName),
            isEnabled: Value(device.isEnabled),
            isReadOnly: const Value(true),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      final updatedEntity = device.copyWith(id: savedId);
      _notifyChanged();
      return Result.success(updatedEntity);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to save infrastructure device: $e'),
      );
    }
  }

  @override
  Future<Result<void>> deleteInfrastructureDevice(int id) async {
    if (AppConfig.isProductionClient) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
      final res = await client.deleteInfrastructureDevice(id);
      if (res.isSuccess) {
        _notifyChanged();
        return Result.success(null);
      } else {
        return Result.failure(
          NetworkFailure(
            'Failed to delete infrastructure device via service API: ${res.errorMessage}',
          ),
        );
      }
    }

    try {
      await (_db.delete(
        _db.infrastructureDevices,
      )..where((t) => t.id.equals(id))).go();

      _notifyChanged();
      return Result.success(null);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to delete infrastructure device: $e'),
      );
    }
  }

  @override
  Future<Result<UniFiDeviceEntity>> confirmDeviceRole({
    required int id,
    required UniFiDeviceRole role,
    required bool isCritical,
    required List<String> linkedSubnets,
  }) async {
    try {
      final existingRes = await getDeviceById(id);
      final existing = existingRes.dataOrNull;
      if (existing == null) {
        return Result.failure(
          NotFoundFailure('Infrastructure device #$id not found'),
        );
      }

      final updated = existing.copyWith(
        role: role,
        isCriticalInfrastructure: isCritical,
        requiresAdminConfirmation: false,
        linkedSubnets: linkedSubnets,
        updatedAt: DateTime.now(),
      );

      return await saveInfrastructureDevice(updated);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to confirm device role: $e'),
      );
    }
  }

  @override
  Stream<List<UniFiDeviceEntity>> watchInfrastructureDevices({
    String? factoryId,
  }) {
    if (AppConfig.isProductionClient) {
      return _devicesController.stream;
    }
    var query = _db.select(_db.infrastructureDevices);
    if (factoryId != null && factoryId.isNotEmpty) {
      query = query..where((t) => t.factoryId.equals(factoryId));
    }
    return query.watch().map((rows) => rows.map(_mapToEntity).toList());
  }

  void _notifyChanged() async {
    final res = await getInfrastructureDevices();
    if (res.isSuccess && !_devicesController.isClosed) {
      _devicesController.add(res.dataOrNull ?? []);
    }
  }

  @override
  Future<Result<void>> bootstrapVerifiedAccessPoints() async {
    if (AppConfig.isProductionClient) {
      return Result.failure(
        NetworkFailure(
          'Infrastructure bootstrap is restricted to the authoritative service daemon.',
        ),
      );
    }

    try {
      final verifiedAps = [
        (
          name: 'Packing Area',
          ip: '192.168.7.6',
          location: 'Factory Administration, Upper Area',
        ),
        (
          name: 'Meeting Room',
          ip: '192.168.7.4',
          location: 'Factory Administration, Upper Area',
        ),
        (
          name: 'FM Office',
          ip: '192.168.7.2',
          location: 'Factory Administration, Upper Area',
        ),
        (name: 'IoT_Palitizer', ip: '192.168.8.5', location: 'Lower Area'),
      ];

      bool anyAdded = false;

      for (final ap in verifiedAps) {
        final existing = await getDeviceByIp(ap.ip);
        if (existing.dataOrNull == null) {
          final insertedId = await _db
              .into(_db.infrastructureDevices)
              .insert(
                InfrastructureDevicesCompanion.insert(
                  factoryId: const Value('rnf'),
                  name: ap.name,
                  ip: ap.ip,
                  role: const Value('ap'),
                  location: Value(ap.location),
                  isCriticalInfrastructure: const Value(false),
                  requiresAdminConfirmation: const Value(false),
                  linkedSubnetsJson: const Value('[]'),
                  controllerUrl: const Value(null),
                  siteName: const Value('default'),
                  isEnabled: const Value(true),
                  isReadOnly: const Value(true),
                  createdAt: Value(DateTime.now()),
                  updatedAt: Value(DateTime.now()),
                ),
              );

          // Initialize monitoring status as unknown until actual checks run
          final virtualId = 10000 + insertedId;
          final existingStatus = await (_db.select(
            _db.deviceStatuses,
          )..where((t) => t.deviceId.equals(virtualId))).getSingleOrNull();

          if (existingStatus == null) {
            await _db
                .into(_db.deviceStatuses)
                .insert(
                  DeviceStatusesCompanion.insert(
                    deviceId: Value(virtualId),
                    status: const Value('unknown'),
                    consecutiveFailures: const Value(0),
                    consecutiveSuccesses: const Value(0),
                    statusChangedAt: Value(DateTime.now()),
                  ),
                );
          }

          anyAdded = true;
        } else {
          final dev = existing.dataOrNull!;
          if (dev.location == null || dev.location != ap.location || dev.factoryId != 'rnf') {
            await (_db.update(
              _db.infrastructureDevices,
            )..where((t) => t.id.equals(dev.id))).write(
              InfrastructureDevicesCompanion(
                factoryId: const Value('rnf'),
                location: Value(ap.location),
                updatedAt: Value(DateTime.now()),
              ),
            );
            anyAdded = true;
          }
        }
      }

      if (anyAdded) {
        _notifyChanged();
      }

      return Result.success(null);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to bootstrap verified access points: $e'),
      );
    }
  }

  @override
  Future<Result<void>> bootstrapVerifiedSwitches() async {
    if (AppConfig.isProductionClient) {
      return Result.success(null);
    }

    try {
      final verifiedSwitches = [
        (
          name: 'RNF Core Switch 1 (Floor 1 - West)',
          ip: '192.168.22.2',
          role: 'switch',
          location: 'Floor 1 - Server Area',
          factoryId: 'rnf',
          isCritical: true,
        ),
        (
          name: 'RNF Core Switch 2 (Floor 1 - East)',
          ip: '192.168.22.3',
          role: 'switch',
          location: 'Floor 1 - Operations Area',
          factoryId: 'rnf',
          isCritical: true,
        ),
        (
          name: 'Warehouse Core Switch',
          ip: '192.168.22.4',
          role: 'switch',
          location: 'Ground Floor - Central Warehouse Hub',
          factoryId: 'rnf',
          isCritical: true,
        ),
        (
          name: 'Raw Materials D-Link Switch',
          ip: '192.168.22.5',
          role: 'switch',
          location: 'Ground Floor - Raw Materials Bay',
          factoryId: 'rnf',
          isCritical: false,
        ),
        (
          name: 'Spare Parts Switch',
          ip: '192.168.22.6',
          role: 'switch',
          location: 'Ground Floor - Spare Parts Department',
          factoryId: 'rnf',
          isCritical: false,
        ),
        (
          name: 'Security Gates Switch',
          ip: '192.168.22.7',
          role: 'switch',
          location: 'Perimeter - Security Gates 1 & 2',
          factoryId: 'rnf',
          isCritical: false,
        ),
      ];

      bool anyAdded = false;

      for (final sw in verifiedSwitches) {
        final existing = await getDeviceByIp(sw.ip);
        if (existing.dataOrNull == null) {
          final insertedId = await _db
              .into(_db.infrastructureDevices)
              .insert(
                InfrastructureDevicesCompanion.insert(
                  factoryId: Value(sw.factoryId),
                  name: sw.name,
                  ip: sw.ip,
                  role: Value(sw.role),
                  location: Value(sw.location),
                  isCriticalInfrastructure: Value(sw.isCritical),
                  requiresAdminConfirmation: const Value(false),
                  linkedSubnetsJson: const Value('[]'),
                  controllerUrl: const Value(null),
                  siteName: const Value('default'),
                  isEnabled: const Value(true),
                  isReadOnly: const Value(true),
                  createdAt: Value(DateTime.now()),
                  updatedAt: Value(DateTime.now()),
                ),
              );

          final virtualId = 10000 + insertedId;
          final existingStatus = await (_db.select(
            _db.deviceStatuses,
          )..where((t) => t.deviceId.equals(virtualId))).getSingleOrNull();

          if (existingStatus == null) {
            await _db
                .into(_db.deviceStatuses)
                .insert(
                  DeviceStatusesCompanion.insert(
                    deviceId: Value(virtualId),
                    status: const Value('unknown'),
                    consecutiveFailures: const Value(0),
                    consecutiveSuccesses: const Value(0),
                    statusChangedAt: Value(DateTime.now()),
                  ),
                );
          }

          anyAdded = true;
        } else {
          final dev = existing.dataOrNull!;
          if (dev.location != sw.location || dev.factoryId != sw.factoryId || dev.name != sw.name) {
            await (_db.update(
              _db.infrastructureDevices,
            )..where((t) => t.id.equals(dev.id))).write(
              InfrastructureDevicesCompanion(
                name: Value(sw.name),
                factoryId: Value(sw.factoryId),
                location: Value(sw.location),
                role: Value(sw.role),
                isCriticalInfrastructure: Value(sw.isCritical),
                updatedAt: Value(DateTime.now()),
              ),
            );
            anyAdded = true;
          }
        }
      }

      if (anyAdded) {
        _notifyChanged();
      }

      return Result.success(null);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to bootstrap verified switches: $e'),
      );
    }
  }

  UniFiDeviceEntity _mapToEntity(InfrastructureDeviceData row) {
    List<String> subnets = [];
    try {
      final decoded = jsonDecode(row.linkedSubnetsJson);
      if (decoded is List) {
        subnets = decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    return UniFiDeviceEntity(
      id: row.id,
      factoryId: row.factoryId,
      name: row.name,
      ip: row.ip,
      mac: row.mac,
      role: UniFiDeviceRole.fromString(row.role),
      location: row.location,
      isCriticalInfrastructure: row.isCriticalInfrastructure,
      requiresAdminConfirmation: row.requiresAdminConfirmation,
      linkedSubnets: subnets,
      controllerUrl: row.controllerUrl,
      siteName: row.siteName,
      isEnabled: row.isEnabled,
      isReadOnly: row.isReadOnly,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
