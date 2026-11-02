import '../../../../core/utils/result.dart';
import '../entities/factory_entity.dart';

import '../entities/gateway_status_entity.dart';

abstract class FactoryRepository {
  Future<Result<List<FactoryEntity>>> getFactories({
    bool includeInactive = false,
  });
  Future<Result<FactoryEntity?>> getFactoryById(String id);
  Future<Result<FactoryEntity?>> getFactoryByCode(String code);
  Future<Result<FactoryEntity>> createFactory(FactoryEntity factory);
  Future<Result<FactoryEntity>> updateFactory(FactoryEntity factory);
  Future<Result<void>> deleteFactory(String id);
  Stream<List<FactoryEntity>> watchFactories();

  // First-class Gateway Monitoring Persistence
  Future<Result<List<GatewayStatusEntity>>> getGatewayStatuses();
  Future<Result<GatewayStatusEntity?>> getGatewayStatus(String factoryId);
  Future<Result<void>> saveGatewayStatus(GatewayStatusEntity status);
  Stream<List<GatewayStatusEntity>> watchGatewayStatuses();
}
