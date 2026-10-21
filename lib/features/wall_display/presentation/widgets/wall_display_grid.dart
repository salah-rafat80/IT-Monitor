import 'dart:math';
import 'package:flutter/material.dart';

import '../../../monitoring/domain/entities/monitored_device.dart';
import 'wall_device_card.dart';

class WallDisplayGrid extends StatelessWidget {
  final List<MonitoredDevice> devices;

  const WallDisplayGrid({super.key, required this.devices});

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return const Center(
        child: Text(
          'No monitored devices in inventory',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;

        // Calculate columns and rows based on device count
        // For 37 devices: 5 columns x 8 rows = 40 capacity
        int crossAxisCount = 5;
        if (availableWidth < 1200) {
          crossAxisCount = 4;
        } else if (availableWidth >= 2200) {
          crossAxisCount = 6;
        }

        final int totalItems = devices.length;
        final int rows = (totalItems / crossAxisCount).ceil();

        const double spacing = 6.0;

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
