import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_run_mode.dart';
import '../../../../core/di/injection.dart';
import '../../../monitoring/data/datasources/monitoring_service_client.dart';
import '../bloc/auth_cubit.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitLogin(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      context.read<AuthCubit>().login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
    }
  }

  void _submitCreateAdmin(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      context.read<AuthCubit>().createInitialAdmin(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthError && !AppConfig.isProductionClient) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          // In production client mode: preserve no-interactive-login experience.
          // Show clear operator connection / access error state instead of login prompt.
          if (AppConfig.isProductionClient) {
            final errorMessage = state is AuthError
                ? state.message
                : (state is AuthUnauthenticated
                      ? 'The desktop client could not establish a verified session with the authoritative Windows Service.'
                      : null);

            return Center(
              child: SingleChildScrollView(
                child: Container(
                  width: 500,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        errorMessage != null
                            ? Icons.error_outline
                            : Icons.security_outlined,
                        size: 56,
                        color: errorMessage != null
                            ? Theme.of(context).colorScheme.error
                            : const Color(0xFF0F62FE),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'IT Network Monitor',
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Local Administrator (No Interactive Login)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      if (isLoading) ...[
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        Text(
                          'Verifying service connection and credentials with authoritative service...',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ] else if (errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.errorContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Operator Service Authentication Error',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                errorMessage,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 8),
                              Builder(
                                builder: (context) {
                                  final client = getIt.isRegistered<MonitoringServiceClient>()
                                      ? getIt<MonitoringServiceClient>()
                                      : null;
                                  final isRemote = client?.isRemoteTokenMode == true ||
                                      (client != null &&
                                          !client.baseUrl.contains('127.0.0.1') &&
                                          !client.baseUrl.contains('localhost'));

                                  if (isRemote) {
                                    return Text(
                                      'LAN Client Troubleshooting:\n'
                                      '• Central Service URL: ${client?.baseUrl ?? "Not Configured"}\n'
                                      '• Ensure central server firewall allows inbound TCP port 8443\n'
                                      '• Ensure server public certificate (server.crt) is placed in:\n'
                                      '   %ProgramData%\\ITNetworkMonitor\\server.crt\n'
                                      '• Verify provisioned token in %ProgramData%\\ITNetworkMonitor\\client_config.json',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'Consolas',
                                        height: 1.4,
                                      ),
                                    );
                                  }

                                  return const Text(
                                    'Local Service Troubleshooting:\n'
                                    '• Ensure ITNetworkMonitorService is running:\n'
                                    '   Get-Service ITNetworkMonitorService\n'
                                    '• Ensure current Windows user is in the authorized group:\n'
                                    '   net localgroup ITNetworkMonitorAdministrators\n'
                                    '• Check logs at %ProgramData%\\ITNetworkMonitor\\logs\\',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'Consolas',
                                      height: 1.4,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            context.read<AuthCubit>().checkAuthStatus();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry Service Connection'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F62FE),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }

          // Standalone development mode with interactive login
          final isSetupMode =
              state is AuthUnauthenticated && !state.hasAdminAccount;

          return Center(
            child: SingleChildScrollView(
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.monitor_heart_outlined,
                        size: 52,
                        color: Color(0xFF0F62FE),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'IT Network Monitor',
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isSetupMode
                            ? 'First Run Setup — Create System Administrator Account'
                            : 'Sign in to access operational monitoring',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length < 3) {
                            return 'Username must be at least 3 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      if (isSetupMode) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: Icon(Icons.lock_reset_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 28),
                      ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () => isSetupMode
                                  ? _submitCreateAdmin(context)
                                  : _submitLogin(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F62FE),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isSetupMode
                                    ? 'Create Administrator Account'
                                    : 'Sign In',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
