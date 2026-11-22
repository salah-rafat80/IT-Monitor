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
  final String? activeFactoryId;
  final ValueChanged<String?>? onFactoryChanged;

  const WallDisplayHeader({
    super.key,
    required this.isConnected,
    this.lastUpdatedAt,
    required this.currentSortBy,
    required this.onSortChanged,
    this.activeFactoryId,
    this.onFactoryChanged,
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
    final tokens = context.appTokens;
    final timeStr = DateFormat('yyyy-MM-dd • HH:mm:ss').format(_now);
    final lastUpdateStr = widget.lastUpdatedAt != null
        ? DateFormat('HH:mm:ss').format(widget.lastUpdatedAt!)
        : '--:--:--';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.cardBorder, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
// Left: Logo & Title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 36,
                  height: 24,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'IT NETWORK MONITOR',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: tokens.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: tokens.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: tokens.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'WALL DISPLAY',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: tokens.primary,
                  letterSpacing: 1.0,
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Factory Scope Switcher
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: tokens.surfaceSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFactoryPill(
                    label: 'ALL',
                    factoryId: null,
                    tokens: tokens,
                  ),
                  _buildFactoryPill(
                    label: 'BNF',
                    factoryId: 'bnf',
                    tokens: tokens,
                  ),
                  _buildFactoryPill(
                    label: 'RNF',
                    factoryId: 'rnf',
                    tokens: tokens,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Center: Live Time Clock
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: tokens.surfaceSecondary,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tokens.cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: tokens.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: tokens.textPrimary,
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
                    ? tokens.statusOnline.withValues(alpha: 0.12)
                    : tokens.statusOffline.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.isConnected
                      ? tokens.statusOnline.withValues(alpha: 0.4)
                      : tokens.statusOffline.withValues(alpha: 0.4),
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
                          ? tokens.statusOnline
                          : tokens.statusOffline,
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
                          ? tokens.statusOnline
                          : tokens.statusOffline,
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
                  color: tokens.surfaceSecondary,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tokens.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.sort_rounded,
                      size: 14,
                      color: tokens.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.currentSortBy == 'severity'
                          ? 'Sort: Severity'
                          : 'Sort: Owner',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: tokens.textPrimary,
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
                side: BorderSide(color: tokens.cardBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              icon: Icon(
                Icons.fullscreen_exit_rounded,
                size: 16,
                color: tokens.textSecondary,
              ),
              label: Text(
                'Exit [ESC]',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: tokens.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFactoryPill({
    required String label,
    required String? factoryId,
    required AppColors tokens,
  }) {
    final isSelected = (widget.activeFactoryId == null && factoryId == null) ||
        (widget.activeFactoryId?.toLowerCase() == factoryId?.toLowerCase() &&
            factoryId != null);

    return InkWell(
      onTap: () => widget.onFactoryChanged?.call(factoryId),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? tokens.primary.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? tokens.primary : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? tokens.primary : tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
