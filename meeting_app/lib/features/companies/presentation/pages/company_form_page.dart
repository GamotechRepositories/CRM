import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/app_scaffold.dart';
import '../../../../shared/widgets/loading/loading_overlay.dart';
import '../../../../shared/widgets/loading/lottie_loading.dart';
import '../../../organization/presentation/providers/organization_providers.dart';
import '../../domain/entities/company.dart';
import '../providers/company_providers.dart';
import '../states/company_form_state.dart';
import '../widgets/company_form_widgets.dart';
import '../../../auth/presentation/widgets/mobile_number_field.dart';

class CompanyFormPage extends ConsumerStatefulWidget {
  const CompanyFormPage({super.key, this.companyId});

  final String? companyId;

  @override
  ConsumerState<CompanyFormPage> createState() => _CompanyFormPageState();
}

class _CompanyFormPageState extends ConsumerState<CompanyFormPage> {
  bool _loadingExisting = false;
  String? _loadError;
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _websiteController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _employeesController;
  CompanyFormArgs? _args;
  bool _initialized = false;

  bool get _isEdit => widget.companyId != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _websiteController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _employeesController = TextEditingController(text: '1');
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (!_isEdit) {
      setState(() {
        _args = const CompanyFormArgs();
        _initialized = true;
      });
      return;
    }

    setState(() {
      _loadingExisting = true;
      _loadError = null;
    });

    final result = await ref
        .read(companyRepositoryProvider)
        .getCompanyById(widget.companyId!);

    if (!mounted) return;

    switch (result) {
      case Success(:final data):
        _nameController.text = data.name;
        _addressController.text = data.address;
        _websiteController.text = data.website;
        _emailController.text = data.email;
        _phoneController.text = data.phone;
        _employeesController.text = '${data.employeeCount}';
        setState(() {
          _args = CompanyFormArgs(existing: data);
          _loadingExisting = false;
          _initialized = true;
        });
      case Error(:final failure):
        setState(() {
          _loadError = failure.message;
          _loadingExisting = false;
        });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _websiteController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _employeesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final args = _args;
    if (args == null) return;
    FocusScope.of(context).unfocus();

    final company = await ref
        .read(companyFormControllerProvider(args).notifier)
        .submit();
    if (!mounted) return;

    if (company == null) {
      final err = ref.read(companyFormControllerProvider(args)).errorMessage;
      context.showAppSnackBar(err ?? 'Unable to save company', isError: true);
      return;
    }

    ref.invalidate(companiesControllerProvider);
    await ref.read(companyContextProvider.notifier).refresh();
    if (!mounted) return;
    context.showAppSnackBar(_isEdit ? 'Company updated' : 'Company created');
    if (_isEdit) {
      context.pop();
    } else {
      context.go(RoutePaths.companyDetailsPath(company.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingExisting) {
      return const AppScaffold(
        body: LottieLoading(message: 'Loading company…'),
      );
    }

    if (_loadError != null) {
      return AppScaffold(
        appBar: AppBar(title: const Text('Company')),
        body: Center(child: Text(_loadError!)),
      );
    }

    if (!_initialized || _args == null) {
      return const AppScaffold(body: SizedBox.shrink());
    }

    final args = _args!;
    final state = ref.watch(companyFormControllerProvider(args));
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AppScaffold(
      maxContentWidth: 720,
      appBar: AppBar(title: Text(_isEdit ? 'Edit Company' : 'Add Company')),
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
            _PreviewHeader(
              state: state,
            ).animate().fadeIn().scale(begin: const Offset(0.96, 0.96)),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _nameController,
              label: 'Company Name *',
              prefixIcon: Icons.business_rounded,
              onChanged: (v) => ref
                  .read(companyFormControllerProvider(args).notifier)
                  .updateName(v),
            ).animate().fadeIn(delay: 60.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: AppSpacing.md),
            Text('Logo', style: context.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            CompanyLogoPicker(
              selected: state.logoIcon,
              color: state.color,
              onSelected: (v) => ref
                  .read(companyFormControllerProvider(args).notifier)
                  .updateLogoIcon(v),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Company Color', style: context.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            CompanyColorPicker(
              selected: state.colorValue,
              onSelected: (v) => ref
                  .read(companyFormControllerProvider(args).notifier)
                  .updateColor(v),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: state.industry,
              decoration: const InputDecoration(
                labelText: 'Industry *',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: CompanyIndustries.all
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  ref
                      .read(companyFormControllerProvider(args).notifier)
                      .updateIndustry(v);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _addressController,
              label: 'Address *',
              prefixIcon: Icons.location_on_outlined,
              maxLines: 2,
              onChanged: (v) => ref
                  .read(companyFormControllerProvider(args).notifier)
                  .updateAddress(v),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _websiteController,
              label: 'Website',
              prefixIcon: Icons.language_rounded,
              keyboardType: TextInputType.url,
              onChanged: (v) => ref
                  .read(companyFormControllerProvider(args).notifier)
                  .updateWebsite(v),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _emailController,
              label: 'Email',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              onChanged: (v) => ref
                  .read(companyFormControllerProvider(args).notifier)
                  .updateEmail(v),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _phoneController,
              label: 'Phone',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              onChanged: (v) => ref
                  .read(companyFormControllerProvider(args).notifier)
                  .updatePhone(v),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _employeesController,
              label: 'Number of Employees *',
              prefixIcon: Icons.groups_outlined,
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final count = int.tryParse(v) ?? 0;
                ref
                    .read(companyFormControllerProvider(args).notifier)
                    .updateEmployeeCount(count);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Status', style: context.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<CompanyStatus>(
              segments: const [
                ButtonSegment(
                  value: CompanyStatus.active,
                  label: Text('Active'),
                  icon: Icon(Icons.check_circle_outline),
                ),
                ButtonSegment(
                  value: CompanyStatus.inactive,
                  label: Text('Inactive'),
                  icon: Icon(Icons.pause_circle_outline),
                ),
              ],
              selected: {state.companyStatus},
              onSelectionChanged: (s) => ref
                  .read(companyFormControllerProvider(args).notifier)
                  .updateStatus(s.first),
            ),
            const SizedBox(height: AppSpacing.xl),
            AuthPrimaryButton(
              label: _isEdit ? 'Save Changes' : 'Create Company',
              icon: Icons.save_rounded,
              enabled: state.isValid,
              isLoading: state.isLoading,
              onPressed: _submit,
            ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.08, end: 0),
          ],
        ),
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.state});

  final CompanyFormState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            state.color.withValues(alpha: 0.18),
            state.color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: state.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: state.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              CompanyLogoIcons.resolve(state.logoIcon),
              color: state.color,
              size: 32,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.name.isEmpty ? 'Company name' : state.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  state.industry,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
