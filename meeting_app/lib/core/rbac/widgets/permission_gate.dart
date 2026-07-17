import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_permission.dart';
import '../permission_set.dart';
import '../rbac_providers.dart';

/// Shows [child] only when the user has [permission].
class PermissionGate extends ConsumerWidget {
  const PermissionGate({
    super.key,
    this.permission,
    required this.child,
    this.fallback = const SizedBox.shrink(),
    this.anyOf,
    this.allOf,
  });

  /// Single required permission.
  final AppPermission? permission;

  /// Pass if user has any of these.
  final List<AppPermission>? anyOf;

  /// Pass if user has all of these.
  final List<AppPermission>? allOf;

  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionSetProvider);
    if (_allowed(permissions)) return child;
    return fallback;
  }

  bool _allowed(PermissionSet set) {
    if (allOf != null && allOf!.isNotEmpty) return set.canAll(allOf!);
    if (anyOf != null && anyOf!.isNotEmpty) return set.canAny(anyOf!);
    if (permission != null) return set.can(permission!);
    return false;
  }
}

/// Builder variant for permission-aware layouts.
class PermissionBuilder extends ConsumerWidget {
  const PermissionBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, PermissionSet permissions)
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return builder(context, ref.watch(permissionSetProvider));
  }
}
