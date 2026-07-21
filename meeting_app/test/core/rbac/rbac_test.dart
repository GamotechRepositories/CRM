import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_app/core/rbac/app_permission.dart';
import 'package:meeting_app/core/rbac/permission_set.dart';
import 'package:meeting_app/core/rbac/system_role.dart';

void main() {
  group('Simplified RBAC', () {
    test('Boss can view meetings and respond / request reschedule', () {
      final set = PermissionSet.forRole(SystemRole.boss);
      expect(set.can(AppPermission.viewDashboard), isTrue);
      expect(set.can(AppPermission.viewMeetings), isTrue);
      expect(set.can(AppPermission.viewMeetingsNav), isTrue);
      expect(set.canCreateMeeting, isFalse);
      expect(set.can(AppPermission.acceptDeclineInvitation), isTrue);
      expect(set.can(AppPermission.rescheduleMeeting), isTrue);
      expect(set.can(AppPermission.switchCompany), isFalse);
    });

    test('Team member can create meetings for Boss', () {
      final set = PermissionSet.forRole(SystemRole.executiveAssistant);
      expect(set.can(AppPermission.createMeeting), isTrue);
      expect(set.can(AppPermission.editOwnMeeting), isTrue);
      expect(set.can(AppPermission.deleteOwnMeeting), isTrue);
      expect(set.can(AppPermission.editAnyMeeting), isFalse);
      expect(set.can(AppPermission.switchCompany), isFalse);
    });

    test('Meeting Coordinator has Boss-like UI and can approve', () {
      final set = PermissionSet.forRole(SystemRole.meetingCoordinator);
      expect(set.usesBossScheduleUi, isTrue);
      expect(set.isBoss, isFalse);
      expect(set.isMeetingCoordinator, isTrue);
      expect(set.canCreateMeeting, isTrue);
      expect(set.canApproveMeeting, isTrue);
      expect(set.can(AppPermission.rescheduleMeeting), isTrue);
      expect(set.can(AppPermission.acceptDeclineInvitation), isTrue);
    });

    test('Boss can view any meeting; team only own', () {
      final boss = PermissionSet.forRole(SystemRole.boss);
      final team = PermissionSet.forRole(SystemRole.executiveAssistant);

      expect(
        boss.canViewMeeting(
          currentUserId: 'boss-1',
          meeting: const MeetingAccessContext(createdByUserId: 'ea-1'),
        ),
        isTrue,
      );
      expect(
        team.canViewMeeting(
          currentUserId: 'ea-1',
          meeting: const MeetingAccessContext(createdByUserId: 'ea-1'),
        ),
        isTrue,
      );
      expect(
        team.canViewMeeting(
          currentUserId: 'ea-1',
          meeting: const MeetingAccessContext(createdByUserId: 'other'),
        ),
        isFalse,
      );
    });
  });
}
