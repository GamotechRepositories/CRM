import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/states/auth_session_state.dart';
import '../../features/companies/presentation/pages/companies_page.dart';
import '../../features/companies/presentation/pages/company_details_page.dart';
import '../../features/companies/presentation/pages/company_form_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/employees/presentation/pages/employee_form_page.dart';
import '../../features/employees/presentation/pages/employee_profile_page.dart';
import '../../features/employees/presentation/pages/employees_page.dart';
import '../../features/meetings/presentation/pages/meeting_details_page.dart';
import '../../features/meetings/presentation/pages/meeting_form_page.dart';
import '../../features/meetings/presentation/pages/meetings_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/shell/presentation/pages/app_shell_page.dart';
import '../../features/shell/presentation/widgets/tab_swipe_shell.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../rbac/app_permission.dart';
import '../rbac/rbac_providers.dart';
import 'page_transitions.dart';
import 'route_names.dart';
import 'shell_nav_catalog.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final authListenable = _AuthRefreshListenable(ref);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RoutePaths.splash,
    debugLogDiagnostics: true,
    refreshListenable: authListenable,
    redirect: (context, state) {
      final auth = ref.read(authSessionProvider);
      final loc = state.matchedLocation;
      final permissions = ref.read(permissionSetProvider);

      final isSplash = loc == RoutePaths.splash;
      final isAuthRoute = loc == RoutePaths.login || loc == RoutePaths.otp;

      if (auth.status == AuthSessionStatus.unknown) {
        return isSplash ? null : RoutePaths.splash;
      }

      if (isSplash) return null;

      if (auth.isAuthenticated && loc == RoutePaths.login) {
        return ShellNavCatalog.homeLocation(permissions.can);
      }

      if (!auth.isAuthenticated && !isAuthRoute) {
        return RoutePaths.login;
      }

      if (auth.isAuthenticated) {
        final denied = _permissionDeniedRedirect(loc, permissions.can);
        if (denied != null) return denied;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        name: RouteNames.splash,
        pageBuilder: (context, state) => buildTransitionPage(
          key: state.pageKey,
          child: const SplashPage(),
          type: PageTransitionType.fade,
        ),
      ),
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        pageBuilder: (context, state) => buildTransitionPage(
          key: state.pageKey,
          child: const LoginPage(),
          type: PageTransitionType.fade,
        ),
      ),
      GoRoute(
        path: RoutePaths.otp,
        name: RouteNames.otp,
        pageBuilder: (context, state) {
          final extra = state.extra;
          var mobile = '';
          var requestId = '';
          if (extra is OtpRouteArgs) {
            mobile = extra.mobileNumber;
            requestId = extra.requestId;
          } else if (extra is Map) {
            mobile = extra['mobileNumber']?.toString() ?? '';
            requestId = extra['requestId']?.toString() ?? '';
          }
          return buildTransitionPage(
            key: state.pageKey,
            child: OtpPage(mobileNumber: mobile, requestId: requestId),
            type: PageTransitionType.slide,
          );
        },
      ),
      StatefulShellRoute(
        builder: (context, state, navigationShell) =>
            AppShellPage(navigationShell: navigationShell),
        navigatorContainerBuilder: (context, navigationShell, children) {
          return Consumer(
            builder: (context, ref, _) {
              final permissions = ref.watch(permissionSetProvider);
              final visible = ShellNavCatalog.visibleFor(permissions.can);
              final isAuthenticated =
                  ref.watch(authSessionProvider).isAuthenticated;
              final gated = <int>{};
              for (var i = 0; i < visible.length; i++) {
                if (kAuthGatedBranchIndices
                    .contains(visible[i].branchIndex)) {
                  gated.add(i);
                }
              }
              return TabSwipeShell(
                navigationShell: navigationShell,
                visibleBranchIndices:
                    visible.map((d) => d.branchIndex).toList(),
                branchNavigatorKeys: ShellNavigatorKeys.all,
                authGatedVisibleIndices: gated,
                isAuthenticated: isAuthenticated,
                onAuthRequired: () {
                  GoRouter.of(context).go(RoutePaths.login);
                },
                children: children,
              );
            },
          );
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: ShellNavigatorKeys.home,
            routes: [
              GoRoute(
                path: RoutePaths.dashboard,
                name: RouteNames.dashboard,
                pageBuilder: (context, state) => buildTransitionPage(
                  key: state.pageKey,
                  child: const DashboardPage(),
                  type: PageTransitionType.fade,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: ShellNavigatorKeys.meetings,
            routes: [
              GoRoute(
                path: RoutePaths.meetings,
                name: RouteNames.meetings,
                pageBuilder: (context, state) => buildTransitionPage(
                  key: state.pageKey,
                  child: const MeetingsPage(),
                  type: PageTransitionType.fade,
                ),
                routes: [
                  GoRoute(
                    path: 'new',
                    name: RouteNames.meetingCreate,
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => buildTransitionPage(
                      key: state.pageKey,
                      child: const MeetingFormPage(),
                      type: PageTransitionType.slide,
                    ),
                  ),
                  GoRoute(
                    path: ':meetingId/edit',
                    name: RouteNames.meetingEdit,
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['meetingId']!;
                      return buildTransitionPage(
                        key: state.pageKey,
                        child: MeetingFormPage(meetingId: id),
                        type: PageTransitionType.slide,
                      );
                    },
                  ),
                  GoRoute(
                    path: ':meetingId',
                    name: RouteNames.meetingDetails,
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['meetingId']!;
                      return buildTransitionPage(
                        key: state.pageKey,
                        child: MeetingDetailsPage(meetingId: id),
                        type: PageTransitionType.sharedAxis,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: ShellNavigatorKeys.settings,
            routes: [
              GoRoute(
                path: RoutePaths.settings,
                name: RouteNames.settings,
                pageBuilder: (context, state) => buildTransitionPage(
                  key: state.pageKey,
                  child: const SettingsPage(),
                  type: PageTransitionType.sharedAxis,
                ),
              ),
            ],
          ),
        ],
      ),
      // Companies on root navigator — floating bar auto-hides.
      GoRoute(
        path: RoutePaths.companies,
        name: RouteNames.companies,
        pageBuilder: (context, state) => buildTransitionPage(
          key: state.pageKey,
          child: const CompaniesPage(),
          type: PageTransitionType.fade,
        ),
        routes: [
          GoRoute(
            path: 'new',
            name: RouteNames.companyCreate,
            pageBuilder: (context, state) => buildTransitionPage(
              key: state.pageKey,
              child: const CompanyFormPage(),
              type: PageTransitionType.slide,
            ),
          ),
          GoRoute(
            path: ':companyId',
            name: RouteNames.companyDetails,
            pageBuilder: (context, state) {
              final id = state.pathParameters['companyId']!;
              return buildTransitionPage(
                key: state.pageKey,
                child: CompanyDetailsPage(companyId: id),
                type: PageTransitionType.sharedAxis,
              );
            },
            routes: [
              GoRoute(
                path: 'edit',
                name: RouteNames.companyEdit,
                pageBuilder: (context, state) {
                  final id = state.pathParameters['companyId']!;
                  return buildTransitionPage(
                    key: state.pageKey,
                    child: CompanyFormPage(companyId: id),
                    type: PageTransitionType.slide,
                  );
                },
              ),
              GoRoute(
                path: 'employees',
                name: RouteNames.employees,
                pageBuilder: (context, state) {
                  final companyId = state.pathParameters['companyId']!;
                  return buildTransitionPage(
                    key: state.pageKey,
                    child: EmployeesPage(companyId: companyId),
                    type: PageTransitionType.slide,
                  );
                },
                routes: [
                  GoRoute(
                    path: 'new',
                    name: RouteNames.employeeCreate,
                    pageBuilder: (context, state) {
                      final companyId = state.pathParameters['companyId']!;
                      return buildTransitionPage(
                        key: state.pageKey,
                        child: EmployeeFormPage(companyId: companyId),
                        type: PageTransitionType.slide,
                      );
                    },
                  ),
                  GoRoute(
                    path: ':employeeId',
                    name: RouteNames.employeeDetails,
                    pageBuilder: (context, state) {
                      final companyId = state.pathParameters['companyId']!;
                      final employeeId = state.pathParameters['employeeId']!;
                      return buildTransitionPage(
                        key: state.pageKey,
                        child: EmployeeProfilePage(
                          companyId: companyId,
                          employeeId: employeeId,
                        ),
                        type: PageTransitionType.sharedAxis,
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        name: RouteNames.employeeEdit,
                        pageBuilder: (context, state) {
                          final companyId =
                              state.pathParameters['companyId']!;
                          final employeeId =
                              state.pathParameters['employeeId']!;
                          return buildTransitionPage(
                            key: state.pageKey,
                            child: EmployeeFormPage(
                              companyId: companyId,
                              employeeId: employeeId,
                            ),
                            type: PageTransitionType.slide,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page not found: ${state.uri}'))),
  );
});

String? _permissionDeniedRedirect(
  String loc,
  bool Function(AppPermission) can,
) {
  if (loc == RoutePaths.dashboard || loc == RoutePaths.home) {
    if (!can(AppPermission.viewDashboard)) {
      return ShellNavCatalog.homeLocation(can);
    }
  }
  if (loc.startsWith(RoutePaths.meetings)) {
    if (!can(AppPermission.viewMeetingsNav) &&
        !can(AppPermission.viewMeetings)) {
      return ShellNavCatalog.homeLocation(can);
    }
    if (loc == RoutePaths.meetingCreate || loc.endsWith('/edit')) {
      final creating = loc == RoutePaths.meetingCreate;
      if (creating &&
          !can(AppPermission.createMeeting) &&
          !can(AppPermission.createTeamMeeting)) {
        return RoutePaths.meetings;
      }
      if (!creating &&
          !can(AppPermission.editAnyMeeting) &&
          !can(AppPermission.editOwnMeeting) &&
          !can(AppPermission.editTeamMeeting)) {
        return RoutePaths.meetings;
      }
    }
  }
  if (loc.startsWith(RoutePaths.companies)) {
    if (!can(AppPermission.viewCompaniesNav) &&
        !can(AppPermission.viewCompanies)) {
      return ShellNavCatalog.homeLocation(can);
    }
    if (loc == RoutePaths.companyCreate && !can(AppPermission.createCompany)) {
      return RoutePaths.companies;
    }
  }
  return null;
}

class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(this._ref) {
    _ref.listen<AuthSessionState>(authSessionProvider, (previous, next) {
      notifyListeners();
    });
    _ref.listen(permissionSetProvider, (previous, next) {
      notifyListeners();
    });
  }

  final Ref _ref;
}
