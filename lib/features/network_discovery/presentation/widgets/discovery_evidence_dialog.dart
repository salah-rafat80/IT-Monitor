import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/discovered_device_entity.dart';

class DiscoveryEvidenceDialog extends StatelessWidget {
  final DiscoveredDeviceEntity device;

  const DiscoveryEvidenceDialog({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appTokens;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.fingerprint_rounded, color: tokens.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Device Fingerprint Evidence',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '${device.ip} ${device.hostname != null ? "(${device.hostname})" : ""}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.disabledColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Summary Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  children: [
                    _InfoRow(
                      'Classification',
                      '${device.effectiveCategory.displayName} (${device.confidence.displayName})',
                    ),
                    if (device.vendor != null)
                      _InfoRow('Vendor OUI', device.vendor!),
                    if (device.mac != null)
                      _InfoRow('MAC Address', device.mac!),
                    _InfoRow('First Seen', dateFormat.format(device.firstSeen)),
                    _InfoRow('Last Seen', dateFormat.format(device.lastSeen)),
                    if (device.observedServices.isNotEmpty)
                      _InfoRow(
                        'Observed Services',
                        device.observedServices.join(', '),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Collected Diagnostic Evidence Items:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),

              if (device.evidence.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text('No detailed probe evidence items recorded.'),
                  ),
                )
              else
                ...device.evidence.map((ev) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ev.isSuccess
                          ? tokens.statusOnlineSurface
                          : tokens.statusOfflineSurface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: ev.isSuccess
                            ? tokens.statusOnline.withValues(alpha: 0.2)
                            : tokens.statusOffline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          ev.isSuccess
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          size: 18,
                          color: ev.isSuccess
                              ? tokens.statusOnline
                              : tokens.statusOffline,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    ev.strategyName.toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    dateFormat.format(ev.timestamp),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: tokens.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ev.details,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.appTokens.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
