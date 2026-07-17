import 'package:equatable/equatable.dart';

enum MeetingRequestStatus { pending, approved, rejected }

/// Internal meeting request awaiting EA scheduling.
class MeetingRequest extends Equatable {
  const MeetingRequest({
    required this.id,
    required this.companyId,
    required this.title,
    required this.requesterName,
    required this.preferredAt,
    required this.status,
    required this.createdAt,
    this.notes,
  });

  final String id;
  final String companyId;
  final String title;
  final String requesterName;
  final DateTime preferredAt;
  final MeetingRequestStatus status;
  final DateTime createdAt;
  final String? notes;

  bool get isPending => status == MeetingRequestStatus.pending;

  @override
  List<Object?> get props => [
    id,
    companyId,
    title,
    requesterName,
    preferredAt,
    status,
    createdAt,
    notes,
  ];
}
