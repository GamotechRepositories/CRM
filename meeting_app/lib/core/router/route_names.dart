/// Named route paths for GoRouter.
abstract final class RoutePaths {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String dashboard = '/';
  static const String home = '/';
  static const String meetings = '/meetings';
  static const String calendar = '/calendar';
  static const String meetingCreate = '/meetings/new';
  static const String companies = '/companies';
  static const String companyCreate = '/companies/new';
  static const String foundation = '/foundation';
  static const String settings = '/settings';
  static const String profile = '/settings';

  static String meetingDetailsPath(String id) => '/meetings/$id';
  static String meetingEditPath(String id) => '/meetings/$id/edit';

  static String companyDetailsPath(String id) => '/companies/$id';
  static String companyEditPath(String id) => '/companies/$id/edit';

  static String employeesPath(String companyId) =>
      '/companies/$companyId/employees';
  static String employeeCreatePath(String companyId) =>
      '/companies/$companyId/employees/new';
  static String employeeDetailsPath(String companyId, String employeeId) =>
      '/companies/$companyId/employees/$employeeId';
  static String employeeEditPath(String companyId, String employeeId) =>
      '/companies/$companyId/employees/$employeeId/edit';
}

abstract final class RouteNames {
  static const String splash = 'splash';
  static const String login = 'login';
  static const String otp = 'otp';
  static const String dashboard = 'dashboard';
  static const String home = 'home';
  static const String meetings = 'meetings';
  static const String calendar = 'calendar';
  static const String meetingCreate = 'meetingCreate';
  static const String meetingDetails = 'meetingDetails';
  static const String meetingEdit = 'meetingEdit';
  static const String companies = 'companies';
  static const String companyCreate = 'companyCreate';
  static const String companyDetails = 'companyDetails';
  static const String companyEdit = 'companyEdit';
  static const String employees = 'employees';
  static const String employeeCreate = 'employeeCreate';
  static const String employeeDetails = 'employeeDetails';
  static const String employeeEdit = 'employeeEdit';
  static const String foundation = 'foundation';
  static const String settings = 'settings';
  static const String profile = 'profile';
}
