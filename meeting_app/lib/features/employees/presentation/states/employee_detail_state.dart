import 'package:equatable/equatable.dart';

import '../../domain/entities/employee.dart';

enum EmployeeDetailStatus { initial, loading, success, error }

class EmployeeDetailState extends Equatable {
  const EmployeeDetailState({
    this.status = EmployeeDetailStatus.initial,
    this.employee,
    this.manager,
    this.directReports = const [],
    this.companyName,
    this.errorMessage,
    this.isDeleting = false,
  });

  final EmployeeDetailStatus status;
  final Employee? employee;
  final Employee? manager;
  final List<Employee> directReports;
  final String? companyName;
  final String? errorMessage;
  final bool isDeleting;

  bool get isLoading => status == EmployeeDetailStatus.loading;

  EmployeeDetailState copyWith({
    EmployeeDetailStatus? status,
    Employee? employee,
    Employee? manager,
    List<Employee>? directReports,
    String? companyName,
    String? errorMessage,
    bool? isDeleting,
    bool clearError = false,
    bool clearManager = false,
  }) {
    return EmployeeDetailState(
      status: status ?? this.status,
      employee: employee ?? this.employee,
      manager: clearManager ? null : (manager ?? this.manager),
      directReports: directReports ?? this.directReports,
      companyName: companyName ?? this.companyName,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isDeleting: isDeleting ?? this.isDeleting,
    );
  }

  @override
  List<Object?> get props => [
    status,
    employee,
    manager,
    directReports,
    companyName,
    errorMessage,
    isDeleting,
  ];
}
