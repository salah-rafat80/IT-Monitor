import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/theme/app_colors.dart';
import 'package:it_network_monitor/core/theme/app_theme.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/presentation/widgets/device_status_chip.dart';
import 'package:it_network_monitor/features/theme/presentation/theme/app_palette.dart';

void main() {
  group('Dynamic Theming & Custom Palette Verification Tests', () {
    testWidgets(
      '1. Custom palette seeds dynamically apply to buttons and status chips',
      (tester) async {
        // Define a non-default custom 60-30-10 palette
        final customPalette = AppPalette.fromSeeds(
          main: const Color(0xFF1E1B4B), // Deep indigo
          second: const Color(0xFF4338CA), // Electric indigo
          accent: const Color(0xFF06B6D4), // Cyan accent
          name: 'Custom Cyber Indigo',
        );

        final themeData = AppTheme.buildTheme(
          palette: customPalette,
          isDark: true,
        );

        final appColors = themeData.extension<AppColors>()!;

        await tester.pumpWidget(
          MaterialApp(
            theme: themeData,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final tokens = context.appTokens;
                  return Column(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.primary,
                          foregroundColor: tokens.onPrimary,
                        ),
                        onPressed: () {},
                        child: const Text('Action Button'),
                      ),
                      const DeviceStatusChip(status: DeviceStatusEnum.up),
                      const DeviceStatusChip(status: DeviceStatusEnum.down),
                      const DeviceStatusChip(status: DeviceStatusEnum.degraded),
                      Container(
                        key: const Key('custom_primary_box'),
                        color: tokens.primary,
                      ),
                      Container(
                        key: const Key('custom_surface_box'),
                        color: tokens.card,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Verify custom primary token matches the second seed
        expect(appColors.primary, customPalette.second);

        // 2. Verify ElevatedButton style derives from the custom primary token
        final elevatedBtn = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        final btnBg = elevatedBtn.style?.backgroundColor?.resolve({});
        expect(btnBg, appColors.primary);

        // 3. Verify status chip container uses semantic statusOnlineSurface
        final connectedChip = find.byType(DeviceStatusChip).first;
        final container = tester.widget<Container>(
          find.descendant(of: connectedChip, matching: find.byType(Container)).first,
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, appColors.statusOnlineSurface);

        // 4. Verify custom primary container renders custom second seed
        final primaryBox = tester.widget<Container>(
          find.byKey(const Key('custom_primary_box')),
        );
        expect(primaryBox.color, customPalette.second);
      },
    );

    testWidgets(
      '2. Toggling ThemeMode.dark <-> ThemeMode.light updates background, surface, and text colors',
      (tester) async {
        final darkTheme = AppTheme.buildTheme(
          palette: AppPalette.defaultDark,
          isDark: true,
        );
        final lightTheme = AppTheme.buildTheme(
          palette: AppPalette.defaultLight,
          isDark: false,
        );

        var currentMode = ThemeMode.dark;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return MaterialApp(
                theme: lightTheme,
                darkTheme: darkTheme,
                themeMode: currentMode,
                home: Scaffold(
                  body: Builder(
                    builder: (innerCtx) {
                      final tokens = innerCtx.appTokens;
                      return Column(
                        children: [
                          Text('Mode Text', style: TextStyle(color: tokens.textPrimary)),
                          Container(
                            key: const Key('surface_container'),
                            color: tokens.card,
                          ),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                currentMode = currentMode == ThemeMode.dark
                                    ? ThemeMode.light
                                    : ThemeMode.dark;
                              });
                            },
                            child: const Text('Toggle Mode'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        );

        await tester.pumpAndSettle();

        // Assert Dark mode values
        final darkColors = darkTheme.extension<AppColors>()!;
        var textWidget = tester.widget<Text>(find.text('Mode Text'));
        expect(textWidget.style?.color, darkColors.textPrimary);
        var surfaceBox = tester.widget<Container>(find.byKey(const Key('surface_container')));
        expect(surfaceBox.color, darkColors.card);

        // Toggle to Light mode
        await tester.tap(find.text('Toggle Mode'));
        await tester.pumpAndSettle();

        // Assert Light mode values changed distinctly
        final lightColors = lightTheme.extension<AppColors>()!;
        textWidget = tester.widget<Text>(find.text('Mode Text'));
        expect(textWidget.style?.color, lightColors.textPrimary);
        surfaceBox = tester.widget<Container>(find.byKey(const Key('surface_container')));
        expect(surfaceBox.color, lightColors.card);

        // Verify dark and light tokens are distinctly different
        expect(darkColors.card, isNot(equals(lightColors.card)));
        expect(darkColors.textPrimary, isNot(equals(lightColors.textPrimary)));
        expect(darkColors.isDark, isTrue);
        expect(lightColors.isDark, isFalse);
      },
    );

    test(
      '3. AppTheme component themes are complete and derive from AppColors',
      () {
        final darkTheme = AppTheme.buildTheme(
          palette: AppPalette.defaultDark,
          isDark: true,
        );
        final tokens = darkTheme.extension<AppColors>()!;

        // Component theme checks
        expect(darkTheme.dialogTheme.backgroundColor, tokens.surfaceContainerHigh);
        expect(darkTheme.snackBarTheme.backgroundColor, tokens.surfaceContainerHighest);
        expect(darkTheme.cardTheme.color, tokens.card);
        expect(darkTheme.dividerColor, tokens.border);
        expect(darkTheme.scaffoldBackgroundColor, tokens.background);
      },
    );
  });
}
