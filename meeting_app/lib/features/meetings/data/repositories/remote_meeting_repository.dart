import '../../../../core/error/error_handler.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/meeting.dart';
import '../../domain/repositories/meeting_repository.dart';
import '../datasources/meeting_remote_datasource.dart';

class RemoteMeetingRepository implements MeetingRepository {
  RemoteMeetingRepository(this._remote);

  final MeetingRemoteDataSource _remote;

  @override
  Future<Result<List<Meeting>>> getByCompany(String companyId) async {
    try {
      final list = await _remote.getByCompany(companyId);
      list.sort((a, b) => a.startAt.compareTo(b.startAt));
      return Success(list);
    } on Failure catch (failure) {
      return Error(failure);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'RemoteMeetings.getByCompany');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<List<Meeting>>> getAll() async {
    try {
      final list = await _remote.getAll();
      list.sort((a, b) => a.startAt.compareTo(b.startAt));
      return Success(list);
    } on Failure catch (failure) {
      return Error(failure);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'RemoteMeetings.getAll');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<Meeting>> getById(String id) async {
    try {
      return Success(await _remote.getById(id));
    } on Failure catch (failure) {
      return Error(failure);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'RemoteMeetings.getById');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<Meeting>> create(Meeting meeting) async {
    try {
      return Success(await _remote.create(meeting));
    } on Failure catch (failure) {
      return Error(failure);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'RemoteMeetings.create');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<Meeting>> update(Meeting meeting) async {
    try {
      return Success(await _remote.update(meeting));
    } on Failure catch (failure) {
      return Error(failure);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'RemoteMeetings.update');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await _remote.delete(id);
      return const Success(null);
    } on Failure catch (failure) {
      return Error(failure);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'RemoteMeetings.delete');
      return Error(ErrorHandler.mapException(error));
    }
  }
}
