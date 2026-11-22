import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/factory_network_config.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../factories/presentation/bloc/factory_cubit.dart';
import '../../../monitoring/domain/entities/monitoring_config.dart';
import '../../../monitoring/domain/services/monitoring_scheduler.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final MonitoringScheduler _scheduler;
  late TextEditingController _intervalController;
  late TextEditingController _timeoutController;
  late TextEditingController _failureThresholdController;
  late TextEditingController _recoveryThresholdController;
  late TextEditingController _concurrencyController;

  bool _isSaving = false;
  String? _statusMessage;
  bool _isSuccessMessage = false;

  @override
  void initState() {
    super.initState();
    _scheduler = getIt<MonitoringScheduler>();
    final cfg = _scheduler.config;

    _intervalController = TextEditingController(
      text: cfg.checkIntervalSeconds.toString(),
    );
    _timeoutController = TextEditingController(
      text: cfg.timeoutSeconds.toString(),
    );
    _failureThresholdController = TextEditingController(
      text: cfg.failureThreshold.toString(),
    );
    _recoveryThresholdController = TextEditingController(
      text: cfg.recoveryThreshold.toString(),
    );
    _concurrencyController = TextEditingController(
      text: cfg.maxConcurrentChecks.toString(),
    );
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _timeoutController.dispose();
    _failureThresholdController.dispose();
    _recoveryThresholdController.dispose();
    _concurrencyController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final interval = int.tryParse(_intervalController.text.trim());
    final timeout = int.tryParse(_timeoutController.text.trim());
    final failure = int.tryParse(_failureThresholdController.text.trim());
    final recovery = int.tryParse(_recoveryThresholdController.text.trim());
    final concurrency = int.tryParse(_concurrencyController.text.trim());

    if (interval == null || interval < 5 || interval > 3600) {
      setState(() {
        _statusMessage =
            'Monitoring interval must be between 5 and 3600 seconds.';
        _isSuccessMessage = false;
      });
      return;
    }
    if (timeout == null || timeout < 1 || timeout > 30) {
      setState(() {
        _statusMessage = 'Ping timeout must be between 1 and 30 seconds.';
        _isSuccessMessage = false;
      });
      return;
    }
    if (failure == null || failure < 1 || failure > 10) {
      setState(() {
        _statusMessage = 'Failure threshold must be between 1 and 10.';
        _isSuccessMessage = false;
      });
      return;
    }
    if (recovery == null || recovery < 1 || recovery > 10) {
      setState(() {
        _statusMessage = 'Recovery threshold must be between 1 and 10.';
        _isSuccessMessage = false;
      });
      return;
    }
    if (concurrency == null || concurrency < 1 || concurrency > 100) {
      setState(() {
        _statusMessage = 'Max concurrency must be between 1 and 100.';
        _isSuccessMessage = false;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    final newConfig = MonitoringConfig(
      checkIntervalSeconds: interval,
      timeoutSeconds: timeout,
      failureThreshold: failure,
      recoveryThreshold: recovery,
      maxConcurrentChecks: concurrency,
    );

    _scheduler.updateConfig(newConfig);

    setState(() {
      _isSaving = false;
      _statusMessage = 'Monitoring configuration applied successfully.';
      _isSuccessMessage = true;
    });
  }

  void _resetDefaults() {
    setState(() {
      _intervalController.text = FactoryNetworkConfig
          .defaultMonitoringIntervalSeconds
          .toString();
      _timeoutController.text = FactoryNetworkConfig.defaultPingTimeoutSeconds
          .toString();
      _failureThresholdController.text = FactoryNetworkConfig
          .defaultFailureThreshold
          .toString();
      _recoveryThresholdController.text = FactoryNetworkConfig
          .defaultRecoveryThreshold
          .toString();
      _concurrencyController.text = FactoryNetworkConfig
          .defaultMaxConcurrentChecks
          .toString();
      _statusMessage =
          'Reset to factory defaults. Click "Save Configuration" to apply.';
      _isSuccessMessage = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appTokens;
    final isAdmin = true;
    final factoryState = context.watch<FactoryCubit>().state;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.tune_rounded, size: 24),
            SizedBox(width: 10),
            Text('Settings & Visual Identity'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Visual Identity & Theme Customization Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: tokens.cardBorder),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.palette_rounded,
                              color: tokens.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Visual Identity & Theme Selection',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: tokens.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: tokens.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.save_as_rounded,
                                    size: 14,
                                    color: tokens.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Auto-Persisted Locally',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Switch seamlessly between Cyber Neon Dark (Operations Center aesthetic) and Professional Light (Corporate Enterprise aesthetic). The active choice is saved automatically to local storage and restored on startup.',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                        BlocBuilder<ThemeCubit, ThemeState>(
                          builder: (context, themeState) {
                            final isDark = themeState.isDark;
                            return Row(
                              children: [
                                Expanded(
                                  child: _ThemePreviewOptionCard(
                                    title: 'Cyber Neon Dark',
                                    subtitle:
                                        'Cyber Ops / Deep Midnight Navy & Neon Cyan',
                                    isSelected: isDark,
                                    isDarkTheme: true,
                                    onTap: () {
                                      context.read<ThemeCubit>().setThemeMode(
                                        ThemeMode.dark,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _ThemePreviewOptionCard(
                                    title: 'Professional Light',
                                    subtitle:
                                        'Enterprise Corporate / Soft Off-White & Deep Blue',
                                    isSelected: !isDark,
                                    isDarkTheme: false,
                                    onTap: () {
                                      context.read<ThemeCubit>().setThemeMode(
                                        ThemeMode.light,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: const Text('Open 60-30-10 Dynamic Palette & Token Editor'),
                          onPressed: () => context.push('/palette-editor'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (_statusMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isSuccessMessage
                          ? tokens.statusOnline.withValues(alpha: 0.1)
                          : tokens.statusOffline.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isSuccessMessage
                            ? tokens.statusOnline
                            : tokens.statusOffline,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isSuccessMessage
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          color: _isSuccessMessage
                              ? tokens.statusOnline
                              : tokens.statusOffline,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: TextStyle(
                              color: _isSuccessMessage
                                  ? tokens.statusOnline
                                  : tokens.statusOffline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 2. Operational Scheduler Parameters Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: tokens.cardBorder),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.speed_rounded,
                              color: tokens.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Ping Engine & Scheduler Controls',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: tokens.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Configure operational ping intervals, ICMP timeouts, concurrency limits, and failure/recovery debounce thresholds.',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _intervalController,
                                enabled: isAdmin,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Cycle Interval (seconds)',
                                  hintText: '60',
                                  helperText: 'Default: 60s (5-3600s)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _timeoutController,
                                enabled: isAdmin,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Ping Timeout (seconds)',
                                  hintText: '3',
                                  helperText: 'Default: 3s (1-30s)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _failureThresholdController,
                                enabled: isAdmin,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Failure Threshold',
                                  hintText: '3',
                                  helperText:
                                      'Consecutive failures before Down (default: 3)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _recoveryThresholdController,
                                enabled: isAdmin,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Recovery Threshold',
                                  hintText: '1',
                                  helperText:
                                      'Consecutive successes to recover (default: 1)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _concurrencyController,
                          enabled: isAdmin,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Maximum Concurrent Ping Checks',
                            hintText: '20',
                            helperText:
                                'Strictly bounds simultaneous async probes (default: 20)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _resetDefaults,
                              icon: const Icon(Icons.restore, size: 16),
                              label: const Text('Reset Defaults'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveSettings,
                              icon: const Icon(Icons.save, size: 16),
                              label: const Text('Save Configuration'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: tokens.primary,
                                foregroundColor: tokens.isDark
                                    ? const Color(0xFF090D19)
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Authoritative Factory Configuration Summary Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: tokens.cardBorder),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.business_rounded,
                              color: tokens.factoryBnf,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Authoritative Factory Configurations',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: tokens.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Verified operational gateway IP and network CIDR settings for multi-factory isolation.',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        for (final factory in factoryState.factories) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: tokens.cardBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (factory.code.toUpperCase() == 'RNF'
                                                ? tokens.factoryRnf
                                                : tokens.factoryBnf)
                                            .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    factory.code,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: factory.code.toUpperCase() == 'RNF'
                                          ? tokens.factoryRnf
                                          : tokens.factoryBnf,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        factory.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: tokens.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Gateway: ${factory.gatewayIp ?? 'N/A'} | Mask: ${factory.subnetMask ?? 'N/A'} | Scope: ${factory.expectedCidr ?? 'N/A'}',
                                        style: TextStyle(
                                          color: tokens.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tokens.statusOnline.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'ACTIVE',
                                    style: TextStyle(
                                      color: tokens.statusOnline,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemePreviewOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isDarkTheme;
  final VoidCallback onTap;

  const _ThemePreviewOptionCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.isDarkTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    final primaryColor = isDarkTheme
        ? const Color(0xFF00E5FF)
        : const Color(0xFF1769FF);
    final bgColor = isDarkTheme
        ? const Color(0xFF090D19)
        : const Color(0xFFF3F6FC);
    final cardBgColor = isDarkTheme
        ? const Color(0xFF111827)
        : const Color(0xFFFFFFFF);
    final cardBorder = isDarkTheme
        ? const Color(0xFF263650)
        : const Color(0xFFE1E8F2);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : tokens.cardBorder,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: primaryColor.withValues(
                  alpha: isDarkTheme ? 0.25 : 0.15,
                ),
                blurRadius: 12,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Miniature UI Mockup Preview
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cardBorder),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    // Mini Sidebar
                    Container(
                      width: 28,
                      color: isDarkTheme
                          ? const Color(0xFF0D1424)
                          : const Color(0xFFEAF0F8),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: 16,
                            height: 4,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 16,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDarkTheme
                                  ? Colors.white24
                                  : Colors.black12,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 16,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDarkTheme
                                  ? Colors.white24
                                  : Colors.black12,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Mini Main Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Mini header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 48,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isDarkTheme
                                        ? Colors.white70
                                        : const Color(0xFF172B4D),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Mini KPI cards
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 32,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: cardBgColor,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: cardBorder),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 4,
                                          color: isDarkTheme
                                              ? Colors.white30
                                              : Colors.black26,
                                        ),
                                        const Spacer(),
                                        Text(
                                          '42',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Container(
                                    height: 32,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: cardBgColor,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: cardBorder),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 4,
                                          color: isDarkTheme
                                              ? Colors.white30
                                              : Colors.black26,
                                        ),
                                        const Spacer(),
                                        const Text(
                                          '98%',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Mini table bar
                            Container(
                              height: 18,
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: cardBorder),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Title and selection indicator
            Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected ? primaryColor : tokens.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
