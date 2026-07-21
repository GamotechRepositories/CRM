import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/result.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/rbac/rbac_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/app_scaffold.dart';
import '../../../../shared/widgets/loading/loading_overlay.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/meeting.dart';
import '../../domain/meeting_schedule_rules.dart';
import '../providers/meeting_providers.dart';
import '../states/meetings_state.dart';

/// Team member schedules a meeting for the Boss.
class MeetingFormPage extends ConsumerStatefulWidget {
  const MeetingFormPage({super.key, this.meetingId});

  final String? meetingId;

  bool get isEditing => meetingId != null;

  @override
  ConsumerState<MeetingFormPage> createState() => _MeetingFormPageState();
}

class _MeetingFormPageState extends ConsumerState<MeetingFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _agendaController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _meetLinkController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _startAt = DateTime.now().add(const Duration(hours: 1));
  DateTime _endAt = DateTime.now().add(const Duration(hours: 2));
  MeetingPriority _priority = MeetingPriority.medium;
  MeetingType _type = MeetingType.internal;
  Meeting? _existing;
  bool _loading = false;
  bool _saving = false;
  String _bossName = 'Boss';
  String? _scheduleHint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  Future<void> _hydrate() async {
    setState(() => _loading = true);
    try {
      final boss = await ref.read(meetingRemoteDataSourceProvider).getBoss();
      _bossName = boss.name;

      if (widget.isEditing && widget.meetingId != null) {
        final result = await ref
            .read(meetingRepositoryProvider)
            .getById(widget.meetingId!);
        if (result case Success(:final data)) {
          _existing = data;
          _titleController.text = data.title;
          _agendaController.text = data.agenda;
          _descriptionController.text = data.description;
          _locationController.text = data.location ?? '';
          _meetLinkController.text = data.meetLink ?? '';
          _notesController.text = data.notes;
          _startAt = data.startAt;
          _endAt = data.endAt;
          _priority = data.priority;
          _type = data.type;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    await ref.read(meetingsControllerProvider.notifier).load(null);
    if (!mounted) return;
    setState(() => _loading = false);
    _refreshScheduleHint();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _agendaController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _meetLinkController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;

    return AppScaffold(
      maxContentWidth: 640,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit meeting' : 'New meeting'),
      ),
      body: LoadingOverlay(
        isLoading: _loading || _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.lgAll,
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.secondary,
                      child: Text(
                        _bossName.isNotEmpty
                            ? _bossName[0].toUpperCase()
                            : 'B',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'For the Boss',
                            style: context.textTheme.labelLarge?.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _bossName,
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'This meeting is added to the Boss schedule.',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 260.ms).slideY(begin: 0.04, end: 0),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Basics',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ).animate().fadeIn(delay: 40.ms),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _titleController,
                label: 'Meeting title',
                hint: 'e.g. Weekly review with Boss',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ).animate().fadeIn(delay: 70.ms).slideX(begin: 0.02, end: 0),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _agendaController,
                label: 'Agenda',
                hint: 'What will you discuss?',
                maxLines: 3,
              ).animate().fadeIn(delay: 90.ms).slideX(begin: 0.02, end: 0),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _descriptionController,
                label: 'Notes / details (optional)',
                maxLines: 2,
              ).animate().fadeIn(delay: 110.ms).slideX(begin: 0.02, end: 0),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'When',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ).animate().fadeIn(delay: 140.ms),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _DateTimeTile(
                      label: 'Starts',
                      value: DateFormat(
                        'EEE, MMM d\nh:mm a',
                      ).format(_startAt.toLocal()),
                      onTap: () => _pickDateTime(isStart: true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _DateTimeTile(
                      label: 'Ends',
                      value: DateFormat(
                        'EEE, MMM d\nh:mm a',
                      ).format(_endAt.toLocal()),
                      onTap: () => _pickDateTime(isStart: false),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 160.ms).slideY(begin: 0.02, end: 0),
              if (_scheduleHint != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _scheduleHint!,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Past times and overlapping slots are not allowed.',
                style: context.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Details',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ).animate().fadeIn(delay: 190.ms),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<MeetingPriority>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: MeetingPriority.values
                    .map(
                      (p) => DropdownMenuItem(value: p, child: Text(p.label)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _priority = v);
                },
              ).animate().fadeIn(delay: 220.ms).slideX(begin: 0.02, end: 0),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<MeetingType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Meeting type'),
                items: MeetingType.values
                    .map(
                      (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
              ).animate().fadeIn(delay: 240.ms).slideX(begin: 0.02, end: 0),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _locationController,
                label: 'Location (optional)',
                hint: 'Office / room / city',
                prefixIcon: Icons.place_outlined,
              ).animate().fadeIn(delay: 260.ms).slideX(begin: 0.02, end: 0),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _meetLinkController,
                label: 'Video link (optional)',
                hint: 'https://meet.google.com/...',
                prefixIcon: Icons.videocam_outlined,
              ).animate().fadeIn(delay: 280.ms).slideX(begin: 0.02, end: 0),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _notesController,
                label: 'Private notes (optional)',
                maxLines: 2,
              ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.02, end: 0),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: widget.isEditing
                    ? 'Save changes'
                    : 'Create meeting for Boss',
                icon: Icons.check_rounded,
                isExpanded: true,
                onPressed: _save,
              ).animate().fadeIn(delay: 340.ms).scale(
                begin: const Offset(0.98, 0.98),
                end: const Offset(1, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Meeting> get _knownMeetings =>
      ref.read(meetingsControllerProvider).meetings;

  void _refreshScheduleHint() {
    final error = MeetingScheduleRules.validateSlot(
      start: _startAt,
      end: _endAt,
      existing: _knownMeetings,
      excludeMeetingId: _existing?.id,
    );
    setState(() => _scheduleHint = error);
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _startAt : _endAt;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Avoid nested TextScaler.clamp crash inside Material date/time pickers
    // when the app already clamps text scaling.
    final rootContext = Navigator.of(context, rootNavigator: true).context;

    final date = await showDatePicker(
      context: rootContext,
      initialDate: initial.isBefore(today) ? today : initial,
      firstDate: today,
      lastDate: now.add(const Duration(days: 365)),
      helpText: isStart ? 'Select start date' : 'Select end date',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: rootContext,
      initialTime: TimeOfDay.fromDateTime(
        initial.isBefore(now) ? now.add(const Duration(hours: 1)) : initial,
      ),
      helpText: isStart ? 'Select start time' : 'Select end time',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (time == null || !mounted) return;
    var next = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (isStart && MeetingScheduleRules.isInThePast(next, now: now)) {
      context.showAppSnackBar(
        'Cannot pick a past time. Choose a future slot.',
        isError: true,
      );
      return;
    }

    if (!isStart && !next.isAfter(_startAt)) {
      context.showAppSnackBar(
        'End time must be after start time',
        isError: true,
      );
      next = _startAt.add(const Duration(hours: 1));
    }

    setState(() {
      if (isStart) {
        _startAt = next;
        if (!_endAt.isAfter(_startAt)) {
          _endAt = _startAt.add(const Duration(hours: 1));
        }
      } else {
        _endAt = next;
      }
    });
    _refreshScheduleHint();
  }

  Future<void> _ensureMeetingsLoaded() async {
    final state = ref.read(meetingsControllerProvider);
    if (state.status == MeetingsStatus.success && state.meetings.isNotEmpty) {
      return;
    }
    await ref.read(meetingsControllerProvider.notifier).load(null);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    await _ensureMeetingsLoaded();
    if (!mounted) return;

    final scheduleError = MeetingScheduleRules.validateSlot(
      start: _startAt,
      end: _endAt,
      existing: _knownMeetings,
      excludeMeetingId: _existing?.id,
    );
    if (scheduleError != null) {
      setState(() => _scheduleHint = scheduleError);
      context.showAppSnackBar(scheduleError, isError: true);
      return;
    }

    final user = ref.read(authSessionProvider).session?.user;
    if (user == null) return;

    final permissions = ref.read(permissionSetProvider);
    final createdByCoordinator = permissions.isMeetingCoordinator;

    setState(() => _saving = true);
    final now = DateTime.now();
    final meeting = Meeting(
      id: _existing?.id ?? 'new',
      companyId: _existing?.companyId ?? '',
      companyName: _existing?.companyName ?? '',
      title: _titleController.text.trim(),
      organizerId: user.id,
      organizerName: user.displayName ?? 'Team member',
      organizerRole: _existing?.organizerId == user.id
          ? (_existing!.organizerRoleOrEmpty.isNotEmpty
                ? _existing!.organizerRoleOrEmpty
                : (user.roleLabel ?? 'Team'))
          : (user.roleLabel ?? 'Team'),
      agenda: _agendaController.text.trim(),
      description: _descriptionController.text.trim(),
      priority: _priority,
      status: _existing?.status ?? MeetingStatus.scheduled,
      type: _type,
      participants: const [],
      startAt: _startAt,
      endAt: _endAt,
      meetLink: _meetLinkController.text.trim().isEmpty
          ? null
          : _meetLinkController.text.trim(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      notes: _notesController.text.trim(),
      coordinatorApproval: _existing?.coordinatorApproval ??
          (createdByCoordinator
              ? CoordinatorApproval.approved
              : CoordinatorApproval.pending),
      approvedById: _existing?.approvedById ??
          (createdByCoordinator ? user.id : ''),
      approvedByName: _existing?.approvedByName ??
          (createdByCoordinator
              ? (user.displayName ?? user.email ?? 'Meeting Coordinator')
              : ''),
      approvedAt: _existing?.approvedAt ??
          (createdByCoordinator ? now : null),
      createdAt: _existing?.createdAt ?? now,
      updatedAt: now,
    );

    final ok = widget.isEditing
        ? await ref
              .read(meetingsControllerProvider.notifier)
              .updateMeeting(meeting)
        : await ref
              .read(meetingsControllerProvider.notifier)
              .createMeeting(meeting);

    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      context.showAppSnackBar(
        widget.isEditing
            ? 'Meeting updated'
            : createdByCoordinator
                ? 'Meeting created for Boss'
                : 'Meeting created — waiting for Meeting Coordinator approval',
      );
      context.pop();
    } else {
      final err = ref.read(meetingsControllerProvider).errorMessage;
      context.showAppSnackBar(err ?? 'Could not save', isError: true);
    }
  }
}

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: AppRadius.lgAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Icon(Icons.edit_calendar_rounded, size: 18, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
