import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum CompanyStatus { active, inactive }

/// Domain entity for a company owned by the logged-in boss.
class Company extends Equatable {
  const Company({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.industry,
    required this.address,
    required this.website,
    required this.email,
    required this.phone,
    required this.employeeCount,
    required this.colorValue,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.logoIcon = 'business',
  });

  final String id;
  final String ownerId;
  final String name;
  final String industry;
  final String address;
  final String website;
  final String email;
  final String phone;
  final int employeeCount;
  final int colorValue;
  final CompanyStatus status;
  final String logoIcon;
  final DateTime createdAt;
  final DateTime updatedAt;

  Color get color => Color(colorValue);
  bool get isActive => status == CompanyStatus.active;
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  Company copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? industry,
    String? address,
    String? website,
    String? email,
    String? phone,
    int? employeeCount,
    int? colorValue,
    CompanyStatus? status,
    String? logoIcon,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Company(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      industry: industry ?? this.industry,
      address: address ?? this.address,
      website: website ?? this.website,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      employeeCount: employeeCount ?? this.employeeCount,
      colorValue: colorValue ?? this.colorValue,
      status: status ?? this.status,
      logoIcon: logoIcon ?? this.logoIcon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    ownerId,
    name,
    industry,
    address,
    website,
    email,
    phone,
    employeeCount,
    colorValue,
    status,
    logoIcon,
    createdAt,
    updatedAt,
  ];
}

/// Preset industries for forms.
abstract final class CompanyIndustries {
  static const List<String> all = [
    'Technology',
    'Finance',
    'Healthcare',
    'Real Estate',
    'Manufacturing',
    'Retail',
    'Education',
    'Consulting',
    'Media',
    'Other',
  ];
}

/// Preset logo icons (Material icon names).
abstract final class CompanyLogoIcons {
  static const Map<String, IconData> icons = {
    'business': Icons.business_rounded,
    'apartment': Icons.apartment_rounded,
    'store': Icons.storefront_rounded,
    'factory': Icons.factory_rounded,
    'school': Icons.school_rounded,
    'health': Icons.local_hospital_rounded,
    'finance': Icons.account_balance_rounded,
    'tech': Icons.memory_rounded,
  };

  static IconData resolve(String key) => icons[key] ?? Icons.business_rounded;
}

/// Preset brand colors for company theming.
abstract final class CompanyColors {
  static const List<Color> presets = [
    Color(0xFF1D4ED8),
    Color(0xFF0F766E),
    Color(0xFF7C3AED),
    Color(0xFFBE123C),
    Color(0xFFC2410C),
    Color(0xFF047857),
    Color(0xFF0369A1),
    Color(0xFF4F46E5),
  ];
}
