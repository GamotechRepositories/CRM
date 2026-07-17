import 'package:equatable/equatable.dart';

import '../../domain/entities/employee.dart';

enum EmployeesStatus { initial, loading, success, error }

class EmployeesState extends Equatable {
  const EmployeesState({
    this.status = EmployeesStatus.initial,
    this.employees = const [],
    this.filtered = const [],
    this.searchQuery = '',
    this.departmentFilter,
    this.roleFilter,
    this.statusFilter,
    this.errorMessage,
    this.isDeleting = false,
  });

  final EmployeesStatus status;
  final List<Employee> employees;
  final List<Employee> filtered;
  final String searchQuery;
  final String? departmentFilter;
  final EmployeeRole? roleFilter;
  final EmployeeStatus? statusFilter;
  final String? errorMessage;
  final bool isDeleting;

  bool get isLoading => status == EmployeesStatus.loading;
  bool get isEmpty => filtered.isEmpty && !isLoading;
  bool get hasActiveFilters =>
      (departmentFilter != null && departmentFilter!.isNotEmpty) ||
      roleFilter != null ||
      statusFilter != null;

  int get activeCount =>
      employees.where((e) => e.status == EmployeeStatus.active).length;

  Map<String, int> get countByDepartment {
    final map = <String, int>{};
    for (final e in employees) {
      map[e.department] = (map[e.department] ?? 0) + 1;
    }
    return map;
  }

  Map<EmployeeRole, int> get countByRole {
    final map = <EmployeeRole, int>{};
    for (final e in employees) {
      map[e.role] = (map[e.role] ?? 0) + 1;
    }
    return map;
  }

  EmployeesState copyWith({
    EmployeesStatus? status,
    List<Employee>? employees,
    List<Employee>? filtered,
    String? searchQuery,
    String? departmentFilter,
    EmployeeRole? roleFilter,
    EmployeeStatus? statusFilter,
    String? errorMessage,
    bool? isDeleting,
    bool clearError = false,
    bool clearDepartment = false,
    bool clearRole = false,
    bool clearStatus = false,
  }) {
    return EmployeesState(
      status: status ?? this.status,
      employees: employees ?? this.employees,
      filtered: filtered ?? this.filtered,
      searchQuery: searchQuery ?? this.searchQuery,
      departmentFilter: clearDepartment
          ? null
          : (departmentFilter ?? this.departmentFilter),
      roleFilter: clearRole ? null : (roleFilter ?? this.roleFilter),
      statusFilter: clearStatus ? null : (statusFilter ?? this.statusFilter),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isDeleting: isDeleting ?? this.isDeleting,
    );
  }

  @override
  List<Object?> get props => [
    status,
    employees,
    filtered,
    searchQuery,
    departmentFilter,
    roleFilter,
    statusFilter,
    errorMessage,
    isDeleting,
  ];
}
