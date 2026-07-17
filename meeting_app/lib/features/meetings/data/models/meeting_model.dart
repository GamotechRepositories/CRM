import '../../domain/entities/meeting.dart';

class MeetingModel {
  const MeetingModel({
    required this.id,
    required this.companyId,
    required this.title,
    required this.organizerId,
    required this.organizerName,
    required this.startAtIso,
    required this.endAtIso,
    required this.createdAtIso,
    required this.updatedAtIso,
    this.organizerRole = '',
    this.bossId,
    this.bossName,
    this.companyName = '',
    this.agenda = '',
    this.description = '',
    this.priority = 'medium',
    this.status = 'scheduled',
    this.type = 'internal',
    this.participants = const [],
    this.meetLink,
    this.location,
    this.reminderMinutes = 15,
    this.attachments = const [],
    this.notes = '',
    this.actionItems = const [],
    this.teamLeadId,
    this.isTeamMeeting = false,
  });

  final String id;
  final String companyId;
  final String title;
  final String organizerId;
  final String organizerName;
  final String organizerRole;
  final String? bossId;
  final String? bossName;
  final String companyName;
  final String agenda;
  final String description;
  final String priority;
  final String status;
  final String type;
  final List<Map<String, dynamic>> participants;
  final String startAtIso;
  final String endAtIso;
  final String? meetLink;
  final String? location;
  final int reminderMinutes;
  final List<String> attachments;
  final String notes;
  final List<String> actionItems;
  final String? teamLeadId;
  final bool isTeamMeeting;
  final String createdAtIso;
  final String updatedAtIso;

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    // Legacy seed support: scheduledAt → start/end
    final startIso =
        json['startAt'] as String? ??
        json['scheduledAt'] as String? ??
        DateTime.now().toIso8601String();
    final endIso =
        json['endAt'] as String? ??
        DateTime.parse(
          startIso,
        ).add(const Duration(hours: 1)).toIso8601String();

    final rawParticipants = json['participants'];
    final participants = <Map<String, dynamic>>[];
    if (rawParticipants is List) {
      for (final p in rawParticipants) {
        if (p is Map) {
          participants.add(Map<String, dynamic>.from(p));
        }
      }
    }

    final rawAttachments = json['attachments'];
    final attachments = rawAttachments is List
        ? rawAttachments.map((e) => e.toString()).toList()
        : <String>[];

    final rawActions = json['actionItems'];
    final actionItems = rawActions is List
        ? rawActions.map((e) => e.toString()).toList()
        : <String>[];

    return MeetingModel(
      id: json['id'] as String,
      companyId: json['companyId'] as String? ?? '',
      title: json['title'] as String,
      organizerId:
          json['organizerId'] as String? ??
          json['createdByUserId'] as String? ??
          '',
      organizerName: json['organizerName'] as String? ?? 'Organizer',
      organizerRole: json['organizerRole'] as String? ?? '',
      bossId: json['bossId'] as String?,
      bossName: json['bossName'] as String?,
      companyName: json['companyName'] as String? ?? '',
      agenda: json['agenda'] as String? ?? '',
      description: json['description'] as String? ?? '',
      priority: json['priority'] as String? ?? 'medium',
      status: json['status'] as String? ?? 'scheduled',
      type: json['type'] as String? ?? 'internal',
      participants: participants,
      startAtIso: startIso,
      endAtIso: endIso,
      meetLink: json['meetLink'] as String?,
      location: json['location'] as String?,
      reminderMinutes: json['reminderMinutes'] as int? ?? 15,
      attachments: attachments,
      notes: json['notes'] as String? ?? '',
      actionItems: actionItems,
      teamLeadId: json['teamLeadId'] as String?,
      isTeamMeeting: json['isTeamMeeting'] as bool? ?? false,
      createdAtIso: json['createdAt'] as String? ?? startIso,
      updatedAtIso: json['updatedAt'] as String? ?? startIso,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'companyId': companyId,
    'title': title,
    'organizerId': organizerId,
    'organizerName': organizerName,
    'organizerRole': organizerRole,
    'bossId': bossId,
    'bossName': bossName,
    'companyName': companyName,
    'agenda': agenda,
    'description': description,
    'priority': priority,
    'status': status,
    'type': type,
    'participants': participants,
    'startAt': startAtIso,
    'endAt': endAtIso,
    'meetLink': meetLink,
    'location': location,
    'reminderMinutes': reminderMinutes,
    'attachments': attachments,
    'notes': notes,
    'actionItems': actionItems,
    'teamLeadId': teamLeadId,
    'isTeamMeeting': isTeamMeeting,
    'createdAt': createdAtIso,
    'updatedAt': updatedAtIso,
    // Legacy keys for older readers
    'scheduledAt': startAtIso,
    'createdByUserId': organizerId,
  };

  factory MeetingModel.fromEntity(Meeting e) {
    return MeetingModel(
      id: e.id,
      companyId: e.companyId,
      title: e.title,
      organizerId: e.organizerId,
      organizerName: e.organizerName,
      organizerRole: e.organizerRoleOrEmpty,
      bossId: e.bossId,
      bossName: e.bossName,
      companyName: e.companyNameOrEmpty,
      agenda: e.agenda,
      description: e.description,
      priority: e.priority.name,
      status: e.status.name,
      type: e.type.name,
      participants: e.participants.map((p) => p.toJson()).toList(),
      startAtIso: e.startAt.toIso8601String(),
      endAtIso: e.endAt.toIso8601String(),
      meetLink: e.meetLink,
      location: e.location,
      reminderMinutes: e.reminderMinutes,
      attachments: e.attachments,
      notes: e.notes,
      actionItems: e.actionItems,
      teamLeadId: e.teamLeadId,
      isTeamMeeting: e.isTeamMeeting,
      createdAtIso: e.createdAt.toIso8601String(),
      updatedAtIso: e.updatedAt.toIso8601String(),
    );
  }

  Meeting toEntity() {
    return Meeting(
      id: id,
      companyId: companyId,
      title: title,
      organizerId: organizerId,
      organizerName: organizerName,
      organizerRole: organizerRole,
      bossId: bossId,
      bossName: bossName,
      companyName: companyName,
      agenda: agenda,
      description: description,
      priority: MeetingPriorityX.fromStorage(priority),
      status: MeetingStatusX.fromStorage(status),
      type: MeetingTypeX.fromStorage(type),
      participants: participants
          .map(MeetingParticipant.fromJson)
          .toList(growable: false),
      startAt: DateTime.parse(startAtIso),
      endAt: DateTime.parse(endAtIso),
      meetLink: meetLink,
      location: location,
      reminderMinutes: reminderMinutes,
      attachments: attachments,
      notes: notes,
      actionItems: actionItems,
      teamLeadId: teamLeadId,
      isTeamMeeting: isTeamMeeting,
      createdAt: DateTime.parse(createdAtIso),
      updatedAt: DateTime.parse(updatedAtIso),
    );
  }
}
