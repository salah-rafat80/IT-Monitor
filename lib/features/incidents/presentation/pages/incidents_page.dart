import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../factories/presentation/bloc/factory_cubit.dart';
import '../bloc/incidents_cubit.dart';
import '../bloc/incidents_state.dart';
import '../widgets/incident_details_modal.dart';
import '../widgets/incident_status_chip.dart';
import 'package:it_network_monitor/features/incidents/domain/entities/incident_entity.dart';

class IncidentsPage extends StatelessWidget {
  const IncidentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final initialFactoryId = context
        .read<FactoryCubit>()
        .state
        .selectedFactoryId;
    return BlocProvider<IncidentsCubit>(
      create: (context) =>
          getIt<IncidentsCubit>()..initIncidents(initialFactoryId),
      child: BlocListener<FactoryCubit, FactoryState>(
        listener: (context, state) {
          context.read<IncidentsCubit>().setFactory(state.selectedFactoryId);
        },
        child: const IncidentsView(),
      ),
    );
  }
}

class IncidentsView extends StatelessWidget {
  const IncidentsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthCubit>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final userRole = user?.role ?? UserRole.viewer;
    final currentUsername = user?.username ?? 'Viewer';
    final isAdmin = userRole == UserRole.admin;
    final factoryState = context.watch<FactoryCubit>().state;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 24),
              const SizedBox(width: 10),
              const Text('Incidents & History Log'),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAdmin
                      ? theme.primaryColor.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isAdmin
                        ? theme.primaryColor.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  isAdmin ? 'ADMIN ROLE' : 'VIEWER (READ ONLY)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isAdmin ? theme.primaryColor : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F62FE).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF0F62FE).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  factoryState.activeFactoryName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F62FE),
                  ),
                ),
              ),
            ],
          ),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.error_outline_rounded, size: 18),
                text: 'Active Incidents',
              ),
              Tab(
                icon: Icon(Icons.history_rounded, size: 18),
                text: 'Incident History Log',
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => context.read<IncidentsCubit>().refreshHistory(),
              tooltip: 'Refresh Incidents',
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: BlocBuilder<IncidentsCubit, IncidentsState>(
          builder: (context, state) {
            if (state is IncidentsLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is IncidentsError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text('Failed to load incidents: ${state.message}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          context.read<IncidentsCubit>().initIncidents(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (state is IncidentsLoaded) {
              final cubit = context.read<IncidentsCubit>();

              return TabBarView(
                children: [
                  // Tab 1: Active Incidents List
                  _buildActiveIncidentsTab(
                    context,
                    state,
                    userRole,
                    currentUsername,
                    cubit,
                  ),

                  // Tab 2: Incident History Log
                  _buildHistoryTab(
                    context,
                    state,
                    userRole,
                    currentUsername,
                    cubit,
                  ),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildActiveIncidentsTab(
    BuildContext context,
    IncidentsLoaded state,
    UserRole userRole,
    String currentUsername,
    IncidentsCubit cubit,
  ) {
    final theme = Theme.of(context);
    final active = state.activeIncidents;

    if (active.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 64,
                color: Color(0xFF10B981),
              ),
              const SizedBox(height: 16),
              const Text(
                'Zero Active Monitoring Incidents',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'All monitored PC/Laptop devices are functioning normally.',
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: active.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final inc = active[index];
        final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: inc.severity == IncidentSeverityEnum.critical
                  ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                  : theme.dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              IncidentSeverityChip(severity: inc.severity),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${inc.ownerName.trim().isEmpty || inc.ownerName.trim().toLowerCase() == "unassigned" ? "Unassigned" : inc.ownerName} (${inc.department})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color:
                                (inc.ownerName.trim().isEmpty ||
                                    inc.ownerName.trim().toLowerCase() ==
                                        "unassigned")
                                ? Colors.orangeAccent
                                : null,
                            fontStyle:
                                (inc.ownerName.trim().isEmpty ||
                                    inc.ownerName.trim().toLowerCase() ==
                                        "unassigned")
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${inc.deviceName} (${inc.deviceIp})',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Location: ${inc.location ?? "-"} | Started: ${dateFormat.format(inc.startedAt)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (inc.correlationMessage != null &&
                        inc.correlationMessage!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Signal: ${inc.correlationMessage}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IncidentStatusChip(status: inc.status),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _showDetails(
                  context,
                  inc,
                  userRole,
                  currentUsername,
                  cubit,
                ),
                icon: const Icon(Icons.info_outline_rounded, size: 16),
                label: const Text('View Details'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab(
    BuildContext context,
    IncidentsLoaded state,
    UserRole userRole,
    String currentUsername,
    IncidentsCubit cubit,
  ) {
    final theme = Theme.of(context);
    final history = state.filteredHistory;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Filter Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => cubit.setSearchQuery(val),
                  decoration: const InputDecoration(
                    hintText:
                        'Search incident history by Owner, Department, Device, IP, Location...',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: state.statusFilter,
                hint: const Text('All Statuses'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Statuses')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(
                    value: 'acknowledged',
                    child: Text('Acknowledged'),
                  ),
                  DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                ],
                onChanged: (val) => cubit.setStatusFilter(val),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // History Table
          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Text(
                      'No incident history records found.',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.1),
                          ),
                        ),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            theme.primaryColor.withValues(alpha: 0.04),
                          ),
                          columns: const [
                            DataColumn(
                              label: Text(
                                '# ID',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Owner Name',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Department',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Device',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Severity',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Status',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Started At',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Resolved At',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Actions',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          rows: history.map((inc) {
                            return DataRow(
                              cells: [
                                DataCell(Text('#${inc.id}')),
                                DataCell(
                                  Text(
                                    inc.ownerName.trim().isEmpty ||
                                            inc.ownerName
                                                    .trim()
                                                    .toLowerCase() ==
                                                'unassigned'
                                        ? 'Unassigned'
                                        : inc.ownerName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          (inc.ownerName.trim().isEmpty ||
                                              inc.ownerName
                                                      .trim()
                                                      .toLowerCase() ==
                                                  'unassigned')
                                          ? Colors.orangeAccent
                                          : null,
                                      fontStyle:
                                          (inc.ownerName.trim().isEmpty ||
                                              inc.ownerName
                                                      .trim()
                                                      .toLowerCase() ==
                                                  'unassigned')
                                          ? FontStyle.italic
                                          : FontStyle.normal,
                                    ),
                                  ),
                                ),
                                DataCell(Text(inc.department)),
                                DataCell(
                                  Text('${inc.deviceName} (${inc.deviceIp})'),
                                ),
                                DataCell(
                                  IncidentSeverityChip(severity: inc.severity),
                                ),
                                DataCell(
                                  IncidentStatusChip(status: inc.status),
                                ),
                                DataCell(
                                  Text(
                                    dateFormat.format(inc.startedAt),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    inc.resolvedAt != null
                                        ? dateFormat.format(inc.resolvedAt!)
                                        : '-',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(
                                      Icons.info_outline_rounded,
                                      size: 18,
                                    ),
                                    onPressed: () => _showDetails(
                                      context,
                                      inc,
                                      userRole,
                                      currentUsername,
                                      cubit,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showDetails(
    BuildContext context,
    inc,
    UserRole userRole,
    String currentUsername,
    IncidentsCubit cubit,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => IncidentDetailsModal(
        incident: inc,
        userRole: userRole,
        currentUsername: currentUsername,
        onAcknowledge: (id, username, note) =>
            cubit.acknowledgeIncident(id: id, username: username, note: note),
        onAddNote: (id, note) => cubit.addNote(id: id, note: note),
      ),
    );
  }
}
