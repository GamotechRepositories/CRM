import 'package:equatable/equatable.dart';

import 'meeting_enums.dart';

export 'meeting_enums.dart';

/// Participant invited to a meeting.
class MeetingParticipant extends Equatable {
  const MeetingParticipant({
    required this.userId,
    required this.name,
    this.response = InvitationResponse.pending,
  });

  final String userId;
  final String name;
  final InvitationResponse response;

  MeetingParticipant copyWith({
    String? userId,
    String? name,
    InvitationResponse? response,
  }) {
    return MeetingParticipant(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      response: response ?? this.response,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'response': response.name,
  };

  factory MeetingParticipant.fromJson(Map<String, dynamic> json) {
    return MeetingParticipant(
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ?? 'Guest',
      response: InvitationResponseX.fromStorage(json['response'] as String?),
    );
  }

  @override
  List<Object?> get props => [userId, name, response];
}

/// Full meeting entity for production meeting management.
class Meeting extends Equatable {
  const Meeting({
    required this.id,
    required this.companyId,
    required this.title,
    required this.organizerId,
    required this.organizerName,
    required this.startAt,
    required this.endAt,
    required this.createdAt,
    required this.updatedAt,
    this.organizerRole = '',
    this.bossId,
    this.bossName,
    this.companyName = '',
    this.agenda = '',
    this.description = '',
    this.priority = MeetingPriority.medium,
    this.status = MeetingStatus.scheduled,
    this.type = MeetingType.internal,
    this.participants = const [],
    this.meetLink,
    this.location,
    this.reminderMinutes = 15,
    this.attachments = const [],
    this.notes = '',
    this.actionItems = const [],
    this.teamLeadId,
    this.isTeamMeeting = false,
    this.bossResponse = InvitationResponse.pending,
    this.bossResponseNote = '',
    this.bossResponseAt,
    this.rescheduleRequested = false,
    this.reschedulePreferredStartAt,
    this.reschedulePreferredEndAt,
    this.rescheduleReason = '',
    this.rescheduleRequestedAt,
    this.bossMarkedImportant = false,
    this.bossPersonalNote = '',
    this.coordinatorApproval = CoordinatorApproval.approved,
    this.approvedById = '',
    this.approvedByName = '',
    this.approvedAt,
    this.rejectionReason = '',
  });

  final String id;
  final String companyId;
  final String title;
  final String organizerId;
  final String organizerName;
  /// Create Team role of the person who scheduled this (e.g. EA).
  final String organizerRole;
  final String? bossId;
  final String? bossName;
  final String companyName;
  final String agenda;
  final String description;
  final MeetingPriority priority;
  final MeetingStatus status;
  final MeetingType type;
  final List<MeetingParticipant> participants;
  final DateTime startAt;
  final DateTime endAt;
  final String? meetLink;
  final String? location;
  final int reminderMinutes;
  final List<String> attachments;
  final String notes;
  final List<String> actionItems;
  final String? teamLeadId;
  final bool isTeamMeeting;

  /// Boss RSVP: pending / accepted (will attend) / declined.
  final InvitationResponse bossResponse;
  final String bossResponseNote;
  final DateTime? bossResponseAt;

  /// Boss asked team to move this meeting.
  final bool rescheduleRequested;
  final DateTime? reschedulePreferredStartAt;
  final DateTime? reschedulePreferredEndAt;
  final String rescheduleReason;
  final DateTime? rescheduleRequestedAt;

  /// Boss flagged as important + optional note for the team.
  final bool bossMarkedImportant;
  final String bossPersonalNote;

  /// Meeting Coordinator must approve before Boss sees this meeting.
  final CoordinatorApproval coordinatorApproval;
  final String approvedById;
  final String approvedByName;
  final DateTime? approvedAt;
  final String rejectionReason;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Compatibility alias used by dashboards/filters.
  DateTime get scheduledAt => startAt;
  String get createdByUserId => organizerId;

  /// Null-safe reads (older API docs / hot-reload can leave new fields null).
  String get companyNameOrEmpty {
    final value = (this as dynamic).companyName;
    return value is String ? value : '';
  }

  String get organizerRoleOrEmpty {
    final value = (this as dynamic).organizerRole;
    return value is String ? value : '';
  }

