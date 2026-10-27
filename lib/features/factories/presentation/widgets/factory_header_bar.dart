import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../devices/presentation/bloc/devices_cubit.dart';
import '../../../infrastructure/presentation/bloc/infrastructure_cubit.dart';
import '../../../monitoring/presentation/bloc/monitoring_dashboard_cubit.dart';
import '../../../network_discovery/presentation/bloc/network_discovery_cubit.dart';
import '../bloc/factory_cubit.dart';
import 'add_factory_dialog.dart';

class FactoryHeaderBar extends StatelessWidget {
  const FactoryHeaderBar({super.key});

  void _onFactoryChanged(BuildContext context, String? factoryId) {
    context.read<FactoryCubit>().selectFactoryById(factoryId);

    // Propagate active factory context across active cubits if registered
    try {
      context.read<DevicesCubit>().setFactory(factoryId);
    } catch (_) {}

    try {
      context.read<MonitoringDashboardCubit>().setFactoryFilter(factoryId);
    } catch (_) {}

    try {
      context.read<NetworkDiscoveryCubit>().setFactory(factoryId);
    } catch (_) {}

    try {
      context.read<InfrastructureCubit>().setFactory(factoryId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final FactoryState factoryState;
    try {
      factoryState = context.watch<FactoryCubit>().state;
    } catch (_) {
      return const SizedBox.shrink();
    }

    UserEntity? currentUser;
    try {
      final authState = context.watch<AuthCubit>().state;
      if (authState is AuthAuthenticated) {
        currentUser = authState.user;
      }
    } catch (_) {}
    final isAdmin = currentUser?.role == UserRole.admin;

    final factories = factoryState.factories;
    final selected = factoryState.selectedFactory;
    final selectedId = selected?.id;

    final isConsolidated = selectedId == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isConsolidated
                              ? const Color(0xFF0F62FE).withValues(alpha: 0.12)
                              : const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isConsolidated
                              ? Icons.hub_rounded
                              : Icons.factory_rounded,
                          size: 20,
                          color: isConsolidated
                              ? const Color(0xFF0F62FE)
                              : const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Factory Context:',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: selectedId,
                            isDense: true,
                            dropdownColor: theme.colorScheme.surface,
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.all_inclusive_rounded,
                                      size: 16,
                                      color: Color(0xFF0F62FE),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'All Factories (Consolidated)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              for (final f in factories)
                                DropdownMenuItem<String?>(
                                  value: f.id,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF10B981,
                                          ).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          f.code,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(f.name),
                                    ],
                                  ),
                                ),
                            ],
                            onChanged: (val) => _onFactoryChanged(context, val),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Scope badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isConsolidated
                              ? const Color(0xFF0F62FE).withValues(alpha: 0.1)
                              : const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isConsolidated
                                ? const Color(0xFF0F62FE).withValues(alpha: 0.3)
                                : const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          isConsolidated
                              ? 'SCOPE: ALL SITES'
                              : 'ISOLATED SCOPE: ${selected!.code}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isConsolidated
                                ? const Color(0xFF0F62FE)
                                : const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  if (isAdmin)
                    TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const AddFactoryDialog(),
                        );
                      },
                      icon: const Icon(Icons.add_business_rounded, size: 16),
                      label: const Text('Add Factory'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0F62FE),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
