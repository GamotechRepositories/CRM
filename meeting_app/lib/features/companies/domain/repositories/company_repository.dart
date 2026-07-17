import '../../../../core/error/result.dart';
import '../entities/company.dart';

abstract class CompanyRepository {
  Future<Result<List<Company>>> getCompanies(String ownerId);

  Future<Result<Company>> getCompanyById(String id);

  Future<Result<Company>> createCompany(Company company);

  Future<Result<Company>> updateCompany(Company company);

  Future<Result<void>> deleteCompany(String id);

  Future<Result<List<Company>>> searchCompanies({
    required String ownerId,
    required String query,
  });
}
