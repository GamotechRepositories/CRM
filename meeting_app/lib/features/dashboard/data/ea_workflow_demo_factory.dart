import '../domain/entities/meeting_invitation.dart';
import '../domain/entities/meeting_request.dart';
import '../presentation/states/ea_dashboard_state.dart';

/// Demo EA workflow data scoped to a single company.
abstract final class EaWorkflowDemoFactory {
  static List<MeetingInvitation> invitations({
    required String companyId,
    required DateTime now,
  }) {
    DateTime at(int day, int hour, [int minute = 0]) => DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: day, hours: hour, minutes: minute));

    return [
      MeetingInvitation(
        id: 'inv_${companyId}_1',
        companyId: companyId,
        title: 'Vendor Kickoff Call',
        fromName: 'Priya Shah',
        scheduledAt: at(1, 11),
        status: InvitationStatus.pending,
        location: 'Virtual',
      ),
      MeetingInvitation(
        id: 'inv_${companyId}_2',
        companyId: companyId,
        title: 'Legal Review Session',
        fromName: 'External Counsel',
        scheduledAt: at(2, 15, 30),
        status: InvitationStatus.pending,
        location: 'Conference B',
      ),
      MeetingInvitation(
        id: 'inv_${companyId}_3',
        companyId: companyId,
        title: 'Partner Breakfast',
        fromName: 'Alliance Desk',
        scheduledAt: at(0, 8),
        status: InvitationStatus.accepted,
        location: 'Lobby Café',
      ),
    ];
  }

  static List<MeetingRequest> requests({
    required String companyId,
    required DateTime now,
  }) {
    DateTime at(int day, int hour) => DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: day, hours: hour));

    return [
      MeetingRequest(
        id: 'req_${companyId}_1',
        companyId: companyId,
        title: '1:1 with Engineering Head',
        requesterName: 'Ops Manager',
        preferredAt: at(1, 10),
        status: MeetingRequestStatus.pending,
        createdAt: now.subtract(const Duration(hours: 3)),
        notes: 'Needs 45 minutes and whiteboard room.',
      ),
      MeetingRequest(
        id: 'req_${companyId}_2',
        companyId: companyId,
        title: 'Budget Sync — Marketing',
        requesterName: 'Finance Lead',
        preferredAt: at(3, 14),
        status: MeetingRequestStatus.pending,
        createdAt: now.subtract(const Duration(hours: 8)),
        notes: 'Prefer afternoon slot this week.',
      ),
      MeetingRequest(
        id: 'req_${companyId}_3',
        companyId: companyId,
        title: 'Office Relocation Brief',
        requesterName: 'Facilities',
        preferredAt: at(5, 12),
        status: MeetingRequestStatus.approved,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  static List<ActivityItem> activity({
    required String companyId,
    required DateTime now,
  }) {
    return [
      ActivityItem(
        id: 'act_1',
        title: 'Meeting confirmed',
        subtitle: 'Board Strategy Sync locked for today 10:00',
        at: now.subtract(const Duration(minutes: 25)),
        icon: 'check',
      ),
      ActivityItem(
        id: 'act_2',
        title: 'Invitation received',
        subtitle: 'Vendor Kickoff Call from Priya Shah',
        at: now.subtract(const Duration(hours: 2)),
        icon: 'mail',
      ),
      ActivityItem(
        id: 'act_3',
        title: 'Request submitted',
        subtitle: 'Ops Manager asked for Engineering 1:1',
        at: now.subtract(const Duration(hours: 3)),
        icon: 'request',
      ),
      ActivityItem(
        id: 'act_4',
        title: 'Room updated',
        subtitle: 'Architecture Council moved to Lab 2',
        at: now.subtract(const Duration(hours: 5)),
        icon: 'place',
      ),
    ];
  }
}
