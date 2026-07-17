import '../../domain/entities/company.dart';

class CompanyModel {
  const CompanyModel({
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
    required this.logoIcon,
    required this.createdAt,
    required this.updatedAt,
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
  final String status;
  final String logoIcon;
  final String createdAt;
  final String updatedAt;

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String,
      name: json['name'] as String,
      industry: json['industry'] as String,
      address: json['address'] as String,
      website: json['website'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      employeeCount: json['employeeCount'] as int? ?? 0,
      colorValue: json['colorValue'] as int? ?? 0xFF1D4ED8,
      status: json['status'] as String? ?? 'active',
      logoIcon: json['logoIcon'] as String? ?? 'business',
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'name': name,
    'industry': industry,
    'address': address,
    'website': website,
    'email': email,
    'phone': phone,
    'employeeCount': employeeCount,
    'colorValue': colorValue,
    'status': status,
    'logoIcon': logoIcon,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  Company toEntity() => Company(
    id: id,
    ownerId: ownerId,
    name: name,
    industry: industry,
    address: address,
    website: website,
    email: email,
    phone: phone,
    employeeCount: employeeCount,
    colorValue: colorValue,
    status: status == 'inactive'
        ? CompanyStatus.inactive
        : CompanyStatus.active,
    logoIcon: logoIcon,
    createdAt: DateTime.parse(createdAt),
    updatedAt: DateTime.parse(updatedAt),
  );

  factory CompanyModel.fromEntity(Company company) => CompanyModel(
    id: company.id,
    ownerId: company.ownerId,
    name: company.name,
    industry: company.industry,
    address: company.address,
    website: company.website,
    email: company.email,
    phone: company.phone,
    employeeCount: company.employeeCount,
    colorValue: company.colorValue,
    status: company.status == CompanyStatus.inactive ? 'inactive' : 'active',
    logoIcon: company.logoIcon,
    createdAt: company.createdAt.toIso8601String(),
    updatedAt: company.updatedAt.toIso8601String(),
  );
}
