import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../bloc/user_management_cubit.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<UserManagementCubit>().loadUsersAndLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddUserDialog(BuildContext context) {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    UserRole selectedRole = UserRole.viewer;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                initialValue: selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(
                    value: UserRole.viewer,
                    child: Text('Viewer'),
                  ),
                  DropdownMenuItem(value: UserRole.admin, child: Text('Admin')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => selectedRole = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (usernameController.text.trim().isNotEmpty &&
                    passwordController.text.isNotEmpty) {
                  context.read<UserManagementCubit>().createUser(
                    username: usernameController.text.trim(),
                    password: passwordController.text,
                    role: selectedRole,
                  );
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context, UserEntity user) {
    final newPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reset Password for ${user.username}'),
        content: TextField(
          controller: newPasswordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New Password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newPasswordController.text.length >= 6) {
                context.read<UserManagementCubit>().resetPassword(
                  userId: user.id,
                  newPassword: newPasswordController.text,
                );
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final currentUser = authState is AuthAuthenticated ? authState.user : null;
    final isAdmin = currentUser?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management & Security Audit'),
        actions: [
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ElevatedButton.icon(
                onPressed: () => _showAddUserDialog(context),
                icon: const Icon(Icons.person_add),
                label: const Text('Add User'),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.history), text: 'Audit Log'),
          ],
        ),
      ),
      body: BlocConsumer<UserManagementCubit, UserManagementState>(
        listener: (context, state) {
          if (state is UserManagementError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is UserManagementLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is UserManagementLoaded) {
            return TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Users Table
                SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Username')),
                        DataColumn(label: Text('Role')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Created At')),
                        DataColumn(label: Text('Last Login')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: state.users.map((user) {
                        final isCurrent = user.id == currentUser?.id;
                        final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                user.username + (isCurrent ? ' (You)' : ''),
                                style: TextStyle(
                                  fontWeight: isCurrent
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            DataCell(
                              Chip(
                                label: Text(
                                  user.role.name.toUpperCase(),
                                  style: TextStyle(
                                    color: user.isAdmin
                                        ? Colors.blue.shade200
                                        : Colors.grey.shade300,
                                    fontSize: 11,
                                  ),
                                ),
                                backgroundColor: user.isAdmin
                                    ? Colors.blue.shade900
                                    : Colors.grey.shade800,
                              ),
                            ),
                            DataCell(
                              Chip(
                                label: Text(
                                  user.isEnabled ? 'Active' : 'Disabled',
                                  style: TextStyle(
                                    color: user.isEnabled
                                        ? Colors.green.shade200
                                        : Colors.red.shade200,
                                    fontSize: 11,
                                  ),
                                ),
                                backgroundColor: user.isEnabled
                                    ? Colors.green.shade900
                                    : Colors.red.shade900,
                              ),
                            ),
                            DataCell(Text(dateFormat.format(user.createdAt))),
                            DataCell(
                              Text(
                                user.lastLoginAt != null
                                    ? dateFormat.format(user.lastLoginAt!)
                                    : 'Never',
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isAdmin && !isCurrent) ...[
                                    IconButton(
                                      icon: const Icon(
                                        Icons.swap_horiz,
                                        size: 20,
                                      ),
                                      tooltip: 'Toggle Role (Admin/Viewer)',
                                      onPressed: () {
                                        final newRole = user.isAdmin
                                            ? UserRole.viewer
                                            : UserRole.admin;
                                        context
                                            .read<UserManagementCubit>()
                                            .updateUserRole(
                                              userId: user.id,
                                              role: newRole,
                                            );
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        user.isEnabled
                                            ? Icons.block
                                            : Icons.check_circle_outline,
                                        size: 20,
                                        color: user.isEnabled
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                      tooltip: user.isEnabled
                                          ? 'Disable Account'
                                          : 'Enable Account',
                                      onPressed: () {
                                        context
                                            .read<UserManagementCubit>()
                                            .toggleUserEnabled(
                                              userId: user.id,
                                              isEnabled: !user.isEnabled,
                                            );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.key, size: 20),
                                      tooltip: 'Reset Password',
                                      onPressed: () => _showResetPasswordDialog(
                                        context,
                                        user,
                                      ),
                                    ),
                                  ] else
                                    const Text(
                                      '—',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                // Tab 2: Audit Logs Table
                SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Timestamp')),
                        DataColumn(label: Text('User')),
                        DataColumn(label: Text('Action')),
                        DataColumn(label: Text('Details')),
                      ],
                      rows: state.auditLogs.map((log) {
                        final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
                        return DataRow(
                          cells: [
                            DataCell(Text(dateFormat.format(log.timestamp))),
                            DataCell(Text(log.username)),
                            DataCell(
                              Chip(
                                label: Text(
                                  log.action,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(log.details ?? '—')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
