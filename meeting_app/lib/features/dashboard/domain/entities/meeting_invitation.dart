import 'package:equatable/equatable.dart';

enum InvitationStatus { pending, accepted, declined }

/// Pending calendar invitation for EA workflow.
class MeetingInvitation extends Equatable {
  const MeetingInvitation({
    required this.id,
    required this.companyId,
    required this.title,
    required this.fromName,
    required this.scheduledAt,
    required this.status,
    this.location,
  });

  final String id;
  final String companyId;
  final String title;
  final String fromName;
  final DateTime scheduledAt;
  final InvitationStatus status;
  final String? location;

  bool get isPending => status == InvitationStatus.pending;

  @override
  List<Object?> get props => [
    id,
    companyId,
    title,
    fromName,
    scheduledAt,
    status,
    location,
  ];
}
