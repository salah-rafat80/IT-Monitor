import 'package:flutter/material.dart';

import '../../domain/services/excel_inventory_service.dart';

class ExcelImportPreviewDialog extends StatelessWidget {
  final ExcelImportSummary summary;
  final String factoryCode;
  final VoidCallback onConfirm;

  const ExcelImportPreviewDialog({
    super.key,
    required this.summary,
    required this.factoryCode,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final validRows = summary.rows.where((r) => r.isValid).toList();
    final invalidRows = summary.rows.where((r) => r.isInvalid).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F62FE).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.table_view_rounded,
                      color: Color(0xFF0F62FE),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Excel Inventory Import Preview — ${factoryCode.toUpperCase()}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Target Factory: ${factoryCode.toUpperCase()} | Existing devices will be preserved unless updated explicitly.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // KPI stats cards
              Row(
                children: [
                  _StatBadge(
                    label: 'New Devices to Insert',
                    count: summary.insertCount,
                    color: const Color(0xFF10B981),
                    icon: Icons.add_circle_outline_rounded,
                  ),
                  const SizedBox(width: 12),
                  _StatBadge(
                    label: 'Existing to Update',
                    count: summary.updateCount,
                    color: const Color(0xFF0F62FE),
                    icon: Icons.update_rounded,
                  ),
                  const SizedBox(width: 12),
                  _StatBadge(
                    label: 'Invalid / Rejected',
                    count: summary.invalidCount,
                    color: Colors.redAccent,
                    icon: Icons.error_outline_rounded,
                  ),
                  const SizedBox(width: 12),
                  _StatBadge(
                    label: 'Total Rows Processed',
                    count: summary.rows.length,
                    color: Colors.grey[400]!,
                    icon: Icons.receipt_long_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tab View: Valid rows vs Invalid rows
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: theme.colorScheme.primary,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: theme.colorScheme.primary,
                        tabs: [
                          Tab(text: 'Valid Devices (${validRows.length})'),
                          Tab(
                            text:
                                'Invalid / Rejected Rows (${invalidRows.length})',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Valid Rows Table
                            validRows.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No valid devices found in the imported spreadsheet.',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: theme.dividerColor.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.vertical,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          headingRowHeight: 40,
                                          dataRowMinHeight: 38,
                                          dataRowMaxHeight: 38,
                                          columns: const [
                                            DataColumn(label: Text('Row')),
                                            DataColumn(label: Text('Action')),
                                            DataColumn(
                                              label: Text('Device Name'),
                                            ),
                                            DataColumn(
                                              label: Text('IP Address'),
                                            ),
                                            DataColumn(
                                              label: Text('Owner Name'),
                                            ),
                                            DataColumn(
                                              label: Text('Department'),
                                            ),
                                            DataColumn(label: Text('Type')),
                                          ],
                                          rows: validRows.map((r) {
                                            final isInsert =
                                                r.action == 'insert';
                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  Text('#${r.rowIndex}'),
                                                ),
                                                DataCell(
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: isInsert
                                                          ? const Color(
                                                              0xFF10B981,
                                                            ).withValues(
                                                              alpha: 0.2,
                                                            )
                                                          : const Color(
                                                              0xFF0F62FE,
                                                            ).withValues(
                                                              alpha: 0.2,
                                                            ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      isInsert
                                                          ? 'INSERT'
                                                          : 'UPDATE',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: isInsert
                                                            ? const Color(
                                                                0xFF10B981,
                                                              )
                                                            : const Color(
                                                                0xFF0F62FE,
                                                              ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    r.device?.name ?? r.rawName,
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    r.device?.ip ?? r.rawIp,
                                                    style: const TextStyle(
                                                      fontFamily: 'monospace',
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    r.device?.ownerName ??
                                                        r.rawOwner,
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    r.device?.department ??
                                                        r.rawDepartment,
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    r
                                                            .device
                                                            ?.type
                                                            .displayName ??
                                                        '—',
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ),

                            // Invalid Rows Table
                            invalidRows.isEmpty
                                ? const Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          color: Color(0xFF10B981),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'All rows in the spreadsheet are valid!',
                                          style: TextStyle(
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.red.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.vertical,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          headingRowHeight: 40,
                                          dataRowMinHeight: 38,
                                          dataRowMaxHeight: 38,
                                          columns: const [
                                            DataColumn(label: Text('Row #')),
                                            DataColumn(
                                              label: Text('Device / IP'),
                                            ),
                                            DataColumn(
                                              label: Text('Rejection Reason'),
                                            ),
                                          ],
                                          rows: invalidRows.map((r) {
                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  Text(
                                                    'Row ${r.rowIndex}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    '${r.rawName.isNotEmpty ? r.rawName : "[No Name]"} (${r.rawIp.isNotEmpty ? r.rawIp : "[No IP]"})',
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    r.rejectionReason ??
                                                        'Validation error',
                                                    style: const TextStyle(
                                                      color: Colors.redAccent,
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
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Actions Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel Import'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F62FE),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onPressed: validRows.isEmpty
                        ? null
                        : () {
                            Navigator.of(context).pop(true);
                            onConfirm();
                          },
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      'Confirm & Apply ${validRows.length} Changes to ${factoryCode.toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatBadge({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
