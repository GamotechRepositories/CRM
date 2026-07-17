import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/company.dart';

enum CompanyFormMode { create, edit }

enum CompanyFormStatus { initial, loading, success, error }

class CompanyFormState extends Equatable {
  const CompanyFormState({
    required this.mode,
    this.status = CompanyFormStatus.initial,
    this.companyId,
    this.name = '',
    this.industry = 'Technology',
    this.address = '',
    this.website = '',
    this.email = '',
    this.phone = '',
    this.employeeCount = 1,
    this.colorValue = 0xFF1D4ED8,
    this.companyStatus = CompanyStatus.active,
    this.logoIcon = 'business',
    this.createdAt,
    this.errorMessage,
  });

  final CompanyFormMode mode;
  final CompanyFormStatus status;
  final String? companyId;
  final String name;
  final String industry;
  final String address;
  final String website;
  final String email;
  final String phone;
  final int employeeCount;
  final int colorValue;
  final CompanyStatus companyStatus;
  final String logoIcon;
  final DateTime? createdAt;
  final String? errorMessage;

  bool get isLoading => status == CompanyFormStatus.loading;
  bool get isValid =>
      name.trim().isNotEmpty &&
      industry.trim().isNotEmpty &&
      address.trim().isNotEmpty &&
      employeeCount > 0;

  Color get color => Color(colorValue);

  factory CompanyFormState.fromCompany(Company company) {
    return CompanyFormState(
      mode: CompanyFormMode.edit,
      companyId: company.id,
      name: company.name,
      industry: company.industry,
      address: company.address,
      website: company.website,
      email: company.email,
      phone: company.phone,
      employeeCount: company.employeeCount,
      colorValue: company.colorValue,
      companyStatus: company.status,
      logoIcon: company.logoIcon,
      createdAt: company.createdAt,
    );
  }

  CompanyFormState copyWith({
    CompanyFormMode? mode,
    CompanyFormStatus? status,
    String? companyId,
    String? name,
    String? industry,
    String? address,
    String? website,
    String? email,
    String? phone,
    int? employeeCount,
    int? colorValue,
    CompanyStatus? companyStatus,
    String? logoIcon,
    DateTime? createdAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CompanyFormState(
      mode: mode ?? this.mode,
      status: status ?? this.status,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      industry: industry ?? this.industry,
      address: address ?? this.address,
      website: website ?? this.website,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      employeeCount: employeeCount ?? this.employeeCount,
      colorValue: colorValue ?? this.colorValue,
      companyStatus: companyStatus ?? this.companyStatus,
      logoIcon: logoIcon ?? this.logoIcon,
      createdAt: createdAt ?? this.createdAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    mode,
    status,
    companyId,
    name,
    industry,
    address,
    website,
    email,
    phone,
    employeeCount,
    colorValue,
    companyStatus,
    logoIcon,
    createdAt,
    errorMessage,
  ];
}
