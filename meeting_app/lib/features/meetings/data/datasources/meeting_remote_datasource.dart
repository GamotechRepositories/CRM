import 'package:dio/dio.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/meeting.dart';

class MeetingRemoteDataSource {
  MeetingRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<Meeting>> getByCompany(String companyId) => getAll();

  Future<List<Meeting>> getAll() async {
    try {
      final response = await _dio.get<List<dynamic>>('/meetings');
      return _parseList(response.data);
    } on DioException catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'MeetingRemote.getAll');
      throw ErrorHandler.mapException(error);
    }
  }

  Future<Meeting> getById(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/meetings/$id');
      final data = response.data;
      if (data == null) throw const ServerException('Meeting not found');
      return _fromJson(data);
    } on DioException catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'MeetingRemote.getById');
      throw ErrorHandler.mapException(error);
    }
  }

  Future<Meeting> create(Meeting meeting) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/meetings',
        data: _toJson(meeting),
      );
      final data = response.data?['meeting'] ?? response.data;
      if (data is! Map) throw const ServerException('Invalid create response');
      return _fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'MeetingRemote.create');
      throw ErrorHandler.mapException(error);
    }
  }

  Future<Meeting> update(Meeting meeting) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/meetings/${meeting.id}',
        data: _toJson(meeting),
      );
      final data = response.data?['meeting'] ?? response.data;
      if (data is! Map) throw const ServerException('Invalid update response');
      return _fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'MeetingRemote.update');
      throw ErrorHandler.mapException(error);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete<void>('/meetings/$id');
    } on DioException catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'MeetingRemote.delete');
      throw ErrorHandler.mapException(error);
    }
  }

  Future<({String id, String name})> getBoss() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/boss');
      final data = response.data;
      if (data == null) throw const ServerException('Boss not found');
      return (
        id: (data['id'] ?? '').toString(),
        name: data['name'] as String? ?? 'Boss',
      );
    } on DioException catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'MeetingRemote.getBoss');
      throw ErrorHandler.mapException(error);
    }
  }

  List<Meeting> _parseList(List<dynamic>? data) {
    if (data == null) return const [];
    return data
        .map((e) => _fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Meeting _fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is String) return DateTime.parse(value);
      if (value is DateTime) return value;
      return DateTime.now();
    }

    return Meeting(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      companyId: json['companyId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      organizerId: json['organizerId'] as String? ?? '',
      organizerName: json['organizerName'] as String? ?? '',
      organizerRole: json['organizerRole'] as String? ?? '',
      bossId: json['bossId']?.toString(),
      bossName: json['bossName'] as String?,
      companyName: (json['companyName'] ?? '').toString(),
      agenda: json['agenda'] as String? ?? '',
      description: json['description'] as String? ?? '',
      priority: MeetingPriorityX.fromStorage(json['priority'] as String?),
      status: MeetingStatusX.fromStorage(json['status'] as String?),
      type: MeetingTypeX.fromStorage(json['type'] as String?),
      participants: (json['participants'] as List<dynamic>? ?? const [])
          .map(
            (e) => MeetingParticipant.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      startAt: parseDate(json['startAt']),
      endAt: parseDate(json['endAt']),
      meetLink: (json['meetLink'] as String?)?.isEmpty == true
          ? null
          : json['meetLink'] as String?,
      location: (json['location'] as String?)?.isEmpty == true
          ? null
          : json['location'] as String?,
      reminderMinutes: json['reminderMinutes'] as int? ?? 15,
      attachments: const [],
      notes: json['notes'] as String? ?? '',
      actionItems: const [],
      teamLeadId: null,
      isTeamMeeting: false,
      createdAt: parseDate(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: parseDate(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> _toJson(Meeting meeting) => {
    'title': meeting.title,
    'organizerId': meeting.organizerId,
    'organizerName': meeting.organizerName,
    'organizerRole': meeting.organizerRoleOrEmpty,
    'companyId': meeting.companyId,
    'companyName': meeting.companyNameOrEmpty,
    'agenda': meeting.agenda,
    'description': meeting.description,
    'priority': meeting.priority.name,
    'status': meeting.status.name,
    'type': meeting.type.name,
    'startAt': meeting.startAt.toUtc().toIso8601String(),
    'endAt': meeting.endAt.toUtc().toIso8601String(),
    'meetLink': meeting.meetLink,
    'location': meeting.location,
    'notes': meeting.notes,
  };
}
