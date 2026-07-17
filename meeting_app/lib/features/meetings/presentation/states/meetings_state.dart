import 'package:equatable/equatable.dart';

import '../../domain/entities/meeting.dart';

enum MeetingsStatus { initial, loading, success, error }

class MeetingsState extends Equatable {
  const MeetingsState({
    this.status = MeetingsStatus.initial,
    this.meetings = const [],
    this.errorMessage,
    this.isMutating = false,
  });

  final MeetingsStatus status;
  final List<Meeting> meetings;
  final String? errorMessage;
  final bool isMutating;

  bool get isLoading => status == MeetingsStatus.loading;
  bool get isEmpty => !isLoading && meetings.isEmpty;

  MeetingsState copyWith({
    MeetingsStatus? status,
    List<Meeting>? meetings,
    String? errorMessage,
    bool? isMutating,
    bool clearError = false,
  }) {
    return MeetingsState(
      status: status ?? this.status,
      meetings: meetings ?? this.meetings,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isMutating: isMutating ?? this.isMutating,
    );
  }

  @override
  List<Object?> get props => [status, meetings, errorMessage, isMutating];
}
