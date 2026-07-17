import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/result.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/app_scaffold.dart';
import '../../../../shared/widgets/loading/loading_overlay.dart';
import '../../../../shared/widgets/loading/lottie_loading.dart';
import '../../../auth/presentation/widgets/mobile_number_field.dart';
import '../../domain/entities/employee.dart';
import '../providers/employee_providers.dart';
import '../states/employee_form_state.dart';
import '../widgets/employee_widgets.dart';

class EmployeeFormPage extends ConsumerStatefulWidget {
  const EmployeeFormPage({super.key, required this.companyId, this.employeeId});

  final String companyId;
  final String? employeeId;

  @override
  ConsumerState<EmployeeFormPage> createState() => _EmployeeFormPageState();
}

class _EmployeeFormPageState extends ConsumerState<EmployeeFormPage> {
  bool _loading = true;
  String? _loadError;
  EmployeeFormArgs? _args;

  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _emailController;

  bool get _isEdit => widget.employeeId != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _mobileController = TextEditingController();
    _emailController = TextEditingController();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(employeeRepositoryProvider);
    final peersResult = await repo.getByCompany(widget.companyId);
    final peers = switch (peersResult) {
      Success(:final data) => data,
      Error() => <Employee>[],
    };

    if (_isEdit) {
      final result = await repo.getById(widget.employeeId!);
      if (!mounted) return;
      switch (result) {
        case Error(:final failure):
          setState(() {
            _loadError = failure.message;
            _loading = false;
          });
          return;
        case Success(:final data):
          _nameController.text = data.name;
          _mobileController.text = data.mobile;
          _emailController.text = data.email;
          setState(() {
            _args = EmployeeFormArgs(
              companyId: widget.companyId,
              existing: data,
              managerOptions: peers,
            );
            _loading = false;
          });
      }
    } else {
      if (!mounted) return;
      setState(() {
        _args = EmployeeFormArgs(
          companyId: widget.companyId,
          managerOptions: peers,
        );
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final args = _args;
    if (args == null) return;
    FocusScope.of(context).unfocus();

    final employee = await ref
        .read(employeeFormControllerProvider(args).notifier)
        .submit();
    if (!mounted) return;

    if (employee == null) {
      final err = ref.read(employeeFormControllerProvider(args)).errorMessage;
      context.showAppSnackBar(err ?? 'Unable to save', isError: true);
      return;
    }

    ref.invalidate(employeesControllerProvider(widget.companyId));
    context.showAppSnackBar(_isEdit ? 'Employee updated' : 'Employee added');
    if (_isEdit) {
      context.pop();
    } else {
      context.go(RoutePaths.employeeDetailsPath(widget.companyId, employee.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(body: LottieLoading(message: 'Loading…'));
    }
    if (_loadError != null || _args == null) {
      return AppScaffold(
        appBar: AppBar(title: const Text('Employee')),
        body: Center(child: Text(_loadError ?? 'Something went wrong')),
      );
    }

    final args = _args!;
    final state = ref.watch(employeeFormControllerProvider(args));
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AppScaffold(
      maxContentWidth: 720,
      appBar: AppBar(title: Text(_isEdit ? 'Edit Employee' : 'Add Employee')),
      body: LoadingOverlay(
        isLoading: state.isLoading,
        message: 'Saving…',
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xxl + bottomInset,
          ),
          children: [
            _Preview(
              state: state,
            ).animate().fadeIn().scale(begin: const Offset(0.96, 0.96)),
            const SizedBox(height: AppSpacing.lg),
            EmployeeAvatarPicker(
              selectedIcon: state.avatarIcon,
              selectedColor: state.avatarColorValue,
              onIconSelected: (v) => ref
                  .read(employeeFormControllerProvider(args).notifier)
                  .updateAvatarIcon(v),
              onColorSelected: (v) => ref
                  .read(employeeFormControllerProvider(args).notifier)
                  .updateAvatarColor(v),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _nameController,
              label: 'Full Name *',
              prefixIcon: Icons.person_outline,
              onChanged: (v) => ref
                  .read(employeeFormControllerProvider(args).notifier)
                  .updateName(v),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _mobileController,
              label: 'Mobile *',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              onChanged: (v) => ref
                  .read(employeeFormControllerProvider(args).notifier)
                  .updateMobile(v),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _emailController,
              label: 'Email *',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              onChanged: (v) => ref
                  .read(employeeFormControllerProvider(args).notifier)
                  .updateEmail(v),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: state.department,
              decoration: const InputDecoration(
                labelText: 'Department *',
                prefixIcon: Icon(Icons.apartment_outlined),
              ),
              items: EmployeeDepartments.all
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  ref
                      .read(employeeFormControllerProvider(args).notifier)
                      .updateDepartment(v);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: state.designation,
              decoration: const InputDecoration(
                labelText: 'Designation *',
                prefixIcon: Icon(Icons.work_outline),
              ),
              items: EmployeeDesignations.all
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  ref
                      .read(employeeFormControllerProvider(args).notifier)
                      .updateDesignation(v);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<EmployeeRole>(
              initialValue: state.role,
              decoration: const InputDecoration(
                labelText: 'Role *',
                prefixIcon: Icon(Icons.shield_outlined),
              ),
              items: EmployeeRole.values
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  ref
                      .read(employeeFormControllerProvider(args).notifier)
                      .updateRole(v);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              initialValue: state.reportingManagerId,
              decoration: const InputDecoration(
                labelText: 'Reporting Manager',
                prefixIcon: Icon(Icons.supervisor_account_outlined),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('None'),
                ),
                ...state.managerOptions.map(
                  (e) => DropdownMenuItem<String?>(
                    value: e.id,
                    child: Text('${e.name} (${e.role.label})'),
                  ),
                ),
              ],
              onChanged: (v) => ref
                  .read(employeeFormControllerProvider(args).notifier)
                  .updateManager(v),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Status', style: context.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<EmployeeStatus>(
              segments: const [
                ButtonSegment(
                  value: EmployeeStatus.active,
                  label: Text('Active'),
                  icon: Icon(Icons.check_circle_outline),
                ),
                ButtonSegment(
                  value: EmployeeStatus.inactive,
                  label: Text('Inactive'),
                  icon: Icon(Icons.pause_circle_outline),
                ),
              ],
              selected: {state.employeeStatus},
              onSelectionChanged: (s) => ref
                  .read(employeeFormControllerProvider(args).notifier)
                  .updateStatus(s.first),
            ),
            const SizedBox(height: AppSpacing.xl),
            AuthPrimaryButton(
              label: _isEdit ? 'Save Changes' : 'Add Employee',
              icon: Icons.save_rounded,
              enabled: state.isValid,
              isLoading: state.isLoading,
              onPressed: _submit,
            ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.08, end: 0),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.state});

  final EmployeeFormState state;

  @override
  Widget build(BuildContext context) {
    final temp = Employee(
      id: 'preview',
      companyId: state.companyId,
      name: state.name.isEmpty ? 'Employee name' : state.name,
      mobile: state.mobile,
      email: state.email,
      department: state.department,
      designation: state.designation,
      role: state.role,
      status: state.employeeStatus,
      avatarColorValue: state.avatarColorValue,
      avatarIcon: state.avatarIcon,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            state.avatarColor.withValues(alpha: 0.2),
            state.avatarColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: state.avatarColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          EmployeeAvatar(employee: temp, size: 64, showInitial: true),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  temp.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${temp.designation} · ${temp.department}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                EmployeeRoleChip(role: temp.role),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
