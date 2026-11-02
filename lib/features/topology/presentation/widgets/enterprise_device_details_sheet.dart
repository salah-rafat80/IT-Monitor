import 'package:flutter/material.dart';

import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../domain/entities/enterprise_topology_models.dart';

/// Modal or Side Panel displaying rich details of a selected topology node or link.
class EnterpriseDeviceDetailsSheet extends StatelessWidget {
  final EnterpriseTopologyNode node;
  final VoidCallback? onOpenFullDetails;
  final VoidCallback onClose;

  const EnterpriseDeviceDetailsSheet({
    super.key,
    required this.node,
    this.onOpenFullDetails,
    required this.onClose,
  });

  Color _getStatusColor(DeviceStatusEnum status) {
    switch (status) {
      case DeviceStatusEnum.up:
        return const Color(0xFF16A34A);
      case DeviceStatusEnum.down:
      case DeviceStatusEnum.unknown:
      case DeviceStatusEnum.unreachable:
        return const Color(0xFFDC2626);
      case DeviceStatusEnum.degraded:
        return const Color(0xFFD97706);
      case DeviceStatusEnum.maintenance:
        return const Color(0xFF0284C7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(node.status);

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
        border: const Border(left: BorderSide(color: Color(0xFF334155))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF334155))),
              color: Color(0xFF0F172A),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.devices_rounded,
                    size: 18,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF8FAFC),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            node.status.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: Color(0xFF94A3B8),
                  ),
                  onPressed: onClose,
                  splashRadius: 18,
                ),
              ],
            ),
          ),

          // ── Metadata List ──────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildInfoSection('Network Identity', [
                  _buildDetailRow(
                    'IP Address',
                    node.subtitle ?? node.deviceRef?.ip ?? '--',
                    isMonospace: true,
                  ),
                  if (node.mac != null && node.mac!.isNotEmpty)
                    _buildDetailRow(
                      'MAC Address',
                      node.mac!,
                      isMonospace: true,
                    ),
                  _buildDetailRow('Category', node.category.displayName),
                  if (node.hostname != null && node.hostname!.isNotEmpty)
                    _buildDetailRow('Hostname', node.hostname!),
                  if (node.lastLatencyMs != null && node.lastLatencyMs! > 0)
                    _buildDetailRow('Latency', '${node.lastLatencyMs} ms'),
                ]),

                const SizedBox(height: 16),

                _buildInfoSection('Deployment & Location', [
                  _buildDetailRow('Location', node.location ?? 'Main Campus'),
                  if (node.department != null && node.department!.isNotEmpty)
                    _buildDetailRow('Department', node.department!),
                  if (node.vendor != null && node.vendor!.isNotEmpty)
                    _buildDetailRow('Vendor', node.vendor!),
                  if (node.model != null && node.model!.isNotEmpty)
                    _buildDetailRow('Model', node.model!),
                ]),

                if (node.category == TopologyDeviceCategory.switchDevice) ...[
                  const SizedBox(height: 16),
                  _buildInfoSection('Switch Port Utilization', [
                    _buildDetailRow(
                      'Active Connected Ports',
                      '${node.activePortCount ?? 0}',
                    ),
                    _buildDetailRow(
                      'Total Switch Ports',
                      '${node.totalPortCount ?? 24}',
                    ),
                    _buildDetailRow(
                      'Downstream Devices',
                      '${node.activePortCount ?? 0} endpoints/APs',
                    ),
                  ]),
                ],

                if (node.infraRef != null) ...[
                  const SizedBox(height: 16),
                  _buildInfoSection('UniFi Infrastructure Details', [
                    _buildDetailRow('Role', node.infraRef!.role.displayName),
                    _buildDetailRow(
                      'Enabled State',
                      node.infraRef!.isEnabled ? 'Active' : 'Disabled',
                    ),
                    if (node.infraRef!.siteName.isNotEmpty)
                      _buildDetailRow('Site', node.infraRef!.siteName),
                    if (node.infraRef!.controllerUrl != null &&
                        node.infraRef!.controllerUrl!.isNotEmpty)
                      _buildDetailRow(
                        'Controller',
                        node.infraRef!.controllerUrl!,
                      ),
                  ]),
                ],
              ],
            ),
          ),

          // ── Footer Actions ─────────────────────────────────────────────────
          if (onOpenFullDetails != null && node.deviceRef != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF334155))),
                color: Color(0xFF0F172A),
              ),
              child: ElevatedButton.icon(
                onPressed: onOpenFullDetails,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('View Full Device Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isMonospace = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: isMonospace ? 'Consolas' : null,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFF8FAFC),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
