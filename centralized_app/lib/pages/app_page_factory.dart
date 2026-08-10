import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../auth/role_access.dart';
import 'assign_task_page.dart';
import 'attendance_page.dart';
import 'chat_page.dart';
import 'dashboard_page.dart';
import 'leave_page.dart';
import 'my_projects_page.dart';
import 'my_tasks_page.dart';
import 'placeholder_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';

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

String _populatedName(dynamic v) {
  if (v is Map) return (v['name'] ?? v['title'] ?? '').toString();
  return v?.toString() ?? '';
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
    if (path == '/my-profile') return const ProfilePage();
    if (path == '/settings') return const SettingsPage();

    switch (path) {
      case '/leads':
      case '/lead-management':
        return ModuleListPage(
          title: 'Leads',
          fetch: (s) => s.api!.fetchLeads(viewerId: s.userId),
          titleFor: (i) => (i['businessName'] ?? i['name'] ?? 'Lead').toString(),
          subtitleFor: (i) => '${i['status'] ?? '—'} · ${i['leadSource'] ?? '—'}',
        );
      case '/employees':
        return ModuleListPage(
          title: 'Employees',
          fetch: (s) => s.api!.fetchEmployees(),
          titleFor: (i) => (i['name'] ?? 'Employee').toString(),
          subtitleFor: (i) {
            final d = i['designation'];
            final title = d is Map ? (d['title'] ?? d['name']) : d;
            return '${i['department'] ?? '—'} · ${title ?? '—'}';
          },
        );
      case '/clients':
        return ModuleListPage(
          title: 'Clients',
          fetch: (s) => s.api!.fetchClients(),
          titleFor: (i) => (i['clientName'] ?? i['name'] ?? 'Client').toString(),
          subtitleFor: (i) => '${i['email'] ?? i['phone'] ?? '—'}',
        );
      case '/projects':
        return ModuleListPage(
          title: 'Projects',
          fetch: (s) => s.api!.fetchProjects(),
          titleFor: (i) => (i['projectName'] ?? i['name'] ?? 'Project').toString(),
          subtitleFor: (i) => '${i['status'] ?? '—'} · ${_fmtDate(i['createdAt'])}',
        );
      case '/my-projects':
        return const MyProjectsPage();
      case '/tasks':
        return ModuleListPage(
          title: 'Tasks',
          fetch: (s) => s.api!.fetchTasks(),
          titleFor: (i) => (i['title'] ?? 'Task').toString(),
          subtitleFor: (i) => '${i['status'] ?? '—'} · ${_fmtDate(i['dueDate'] ?? i['updatedAt'])}',
        );
      case '/my-tasks':
        return const MyTasksPage();
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
      case '/billings':
        return ModuleListPage(
          title: 'Invoices',
          fetch: (s) => s.api!.fetchBillings(),
          titleFor: (i) {
            final client = i['client'];
            final name = client is Map ? (client['clientName'] ?? client['name']) : client;
            return (name ?? 'Invoice').toString();
          },
          subtitleFor: (i) {
            final amount = i['paymentDetails'] is Map ? i['paymentDetails']['amount'] : null;
            return '₹${amount ?? 0} · ${_fmtDate(i['createdAt'])}';
          },
        );
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
