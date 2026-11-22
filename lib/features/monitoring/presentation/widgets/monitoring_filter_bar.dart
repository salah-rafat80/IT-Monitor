import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../bloc/monitoring_dashboard_cubit.dart';
import '../bloc/monitoring_dashboard_state.dart';

class MonitoringFilterBar extends StatelessWidget {
  final MonitoringDashboardLoaded state;
  final MonitoringDashboardCubit cubit;

  const MonitoringFilterBar({
    super.key,
    required this.state,
    required this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;

    // Extract unique departments and locations for dropdowns
    final departments =
        state.allDevices.map((d) => d.device.department).toSet().toList()
          ..sort();
    final locations =
        state.allDevices
            .map((d) => d.device.officeLocation)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        children: [
          // Search & Engine Controller Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 780;

              final searchField = TextField(
                onChanged: (val) => cubit.setSearchQuery(val),
                style: TextStyle(color: tokens.onInput, fontSize: 13),
                decoration: InputDecoration(
                  hintText:
                      'Search by Owner, Department, Device Name, IP, Office Location...',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: tokens.onSurfaceVariant,
                  ),
                  suffixIcon: state.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            size: 18,
                            color: tokens.onSurfaceVariant,
                          ),
                          onPressed: () => cubit.setSearchQuery(''),
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              );

              final isEngineActive = state.isEngineRunning && !state.isEnginePaused;
              final engineStatus = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isEngineActive
                      ? tokens.statusOnlineSurface
                      : tokens.statusDegradedSurface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isEngineActive
                        ? tokens.onStatusOnline.withValues(alpha: 0.35)
                        : tokens.onStatusDegraded.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isEngineActive
                            ? tokens.onStatusOnline
                            : tokens.onStatusDegraded,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        state.isEngineRunning
                            ? 'Engine Active (${state.config.checkIntervalSeconds}s)'
                            : 'Engine Stopped',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isEngineActive
                              ? tokens.onStatusOnline
                              : tokens.onStatusDegraded,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        state.isEngineRunning
                            ? Icons.pause_circle_outline_rounded
                            : Icons.play_circle_outline_rounded,
                        size: 20,
                        color: isEngineActive
                            ? tokens.onStatusOnline
                            : tokens.onStatusDegraded,
                      ),
                      onPressed: () => cubit.toggleEngine(),
                      tooltip: state.isEngineRunning
                          ? 'Pause Engine'
                          : 'Start Engine',
                    ),
                  ],
                ),
              );

              final wallDisplayBtn = FittedBox(
                fit: BoxFit.scaleDown,
                child: ElevatedButton.icon(
                  onPressed: () => GoRouter.of(context).push('/wall-display'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.primary.withValues(alpha: 0.12),
                    foregroundColor: tokens.primary,
                    side: BorderSide(color: tokens.primary, width: 1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  icon: const Icon(Icons.tv_rounded, size: 18),
                  label: const Text(
                    'Wall Display',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [engineStatus, wallDisplayBtn],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: AppSpacing.lg),
                  engineStatus,
                  const SizedBox(width: AppSpacing.md),
                  wallDisplayBtn,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Filters & Sorting Dropdowns Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Status Filter Dropdown
                _buildDropdown<String>(
                  context,
                  tokens: tokens,
                  label: 'Status',
                  value: state.statusFilter,
                  items: [
                    DropdownMenuItem(value: null, child: Text('All Statuses', style: TextStyle(color: tokens.onInput))),
                    DropdownMenuItem(value: 'up', child: Text('Connected', style: TextStyle(color: tokens.onInput))),
                    DropdownMenuItem(value: 'degraded', child: Text('Degraded', style: TextStyle(color: tokens.onInput))),
                    DropdownMenuItem(value: 'down', child: Text('Disconnected', style: TextStyle(color: tokens.onInput))),
                    DropdownMenuItem(value: 'maintenance', child: Text('Maintenance', style: TextStyle(color: tokens.onInput))),
                  ],
                  onChanged: (val) => cubit.setStatusFilter(val),
                ),
                const SizedBox(width: AppSpacing.md),

                // Department Filter Dropdown
                _buildDropdown<String>(
                  context,
                  tokens: tokens,
                  label: 'Department',
                  value: state.departmentFilter,
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text('All Departments', style: TextStyle(color: tokens.onInput)),
                    ),
                    ...departments.map(
                      (dept) => DropdownMenuItem(
                        value: dept,
                        child: Text(dept, style: TextStyle(color: tokens.onInput)),
                      ),
                    ),
                  ],
                  onChanged: (val) => cubit.setDepartmentFilter(val),
                ),
                const SizedBox(width: AppSpacing.md),

                // Location Filter Dropdown
                _buildDropdown<String>(
                  context,
                  tokens: tokens,
                  label: 'Location',
                  value: state.locationFilter,
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text('All Locations', style: TextStyle(color: tokens.onInput)),
                    ),
                    ...locations.map(
                      (loc) => DropdownMenuItem(
                        value: loc,
                        child: Text(loc, style: TextStyle(color: tokens.onInput)),
                      ),
                    ),
                  ],
                  onChanged: (val) => cubit.setLocationFilter(val),
                ),
                const SizedBox(width: AppSpacing.md),

                // Type Filter Dropdown
                _buildDropdown<String>(
                  context,
                  tokens: tokens,
                  label: 'Type',
                  value: state.typeFilter,
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text('All Types (PC & Laptop)', style: TextStyle(color: tokens.onInput)),
                    ),
                    DropdownMenuItem(value: 'pc', child: Text('PC', style: TextStyle(color: tokens.onInput))),
                    DropdownMenuItem(value: 'laptop', child: Text('Laptop', style: TextStyle(color: tokens.onInput))),
                  ],
                  onChanged: (val) => cubit.setTypeFilter(val),
                ),
                const SizedBox(width: AppSpacing.md),

                // Sorting Selector
                _buildDropdown<String>(
                  context,
                  tokens: tokens,
                  label: 'Sort By',
                  value: state.sortBy,
                  items: [
                    DropdownMenuItem(value: 'owner', child: Text('Owner Name', style: TextStyle(color: tokens.onInput))),
                    DropdownMenuItem(value: 'department', child: Text('Department', style: TextStyle(color: tokens.onInput))),
                    DropdownMenuItem(value: 'name', child: Text('Device Name', style: TextStyle(color: tokens.onInput))),
                    DropdownMenuItem(value: 'ip', child: Text('IP Address', style: TextStyle(color: tokens.onInput))),
                    DropdownMenuItem(value: 'status', child: Text('Status', style: TextStyle(color: tokens.onInput))),
                    DropdownMenuItem(value: 'latency', child: Text('Latency', style: TextStyle(color: tokens.onInput))),
                    DropdownMenuItem(value: 'lastCheck', child: Text('Last Check', style: TextStyle(color: tokens.onInput))),
                  ],
                  onChanged: (val) {
                    if (val != null) cubit.setSorting(val);
                  },
                ),
                IconButton(
                  icon: Icon(
                    state.sortAscending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 18,
                    color: tokens.onSurfaceVariant,
                  ),
                  onPressed: () => cubit.setSorting(state.sortBy),
                  tooltip: state.sortAscending
                      ? 'Sort Ascending'
                      : 'Sort Descending',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>(
    BuildContext context, {
    required AppColors tokens,
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: tokens.input,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tokens.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isDense: true,
          dropdownColor: tokens.card,
          iconEnabledColor: tokens.onSurfaceVariant,
          style: TextStyle(
            fontSize: 12,
            color: tokens.onInput,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
