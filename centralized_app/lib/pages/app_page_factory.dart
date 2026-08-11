import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../auth/role_access.dart';
import '../auth/role_guard.dart';
import 'assign_task_page.dart';
import 'attendance_page.dart';
import 'chat_page.dart';
import 'collaborators_page.dart';
import 'dashboard_page.dart';
import 'directory_page.dart';
import 'lead_management_page.dart';

import 'leave_page.dart';


import 'assets_page.dart';
import 'campaigns_page.dart';
import 'companies_page.dart';
import 'departments_page.dart';
import 'designations_page.dart';
import 'email_marketing_page.dart';
import 'expenses_page.dart';
import 'gst_page.dart';
import 'hr_dashboard_page.dart';
import 'invoices_page.dart';
import 'manager_dashboard_page.dart';
import 'sms_marketing_page.dart';
import 'social_media_page.dart';
import 'team_leader_dashboard_page.dart';
import 'whatsapp_marketing_page.dart';

import 'my_projects_page.dart';
import 'my_tasks_page.dart';
import 'milestones_page.dart';
import 'payroll_page.dart';
import 'performance_page.dart';
import 'placeholder_page.dart';
import 'profile_page.dart';
import 'quotations_page.dart';
import 'reports_page.dart';
import 'revenue_page.dart';
import 'settings_page.dart';
import 'timesheets_page.dart';





typedef ListFetcher = Future<List<Map<String, dynamic>>> Function(AuthSession session);

class ModuleListPage extends StatefulWidget {
  const ModuleListPage({
    super.key,
    required this.title,
    required this.fetch,
    required this.titleFor,
    required this.subtitleFor,
    this.emptyLabel = 'No records yet',
  });

  final String title;
  final ListFetcher fetch;
  final String Function(Map<String, dynamic> item) titleFor;
  final String Function(Map<String, dynamic> item) subtitleFor;
  final String emptyLabel;

  @override
  State<ModuleListPage> createState() => _ModuleListPageState();
}

class _ModuleListPageState extends State<ModuleListPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = context.read<AuthSession>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.fetch(session);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
          const SizedBox(height: 8),
          TextButton(onPressed: _load, child: const Text('Retry', style: TextStyle(fontSize: 12))),
        ],
      );
    }
    if (_items.isEmpty) {
      return Center(child: Text(widget.emptyLabel, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
        itemCount: _items.length,
        separatorBuilder: (context, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final item = _items[index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.titleFor(item),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitleFor(item),
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _fmtDate(dynamic v) {
  if (v == null) return '—';
  final d = DateTime.tryParse(v.toString());
  if (d == null) return v.toString();
  return '${d.day}/${d.month}/${d.year}';
}

String currentMonthKey() {
  final now = DateTime.now();
  final m = now.month.toString().padLeft(2, '0');
  return '${now.year}-$m';
}

/// Maps sidebar paths to compact list pages backed by tenant APIs.
class AppPageFactory {
  AppPageFactory._();

  static bool isDashboardPath(String path) => RoleAccess.isDashboardPath(path);

  static Widget build(String path) {
    if (isDashboardPath(path)) return DashboardPage(requestedPath: path);
    return RoleGuard(
      path: path,
      child: _buildRaw(path),
    );
  }

  static Widget _buildRaw(String path) {
    if (path == '/my-profile') return const ProfilePage();
    if (path == '/settings') return const SettingsPage();

    switch (path) {
      case '/leads':
      case '/lead-management':
        return const LeadManagementPage();
      case '/collaborators':
      case '/contacts':
        return const CollaboratorsPage();
      case '/companies':
        return const CompaniesPage();
      case '/quotations':
        return const QuotationsPage();
      case '/employees':
      case '/directory':
        return const DirectoryPage();
      case '/clients':

        return ModuleListPage(
          title: 'Clients',
          fetch: (s) => s.api!.fetchClients(),
          titleFor: (i) => (i['clientName'] ?? i['name'] ?? 'Client').toString(),
          subtitleFor: (i) => '${i['email'] ?? i['phone'] ?? '—'}',
        );
      case '/projects':
        return const MyProjectsPage(isAllProjects: true);
      case '/my-projects':
        return const MyProjectsPage(isAllProjects: false);
      case '/tasks':
        return const MyTasksPage(isAllTasks: true);
      case '/my-tasks':
        return const MyTasksPage(isAllTasks: false);
      case '/module/milestones':
      case '/milestones':
        return const MilestonesPage();
      case '/module/timesheets':
      case '/timesheets':
        return const TimesheetsPage();
      case '/assign-task':
        return const AssignTaskPage();
      case '/assign-task-self':
        return const AssignTaskPage(selfMode: true);
      case '/leave':
        return const LeavePage();
      case '/attendance':
        return const AttendancePage();
      case '/my-attendance':
        return const AttendancePage(forceSelfMode: true);
      case '/module/performance':
      case '/performance':
        return const PerformancePage();
      case '/module/assets':
      case '/assets':
        return const AssetsPage();

      case '/billings':
      case '/invoices':
        return const InvoicesPage();
      case '/expenses':
        return const ExpensesPage();
      case '/revenue':
        return const RevenuePage();
      case '/salaries':
      case '/payroll':
        return const PayrollPage();
      case '/module/gst':
      case '/gst':
        return const GstPage();
      case '/reports':
        return const ReportsPage();
      case '/module/departments':
      case '/departments':
        return const DepartmentsPage();
      case '/module/designations':
      case '/designations':
        return const DesignationsPage();
      case '/campaigns':
        return const CampaignsPage();
      case '/module/email':
      case '/email':
        return const EmailMarketingPage();
      case '/module/sms':
      case '/sms':
        return const SmsMarketingPage();
      case '/module/whatsapp':
      case '/whatsapp':
        return const WhatsappMarketingPage();
      case '/social-calendar':
      case '/social':
        return const SocialMediaPage();
      case '/hr-dashboard':
      case '/dashboard/hr':
      case '/hr':
        return const HrDashboardPage();
      case '/manager-dashboard':
      case '/dashboard/manager':
      case '/manager':
        return const ManagerDashboardPage();
      case '/team-leader-dashboard':
      case '/dashboard/team_leader':
      case '/team-leader':
        return const TeamLeaderDashboardPage();







      case '/properties':
        return ModuleListPage(
          title: 'Properties',
          fetch: (s) => s.api!.fetchProperties(),
          titleFor: (i) => (i['propertyName'] ?? i['title'] ?? i['name'] ?? 'Property').toString(),
          subtitleFor: (i) => '${i['status'] ?? i['propertyType'] ?? '—'} · ${i['location'] ?? i['city'] ?? '—'}',
        );
      case '/module/announcements':
        return ModuleListPage(
          title: 'Announcements',
          fetch: (s) => s.api!.fetchAnnouncements(),
          titleFor: (i) => (i['title'] ?? 'Announcement').toString(),
          subtitleFor: (i) => '${_fmtDate(i['createdAt'])} · ${i['message'] ?? i['content'] ?? ''}',
        );
      case '/module/chat':
        return const ChatPage();
      case '/my-team':
        return ModuleListPage(
          title: 'Team Members',
          fetch: (s) => s.api!.fetchEmployees(),
          titleFor: (i) => (i['name'] ?? 'Employee').toString(),
          subtitleFor: (i) => RoleAccess.designationTitle(i),
          emptyLabel: 'No team members found',
        );
      default:
        return PlaceholderPage(
          title: 'Coming soon',
          subtitle: 'This module is available on the web CRM. Flutter support will follow.',
          webPath: path,
        );
    }
  }
}
