import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/result.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/rbac/permission_set.dart';
import '../../../../core/rbac/rbac_providers.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/meeting_link_launcher.dart';
import '../../../../core/utils/meeting_pickers.dart';
import '../../../../shared/widgets/layout/app_scaffold.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/meeting.dart';
import '../providers/meeting_providers.dart';
import '../widgets/meeting_ui.dart';

class MeetingDetailsPage extends ConsumerStatefulWidget {
  const MeetingDetailsPage({super.key, required this.meetingId});

  final String meetingId;

  @override
  ConsumerState<MeetingDetailsPage> createState() => _MeetingDetailsPageState();
}

class _MeetingDetailsPageState extends ConsumerState<MeetingDetailsPage> {
  Meeting? _meeting;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  ProviderSubscription<void>? _realtimeSub;
  StreamSubscription<Map<String, dynamic>>? _changesSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      // Keep details in sync when Boss updates Confirm for your team.
      _realtimeSub = ref.listenManual(meetingRealtimeSyncProvider, (_, __) {});
      _changesSub = MeetingRealtimeService.instance.changes.listen((event) {
        final id = event['meetingId']?.toString();
        if (id == null || id == widget.meetingId) {
          _load(silent: true);
        }
      });
    });
  }

  @override
  void dispose() {
    _realtimeSub?.close();
    _changesSub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final result = await ref
        .read(meetingRepositoryProvider)
        .getById(widget.meetingId);
    if (!mounted) return;
    switch (result) {
      case Success(:final data):
        setState(() {
          _meeting = data;
          _loading = false;
          _error = null;
        });
      case Error(:final failure):
        if (!silent) {
          setState(() {
            _error = failure.message;
            _loading = false;
          });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionSetProvider);
    final userId = ref.watch(currentUserIdProvider);
    final meeting = _meeting;
    final scheme = context.colorScheme;

    if (_loading) {
      return AppScaffold(
        appBar: AppBar(title: const Text('Meeting')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || meeting == null) {
      return AppScaffold(
        appBar: AppBar(title: const Text('Meeting')),
        body: MeetingEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Meeting not found',
          message: _error ?? 'This meeting may have been deleted.',
        ),
      );
    }

    final access = MeetingAccessContext(
      createdByUserId: meeting.createdByUserId,
      participantIds: meeting.participants.map((p) => p.userId).toSet(),
    );
    final canView =
        userId != null &&
        permissions.canViewMeeting(currentUserId: userId, meeting: access);
    if (!canView) {
      return AppScaffold(
        appBar: AppBar(title: const Text('Meeting')),
        body: const MeetingEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'No access',
          message: 'You do not have permission to view this meeting.',
        ),
      );
    }

    final canEdit = permissions.canEditMeeting(
      currentUserId: userId,
      meeting: access,
    );
    final canDelete = permissions.canDeleteMeeting(
      currentUserId: userId,
      meeting: access,
    );
    // Boss = CEO schedule UI. Coordinator = same layout + approve gate.
    final isBossView = permissions.isBoss;
    final isCoordinatorView = permissions.isMeetingCoordinator;
    final usesScheduleUi = permissions.usesBossScheduleUi;

    final start = meeting.startAt.toLocal();
    final end = meeting.endAt.toLocal();
    final duration = end.difference(start);
    final durationLabel = duration.inHours > 0
        ? '${duration.inHours}h ${duration.inMinutes.remainder(60)}m'
        : '${duration.inMinutes} min';
    final hasLink =
        meeting.meetLink != null && meeting.meetLink!.trim().isNotEmpty;
    final location = meeting.location?.trim() ?? '';
    final agenda = meeting.agenda.trim();
    final notes = meeting.notes.trim();
    final description = meeting.description.trim();
    final detailsText = [
      if (agenda.isNotEmpty) agenda,
      if (description.isNotEmpty) description,
      if (notes.isNotEmpty) notes,
    ].join('\n\n');
    final creatorRole = meeting.organizerRoleOrEmpty.trim().isEmpty
        ? 'Team'
        : meeting.organizerRoleOrEmpty.trim();
    final now = DateTime.now();
    final isPast = end.isBefore(now);
    final isOngoing = !start.isAfter(now) && end.isAfter(now);
    final whenHint = isOngoing
        ? 'Happening now'
        : isPast
            ? 'Already finished'
            : _relativeStart(start);

    return AppScaffold(
      maxContentWidth: 720,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Text(usesScheduleUi ? 'Your meeting' : 'Meeting details'),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'Edit',
              onPressed: () async {
                await context.push(RoutePaths.meetingEditPath(meeting.id));
                _load();
              },
              icon: const Icon(Icons.edit_rounded),
            ),
          if (canDelete)
            IconButton(
              tooltip: 'Delete',
              onPressed: () => _delete(meeting),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          // Title + status
          Text(
            meeting.title,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ).animate().fadeIn().slideY(begin: 0.04, end: 0),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              MeetingTag(
                label: meeting.status.label,
                color: meetingStatusColor(meeting.status),
              ),
              if (meeting.priority == MeetingPriority.high ||
                  meeting.priority == MeetingPriority.critical)
                MeetingTag(
                  label: meeting.priority.label,
                  color: meetingPriorityColor(meeting.priority),
                ),
              MeetingTag(label: whenHint, color: AppColors.info),
              if (meeting.bossMarkedImportant)
                MeetingTag(label: 'Important', color: AppColors.warning),
              if (meeting.coordinatorApproval == CoordinatorApproval.pending)
                MeetingTag(
                  label: 'Awaiting coordinator',
                  color: AppColors.warning,
                ),
              if (meeting.coordinatorApproval == CoordinatorApproval.rejected)
                MeetingTag(label: 'Rejected', color: AppColors.error),
              // Attendance tags for team + coordinator (not Boss — they have their own card).
              if (!isBossView &&
                  meeting.bossResponse == InvitationResponse.accepted)
                MeetingTag(label: 'Boss attending', color: AppColors.success),
              if (!isBossView &&
                  meeting.bossResponse == InvitationResponse.declined)
                MeetingTag(label: 'Boss not attending', color: AppColors.error),
              if (meeting.rescheduleRequested)
                MeetingTag(
                  label: 'Reschedule requested',
                  color: AppColors.warning,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // WHEN — most important for Boss
          _HeroWhenCard(
            weekday: DateFormat('EEEE').format(start),
            dateLine: DateFormat('MMMM d, yyyy').format(start),
            timeLine:
                '${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}',
            durationLabel: durationLabel,
          ).animate().fadeIn(delay: 40.ms),
          const SizedBox(height: AppSpacing.md),

          // WHERE / JOIN
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'How to attend',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (hasLink) ...[
                  FilledButton.icon(
                    onPressed: () => _joinMeeting(meeting.meetLink!),
                    icon: const Icon(Icons.videocam_rounded),
                    label: const Text('Join video call'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () => _copyLink(meeting.meetLink!),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy meeting link'),
                  ),
                ] else
                  _EmptyHint(
                    icon: Icons.videocam_off_outlined,
                    text: 'No video link yet',
                  ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 20,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Location',
                              style: context.textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              location,
                              style: context.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ).animate().fadeIn(delay: 80.ms),
          const SizedBox(height: AppSpacing.md),

          if (isCoordinatorView) ...[
            _CoordinatorActionsCard(
              meeting: meeting,
              busy: _busy,
              readOnly: isPast,
              onApprove: () => _approveForBoss(meeting),
              onReject: () => _rejectMeeting(meeting),
              onRequestReschedule: () => _showRescheduleSheet(meeting),
              onClearReschedule: meeting.rescheduleRequested
                  ? () => _clearReschedule(meeting)
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          if (isBossView) ...[
            _BossActionsCard(
              key: ValueKey(
                'boss-actions-${meeting.bossResponse.name}-'
                '${meeting.rescheduleRequested}-'
                '${meeting.bossMarkedImportant}-'
                '${meeting.bossPersonalNote}',
              ),
              meeting: meeting,
              busy: _busy,
              readOnly: isPast,
              onAttend: () => _setAttendance(
                meeting,
                InvitationResponse.accepted,
              ),
              onDecline: () => _setAttendance(
                meeting,
                InvitationResponse.declined,
              ),
              onRequestReschedule: () => _showRescheduleSheet(meeting),
              onClearReschedule: meeting.rescheduleRequested
                  ? () => _clearReschedule(meeting)
                  : null,
              onToggleImportant: () => _toggleImportant(meeting),
              onEditNote: () => _editBossNote(meeting),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Meeting creator + coordinator must see Boss reply clearly.
          // (Coordinator uses schedule UI layout, so do not gate on usesScheduleUi.)
          if (!isBossView) ...[
            _TeamBossFeedbackCard(
              meeting: meeting,
              canEdit: canEdit,
              onEdit: canEdit
                  ? () async {
                      await context.push(
                        RoutePaths.meetingEditPath(meeting.id),
                      );
                      _load();
                    }
                  : null,
            ).animate().fadeIn(delay: 90.ms),
            const SizedBox(height: AppSpacing.md),
          ],

          // WHAT — agenda / notes combined
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What is this about?',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (detailsText.isNotEmpty)
                  Text(
                    detailsText,
                    style: context.textTheme.bodyLarge?.copyWith(height: 1.5),
                  )
                else
                  Text(
                    'No agenda or notes added.',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: AppSpacing.md),

          // WHO scheduled
          _Card(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
                  child: Text(
                    meeting.organizerName.trim().isNotEmpty
                        ? meeting.organizerName.trim()[0].toUpperCase()
                        : 'T',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usesScheduleUi ? 'Scheduled by your team' : 'Created by',
                        style: context.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meeting.organizerName,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        creatorRole,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 120.ms),

          if (!usesScheduleUi && meeting.participants.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Participants',
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...meeting.participants.map(
                    (p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: scheme.primaryContainer,
                            child: Text(
                              p.name.isNotEmpty
                                  ? p.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              p.name,
                              style: context.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          MeetingTag(
                            label: p.response.label,
                            color: AppColors.info,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (!usesScheduleUi) ...[
            const SizedBox(height: AppSpacing.md),
            _Card(
              child: Column(
                children: [
                  _MetaRow(
                    label: 'Type',
                    value: meeting.type.label,
                  ),
                  _MetaRow(
                    label: 'Priority',
                    value: meeting.priority.label,
                  ),
                  _MetaRow(
                    label: 'Created',
                    value: DateFormat(
                      'MMM d, yyyy · h:mm a',
                    ).format(meeting.createdAt.toLocal()),
                  ),
                ],
              ),
            ),
            if (canEdit || canDelete) ...[
              const SizedBox(height: AppSpacing.lg),
              if (canEdit)
                OutlinedButton.icon(
                  onPressed: () async {
                    await context.push(RoutePaths.meetingEditPath(meeting.id));
                    _load();
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit meeting'),
                ),
              if (canDelete) ...[
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  onPressed: () => _delete(meeting),
                  icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                  label: Text(
                    'Delete meeting',
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  String _relativeStart(DateTime start) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(start.year, start.month, start.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff > 1 && diff < 7) return 'In $diff days';
    return DateFormat('MMM d').format(start);
  }

  Future<void> _copyLink(String link) async {
    final normalized = MeetingLinkLauncher.normalize(link);
    await Clipboard.setData(
      ClipboardData(text: normalized?.toString() ?? link.trim()),
    );
    if (!mounted) return;
    context.showAppSnackBar('Link copied');
  }

  Future<void> _delete(Meeting meeting) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete meeting?'),
        content: Text('Remove “${meeting.title}”? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await ref
        .read(meetingsControllerProvider.notifier)
        .deleteMeeting(meeting);
    if (!mounted) return;
    if (ok) {
      context.showAppSnackBar('Meeting deleted');
      context.pop();
    } else {
      context.showAppSnackBar('Could not delete', isError: true);
    }
  }

  Future<void> _joinMeeting(String link) async {
    final ok = await MeetingLinkLauncher.open(link);
    if (!ok && mounted) {
      context.showAppSnackBar(
        'Could not open meeting link. Check the URL or install a browser.',
        isError: true,
      );
    }
  }

  Future<void> _runBossAction(
    Meeting Function() optimisticMeeting,
    Future<bool> Function() action, {
    required String successMessage,
  }) async {
    if (_busy) return;
    final previous = _meeting;
    // Instant UI confirmation — don't wait for network.
    setState(() {
      _busy = true;
      _meeting = optimisticMeeting();
    });
    final ok = await action();
    if (!mounted) return;
    if (ok) {
      final matches = ref
          .read(meetingsControllerProvider)
          .meetings
          .where((m) => m.id == previous?.id);
      setState(() {
        _busy = false;
        if (matches.isNotEmpty) _meeting = matches.first;
      });
      context.showAppSnackBar(successMessage);
    } else {
      setState(() {
        _busy = false;
        _meeting = previous;
      });
      final err =
          ref.read(meetingsControllerProvider).errorMessage ??
          'Could not update meeting';
      context.showAppSnackBar(err, isError: true);
    }
  }

  Future<void> _approveForBoss(Meeting meeting) async {
    final user = ref.read(authSessionProvider).session?.user;
    if (user == null) return;
    await _runBossAction(
      () => meeting.copyWith(
        coordinatorApproval: CoordinatorApproval.approved,
        approvedById: user.id,
        approvedByName: user.displayName ?? user.email ?? 'Coordinator',
        approvedAt: DateTime.now(),
        rejectionReason: '',
        updatedAt: DateTime.now(),
      ),
      () => ref.read(meetingsControllerProvider.notifier).approveForBoss(
        meeting: meeting,
        approverId: user.id,
        approverName: user.displayName ?? user.email ?? 'Coordinator',
      ),
      successMessage: 'Approved — Boss can now see this meeting',
    );
  }

  Future<void> _rejectMeeting(Meeting meeting) async {
    final user = ref.read(authSessionProvider).session?.user;
    if (user == null) return;
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject meeting?'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || !mounted) return;

    await _runBossAction(
      () => meeting.copyWith(
        coordinatorApproval: CoordinatorApproval.rejected,
        approvedById: user.id,
        approvedByName: user.displayName ?? user.email ?? 'Coordinator',
        clearApprovedAt: true,
        rejectionReason: reason.trim(),
        updatedAt: DateTime.now(),
      ),
      () => ref.read(meetingsControllerProvider.notifier).rejectMeeting(
        meeting: meeting,
        approverId: user.id,
        approverName: user.displayName ?? user.email ?? 'Coordinator',
        reason: reason,
      ),
      successMessage: 'Meeting rejected — Boss will not see it',
    );
  }

  Future<void> _setAttendance(
    Meeting meeting,
    InvitationResponse response,
  ) async {
    final now = DateTime.now();
    await _runBossAction(
      () => meeting.copyWith(
        bossResponse: response,
        bossResponseAt: now,
        updatedAt: now,
      ),
      () => ref.read(meetingsControllerProvider.notifier).respondToInvitation(
        meeting: meeting,
        response: response,
      ),
      successMessage: response == InvitationResponse.accepted
          ? 'Confirmed — you will attend'
          : 'Confirmed — you will not attend',
    );
  }

  Future<void> _toggleImportant(Meeting meeting) async {
    final next = !meeting.bossMarkedImportant;
    await _runBossAction(
      () => meeting.copyWith(
        bossMarkedImportant: next,
        updatedAt: DateTime.now(),
      ),
      () => ref.read(meetingsControllerProvider.notifier).setBossMarkedImportant(
        meeting: meeting,
        important: next,
      ),
      successMessage: next ? 'Marked as important' : 'Important flag removed',
    );
  }

  Future<void> _clearReschedule(Meeting meeting) async {
    await _runBossAction(
      () => meeting.copyWith(
        rescheduleRequested: false,
        rescheduleReason: '',
        clearReschedulePreferred: true,
        clearRescheduleRequestedAt: true,
        updatedAt: DateTime.now(),
      ),
      () => ref
          .read(meetingsControllerProvider.notifier)
          .clearRescheduleRequest(meeting),
      successMessage: 'Reschedule request cancelled',
    );
  }

  Future<void> _editBossNote(Meeting meeting) async {
    final controller = TextEditingController(text: meeting.bossPersonalNote);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Note for your team'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Keep this short — I have a hard stop at 4pm',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved == null || !mounted) return;
    await _runBossAction(
      () => meeting.copyWith(
        bossPersonalNote: saved.trim(),
        updatedAt: DateTime.now(),
      ),
      () => ref.read(meetingsControllerProvider.notifier).saveBossPersonalNote(
        meeting: meeting,
        note: saved,
      ),
      successMessage: 'Note saved for your team',
    );
  }

  Future<void> _showRescheduleSheet(Meeting meeting) async {
    var preferredStart = meeting.reschedulePreferredStartAt?.toLocal() ??
        meeting.startAt.toLocal().add(const Duration(days: 1));
    var preferredEnd = meeting.reschedulePreferredEndAt?.toLocal() ??
        preferredStart.add(meeting.endAt.difference(meeting.startAt));
    final reasonController = TextEditingController(
      text: meeting.rescheduleReason,
    );

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              Future<void> pickDateTime({required bool isStart}) async {
                final initial = isStart ? preferredStart : preferredEnd;
                final date = await MeetingPickers.pickDate(
                  ctx,
                  initialDate: initial,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date == null || !ctx.mounted) return;
                final time = await MeetingPickers.pickTime(
                  ctx,
                  initialTime: TimeOfDay.fromDateTime(initial),
                );
                if (time == null || !ctx.mounted) return;
                final next = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
                setSheet(() {
                  if (isStart) {
                    final duration = preferredEnd.difference(preferredStart);
                    preferredStart = next;
                    preferredEnd = next.add(
                      duration.isNegative
                          ? const Duration(hours: 1)
                          : duration,
                    );
                  } else {
                    preferredEnd = next.isAfter(preferredStart)
                        ? next
                        : preferredStart.add(const Duration(hours: 1));
                  }
                });
              }

              String fmt(DateTime d) =>
                  DateFormat('EEE, MMM d · h:mm a').format(d);

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Request reschedule',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your team will get a preferred new time and reason.',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_available_rounded),
                    title: const Text('Preferred start'),
                    subtitle: Text(fmt(preferredStart)),
                    onTap: () => pickDateTime(isStart: true),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_busy_rounded),
                    title: const Text('Preferred end'),
                    subtitle: Text(fmt(preferredEnd)),
                    onTap: () => pickDateTime(isStart: false),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                      hintText: 'e.g. Conflict with investor call',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Send request to team'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    final reason = reasonController.text;
    reasonController.dispose();
    if (confirmed != true || !mounted) return;

    await _runBossAction(
      () => meeting.copyWith(
        rescheduleRequested: true,
        reschedulePreferredStartAt: preferredStart,
        reschedulePreferredEndAt: preferredEnd,
        rescheduleReason: reason.trim(),
        rescheduleRequestedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      () => ref.read(meetingsControllerProvider.notifier).requestReschedule(
        meeting: meeting,
        preferredStart: preferredStart,
        preferredEnd: preferredEnd,
        reason: reason,
      ),
      successMessage: 'Reschedule request sent to your team',
    );
  }
}

class _HeroWhenCard extends StatelessWidget {
  const _HeroWhenCard({
    required this.weekday,
    required this.dateLine,
    required this.timeLine,
    required this.durationLabel,
  });

  final String weekday;
  final String dateLine;
  final String timeLine;
  final String durationLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.calendar_month_rounded,
            color: AppColors.primary,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'When',
                  style: context.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  weekday,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  dateLine,
                  style: context.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  timeLine,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$durationLabel long',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: child,
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(
            text,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: context.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoordinatorActionsCard extends StatelessWidget {
  const _CoordinatorActionsCard({
    required this.meeting,
    required this.busy,
    required this.readOnly,
    required this.onApprove,
    required this.onReject,
    required this.onRequestReschedule,
    this.onClearReschedule,
  });

  final Meeting meeting;
  final bool busy;
  final bool readOnly;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRequestReschedule;
  final VoidCallback? onClearReschedule;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final pending =
        meeting.coordinatorApproval == CoordinatorApproval.pending;
    final approved =
        meeting.coordinatorApproval == CoordinatorApproval.approved;
    final rejected =
        meeting.coordinatorApproval == CoordinatorApproval.rejected;
    final statusColor = approved
        ? AppColors.success
        : rejected
            ? AppColors.error
            : AppColors.warning;

    return AnimatedContainer(
      duration: 320.ms,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Meeting Coordinator review',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  approved
                      ? 'Approved — visible to Boss'
                      : rejected
                          ? 'Rejected — Boss will not see this'
                          : 'Waiting for your approval',
                  style: context.textTheme.titleSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  approved
                      ? 'Boss can now see and respond to this meeting.'
                      : rejected
                          ? (meeting.rejectionReason.trim().isEmpty
                              ? 'Ask the team to create a new time if needed.'
                              : meeting.rejectionReason.trim())
                          : 'Approve to send this meeting to the Boss schedule. You can also request a reschedule first.',
                  style: context.textTheme.bodySmall?.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
          if (!readOnly && pending) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: busy ? null : onApprove,
              icon: const Icon(Icons.verified_rounded),
              label: const Text('Approve for Boss'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : onReject,
              icon: const Icon(Icons.block_rounded),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
          if (!readOnly && rejected) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : onApprove,
              icon: const Icon(Icons.verified_rounded),
              label: const Text('Approve anyway for Boss'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
              ),
            ),
          ],
          if (!readOnly) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'Need a different time?',
              style: context.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Request a reschedule — same as Boss. Team will update the slot.',
              style: context.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : onRequestReschedule,
              icon: const Icon(Icons.event_repeat_rounded),
              label: Text(
                meeting.rescheduleRequested
                    ? 'Update reschedule request'
                    : 'Request reschedule',
              ),
            ),
            if (onClearReschedule != null)
              TextButton(
                onPressed: busy ? null : onClearReschedule,
                child: const Text('Cancel reschedule request'),
              ),
          ],
          if (meeting.rescheduleRequested) ...[
            const SizedBox(height: 12),
            Text(
              [
                'Reschedule requested',
                if (meeting.reschedulePreferredStartAt != null)
                  'Preferred: ${DateFormat('EEE, MMM d · h:mm a').format(meeting.reschedulePreferredStartAt!.toLocal())}',
                if (meeting.rescheduleReason.trim().isNotEmpty)
                  meeting.rescheduleReason.trim(),
              ].join('\n'),
              style: context.textTheme.bodySmall?.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BossActionsCard extends StatefulWidget {
  const _BossActionsCard({
    super.key,
    required this.meeting,
    required this.busy,
    required this.readOnly,
    required this.onAttend,
    required this.onDecline,
    required this.onRequestReschedule,
    required this.onToggleImportant,
    required this.onEditNote,
    this.onClearReschedule,
  });

  final Meeting meeting;
  final bool busy;
  final bool readOnly;
  final VoidCallback onAttend;
  final VoidCallback onDecline;
  final VoidCallback onRequestReschedule;
  final VoidCallback? onClearReschedule;
  final VoidCallback onToggleImportant;
  final VoidCallback onEditNote;

  @override
  State<_BossActionsCard> createState() => _BossActionsCardState();
}

class _BossActionsCardState extends State<_BossActionsCard> {
  bool _changeResponse = false;

  @override
  void didUpdateWidget(covariant _BossActionsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meeting.bossResponse != widget.meeting.bossResponse) {
      _changeResponse = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final meeting = widget.meeting;
    final scheme = context.colorScheme;
    final attending = meeting.bossResponse == InvitationResponse.accepted;
    final declining = meeting.bossResponse == InvitationResponse.declined;
    final pending = meeting.bossResponse == InvitationResponse.pending;
    final showChoices =
        !widget.readOnly && (pending || _changeResponse);

    final statusColor = attending
        ? AppColors.success
        : declining
            ? AppColors.error
            : AppColors.warning;

    return AnimatedContainer(
      duration: 320.ms,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: attending
            ? AppColors.success.withValues(alpha: 0.08)
            : declining
                ? AppColors.error.withValues(alpha: 0.08)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Confirm for your team',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: 380.ms,
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
                  child: child,
                ),
              );
            },
            child: _ConfirmedBanner(
              key: ValueKey(meeting.bossResponse.name),
              attending: attending,
              declining: declining,
              pending: pending,
              statusColor: statusColor,
            ),
          ),
          AnimatedSize(
            duration: 280.ms,
            curve: Curves.easeOutCubic,
            child: showChoices
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 14),
                      Text(
                        pending
                            ? 'Will you join this meeting?'
                            : 'Change your reply',
                        style: context.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: widget.busy ? null : widget.onAttend,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Yes, I will attend'),
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: widget.busy ? null : widget.onDecline,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('No, I cannot attend'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      if (_changeResponse) ...[
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: widget.busy
                              ? null
                              : () => setState(() => _changeResponse = false),
                          child: const Text('Keep current reply'),
                        ),
                      ],
                    ],
                  )
                : (!widget.readOnly && !pending
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: TextButton.icon(
                          onPressed: widget.busy
                              ? null
                              : () => setState(() => _changeResponse = true),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Change my reply'),
                        ),
                      )
                    : const SizedBox.shrink()),
          ),
          if (!widget.readOnly) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'Need a different time?',
              style: context.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ask your team to move this meeting.',
              style: context.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: widget.busy ? null : widget.onRequestReschedule,
              icon: const Icon(Icons.event_repeat_rounded),
              label: Text(
                meeting.rescheduleRequested
                    ? 'Update reschedule request'
                    : 'Request reschedule',
              ),
            ),
            if (widget.onClearReschedule != null) ...[
              TextButton(
                onPressed: widget.busy ? null : widget.onClearReschedule,
                child: const Text('Cancel reschedule request'),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Extra for your team (optional)',
              style: context.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.busy ? null : widget.onToggleImportant,
                    icon: Icon(
                      meeting.bossMarkedImportant
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                    ),
                    label: Text(
                      meeting.bossMarkedImportant
                          ? 'Important'
                          : 'Mark important',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.busy ? null : widget.onEditNote,
                    icon: const Icon(Icons.sticky_note_2_outlined),
                    label: Text(
                      meeting.bossPersonalNote.trim().isEmpty
                          ? 'Add note'
                          : 'Edit note',
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (meeting.bossPersonalNote.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Your note',
              style: context.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              meeting.bossPersonalNote.trim(),
              style: context.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
          if (meeting.rescheduleRequested) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reschedule request sent',
                    style: context.textTheme.labelLarge?.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (meeting.reschedulePreferredStartAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Preferred: ${DateFormat('EEE, MMM d · h:mm a').format(meeting.reschedulePreferredStartAt!.toLocal())}'
                      '${meeting.reschedulePreferredEndAt != null ? ' – ${DateFormat('h:mm a').format(meeting.reschedulePreferredEndAt!.toLocal())}' : ''}',
                      style: context.textTheme.bodySmall,
                    ),
                  ],
                  if (meeting.rescheduleReason.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      meeting.rescheduleReason.trim(),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConfirmedBanner extends StatelessWidget {
  const _ConfirmedBanner({
    super.key,
    required this.attending,
    required this.declining,
    required this.pending,
    required this.statusColor,
  });

  final bool attending;
  final bool declining;
  final bool pending;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final icon = attending
        ? Icons.check_circle_rounded
        : declining
            ? Icons.cancel_rounded
            : Icons.mark_email_unread_outlined;
    final title = attending
        ? 'Confirmed — you will attend'
        : declining
            ? 'Confirmed — you will not attend'
            : 'Waiting for your reply';
    final subtitle = attending
        ? 'Your team can already see this confirmation.'
        : declining
            ? 'Your team can see you declined this meeting.'
            : 'Choose Yes or No below. Your scheduler will see it.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: statusColor, size: 36)
              .animate(target: attending || declining ? 1 : 0)
              .scale(
                begin: const Offset(0.6, 0.6),
                end: const Offset(1, 1),
                duration: 420.ms,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textTheme.titleSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamBossFeedbackCard extends StatelessWidget {
  const _TeamBossFeedbackCard({
    required this.meeting,
    this.canEdit = false,
    this.onEdit,
  });

  final Meeting meeting;
  final bool canEdit;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final attending = meeting.bossResponse == InvitationResponse.accepted;
    final declining = meeting.bossResponse == InvitationResponse.declined;
    final pending = meeting.bossResponse == InvitationResponse.pending;
    final needsAction = meeting.rescheduleRequested || declining;

    final accent = meeting.rescheduleRequested
        ? AppColors.warning
        : declining
            ? AppColors.error
            : attending
                ? AppColors.success
                : AppColors.info;

    final attendanceLabel = switch (meeting.bossResponse) {
      InvitationResponse.accepted => 'Boss confirmed: WILL ATTEND',
      InvitationResponse.declined => 'Boss confirmed: WILL NOT ATTEND',
      InvitationResponse.pending => 'Boss has not replied yet',
    };
    final attendanceHint = switch (meeting.bossResponse) {
      InvitationResponse.accepted =>
        'Boss is coming. Keep the meeting as scheduled unless something changes.',
      InvitationResponse.declined =>
        'Boss cannot join. Cancel this meeting or pick a new time.',
      InvitationResponse.pending =>
        'Waiting for Boss to confirm attendance on their app.',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.campaign_rounded, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Boss response',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (needsAction)
                MeetingTag(label: 'Action needed', color: accent),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Updates from Boss for the meeting you scheduled.',
            style: context.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          _FeedbackRow(
            icon: meeting.coordinatorApproval == CoordinatorApproval.approved
                ? Icons.verified_rounded
                : meeting.coordinatorApproval == CoordinatorApproval.rejected
                    ? Icons.block_rounded
                    : Icons.hourglass_top_rounded,
            color: meeting.coordinatorApproval == CoordinatorApproval.approved
                ? AppColors.success
                : meeting.coordinatorApproval == CoordinatorApproval.rejected
                    ? AppColors.error
                    : AppColors.warning,
            title: switch (meeting.coordinatorApproval) {
              CoordinatorApproval.approved => 'Coordinator approved for Boss',
              CoordinatorApproval.rejected => 'Coordinator rejected',
              CoordinatorApproval.pending =>
                'Waiting for Meeting Coordinator approval',
            },
            subtitle: switch (meeting.coordinatorApproval) {
              CoordinatorApproval.approved =>
                'Boss can see this meeting on their schedule.',
              CoordinatorApproval.rejected => meeting.rejectionReason.trim().isEmpty
                  ? 'This meeting was not sent to Boss.'
                  : meeting.rejectionReason.trim(),
              CoordinatorApproval.pending =>
                'Boss will not see this until the Meeting Coordinator approves.',
            },
          ),
          const SizedBox(height: 12),
          _FeedbackRow(
            icon: attending
                ? Icons.check_circle_rounded
                : declining
                    ? Icons.cancel_rounded
                    : Icons.hourglass_top_rounded,
            color: attending
                ? AppColors.success
                : declining
                    ? AppColors.error
                    : AppColors.warning,
            title: attendanceLabel,
            subtitle: attendanceHint,
          ),
          if (meeting.rescheduleRequested) ...[
            const SizedBox(height: 12),
            _FeedbackRow(
              icon: Icons.event_repeat_rounded,
              color: AppColors.warning,
              title: 'Boss requested a reschedule',
              subtitle: [
                if (meeting.reschedulePreferredStartAt != null)
                  'Preferred time: ${DateFormat('EEE, MMM d · h:mm a').format(meeting.reschedulePreferredStartAt!.toLocal())}'
                  '${meeting.reschedulePreferredEndAt != null ? ' – ${DateFormat('h:mm a').format(meeting.reschedulePreferredEndAt!.toLocal())}' : ''}',
                if (meeting.rescheduleReason.trim().isNotEmpty)
                  'Reason: ${meeting.rescheduleReason.trim()}',
                if (meeting.reschedulePreferredStartAt == null &&
                    meeting.rescheduleReason.trim().isEmpty)
                  'Open Edit meeting and set a new date & time.',
              ].where((e) => e.isNotEmpty).join('\n'),
            ),
          ],
          if (meeting.bossMarkedImportant) ...[
            const SizedBox(height: 12),
            _FeedbackRow(
              icon: Icons.star_rounded,
              color: AppColors.warning,
              title: 'Boss marked this important',
              subtitle: 'Treat this meeting as high priority.',
            ),
          ],
          if (meeting.bossPersonalNote.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _FeedbackRow(
              icon: Icons.sticky_note_2_outlined,
              color: AppColors.info,
              title: 'Note from Boss',
              subtitle: meeting.bossPersonalNote.trim(),
            ),
          ],
          if (pending &&
              !meeting.rescheduleRequested &&
              !meeting.bossMarkedImportant &&
              meeting.bossPersonalNote.trim().isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'No extra instructions yet. You will see attendance, reschedule requests, and notes here when Boss replies.',
              style: context.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
          if (canEdit && onEdit != null && needsAction) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_calendar_rounded),
              label: Text(
                meeting.rescheduleRequested
                    ? 'Edit meeting time'
                    : 'Edit / cancel meeting',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackRow extends StatelessWidget {
  const _FeedbackRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
