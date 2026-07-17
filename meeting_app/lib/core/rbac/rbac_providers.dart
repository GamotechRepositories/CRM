import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import 'app_permission.dart';
import 'permission_set.dart';
import 'system_role.dart';

final systemRoleProvider = Provider<SystemRole?>((ref) {
  final user = ref.watch(authSessionProvider).session?.user;
  if (user == null) return null;
  return RoleResolver.fromAuthUser(user);
});

final permissionSetProvider = Provider<PermissionSet>((ref) {
  final role = ref.watch(systemRoleProvider);
  if (role == null) return PermissionSet.empty();
  return PermissionSet.forRole(role);
});

final currentUserIdProvider = Provider<String?>((ref) {
  final user = ref.watch(authSessionProvider).session?.user;
  return user?.employeeId ?? user?.id;
});

/// Convenience: `ref.watch(canPermissionProvider(AppPermission.x))`
final canPermissionProvider = Provider.family<bool, AppPermission>((
  ref,
  permission,
) {
  return ref.watch(permissionSetProvider).can(permission);
});
