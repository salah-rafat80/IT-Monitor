// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../../features/devices/data/repositories/device_repository_impl.dart'
    as _i313;
import '../../features/devices/domain/repositories/device_repository.dart'
    as _i1071;
import '../../features/devices/presentation/bloc/devices_cubit.dart' as _i264;
import '../../features/factories/data/repositories/factory_repository_impl.dart'
    as _i801;
import '../../features/factories/domain/repositories/factory_repository.dart'
    as _i911;
import '../../features/factories/domain/services/network_detection_service.dart'
    as _i404;
import '../../features/factories/presentation/bloc/factory_cubit.dart' as _i418;
import '../../features/infrastructure/data/datasources/unifi_api_client.dart'
    as _i1032;
import '../../features/infrastructure/data/repositories/infrastructure_repository_impl.dart'
    as _i921;
import '../../features/infrastructure/domain/repositories/infrastructure_repository.dart'
    as _i114;
import '../../features/infrastructure/presentation/bloc/infrastructure_cubit.dart'
    as _i236;
import '../../features/inventory/domain/services/excel_inventory_service.dart'
    as _i93;
import '../../features/monitoring/data/datasources/monitoring_service_client.dart'
    as _i63;
import '../../features/monitoring/data/datasources/platform_ping_checker.dart'
    as _i820;
import '../../features/monitoring/data/repositories/monitoring_repository_impl.dart'
    as _i592;
import '../../features/monitoring/domain/repositories/monitoring_repository.dart'
    as _i365;
import '../../features/monitoring/domain/services/monitoring_scheduler.dart'
    as _i714;
import '../../features/monitoring/domain/services/ping_checker.dart' as _i217;
import '../../features/monitoring/presentation/bloc/monitoring_cubit.dart'
    as _i651;
import '../../features/monitoring/presentation/bloc/monitoring_dashboard_cubit.dart'
    as _i1070;
import '../../features/network_discovery/data/datasources/strategies/arp_discovery_strategy.dart'
    as _i575;
import '../../features/network_discovery/data/datasources/strategies/dns_hostname_strategy.dart'
    as _i819;
import '../../features/network_discovery/data/datasources/strategies/icmp_discovery_strategy.dart'
    as _i693;
import '../../features/network_discovery/data/datasources/strategies/mdns_ssdp_discovery_strategy.dart'
    as _i904;
import '../../features/network_discovery/data/datasources/strategies/onvif_discovery_strategy.dart'
    as _i241;
import '../../features/network_discovery/data/datasources/strategies/tcp_probe_discovery_strategy.dart'
    as _i400;
import '../../features/network_discovery/data/repositories/discovery_repository_impl.dart'
    as _i670;
import '../../features/network_discovery/domain/repositories/discovery_repository.dart'
    as _i379;
import '../../features/network_discovery/domain/services/device_classification_engine.dart'
    as _i547;
import '../../features/network_discovery/domain/services/discovery_coordinator.dart'
    as _i993;
import '../../features/network_discovery/domain/services/mac_vendor_lookup.dart'
    as _i547;
import '../../features/network_discovery/domain/services/network_range_validator.dart'
    as _i185;
import '../../features/network_discovery/presentation/bloc/network_discovery_cubit.dart'
    as _i319;
import '../../features/topology/domain/services/enterprise_topology_builder.dart'
    as _i524;
