import 'dart:convert';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/storage/hive_service.dart';
import '../models/employee_model.dart';

class EmployeeLocalDataSource {
  EmployeeLocalDataSource(this._hive);

  final HiveService _hive;

  List<EmployeeModel> readAll() {
    try {
      final raw = _hive.get<String>(StorageKeys.employees);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (e) => EmployeeModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (_) {
      throw const CacheException('Failed to read employees');
    }
  }

  Future<void> writeAll(List<EmployeeModel> employees) async {
    try {
      final encoded = jsonEncode(employees.map((e) => e.toJson()).toList());
      await _hive.put(StorageKeys.employees, encoded);
    } catch (_) {
      throw const CacheException('Failed to save employees');
    }
  }

  EmployeeModel? readById(String id) {
    for (final e in readAll()) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<void> upsert(EmployeeModel employee) async {
    final all = readAll();
    final index = all.indexWhere((e) => e.id == employee.id);
    if (index >= 0) {
      all[index] = employee;
    } else {
      all.add(employee);
    }
    await writeAll(all);
  }

  Future<void> delete(String id) async {
    final all = readAll()..removeWhere((e) => e.id == id);
    // Clear reporting manager refs pointing to deleted employee
    final cleaned = all
        .map(
          (e) => e.reportingManagerId == id
              ? EmployeeModel(
                  id: e.id,
                  companyId: e.companyId,
                  name: e.name,
                  mobile: e.mobile,
                  email: e.email,
                  department: e.department,
                  designation: e.designation,
                  role: e.role,
                  reportingManagerId: null,
                  status: e.status,
                  avatarColorValue: e.avatarColorValue,
                  avatarIcon: e.avatarIcon,
                  createdAt: e.createdAt,
                  updatedAt: e.updatedAt,
                )
              : e,
        )
        .toList();
    await writeAll(cleaned);
  }
}
