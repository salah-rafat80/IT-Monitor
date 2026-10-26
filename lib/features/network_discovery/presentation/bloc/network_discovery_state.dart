import 'package:equatable/equatable.dart';

import '../../domain/entities/device_category.dart';
import '../../domain/entities/discovered_device_entity.dart';
import '../../domain/entities/discovery_config_entity.dart';
import '../../domain/entities/discovery_progress.dart';
import '../../domain/entities/discovery_scan_job.dart';
import '../../domain/entities/network_range.dart';
import '../../domain/entities/review_state.dart';

abstract class NetworkDiscoveryState extends Equatable {
  const NetworkDiscoveryState();

  @override
  List<Object?> get props => [];
}

class NetworkDiscoveryInitial extends NetworkDiscoveryState {
  const NetworkDiscoveryInitial();
}

class NetworkDiscoveryLoading extends NetworkDiscoveryState {
  const NetworkDiscoveryLoading();
}

class NetworkDiscoveryLoaded extends NetworkDiscoveryState {
  final DiscoveryConfigEntity config;
  final DiscoveryScanJob? latestScan;
  final List<DiscoveredDeviceEntity> discoveredDevices;
  final List<DiscoveredDeviceEntity> filteredDevices;
  final List<DiscoveryScanJob> allScans;
  final List<NetworkRange> rangesWithStatus;
  final bool isScanning;
  final String searchQuery;
  final DeviceCategory? categoryFilter;
  final ReviewState? reviewFilter;
  final String? subnetFilter;
  final DiscoveryProgress? progress;
  final String? errorMessage;

  const NetworkDiscoveryLoaded({
    required this.config,
    this.latestScan,
    this.discoveredDevices = const [],
    this.filteredDevices = const [],
    this.allScans = const [],
    this.rangesWithStatus = const [],
    this.isScanning = false,
    this.searchQuery = '',
    this.categoryFilter,
    this.reviewFilter,
    this.subnetFilter,
    this.progress,
    this.errorMessage,
  });

  // Derived Summary Counters from actual scan results
  int get totalDiscovered => discoveredDevices.length;
  int get pendingReviewCount => discoveredDevices
      .where((d) => d.reviewState == ReviewState.pendingReview)
      .length;
  int get alreadyKnownCount => discoveredDevices
      .where((d) => d.reviewState == ReviewState.alreadyKnown)
      .length;
  int get approvedCount => discoveredDevices
      .where((d) => d.reviewState == ReviewState.approved)
      .length;
  int get rejectedCount => discoveredDevices
      .where((d) => d.reviewState == ReviewState.rejected)
      .length;
  int get conflictCount => discoveredDevices
      .where((d) => d.reviewState == ReviewState.conflict)
      .length;
  int get classifiedCount => discoveredDevices
      .where((d) => d.predictedCategory != DeviceCategory.unknown)
      .length;
  int get unknownCount => discoveredDevices
      .where((d) => d.predictedCategory == DeviceCategory.unknown)
      .length;

  NetworkDiscoveryLoaded copyWith({
    DiscoveryConfigEntity? config,
    DiscoveryScanJob? latestScan,
    List<DiscoveredDeviceEntity>? discoveredDevices,
    List<DiscoveredDeviceEntity>? filteredDevices,
    List<DiscoveryScanJob>? allScans,
    List<NetworkRange>? rangesWithStatus,
    bool? isScanning,
    String? searchQuery,
    DeviceCategory? categoryFilter,
    bool clearCategoryFilter = false,
    ReviewState? reviewFilter,
    bool clearReviewFilter = false,
    String? subnetFilter,
    bool clearSubnetFilter = false,
    DiscoveryProgress? progress,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return NetworkDiscoveryLoaded(
      config: config ?? this.config,
      latestScan: latestScan ?? this.latestScan,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      filteredDevices: filteredDevices ?? this.filteredDevices,
      allScans: allScans ?? this.allScans,
      rangesWithStatus: rangesWithStatus ?? this.rangesWithStatus,
      isScanning: isScanning ?? this.isScanning,
      searchQuery: searchQuery ?? this.searchQuery,
      categoryFilter: clearCategoryFilter
          ? null
          : (categoryFilter ?? this.categoryFilter),
      reviewFilter: clearReviewFilter
          ? null
          : (reviewFilter ?? this.reviewFilter),
      subnetFilter: clearSubnetFilter
          ? null
          : (subnetFilter ?? this.subnetFilter),
      progress: progress ?? this.progress,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    config,
    latestScan,
    discoveredDevices,
    filteredDevices,
    allScans,
    rangesWithStatus,
    isScanning,
    searchQuery,
    categoryFilter,
    reviewFilter,
    subnetFilter,
    progress,
    errorMessage,
  ];
}

class NetworkDiscoveryError extends NetworkDiscoveryState {
  final String message;

  const NetworkDiscoveryError(this.message);

  @override
  List<Object?> get props => [message];
}
