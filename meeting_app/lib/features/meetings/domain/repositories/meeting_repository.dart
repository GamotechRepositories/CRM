import '../../../../core/error/result.dart';
import '../entities/meeting.dart';

abstract class MeetingRepository {
  Future<Result<List<Meeting>>> getByCompany(String companyId);
  Future<Result<List<Meeting>>> getAll();
  Future<Result<Meeting>> getById(String id);
  Future<Result<Meeting>> create(Meeting meeting);
  Future<Result<Meeting>> update(Meeting meeting);
  Future<Result<void>> delete(String id);
}
