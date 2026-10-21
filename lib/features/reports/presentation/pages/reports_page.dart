import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/report_entity.dart';
import '../bloc/reports_cubit.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<ReportsCubit>()..loadReport(ReportPeriod.last24Hours),
      child: const _ReportsView(),
    );
  }
}

class _ReportsView extends StatelessWidget {
  const _ReportsView();

  Widget _buildSummaryCard({
    required double width,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: BlocConsumer<ReportsCubit, ReportsState>(
          listener: (context, state) {
            if (state is ReportsLoaded && state.message != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message!),
                  backgroundColor: AppColors.primary,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is ReportsLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (state is ReportsError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AppColors.statusDown,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      style: const TextStyle(color: AppColors.textPrimaryDark),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          context.read<ReportsCubit>().loadReport(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (state is ReportsLoaded) {
              final report = state.report;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header & Period Controls
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 850;
                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Uptime & Availability Reports',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimaryDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Historical telemetry statistics from ${report.startDate.toString().split('.')[0]} to ${report.endDate.toString().split('.')[0]}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryDark,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SegmentedButton<ReportPeriod>(
                                  segments: const [
                                    ButtonSegment(
                                      value: ReportPeriod.last24Hours,
                                      label: Text('24 Hours'),
                                    ),
                                    ButtonSegment(
                                      value: ReportPeriod.last7Days,
                                      label: Text('7 Days'),
                                    ),
                                    ButtonSegment(
                                      value: ReportPeriod.last30Days,
                                      label: Text('30 Days'),
                                    ),
                                  ],
                                  selected: {report.period},
                                  onSelectionChanged: (selection) {
                                    context.read<ReportsCubit>().loadReport(
                                      selection.first,
                                    );
                                  },
                                ),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      context.read<ReportsCubit>().exportCsv(),
                                  icon: const Icon(
                                    Icons.download_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Export CSV'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Uptime & Availability Reports',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimaryDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Historical telemetry statistics from ${report.startDate.toString().split('.')[0]} to ${report.endDate.toString().split('.')[0]}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Row(
                            children: [
                              SegmentedButton<ReportPeriod>(
                                segments: const [
                                  ButtonSegment(
                                    value: ReportPeriod.last24Hours,
                                    label: Text('Last 24 Hours'),
                                  ),
                                  ButtonSegment(
                                    value: ReportPeriod.last7Days,
                                    label: Text('Last 7 Days'),
                                  ),
                                  ButtonSegment(
                                    value: ReportPeriod.last30Days,
                                    label: Text('Last 30 Days'),
                                  ),
                                ],
                                selected: {report.period},
                                onSelectionChanged: (selection) {
                                  context.read<ReportsCubit>().loadReport(
                                    selection.first,
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    context.read<ReportsCubit>().exportCsv(),
                                icon: const Icon(
                                  Icons.download_rounded,
                                  size: 18,
                                ),
                                label: const Text('Export CSV'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Summary KPI Row
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 900;
                      final cardWidth = isNarrow
                          ? (constraints.maxWidth - 12) / 2
                          : (constraints.maxWidth - (3 * 12)) / 4;

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildSummaryCard(
                            width: cardWidth,
                            title: 'NETWORK AVAILABILITY',
                            value: report.overallAvailabilityPercent != null
                                ? '${report.overallAvailabilityPercent}%'
                                : 'N/A',
                            icon: Icons.stacked_line_chart_rounded,
                            color: report.overallAvailabilityPercent == null
                                ? AppColors.textSecondaryDark
                                : (report.overallAvailabilityPercent! >= 98.0
                                      ? AppColors.statusUp
                                      : (report.overallAvailabilityPercent! >=
                                                90.0
                                            ? AppColors.statusDegraded
                                            : AppColors.statusDown)),
                            subtitle: report.overallAvailabilityPercent == null
                                ? 'Insufficient Telemetry'
                                : '${report.totalDevices} Monitored Devices',
                          ),
                          _buildSummaryCard(
                            width: cardWidth,
                            title: 'TOTAL CHECKS',
                            value: '${report.totalCheckCount}',
                            icon: Icons.checklist_rounded,
                            color: AppColors.primary,
                            subtitle:
                                '${report.successfulCheckCount} Successful / ${report.failedCheckCount} Failed',
                          ),
                          _buildSummaryCard(
                            width: cardWidth,
                            title: 'AVG LATENCY',
                            value: '${report.avgLatencyMs} ms',
                            icon: Icons.speed_rounded,
                            color: AppColors.accent,
                          ),
                          _buildSummaryCard(
                            width: cardWidth,
                            title: 'INCIDENTS LOGGED',
                            value: '${report.totalIncidents}',
                            icon: Icons.warning_amber_rounded,
                            color: report.totalIncidents > 0
                                ? AppColors.statusDown
                                : AppColors.statusUp,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Device Availability DataTable Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Device Uptime Breakdown',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              title: const Text('Data Retention Cleanup'),
                              content: const Text(
                                'Purge historical ping check results older than 30 days to optimize database size?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(dialogCtx);
                                    context.read<ReportsCubit>().purgeOldData(
                                      30,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.statusDown,
                                  ),
                                  child: const Text('Purge >30 Days'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.cleaning_services_rounded,
                          size: 16,
                        ),
                        label: const Text('Purge History (>30d)'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // DataTable
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.darkCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.darkBorder),
                      ),
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            AppColors.darkSurface,
                          ),
                          columns: const [
                            DataColumn(
                              label: Text(
                                'OWNER NAME',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'DEPARTMENT',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'DEVICE NAME',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'IP ADDRESS',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'UPTIME %',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'TOTAL CHECKS',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'FAILED CHECKS',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'AVG LATENCY',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                            ),
                          ],
                          rows: report.deviceUptimes.map((dev) {
                            final hasHistory =
                                dev.hasSufficientHistory &&
                                dev.uptimePercent != null;
                            final uptimeColor = !hasHistory
                                ? AppColors.textSecondaryDark
                                : (dev.uptimePercent! >= 98.0
                                      ? AppColors.statusUp
                                      : (dev.uptimePercent! >= 90.0
                                            ? AppColors.statusDegraded
                                            : AppColors.statusDown));
                            final uptimeText = hasHistory
                                ? '${dev.uptimePercent}%'
                                : 'N/A (No Data)';

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    dev.ownerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimaryDark,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    dev.department,
                                    style: const TextStyle(
                                      color: AppColors.textSecondaryDark,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    dev.deviceName,
                                    style: const TextStyle(
                                      color: AppColors.textPrimaryDark,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    dev.ip,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: uptimeColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: uptimeColor,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      uptimeText,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: uptimeColor,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${dev.totalChecks}',
                                    style: const TextStyle(
                                      color: AppColors.textPrimaryDark,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${dev.failedChecks}',
                                    style: TextStyle(
                                      color: dev.failedChecks > 0
                                          ? AppColors.statusDown
                                          : AppColors.textSecondaryDark,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${dev.avgLatencyMs} ms',
                                    style: const TextStyle(
                                      color: AppColors.textPrimaryDark,
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
                ],
              );
            }

            return const SizedBox();
          },
        ),
      ),
    );
  }
}
