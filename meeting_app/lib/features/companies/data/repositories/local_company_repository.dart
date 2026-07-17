import '../../../../core/error/error_handler.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/company.dart';
import '../../domain/repositories/company_repository.dart';
import '../datasources/company_local_datasource.dart';
import '../models/company_model.dart';

/// Local Hive-backed company repository (no network).
class LocalCompanyRepository implements CompanyRepository {
  LocalCompanyRepository(this._local);

  final CompanyLocalDataSource _local;

  static const _latency = Duration(milliseconds: 650);

  @override
  Future<Result<List<Company>>> getCompanies(String ownerId) async {
    await Future<void>.delayed(_latency);
    try {
      final companies =
          _local
              .readAll()
              .where((c) => c.ownerId == ownerId)
              .map((c) => c.toEntity())
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return Success(companies);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Company.getAll');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<Company>> getCompanyById(String id) async {
    await Future<void>.delayed(_latency);
    try {
      final model = _local.readById(id);
      if (model == null) {
        return const Error(ValidationFailure('Company not found'));
      }
      return Success(model.toEntity());
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Company.getById');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<Company>> createCompany(Company company) async {
    await Future<void>.delayed(_latency);
    try {
      if (company.name.trim().isEmpty) {
        return const Error(ValidationFailure('Company name is required'));
      }
      final model = CompanyModel.fromEntity(company);
      await _local.upsert(model);
      return Success(model.toEntity());
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Company.create');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<Company>> updateCompany(Company company) async {
    await Future<void>.delayed(_latency);
    try {
      final existing = _local.readById(company.id);
      if (existing == null) {
        return const Error(ValidationFailure('Company not found'));
      }
      final updated = company.copyWith(updatedAt: DateTime.now());
      final model = CompanyModel.fromEntity(updated);
      await _local.upsert(model);
      return Success(model.toEntity());
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Company.update');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<void>> deleteCompany(String id) async {
    await Future<void>.delayed(_latency);
    try {
      final existing = _local.readById(id);
      if (existing == null) {
        return const Error(ValidationFailure('Company not found'));
      }
      await _local.delete(id);
      return const Success(null);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Company.delete');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<List<Company>>> searchCompanies({
    required String ownerId,
    required String query,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    try {
      final q = query.trim().toLowerCase();
      final companies =
          _local
              .readAll()
              .where((c) => c.ownerId == ownerId)
              .map((c) => c.toEntity())
              .where((c) {
                if (q.isEmpty) return true;
                return c.name.toLowerCase().contains(q) ||
                    c.industry.toLowerCase().contains(q) ||
                    c.email.toLowerCase().contains(q) ||
                    c.phone.contains(q) ||
                    c.address.toLowerCase().contains(q);
              })
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return Success(companies);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Company.search');
      return Error(ErrorHandler.mapException(error));
    }
  }
}
