import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_session.dart';
import '../auth/role_access.dart';

class DirectoryPage extends StatefulWidget {
  const DirectoryPage({super.key});

  @override
  State<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends State<DirectoryPage> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _leaves = [];
  bool _loading = true;
  String? _error;

  // Filter States
  String _searchQuery = '';
  String _departmentFilter = '';
  String _designationFilter = '';
  String _statusFilter = '';

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final session = context.read<AuthSession>();
    if (session.api == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        session.api!.fetchEmployees(),
        session.api!.fetchLeave().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _employees = results[0];
        _leaves = results[1];
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

  bool _isActiveRecord(Map<String, dynamic> emp) {
    final status = (emp['employmentStatus'] ?? emp['status'] ?? 'Active').toString();
    return status == 'Active';
  }

  bool _isOnLeaveToday(String employeeId) {
    if (employeeId.isEmpty) return false;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);

    return _leaves.any((leave) {
      final leaveStatus = (leave['status'] ?? '').toString().toLowerCase();
      if (leaveStatus != 'approved') return false;

      final emp = leave['employee'];
      final leaveEmpId = emp is Map ? (emp['_id'] ?? '').toString() : leave['employee']?.toString() ?? '';
      if (leaveEmpId != employeeId) return false;

      final startRaw = leave['startDate'] ?? leave['start'];
      final endRaw = leave['endDate'] ?? leave['end'];
      if (startRaw == null || endRaw == null) return false;

      final start = DateTime.tryParse(startRaw.toString());
      final end = DateTime.tryParse(endRaw.toString());
      if (start == null || end == null) return false;

      return (start.isBefore(todayEnd) && end.isAfter(todayStart));
    });
  }

  String _resolveDisplayStatus(Map<String, dynamic> emp) {
    final empId = (emp['_id'] ?? '').toString();
    if (_isOnLeaveToday(empId)) return 'On Leave';
    if (_isActiveRecord(emp)) return 'Active';
    return 'Inactive';
  }

