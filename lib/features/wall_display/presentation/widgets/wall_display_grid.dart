import 'dart:math';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../monitoring/domain/entities/monitored_device.dart';
import 'wall_device_card.dart';

class WallDisplayGrid extends StatelessWidget {
  final List<MonitoredDevice> devices;

  const WallDisplayGrid({super.key, required this.devices});

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return Center(
        child: Text(
          'No monitored devices in inventory',
          style: TextStyle(
            color: context.appTokens.textSecondary,
            fontSize: 16,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;

        const double spacing = 6.0;
        final int totalItems = devices.length;

        // Calculate columns and rows dynamically to optimize card aspect ratio and vertical clearance
        int crossAxisCount = (availableWidth / 200).floor().clamp(3, 7);
        double bestScore = double.infinity;

        for (int c = 3; c <= 8; c++) {
          final int r = (totalItems / c).ceil();
          final double w = (availableWidth - (c - 1) * spacing) / c;
          final double h =
              (availableHeight - (max(1, r) - 1) * spacing) / max(1, r);

          if (w >= 145 && h >= 45) {
            // Target ideal card aspect ratio of ~2.5 (e.g. 175w x 70h)
            final double ratio = w / h;
            final double score = (ratio - 2.5).abs();
            if (score < bestScore) {
              bestScore = score;
              crossAxisCount = c;
            }
          }
        }
        final int rows = (totalItems / crossAxisCount).ceil();

        final double totalHorizontalSpacing = (crossAxisCount - 1) * spacing;
        final double totalVerticalSpacing = (max(1, rows) - 1) * spacing;

        final double itemWidth =
            (availableWidth - totalHorizontalSpacing) / crossAxisCount;
        final double itemHeight =
            (availableHeight - totalVerticalSpacing) / max(1, rows);

        final double aspectRatio = (itemWidth > 0 && itemHeight > 0)
            ? (itemWidth / itemHeight)
            : 1.8;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: aspectRatio,
          ),
          itemCount: devices.length,
          itemBuilder: (context, index) {
            final item = devices[index];
            return WallDeviceCard(
              key: ValueKey('wall_device_${item.device.id}'),
              item: item,
            );
          },
        );
      },
    );
  }
}
