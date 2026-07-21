/// Meeting lifecycle status.
enum MeetingStatus {
  scheduled,
  ongoing,
  completed,
  cancelled,
  rescheduled,
  missed,
}

extension MeetingStatusX on MeetingStatus {
  String get label => switch (this) {
    MeetingStatus.scheduled => 'Scheduled',
    MeetingStatus.ongoing => 'Ongoing',
    MeetingStatus.completed => 'Completed',
    MeetingStatus.cancelled => 'Cancelled',
    MeetingStatus.rescheduled => 'Rescheduled',
    MeetingStatus.missed => 'Missed',
  };

  static MeetingStatus fromStorage(String? value) {
    return MeetingStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MeetingStatus.scheduled,
    );
  }
}

/// Meeting urgency.
enum MeetingPriority { low, medium, high, critical }

extension MeetingPriorityX on MeetingPriority {
  String get label => switch (this) {
    MeetingPriority.low => 'Low',
    MeetingPriority.medium => 'Medium',
    MeetingPriority.high => 'High',
    MeetingPriority.critical => 'Critical',
  };

  static MeetingPriority fromStorage(String? value) {
    return MeetingPriority.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MeetingPriority.medium,
    );
  }
}

/// Meeting classification.
enum MeetingType {
  client,
  internal,
  sales,
  interview,
  training,
  boardMeeting,
  reviewMeeting,
  investorMeeting,
  hrDiscussion,
  projectDiscussion,
}

extension MeetingTypeX on MeetingType {
  String get label => switch (this) {
    MeetingType.client => 'Client',
    MeetingType.internal => 'Internal',
    MeetingType.sales => 'Sales',
    MeetingType.interview => 'Interview',
    MeetingType.training => 'Training',
    MeetingType.boardMeeting => 'Board Meeting',
    MeetingType.reviewMeeting => 'Review Meeting',
    MeetingType.investorMeeting => 'Investor Meeting',
    MeetingType.hrDiscussion => 'HR Discussion',
    MeetingType.projectDiscussion => 'Project Discussion',
  };

  static MeetingType fromStorage(String? value) {
    return MeetingType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MeetingType.internal,
    );
  }
}

enum InvitationResponse { pending, accepted, declined }

extension InvitationResponseX on InvitationResponse {
  String get label => switch (this) {
    InvitationResponse.pending => 'Pending',
    InvitationResponse.accepted => 'Accepted',
    InvitationResponse.declined => 'Declined',
  };

  static InvitationResponse fromStorage(String? value) {
    return InvitationResponse.values.firstWhere(
      (e) => e.name == value,
      orElse: () => InvitationResponse.pending,
    );
  }
}

/// Meeting Coordinator gate before Boss can see the meeting.
enum CoordinatorApproval { pending, approved, rejected }

extension CoordinatorApprovalX on CoordinatorApproval {
  String get label => switch (this) {
    CoordinatorApproval.pending => 'Pending approval',
    CoordinatorApproval.approved => 'Approved for Boss',
    CoordinatorApproval.rejected => 'Rejected',
  };

  static CoordinatorApproval fromStorage(String? value) {
    return CoordinatorApproval.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CoordinatorApproval.approved,
    );
  }
}