  Meeting copyWith({
    String? id,
    String? companyId,
    String? title,
    String? organizerId,
    String? organizerName,
    String? organizerRole,
    String? bossId,
    String? bossName,
    String? companyName,
    String? agenda,
    String? description,
    MeetingPriority? priority,
    MeetingStatus? status,
    MeetingType? type,
    List<MeetingParticipant>? participants,
    DateTime? startAt,
    DateTime? endAt,
    String? meetLink,
    String? location,
    int? reminderMinutes,
    List<String>? attachments,
    String? notes,
    List<String>? actionItems,
    String? teamLeadId,
    bool? isTeamMeeting,
    DateTime? createdAt,
    DateTime? updatedAt,
    InvitationResponse? bossResponse,
    String? bossResponseNote,
    DateTime? bossResponseAt,
    bool clearBossResponseAt = false,
    bool? rescheduleRequested,
    DateTime? reschedulePreferredStartAt,
    DateTime? reschedulePreferredEndAt,
    bool clearReschedulePreferred = false,
    String? rescheduleReason,
    DateTime? rescheduleRequestedAt,
    bool clearRescheduleRequestedAt = false,
    bool? bossMarkedImportant,
    String? bossPersonalNote,
    CoordinatorApproval? coordinatorApproval,
    String? approvedById,
    String? approvedByName,
    DateTime? approvedAt,
    bool clearApprovedAt = false,
    String? rejectionReason,
  }) {
    return Meeting(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      title: title ?? this.title,
      organizerId: organizerId ?? this.organizerId,
      organizerName: organizerName ?? this.organizerName,
      organizerRole: organizerRole ?? this.organizerRole,
      bossId: bossId ?? this.bossId,
      bossName: bossName ?? this.bossName,
      companyName: companyName ?? this.companyName,
      agenda: agenda ?? this.agenda,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      type: type ?? this.type,
      participants: participants ?? this.participants,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      meetLink: meetLink ?? this.meetLink,
      location: location ?? this.location,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      attachments: attachments ?? this.attachments,
      notes: notes ?? this.notes,
      actionItems: actionItems ?? this.actionItems,
      teamLeadId: teamLeadId ?? this.teamLeadId,
      isTeamMeeting: isTeamMeeting ?? this.isTeamMeeting,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      bossResponse: bossResponse ?? this.bossResponse,
      bossResponseNote: bossResponseNote ?? this.bossResponseNote,
      bossResponseAt: clearBossResponseAt
          ? null
          : (bossResponseAt ?? this.bossResponseAt),
      rescheduleRequested: rescheduleRequested ?? this.rescheduleRequested,
      reschedulePreferredStartAt: clearReschedulePreferred
          ? null
          : (reschedulePreferredStartAt ?? this.reschedulePreferredStartAt),
      reschedulePreferredEndAt: clearReschedulePreferred
          ? null
          : (reschedulePreferredEndAt ?? this.reschedulePreferredEndAt),
      rescheduleReason: rescheduleReason ?? this.rescheduleReason,
      rescheduleRequestedAt: clearRescheduleRequestedAt
          ? null
          : (rescheduleRequestedAt ?? this.rescheduleRequestedAt),
      bossMarkedImportant: bossMarkedImportant ?? this.bossMarkedImportant,
      bossPersonalNote: bossPersonalNote ?? this.bossPersonalNote,
      coordinatorApproval: coordinatorApproval ?? this.coordinatorApproval,
      approvedById: approvedById ?? this.approvedById,
      approvedByName: approvedByName ?? this.approvedByName,
      approvedAt: clearApprovedAt ? null : (approvedAt ?? this.approvedAt),
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  @override
  List<Object?> get props => [
    id,
    companyId,
    title,
    organizerId,
    organizerName,
    organizerRole,
    bossId,
    bossName,
    companyName,
    agenda,
    description,
    priority,
    status,
    type,
    participants,
    startAt,
    endAt,
    meetLink,
    location,
    reminderMinutes,
    attachments,
    notes,
    actionItems,
    teamLeadId,
    isTeamMeeting,
    createdAt,
    updatedAt,
    bossResponse,
    bossResponseNote,
    bossResponseAt,
    rescheduleRequested,
    reschedulePreferredStartAt,
    reschedulePreferredEndAt,
    rescheduleReason,
    rescheduleRequestedAt,
    bossMarkedImportant,
    bossPersonalNote,
    coordinatorApproval,
    approvedById,
    approvedByName,
    approvedAt,
    rejectionReason,
  ];
}
