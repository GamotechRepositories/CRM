import '../../../../core/error/error_handler.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/meeting.dart';
import '../../domain/repositories/meeting_repository.dart';
import '../datasources/meeting_local_datasource.dart';
import '../models/meeting_model.dart';

class LocalMeetingRepository implements MeetingRepository {
  LocalMeetingRepository(this._local);

  final MeetingLocalDataSource _local;

  @override
  Future<Result<List<Meeting>>> getByCompany(String companyId) async {
    try {
      final list =
          _local
              .readAll()
              .where((m) => m.companyId == companyId)
              .map((m) => m.toEntity())
              .toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      return Success(list);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Meetings.getByCompany');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<List<Meeting>>> getAll() async {
    try {
      final list = _local.readAll().map((m) => m.toEntity()).toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      return Success(list);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Meetings.getAll');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<Meeting>> getById(String id) async {
    try {
      final model = _local.readById(id);
      if (model == null) {
        return const Error(ValidationFailure('Meeting not found'));
      }
      return Success(model.toEntity());
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Meetings.getById');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<Meeting>> create(Meeting meeting) async {
    try {
      await _local.upsert(MeetingModel.fromEntity(meeting));
      return Success(meeting);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Meetings.create');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<Meeting>> update(Meeting meeting) async {
    try {
      final existing = _local.readById(meeting.id);
      if (existing == null) {
        return const Error(ValidationFailure('Meeting not found'));
      }
      await _local.upsert(MeetingModel.fromEntity(meeting));
      return Success(meeting);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Meetings.update');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      final existing = _local.readById(id);
      if (existing == null) {
        return const Error(ValidationFailure('Meeting not found'));
      }
      await _local.delete(id);
      return const Success(null);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Meetings.delete');
      return Error(ErrorHandler.mapException(error));
    }
  }
}