  List<String> get _departments {
    final set = <String>{};
    for (final e in _employees) {
      final dept = (e['department'] ?? '').toString().trim();
      if (dept.isNotEmpty) set.add(dept);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> get _designations {
    final set = <String>{};
    for (final e in _employees) {
      final title = RoleAccess.designationTitle(e).trim();
      if (title.isNotEmpty && title != '—') set.add(title);
    }
    final list = set.toList()..sort();
    return list;
  }

  Map<String, dynamic> get _stats {
    final total = _employees.length;
    final active = _employees.where((e) => _isActiveRecord(e)).length;
    final inactive = total - active;
    final onLeave = _employees.where((e) => _isOnLeaveToday((e['_id'] ?? '').toString())).length;

    final activePct = total > 0 ? ((active / total) * 100).toStringAsFixed(1) : '0';
    final inactivePct = total > 0 ? ((inactive / total) * 100).toStringAsFixed(1) : '0';

    return {
      'total': total,
      'active': active,
      'inactive': inactive,
      'onLeave': onLeave,
      'activePct': activePct,
      'inactivePct': inactivePct,
    };
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    return _employees.where((emp) {
      final displayStatus = _resolveDisplayStatus(emp);
      if (_statusFilter.isNotEmpty && displayStatus != _statusFilter) return false;

      final dept = (emp['department'] ?? '').toString();
      if (_departmentFilter.isNotEmpty && dept != _departmentFilter) return false;

      final desig = RoleAccess.designationTitle(emp);
      if (_designationFilter.isNotEmpty && desig != _designationFilter) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final name = (emp['name'] ?? '').toString().toLowerCase();
        final email = (emp['email'] ?? '').toString().toLowerCase();
        final code = (emp['employeeCode'] ?? emp['_id'] ?? '').toString().toLowerCase();
        final phone = (emp['officialMobile'] ?? emp['personalMobile'] ?? '').toString().toLowerCase();

        return name.contains(q) || email.contains(q) || code.contains(q) || phone.contains(q) || desig.toLowerCase().contains(q);
      }

      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _departmentFilter = '';
      _designationFilter = '';
      _statusFilter = '';
      _searchCtrl.clear();
    });
  }

  Future<void> _deleteEmployee(String id, String name) async {
    final session = context.read<AuthSession>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Employee', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete employee "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await session.api!.deleteEmployee(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee deleted successfully')),
        );
        _fetchData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    }
  }

  Future<void> _makeCall(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    try {
      await launchUrl(uri);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not dial $phone')));
      }
    }
  }

  Future<void> _sendEmail(String email) async {
    if (email.isEmpty) return;
    final uri = Uri.parse('mailto:$email');
    try {
      await launchUrl(uri);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open email client for $email')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final filtered = _filteredEmployees;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('Employee Directory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: () => _showEmployeeModal(context),
              icon: const Icon(Icons.person_add, size: 16),
              label: const Text('Add Employee', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stat Cards Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth < 600
                      ? (constraints.maxWidth - 8) / 2
                      : (constraints.maxWidth - 24) / 4;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _buildStatCard(
                          title: 'Total',
                          value: '${stats['total']}',
                          subtitle: 'All Depts',
                          icon: Icons.groups,
                          iconBg: const Color(0xFFEFF6FF),
                          iconColor: const Color(0xFF2563EB),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _buildStatCard(
                          title: 'Active',
                          value: '${stats['active']}',
                          subtitle: '${stats['activePct']}% of total',
                          icon: Icons.check_circle_outline,
                          iconBg: const Color(0xFFECFDF5),
                          iconColor: const Color(0xFF10B981),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _buildStatCard(
                          title: 'On Leave',
                          value: '${stats['onLeave']}',
                          subtitle: 'Today',
                          icon: Icons.beach_access,
                          iconBg: const Color(0xFFFFFBEB),
                          iconColor: const Color(0xFFF59E0B),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _buildStatCard(
                          title: 'Inactive',
                          value: '${stats['inactive']}',
                          subtitle: '${stats['inactivePct']}% of total',
                          icon: Icons.cancel_outlined,
                          iconBg: const Color(0xFFF1F5F9),
                          iconColor: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 12),

              // Filter & Search Controls
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    // Search Field
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search by name, email, employee ID...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () => setState(() {
                                  _searchCtrl.clear();
                                  _searchQuery = '';
                                }),
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 10),

                    // Dropdowns row
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _departmentFilter,
                            decoration: InputDecoration(
                              labelText: 'Department',
                              labelStyle: const TextStyle(fontSize: 11),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: [
                              const DropdownMenuItem(value: '', child: Text('All Depts', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              ..._departments.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (v) => setState(() => _departmentFilter = v ?? ''),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _designationFilter,
                            decoration: InputDecoration(
                              labelText: 'Designation',
                              labelStyle: const TextStyle(fontSize: 11),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: [
                              const DropdownMenuItem(value: '', child: Text('All Designations', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              ..._designations.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (v) => setState(() => _designationFilter = v ?? ''),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Status Dropdown & Reset Button
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _statusFilter,
                            decoration: InputDecoration(
                              labelText: 'Status',
                              labelStyle: const TextStyle(fontSize: 11),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: const [
                              DropdownMenuItem(value: '', child: Text('All Status', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'Active', child: Text('Active', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'On Leave', child: Text('On Leave', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'Inactive', child: Text('Inactive', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (v) => setState(() => _statusFilter = v ?? ''),
                          ),
                        ),

                        if (_searchQuery.isNotEmpty ||
                            _departmentFilter.isNotEmpty ||
                            _designationFilter.isNotEmpty ||
                            _statusFilter.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.restart_alt, size: 14, color: Color(0xFFEF4444)),
                            label: const Text('Reset', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Employees List Body
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text('Error: $_error', style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
                )
              else if (filtered.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.person_off_outlined, size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 10),
                      const Text(
                        'No employees found',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Try clearing your search query or filters.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.restart_alt, size: 14),
                        label: const Text('Reset Filters', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final emp = filtered[idx];
                    return _buildEmployeeCard(emp);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 14, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }


  Widget _buildEmployeeCard(Map<String, dynamic> emp) {
    final id = (emp['_id'] ?? '').toString();
    final name = (emp['name'] ?? 'Unnamed Employee').toString();
    final code = (emp['employeeCode'] ?? '').toString();
    final email = (emp['email'] ?? '').toString();
    final phone = (emp['officialMobile'] ?? emp['personalMobile'] ?? '').toString();
    final designation = RoleAccess.designationTitle(emp);
    final department = (emp['department'] ?? '').toString();
    final photo = emp['profilePhoto']?.toString();
    final displayStatus = _resolveDisplayStatus(emp);

    Color statusBg;
    Color statusFg;
    Color statusBorder;

    if (displayStatus == 'Active') {
      statusBg = const Color(0xFFECFDF5);
      statusFg = const Color(0xFF047857);
      statusBorder = const Color(0xFFA7F3D0);
    } else if (displayStatus == 'On Leave') {
      statusBg = const Color(0xFFFFFBEB);
      statusFg = const Color(0xFFB45309);
      statusBorder = const Color(0xFFFDE68A);
    } else {
      statusBg = const Color(0xFFF1F5F9);
      statusFg = const Color(0xFF475569);
      statusBorder = const Color(0xFFCBD5E1);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFDBEAFE),
                  backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
                  child: photo == null || photo.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'E',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF), fontSize: 16),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusBorder),
                            ),
                            child: Text(
                              displayStatus,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusFg),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$designation ${department.isNotEmpty ? '· $department' : ''}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                      ),
                      if (code.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'ID: $code',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 18),

            // Contact Info
            if (phone.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: InkWell(
                  onTap: () => _makeCall(phone),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 6),
                      Text(phone, style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),

            if (email.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () => _sendEmail(email),
                  child: Row(
                    children: [
                      const Icon(Icons.email_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 4),
            // Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showEmployeeProfileModal(context, emp),
                  icon: const Icon(Icons.visibility_outlined, size: 14),
                  label: const Text('View Profile', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF475569)),
                ),
                TextButton.icon(
                  onPressed: () => _showEmployeeModal(context, employee: emp),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                  onPressed: () => _deleteEmployee(id, name),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- VIEW EMPLOYEE PROFILE MODAL ---
  void _showEmployeeProfileModal(BuildContext context, Map<String, dynamic> emp) {
    final name = (emp['name'] ?? 'Unnamed Employee').toString();
    final code = (emp['employeeCode'] ?? '—').toString();
    final email = (emp['email'] ?? '—').toString();
    final phone = (emp['officialMobile'] ?? emp['personalMobile'] ?? '—').toString();
    final dept = (emp['department'] ?? '—').toString();
    final desig = RoleAccess.designationTitle(emp);
    final status = _resolveDisplayStatus(emp);
    final photo = emp['profilePhoto']?.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFDBEAFE),
                    backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
                    child: photo == null || photo.isEmpty
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'E',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF), fontSize: 20),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text('$desig · $dept', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        Text('Employee ID: $code', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(height: 24),
              _profileRow('Employment Status', status),
              _profileRow('Email Address', email),
              _profileRow('Contact Mobile', phone),
              _profileRow('Department', dept),
              _profileRow('Designation', desig),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _profileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // --- ADD / EDIT EMPLOYEE MODAL ---
  void _showEmployeeModal(BuildContext context, {Map<String, dynamic>? employee}) {
    final isEdit = employee != null;
    final id = isEdit ? (employee['_id'] ?? '').toString() : '';

    final nameCtrl = TextEditingController(text: isEdit ? (employee['name'] ?? '').toString() : '');
    final emailCtrl = TextEditingController(text: isEdit ? (employee['email'] ?? '').toString() : '');
    final phoneCtrl = TextEditingController(text: isEdit ? (employee['officialMobile'] ?? employee['personalMobile'] ?? '').toString() : '');
    final codeCtrl = TextEditingController(text: isEdit ? (employee['employeeCode'] ?? '').toString() : '');
    final deptCtrl = TextEditingController(text: isEdit ? (employee['department'] ?? '').toString() : '');
    final desigCtrl = TextEditingController(text: isEdit ? RoleAccess.designationTitle(employee) : '');

    String status = isEdit ? (employee['employmentStatus'] ?? employee['status'] ?? 'Active').toString() : 'Active';
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEdit ? 'Edit Employee' : 'Add New Employee',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full Name *', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email Address *', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Official / Mobile Number', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: codeCtrl,
                            decoration: const InputDecoration(labelText: 'Employee Code (ID)', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: status,
                            decoration: const InputDecoration(labelText: 'Status', isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'Active', child: Text('Active', style: TextStyle(fontSize: 11))),
                              DropdownMenuItem(value: 'Inactive', child: Text('Inactive', style: TextStyle(fontSize: 11))),
                            ],
                            onChanged: (v) => status = v ?? status,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: deptCtrl,
                            decoration: const InputDecoration(labelText: 'Department', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: desigCtrl,
                            decoration: const InputDecoration(labelText: 'Designation Title', isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                final email = emailCtrl.text.trim();
                                if (name.isEmpty || email.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Name and Email are required')),
                                  );
                                  return;
                                }

                                setModalState(() => saving = true);
                                final session = context.read<AuthSession>();
                                try {
                                  final body = <String, dynamic>{
                                    'name': name,
                                    'email': email,
                                    'officialMobile': phoneCtrl.text.trim(),
                                    'employeeCode': codeCtrl.text.trim(),
                                    'department': deptCtrl.text.trim(),
                                    'employmentStatus': status,
                                    'status': status,
                                  };
                                  if (desigCtrl.text.trim().isNotEmpty) {
                                    body['designation'] = desigCtrl.text.trim();
                                  }

                                  if (isEdit) {
                                    await session.api!.updateEmployee(id, body);
                                  } else {
                                    await session.api!.createEmployee(body);
                                  }

                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text(isEdit ? 'Employee updated!' : 'Employee created!')),
                                    );
                                    Navigator.pop(ctx);
                                  }
                                  if (mounted) {
                                    _fetchData();
                                  }
                                } catch (e) {
                                  setModalState(() => saving = false);
                                  if (ctx.mounted) {
                                    final errMsg = e.toString().replaceFirst('Exception: ', '');
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Error: $errMsg')),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(saving ? 'Saving...' : (isEdit ? 'Update Employee' : 'Create Employee')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
