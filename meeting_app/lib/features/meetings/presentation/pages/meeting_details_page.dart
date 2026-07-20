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
import '../../../../shared/widgets/layout/app_scaffold.dart';
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
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref
        .read(meetingRepositoryProvider)
        .getById(widget.meetingId);
    if (!mounted) return;
    switch (result) {
      case Success(:final data):
        setState(() {
          _meeting = data;
          _loading = false;
        });
      case Error(:final failure):
        setState(() {
          _error = failure.message;
          _loading = false;
        });
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
    // Boss = view-only (cannot create meetings).
    final isBossView = !permissions.canCreateMeeting;

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
        title: Text(isBossView ? 'Your meeting' : 'Meeting details'),
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
                        isBossView ? 'Scheduled by your team' : 'Created by',
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

          if (!isBossView && meeting.participants.isNotEmpty) ...[
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

          if (!isBossView) ...[
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
