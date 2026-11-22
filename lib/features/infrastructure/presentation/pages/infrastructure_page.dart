import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../factories/presentation/bloc/factory_cubit.dart';
import '../bloc/infrastructure_cubit.dart';
import '../widgets/infrastructure_devices_table.dart';

class InfrastructurePage extends StatefulWidget {
  const InfrastructurePage({super.key});

  @override
  State<InfrastructurePage> createState() => _InfrastructurePageState();
}

class _InfrastructurePageState extends State<InfrastructurePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final fId = context.read<FactoryCubit>().state.selectedFactoryId;
        final infraCubit = context.read<InfrastructureCubit>();
        if (infraCubit.activeFactoryId != fId) {
          infraCubit.setFactory(fId);
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appTokens;

    return BlocListener<FactoryCubit, FactoryState>(
      listener: (context, fState) {
        context.read<InfrastructureCubit>().setFactory(
          fState.selectedFactoryId,
        );
      },
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tokens.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.hub_outlined,
                      color: tokens.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Network Infrastructure & UniFi Devices',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Live reachability monitoring, latency diagnostics, and coverage tracking for UniFi APs and Gateways',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Infrastructure Table & Controls
              const InfrastructureDevicesTable(),
            ],
          ),
        ),
      ),
    );
  }
}
