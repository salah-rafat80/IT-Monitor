import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    final theme = Theme.of(context);

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // Search & Engine Controller Row
          // Search & Engine Controller Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 780;

              final searchField = TextField(
                onChanged: (val) => cubit.setSearchQuery(val),
                decoration: InputDecoration(
                  hintText:
                      'Search by Owner, Department, Device Name, IP, Office Location...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: state.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => cubit.setSearchQuery(''),
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              );

              final engineStatus = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: (state.isEngineRunning && !state.isEnginePaused)
                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (state.isEngineRunning && !state.isEnginePaused)
                        ? const Color(0xFF10B981).withValues(alpha: 0.4)
                        : Colors.orange.withValues(alpha: 0.4),
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
                        color: (state.isEngineRunning && !state.isEnginePaused)
                            ? const Color(0xFF10B981)
                            : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      state.isEngineRunning
                          ? 'Engine Active (${state.config.checkIntervalSeconds}s)'
                          : 'Engine Stopped',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: (state.isEngineRunning && !state.isEnginePaused)
                            ? const Color(0xFF10B981)
                            : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        state.isEngineRunning
                            ? Icons.pause_circle_outline_rounded
                            : Icons.play_circle_outline_rounded,
                        size: 20,
                        color: state.isEngineRunning
                            ? Colors.orange
                            : const Color(0xFF10B981),
                      ),
                      onPressed: () => cubit.toggleEngine(),
                      tooltip: state.isEngineRunning
                          ? 'Pause Engine'
                          : 'Start Engine',
                    ),
                  ],
                ),
              );

              final wallDisplayBtn = ElevatedButton.icon(
                onPressed: () => GoRouter.of(context).push('/wall-display'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFF00E676,
                  ).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFF00E676),
                  side: const BorderSide(color: Color(0xFF00E676), width: 1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.tv_rounded, size: 18),
                label: const Text(
                  'Wall Display',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                      children: [
                        engineStatus,
                        wallDisplayBtn,
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 16),
                  engineStatus,
                  const SizedBox(width: 12),
                  wallDisplayBtn,
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          // Filters & Sorting Dropdowns Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Status Filter Dropdown
                _buildDropdown<String>(
                  context,
                  label: 'Status',
                  value: state.statusFilter,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Statuses')),
                    DropdownMenuItem(value: 'up', child: Text('Connected')),
                    DropdownMenuItem(
                      value: 'degraded',
                      child: Text('Degraded'),
                    ),
                    DropdownMenuItem(
                      value: 'down',
                      child: Text('Disconnected'),
                    ),
                    DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
                    DropdownMenuItem(
                      value: 'maintenance',
                      child: Text('Maintenance'),
                    ),
                  ],
                  onChanged: (val) => cubit.setStatusFilter(val),
                ),
                const SizedBox(width: 12),

                // Department Filter Dropdown
                _buildDropdown<String>(
                  context,
                  label: 'Department',
                  value: state.departmentFilter,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Departments'),
                    ),
                    ...departments.map(
                      (dept) =>
                          DropdownMenuItem(value: dept, child: Text(dept)),
                    ),
                  ],
                  onChanged: (val) => cubit.setDepartmentFilter(val),
                ),
                const SizedBox(width: 12),

                // Location Filter Dropdown
                _buildDropdown<String>(
                  context,
                  label: 'Location',
                  value: state.locationFilter,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Locations'),
                    ),
                    ...locations.map(
                      (loc) => DropdownMenuItem(value: loc, child: Text(loc)),
                    ),
                  ],
                  onChanged: (val) => cubit.setLocationFilter(val),
                ),
                const SizedBox(width: 12),

                // Type Filter Dropdown
                _buildDropdown<String>(
                  context,
                  label: 'Type',
                  value: state.typeFilter,
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text('All Types (PC & Laptop)'),
                    ),
                    DropdownMenuItem(value: 'pc', child: Text('PC')),
                    DropdownMenuItem(value: 'laptop', child: Text('Laptop')),
                  ],
                  onChanged: (val) => cubit.setTypeFilter(val),
                ),
                const SizedBox(width: 12),

                // Sorting Selector
                _buildDropdown<String>(
                  context,
                  label: 'Sort By',
                  value: state.sortBy,
                  items: const [
                    DropdownMenuItem(value: 'owner', child: Text('Owner Name')),
                    DropdownMenuItem(
                      value: 'department',
                      child: Text('Department'),
                    ),
                    DropdownMenuItem(value: 'name', child: Text('Device Name')),
                    DropdownMenuItem(value: 'ip', child: Text('IP Address')),
                    DropdownMenuItem(value: 'status', child: Text('Status')),
                    DropdownMenuItem(value: 'latency', child: Text('Latency')),
                    DropdownMenuItem(
                      value: 'lastCheck',
                      child: Text('Last Check'),
                    ),
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
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isDense: true,
          style: TextStyle(
            fontSize: 12,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }
}
