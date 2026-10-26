import 'package:flutter/material.dart';

import '../../domain/entities/discovery_config_entity.dart';
import '../../domain/entities/network_range.dart';

class DiscoveryStartDialog extends StatefulWidget {
  final DiscoveryConfigEntity config;
  final List<NetworkRange> ranges;
  final Function({
    required List<String> ranges,
    required List<String> strategies,
    required int concurrency,
    required int timeoutSeconds,
  })
  onStart;

  const DiscoveryStartDialog({
    super.key,
    required this.config,
    required this.ranges,
    required this.onStart,
  });

  @override
  State<DiscoveryStartDialog> createState() => _DiscoveryStartDialogState();
}

class _DiscoveryStartDialogState extends State<DiscoveryStartDialog> {
  late Set<String> _selectedRanges;
  late Set<String> _selectedStrategies;
  late int _concurrency;
  late int _timeoutSeconds;

  @override
  void initState() {
    super.initState();
    _selectedRanges = widget.ranges
        .where((r) => r.isEnabled)
        .map((r) => r.cidr)
        .toSet();
    _selectedStrategies = widget.config.enabledStrategies.toSet();
    _concurrency = widget.config.maxConcurrency;
    _timeoutSeconds = widget.config.timeoutSeconds;
  }

  @override
  Widget build(BuildContext context) {
    final totalTargets = widget.ranges
        .where((r) => _selectedRanges.contains(r.cidr))
        .fold<int>(0, (sum, r) => sum + r.usableHostsCount);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.radar_rounded, color: Color(0xFF0F62FE)),
          SizedBox(width: 10),
          Text('Configure & Launch Network Discovery'),
        ],
      ),
      content: SizedBox(
        width: 550,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.ranges.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No authorized network ranges configured. An administrator must add an authorized network scope before discovery can run.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F62FE).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF0F62FE).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFF0F62FE),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Total of $totalTargets candidate host addresses will be scanned across ${_selectedRanges.length} authorized subnets using safe read-only probes.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'Target Network Scopes:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              if (widget.ranges.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No network ranges configured.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                )
              else
                ...widget.ranges.map((r) {
                  final isChecked = _selectedRanges.contains(r.cidr);
                  return CheckboxListTile(
                    dense: true,
                    enabled: r.isEnabled,
                    value: isChecked,
                    title: Row(
                      children: [
                        Text(
                          r.cidr,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: r.isEnabled ? null : Colors.grey,
                          ),
                        ),
                        if (r.name != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(${r.name})',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                        if (!r.isEnabled) ...[
                          const SizedBox(width: 6),
                          const Text(
                            '(Disabled)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      '${r.usableHostsCount} usable hosts (${r.baseIp} usable range)',
                    ),
                    onChanged: !r.isEnabled
                        ? null
                        : (val) {
                            setState(() {
                              if (val == true) {
                                _selectedRanges.add(r.cidr);
                              } else {
                                if (_selectedRanges.length > 1) {
                                  _selectedRanges.remove(r.cidr);
                                }
                              }
                            });
                          },
                  );
                }),
              const Divider(height: 24),
              const Text(
                'Enabled Discovery Strategies:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _strategyChip('icmp', 'ICMP Ping', Icons.network_ping),
                  _strategyChip('arp', 'ARP Table', Icons.table_chart),
                  _strategyChip('dns', 'Reverse DNS', Icons.dns),
                  _strategyChip('tcp_probe', 'TCP Allowlist', Icons.power),
                  _strategyChip('onvif', 'ONVIF / RTSP', Icons.videocam),
                  _strategyChip('mdns', 'mDNS / SSDP', Icons.cast),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Max Concurrency: $_concurrency',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Slider(
                          value: _concurrency.toDouble(),
                          min: 5,
                          max: 50,
                          divisions: 9,
                          label: '$_concurrency',
                          onChanged: (v) =>
                              setState(() => _concurrency = v.toInt()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Timeout: ${_timeoutSeconds}s',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Slider(
                          value: _timeoutSeconds.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: '${_timeoutSeconds}s',
                          onChanged: (v) =>
                              setState(() => _timeoutSeconds = v.toInt()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _selectedRanges.isEmpty
              ? null
              : () {
                  widget.onStart(
                    ranges: _selectedRanges.toList(),
                    strategies: _selectedStrategies.toList(),
                    concurrency: _concurrency,
                    timeoutSeconds: _timeoutSeconds,
                  );
                  Navigator.of(context).pop();
                },
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start Scan'),
        ),
      ],
    );
  }

  Widget _strategyChip(String key, String label, IconData icon) {
    final isSelected = _selectedStrategies.contains(key);
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 14), const SizedBox(width: 4), Text(label)],
      ),
      onSelected: (val) {
        setState(() {
          if (val) {
            _selectedStrategies.add(key);
          } else {
            if (_selectedStrategies.length > 1) {
              _selectedStrategies.remove(key);
            }
          }
        });
      },
    );
  }
}
