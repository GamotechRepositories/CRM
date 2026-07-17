import 'dart:convert';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/storage/hive_service.dart';
import '../models/company_model.dart';

class CompanyLocalDataSource {
  CompanyLocalDataSource(this._hive);

  final HiveService _hive;

  List<CompanyModel> readAll() {
    try {
      final raw = _hive.get<String>(StorageKeys.companies);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (e) => CompanyModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (_) {
      throw const CacheException('Failed to read companies');
    }
  }

  Future<void> writeAll(List<CompanyModel> companies) async {
    try {
      final encoded = jsonEncode(companies.map((e) => e.toJson()).toList());
      await _hive.put(StorageKeys.companies, encoded);
    } catch (_) {
      throw const CacheException('Failed to save companies');
    }
  }

  CompanyModel? readById(String id) {
    final all = readAll();
    for (final company in all) {
      if (company.id == id) return company;
    }
    return null;
  }

  Future<void> upsert(CompanyModel company) async {
    final all = readAll();
    final index = all.indexWhere((c) => c.id == company.id);
    if (index >= 0) {
      all[index] = company;
    } else {
      all.add(company);
    }
    await writeAll(all);
  }

  Future<void> delete(String id) async {
    final all = readAll()..removeWhere((c) => c.id == id);
    await writeAll(all);
  }
}
