import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';

/// Reusable layout-preserving skeleton component following Unhappy-Path standards.
/// Prevents layout jumps and flickering during initial data loading.
class AppSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxShape shape;

  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppRadius.sm,
    this.shape = BoxShape.rectangle,
  });

  const AppSkeleton.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = 0,
        shape = BoxShape.circle;

  const AppSkeleton.text({
    super.key,
    this.width = 120,
    this.height = 14,
  })  : borderRadius = AppRadius.xs,
        shape = BoxShape.rectangle;

  /// Builds a full table skeleton with header and rows that match actual data layout.
  static Widget table({
    int rowCount = 6,
    int columnCount = 7,
    double rowHeight = 48,
  }) {
    return _TableSkeleton(
      rowCount: rowCount,
      columnCount: columnCount,
      rowHeight: rowHeight,
    );
  }

  /// Builds a row of summary metric card skeletons.
  static Widget summaryCards({int count = 4}) {
    return Row(
      children: List.generate(count, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < count - 1 ? AppSpacing.md : 0),
            child: const _CardSkeleton(),
          ),
        );
      }),
    );
  }

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    final baseColor = tokens.surfaceContainerHigh;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: _animation.value),
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.rectangle
                ? BorderRadius.circular(widget.borderRadius)
                : null,
          ),
        );
      },
    );
  }
}

class _TableSkeleton extends StatelessWidget {
  final int rowCount;
  final int columnCount;
  final double rowHeight;

  const _TableSkeleton({
    required this.rowCount,
    required this.columnCount,
    required this.rowHeight,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;

    return Container(
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: tokens.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isHeightBounded = constraints.maxHeight.isFinite;
            final availableHeight = constraints.maxHeight;

            // If bounded (e.g. inside Expanded), clamp rows to fit without overflow
            final effectiveRowCount = isHeightBounded
                ? ((availableHeight - 44) / rowHeight).floor().clamp(1, rowCount)
                : rowCount;

            final tableContent = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header row
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: tokens.tableHeader,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.lg),
                    ),
                  ),
                  child: Row(
                    children: List.generate(columnCount, (index) {
                      return Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: const AppSkeleton.text(
                            width: 80,
                            height: 12,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                // Skeleton data rows
                ...List.generate(effectiveRowCount, (rowIndex) {
                  return Container(
                    height: rowHeight,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: tokens.border.withValues(alpha: 0.5),
                          width: rowIndex < effectiveRowCount - 1 ? 1 : 0,
                        ),
                      ),
                    ),
                    child: Row(
                      children: List.generate(columnCount, (colIndex) {
                        return Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AppSkeleton.text(
                              width: (colIndex == 0) ? 110 : (colIndex == 1 ? 80 : 65),
                              height: 12,
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ],
            );

            if (isHeightBounded) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: tableContent,
              );
            }

            return tableContent;
          },
        ),
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;

    return Container(
      height: 96,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          AppSkeleton.text(width: 70, height: 11),
          SizedBox(height: AppSpacing.sm),
          AppSkeleton.text(width: 48, height: 22),
          SizedBox(height: AppSpacing.xs),
          AppSkeleton.text(width: 90, height: 10),
        ],
      ),
    );
  }
}
