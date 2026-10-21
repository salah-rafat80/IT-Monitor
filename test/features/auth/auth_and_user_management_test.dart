import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:it_network_monitor/features/auth/domain/entities/user_entity.dart';
import 'package:it_network_monitor/features/users/data/repositories/audit_log_repository_impl.dart';
import 'package:it_network_monitor/features/users/data/repositories/user_repository_impl.dart';

void main() {
  late AppDatabase db;
  late AuditLogRepositoryImpl auditLogRepo;
  late AuthRepositoryImpl authRepo;
  late UserRepositoryImpl userRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    auditLogRepo = AuditLogRepositoryImpl(db);
    authRepo = AuthRepositoryImpl(db, auditLogRepo);
    userRepo = UserRepositoryImpl(db, auditLogRepo, authRepo);
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase 1 - Auth & User Management Unit Tests', () {
    test('1. First-run admin creation workflow', () async {
      // 1.1 Verify no admin exists initially
      final initialHasAdmin = await authRepo.hasAdminAccount();
      expect(initialHasAdmin.dataOrNull, isFalse);

      // 1.2 Create initial admin
      final createRes = await authRepo.createInitialAdmin(
        username: 'admin_sys',
        password: 'AdminPassword123',
      );
      expect(createRes.isSuccess, isTrue);
      final admin = createRes.dataOrNull!;
      expect(admin.username, equals('admin_sys'));
      expect(admin.role, equals(UserRole.admin));
      expect(admin.isAdmin, isTrue);

      // 1.3 Verify hasAdminAccount is now true
      final hasAdminNow = await authRepo.hasAdminAccount();
      expect(hasAdminNow.dataOrNull, isTrue);

      // 1.4 Attempting second initial admin creation fails
      final duplicateRes = await authRepo.createInitialAdmin(
        username: 'admin_two',
        password: 'Password123',
      );
      expect(duplicateRes.isFailure, isTrue);

      // 1.5 Verify audit log recorded INITIAL_ADMIN_CREATED
      final logsRes = await auditLogRepo.getAuditLogs();
      expect(logsRes.dataOrNull?.length, equals(1));
      expect(logsRes.dataOrNull?.first.action, equals('INITIAL_ADMIN_CREATED'));
    });

    test('2. Authentication login & logout flow', () async {
      await authRepo.createInitialAdmin(
        username: 'admin_login',
        password: 'SecretPassword123',
      );

      // Logout active initial session
      await authRepo.logout();
      final loggedOutUser = await authRepo.getCurrentUser();
      expect(loggedOutUser.dataOrNull, isNull);

      // Failed login with invalid password
      final invalidLogin = await authRepo.login(
        username: 'admin_login',
        password: 'WrongPassword',
      );
      expect(invalidLogin.isFailure, isTrue);

      // Successful login
      final validLogin = await authRepo.login(
        username: 'admin_login',
        password: 'SecretPassword123',
      );
      expect(validLogin.isSuccess, isTrue);
      expect(validLogin.dataOrNull?.username, equals('admin_login'));

      // Check current user session
      final sessionUser = await authRepo.getCurrentUser();
      expect(sessionUser.dataOrNull?.username, equals('admin_login'));
    });

    test('3. Admin User CRUD & Role enforcement', () async {
      // 3.1 Setup Admin
      await authRepo.createInitialAdmin(
        username: 'super_admin',
        password: 'AdminPassword123',
      );

      // 3.2 Admin creates a Viewer user
      final createViewerRes = await userRepo.createUser(
        username: 'viewer_user',
        password: 'ViewerPassword123',
        role: UserRole.viewer,
      );
      expect(createViewerRes.isSuccess, isTrue);
      final viewerUser = createViewerRes.dataOrNull!;
      expect(viewerUser.username, equals('viewer_user'));
      expect(viewerUser.role, equals(UserRole.viewer));

      // 3.3 Admin updates Viewer role to Admin
      final updateRoleRes = await userRepo.updateUserRole(
        userId: viewerUser.id,
        role: UserRole.admin,
      );
      expect(updateRoleRes.isSuccess, isTrue);
      expect(updateRoleRes.dataOrNull?.role, equals(UserRole.admin));

      // 3.4 Admin disables user account
      final disableRes = await userRepo.toggleUserEnabled(
        userId: viewerUser.id,
        isEnabled: false,
      );
      expect(disableRes.isSuccess, isTrue);
      expect(disableRes.dataOrNull?.isEnabled, isFalse);

      // 3.5 Admin cannot disable their own account
      final adminUser = (await authRepo.getCurrentUser()).dataOrNull!;
      final selfDisableRes = await userRepo.toggleUserEnabled(
        userId: adminUser.id,
        isEnabled: false,
      );
      expect(selfDisableRes.isFailure, isTrue);

      // 3.6 Admin resets user password
      final resetRes = await userRepo.resetUserPassword(
        userId: viewerUser.id,
        newPassword: 'NewSecretPassword123',
      );
      expect(resetRes.isSuccess, isTrue);
    });

    test('4. Viewer role cannot perform Admin-only actions', () async {
      // Setup Admin and Viewer
      await authRepo.createInitialAdmin(
        username: 'admin_one',
        password: 'Password123',
      );
      await userRepo.createUser(
        username: 'read_only_viewer',
        password: 'Password123',
        role: UserRole.viewer,
      );

      // Login as Viewer
      await authRepo.login(
        username: 'read_only_viewer',
        password: 'Password123',
      );

      // Viewer attempts to create user -> Fails with UnauthorizedFailure
      final viewerCreateRes = await userRepo.createUser(
        username: 'hacker_user',
        password: 'Password123',
        role: UserRole.admin,
      );
      expect(viewerCreateRes.isFailure, isTrue);

      // Viewer attempts to update role -> Fails with UnauthorizedFailure
      final viewerUpdateRoleRes = await userRepo.updateUserRole(
        userId: 1,
        role: UserRole.viewer,
      );
      expect(viewerUpdateRoleRes.isFailure, isTrue);
    });
  });
}
