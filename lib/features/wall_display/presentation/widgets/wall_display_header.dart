import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';

class WallDisplayHeader extends StatefulWidget {
  final bool isConnected;
  final DateTime? lastUpdatedAt;
  final String currentSortBy;
  final ValueChanged<String> onSortChanged;

  const WallDisplayHeader({
    super.key,
    required this.isConnected,
    this.lastUpdatedAt,
    required this.currentSortBy,
    required this.onSortChanged,
  });

  @override
  State<WallDisplayHeader> createState() => _WallDisplayHeaderState();
}

class _WallDisplayHeaderState extends State<WallDisplayHeader> {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('yyyy-MM-dd • HH:mm:ss').format(_now);
    final lastUpdateStr = widget.lastUpdatedAt != null
        ? DateFormat('HH:mm:ss').format(widget.lastUpdatedAt!)
        : '--:--:--';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        border: Border(
          bottom: BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Left: Logo & Title
            const Icon(
              Icons.monitor_heart_outlined,
              color: AppColors.primary,
              size: 26,
            ),
            const SizedBox(width: 10),
            const Text(
              'IT NETWORK MONITOR',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AppColors.textPrimaryDark,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: const Text(
                'WALL DISPLAY',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: AppColors.primary,
                  letterSpacing: 1.0,
                ),
              ),
            ),

            const SizedBox(width: 24),

            // Center: Live Time Clock
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 24),

            // Right Controls: Service Connection Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: widget.isConnected
                    ? AppColors.statusUp.withValues(alpha: 0.12)
                    : AppColors.statusDown.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.isConnected
                      ? AppColors.statusUp.withValues(alpha: 0.4)
                      : AppColors.statusDown.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.isConnected
                          ? AppColors.statusUp
                          : AppColors.statusDown,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.isConnected
                        ? 'CONNECTED ($lastUpdateStr)'
                        : 'DISCONNECTED ($lastUpdateStr)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: widget.isConnected
                          ? AppColors.statusUp
                          : AppColors.statusDown,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Sort Mode Toggle Button
            InkWell(
              onTap: () {
                final newSort = widget.currentSortBy == 'severity'
                    ? 'owner'
                    : 'severity';
                widget.onSortChanged(newSort);
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.sort_rounded,
                      size: 14,
                      color: AppColors.textSecondaryDark,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.currentSortBy == 'severity'
                          ? 'Sort: Severity'
                          : 'Sort: Owner',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Exit Full Screen Button
            OutlinedButton.icon(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/dashboard');
                }
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                side: const BorderSide(color: AppColors.darkBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              icon: const Icon(
                Icons.fullscreen_exit_rounded,
                size: 16,
                color: AppColors.textSecondaryDark,
              ),
              label: const Text(
                'Exit [ESC]',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
