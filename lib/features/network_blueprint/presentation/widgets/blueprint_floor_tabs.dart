import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/blueprint_page_entity.dart';

class BlueprintFloorTabs extends StatelessWidget {
  final List<BlueprintPageEntity> pages;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const BlueprintFloorTabs({
    super.key,
    required this.pages,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(
          bottom: BorderSide(
            color: tokens.cardBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < pages.length; i++) ...[
            _FloorTabItem(
              title: pages[i].englishTitle,
              elementCount: pages[i].elements.length,
              isSelected: selectedIndex == i,
              isDark: isDark,
              onTap: () => onTabSelected(i),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FloorTabItem extends StatelessWidget {
  final String title;
  final int elementCount;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _FloorTabItem({
    required this.title,
    required this.elementCount,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    final activeBg = isDark
        ? AppColors.darkPrimary.withValues(alpha: 0.15)
        : AppColors.lightPrimary.withValues(alpha: 0.1);
    final activeBorder = tokens.primary;
    final activeText = tokens.primary;
    final inactiveText = tokens.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeBorder : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.layers_outlined,
              size: 16,
              color: isSelected ? activeText : inactiveText,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? activeText : inactiveText,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$elementCount',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? activeText : inactiveText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
