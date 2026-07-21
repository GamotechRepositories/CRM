import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/meeting.dart';

/// Live Render may not yet expose bossResponse fields.
/// We also persist a hidden trailer in `notes` so confirmation survives.
const _bossMetaMarker = '\n\n__BOSS_META__';

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
      return _mergeBossFields(
        _fromJson(Map<String, dynamic>.from(data)),
        meeting,
      );
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
      // Live API may strip boss fields — keep what we just saved.
      return _mergeBossFields(
        _fromJson(Map<String, dynamic>.from(data)),
        meeting,
      );
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
      if (value is String && value.isNotEmpty) return DateTime.parse(value);
      if (value is DateTime) return value;
      return DateTime.now();
    }

    DateTime? parseOptionalDate(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isNotEmpty) return DateTime.parse(value);
      if (value is DateTime) return value;
      return null;
    }

    final rawNotes = json['notes'] as String? ?? '';
    final unpacked = _unpackBossMeta(rawNotes);
    final meta = unpacked.meta;

    InvitationResponse bossResponse = InvitationResponseX.fromStorage(
      json['bossResponse'] as String? ?? meta?['r'] as String?,
    );
    // Live old API always hardcodes participant response=accepted — ignore that.

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
      notes: unpacked.cleanNotes,
      actionItems: const [],
      teamLeadId: null,
      isTeamMeeting: false,
      bossResponse: bossResponse,
      bossResponseNote:
          json['bossResponseNote'] as String? ?? meta?['rn'] as String? ?? '',
      bossResponseAt: parseOptionalDate(
        json['bossResponseAt'] ?? meta?['ra'],
      ),
      rescheduleRequested:
          json['rescheduleRequested'] == true || meta?['rr'] == true,
      reschedulePreferredStartAt: parseOptionalDate(
        json['reschedulePreferredStartAt'] ?? meta?['ps'],
      ),
      reschedulePreferredEndAt: parseOptionalDate(
        json['reschedulePreferredEndAt'] ?? meta?['pe'],
      ),
      rescheduleReason:
          json['rescheduleReason'] as String? ?? meta?['rs'] as String? ?? '',
      rescheduleRequestedAt: parseOptionalDate(
        json['rescheduleRequestedAt'] ?? meta?['rt'],
      ),
      bossMarkedImportant:
          json['bossMarkedImportant'] == true || meta?['i'] == true,
      bossPersonalNote:
          json['bossPersonalNote'] as String? ?? meta?['n'] as String? ?? '',
      coordinatorApproval: CoordinatorApprovalX.fromStorage(
        json['coordinatorApproval'] as String? ?? meta?['ca'] as String?,
      ),
      approvedById:
          json['approvedById']?.toString() ?? meta?['abi']?.toString() ?? '',
      approvedByName:
          json['approvedByName'] as String? ?? meta?['abn'] as String? ?? '',
      approvedAt: parseOptionalDate(json['approvedAt'] ?? meta?['aa']),
      rejectionReason:
          json['rejectionReason'] as String? ?? meta?['rj'] as String? ?? '',
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
    // notes carries hidden meta so live Render (old allowlist) still persists it
    'notes': _packBossMeta(meeting),
    'bossResponse': meeting.bossResponse.name,
    'bossResponseNote': meeting.bossResponseNote,
    'bossResponseAt': meeting.bossResponseAt?.toUtc().toIso8601String(),
    'rescheduleRequested': meeting.rescheduleRequested,
    'reschedulePreferredStartAt':
        meeting.reschedulePreferredStartAt?.toUtc().toIso8601String(),
    'reschedulePreferredEndAt':
        meeting.reschedulePreferredEndAt?.toUtc().toIso8601String(),
    'rescheduleReason': meeting.rescheduleReason,
    'rescheduleRequestedAt':
        meeting.rescheduleRequestedAt?.toUtc().toIso8601String(),
    'bossMarkedImportant': meeting.bossMarkedImportant,
    'bossPersonalNote': meeting.bossPersonalNote,
    'coordinatorApproval': meeting.coordinatorApproval.name,
    'approvedById': meeting.approvedById,
    'approvedByName': meeting.approvedByName,
    'approvedAt': meeting.approvedAt?.toUtc().toIso8601String(),
    'rejectionReason': meeting.rejectionReason,
  };

  /// Prefer sent boss/coordinator fields when live API strips them.
  Meeting _mergeBossFields(Meeting fromApi, Meeting sent) {
    var merged = fromApi;

    final apiHasBossField = fromApi.bossResponse != InvitationResponse.pending ||
        fromApi.bossMarkedImportant ||
        fromApi.rescheduleRequested ||
        fromApi.bossPersonalNote.trim().isNotEmpty ||
        fromApi.bossResponseAt != null;

    final sentHasBossAction = sent.bossResponse != InvitationResponse.pending ||
        sent.bossMarkedImportant ||
        sent.rescheduleRequested ||
        sent.bossPersonalNote.trim().isNotEmpty;

    if (!apiHasBossField && sentHasBossAction) {
      merged = merged.copyWith(
        bossResponse: sent.bossResponse,
        bossResponseNote: sent.bossResponseNote,
        bossResponseAt: sent.bossResponseAt,
        rescheduleRequested: sent.rescheduleRequested,
        reschedulePreferredStartAt: sent.reschedulePreferredStartAt,
        reschedulePreferredEndAt: sent.reschedulePreferredEndAt,
        rescheduleReason: sent.rescheduleReason,
        rescheduleRequestedAt: sent.rescheduleRequestedAt,
        bossMarkedImportant: sent.bossMarkedImportant,
        bossPersonalNote: sent.bossPersonalNote,
        notes: sent.notes,
      );
    }

    if (sent.coordinatorApproval != fromApi.coordinatorApproval ||
        sent.approvedById.isNotEmpty ||
        sent.rejectionReason.isNotEmpty) {
      merged = merged.copyWith(
        coordinatorApproval: sent.coordinatorApproval,
        approvedById:
            sent.approvedById.isNotEmpty ? sent.approvedById : fromApi.approvedById,
        approvedByName: sent.approvedByName.isNotEmpty
            ? sent.approvedByName
            : fromApi.approvedByName,
        approvedAt: sent.approvedAt ?? fromApi.approvedAt,
        rejectionReason: sent.rejectionReason,
      );
    }

    return merged;
  }

  String _packBossMeta(Meeting meeting) {
    final clean = _unpackBossMeta(meeting.notes).cleanNotes;
    final meta = <String, dynamic>{
      'r': meeting.bossResponse.name,
      'rn': meeting.bossResponseNote,
      if (meeting.bossResponseAt != null)
        'ra': meeting.bossResponseAt!.toUtc().toIso8601String(),
      'rr': meeting.rescheduleRequested,
      if (meeting.reschedulePreferredStartAt != null)
        'ps': meeting.reschedulePreferredStartAt!.toUtc().toIso8601String(),
      if (meeting.reschedulePreferredEndAt != null)
        'pe': meeting.reschedulePreferredEndAt!.toUtc().toIso8601String(),
      'rs': meeting.rescheduleReason,
      if (meeting.rescheduleRequestedAt != null)
        'rt': meeting.rescheduleRequestedAt!.toUtc().toIso8601String(),
      'i': meeting.bossMarkedImportant,
      'n': meeting.bossPersonalNote,
      'ca': meeting.coordinatorApproval.name,
      'abi': meeting.approvedById,
      'abn': meeting.approvedByName,
      if (meeting.approvedAt != null)
        'aa': meeting.approvedAt!.toUtc().toIso8601String(),
      'rj': meeting.rejectionReason,
    };
    return '$clean$_bossMetaMarker${jsonEncode(meta)}';
  }

  ({String cleanNotes, Map<String, dynamic>? meta}) _unpackBossMeta(
    String raw,
  ) {
    final markerIndex = raw.contains(_bossMetaMarker)
        ? raw.indexOf(_bossMetaMarker)
        : raw.indexOf('__BOSS_META__');
    if (markerIndex < 0) {
      return (cleanNotes: raw, meta: null);
    }
    final clean = raw.substring(0, markerIndex).trimRight();
    final jsonPart = raw
        .substring(
          raw.indexOf('__BOSS_META__') + '__BOSS_META__'.length,
        )
        .trim();
    try {
      final decoded = jsonDecode(jsonPart);
      if (decoded is Map<String, dynamic>) {
        return (cleanNotes: clean, meta: decoded);
      }
      if (decoded is Map) {
        return (
          cleanNotes: clean,
          meta: Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {
      // ignore corrupt trailer
    }
    return (cleanNotes: clean, meta: null);
  }
}