import '../../features/topology/domain/services/topology_grouper.dart' as _i289;
import '../../features/topology/presentation/bloc/topology_cubit.dart' as _i907;
import '../database/app_database.dart' as _i982;
import '../theme/theme_cubit.dart' as _i611;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.lazySingleton<_i982.AppDatabase>(() => _i982.AppDatabase());
    gh.lazySingleton<_i1032.UniFiApiClient>(() => _i1032.UniFiApiClient());
    gh.lazySingleton<_i819.DnsHostnameStrategy>(
      () => _i819.DnsHostnameStrategy(),
    );
    gh.lazySingleton<_i693.IcmpDiscoveryStrategy>(
      () => _i693.IcmpDiscoveryStrategy(),
    );
    gh.lazySingleton<_i904.MdnsSsdpDiscoveryStrategy>(
      () => _i904.MdnsSsdpDiscoveryStrategy(),
    );
    gh.lazySingleton<_i241.OnvifDiscoveryStrategy>(
      () => _i241.OnvifDiscoveryStrategy(),
    );
    gh.lazySingleton<_i400.TcpProbeDiscoveryStrategy>(
      () => _i400.TcpProbeDiscoveryStrategy(),
    );
    gh.lazySingleton<_i547.MacVendorLookup>(() => _i547.MacVendorLookup());
    gh.lazySingleton<_i185.NetworkRangeValidator>(
      () => _i185.NetworkRangeValidator(),
    );
    gh.lazySingleton<_i524.EnterpriseTopologyBuilder>(
      () => const _i524.EnterpriseTopologyBuilder(),
    );
    gh.lazySingleton<_i289.TopologyGrouper>(
      () => const _i289.TopologyGrouper(),
    );
    gh.lazySingleton<_i1071.DeviceRepository>(
      () => _i313.DeviceRepositoryImpl(
        gh<_i982.AppDatabase>(),
        gh<_i63.MonitoringServiceClient>(),
      ),
    );
    gh.lazySingleton<_i217.PingChecker>(() => _i820.PlatformPingChecker());
    gh.lazySingleton<_i611.ThemeCubit>(() => _i611.ThemeCubit());
    gh.lazySingleton<_i404.NetworkDetectionService>(
      () => _i404.NetworkDetectionServiceImpl(),
    );
    gh.lazySingleton<_i379.DiscoveryRepository>(
      () => _i670.DiscoveryRepositoryImpl(
        gh<_i982.AppDatabase>(),
        gh<_i63.MonitoringServiceClient>(),
      ),
    );
    gh.lazySingleton<_i575.ArpDiscoveryStrategy>(
      () => _i575.ArpDiscoveryStrategy(gh<_i547.MacVendorLookup>()),
    );
    gh.lazySingleton<_i547.DeviceClassificationEngine>(
      () => _i547.DeviceClassificationEngine(gh<_i547.MacVendorLookup>()),
    );
    gh.lazySingleton<_i93.ExcelInventoryService>(
      () => _i93.ExcelInventoryServiceImpl(),
    );
    gh.lazySingleton<_i114.InfrastructureRepository>(
      () => _i921.InfrastructureRepositoryImpl(
        gh<_i982.AppDatabase>(),
        gh<_i63.MonitoringServiceClient>(),
      ),
    );
    gh.lazySingleton<_i911.FactoryRepository>(
      () => _i801.FactoryRepositoryImpl(
        gh<_i982.AppDatabase>(),
        gh<_i63.MonitoringServiceClient>(),
      ),
    );
    gh.lazySingleton<_i365.MonitoringRepository>(
      () => _i592.MonitoringRepositoryImpl(
        gh<_i982.AppDatabase>(),
        gh<_i63.MonitoringServiceClient>(),
      ),
    );
    gh.factory<_i264.DevicesCubit>(
      () => _i264.DevicesCubit(gh<_i1071.DeviceRepository>()),
    );
    gh.lazySingleton<_i993.DiscoveryCoordinator>(
      () => _i993.DiscoveryCoordinator(
        gh<_i379.DiscoveryRepository>(),
        gh<_i1071.DeviceRepository>(),
        gh<_i185.NetworkRangeValidator>(),
        gh<_i547.DeviceClassificationEngine>(),
        gh<_i547.MacVendorLookup>(),
        gh<_i693.IcmpDiscoveryStrategy>(),
        gh<_i575.ArpDiscoveryStrategy>(),
        gh<_i819.DnsHostnameStrategy>(),
        gh<_i400.TcpProbeDiscoveryStrategy>(),
        gh<_i241.OnvifDiscoveryStrategy>(),
        gh<_i904.MdnsSsdpDiscoveryStrategy>(),
        gh<_i114.InfrastructureRepository>(),
        gh<_i911.FactoryRepository>(),
      ),
    );
    gh.lazySingleton<_i418.FactoryCubit>(
      () => _i418.FactoryCubit(
        gh<_i911.FactoryRepository>(),
        gh<_i404.NetworkDetectionService>(),
      ),
    );
    gh.lazySingleton<_i236.InfrastructureCubit>(
      () => _i236.InfrastructureCubit(
        gh<_i114.InfrastructureRepository>(),
        gh<_i365.MonitoringRepository>(),
        gh<_i217.PingChecker>(),
      ),
    );
    gh.factory<_i319.NetworkDiscoveryCubit>(
      () => _i319.NetworkDiscoveryCubit(
        gh<_i379.DiscoveryRepository>(),
        gh<_i1071.DeviceRepository>(),
        gh<_i993.DiscoveryCoordinator>(),
        gh<_i185.NetworkRangeValidator>(),
        gh<_i114.InfrastructureRepository>(),
      ),
    );
    gh.factory<_i907.TopologyCubit>(
      () => _i907.TopologyCubit(
        gh<_i1071.DeviceRepository>(),
        gh<_i114.InfrastructureRepository>(),
        gh<_i365.MonitoringRepository>(),
        gh<_i289.TopologyGrouper>(),
        gh<_i524.EnterpriseTopologyBuilder>(),
        gh<_i714.MonitoringScheduler>(),
      ),
    );
    gh.lazySingleton<_i714.MonitoringScheduler>(
      () => _i714.MonitoringScheduler(
        gh<_i1071.DeviceRepository>(),
        gh<_i365.MonitoringRepository>(),
        gh<_i217.PingChecker>(),
        gh<_i114.InfrastructureRepository>(),
        gh<_i911.FactoryRepository>(),
      ),
    );
    gh.factory<_i1070.MonitoringDashboardCubit>(
      () => _i1070.MonitoringDashboardCubit(
        gh<_i1071.DeviceRepository>(),
        gh<_i365.MonitoringRepository>(),
        gh<_i714.MonitoringScheduler>(),
      ),
    );
    gh.factory<_i651.MonitoringCubit>(
      () => _i651.MonitoringCubit(
        gh<_i714.MonitoringScheduler>(),
        gh<_i365.MonitoringRepository>(),
      ),
    );
    return this;
  }
}
