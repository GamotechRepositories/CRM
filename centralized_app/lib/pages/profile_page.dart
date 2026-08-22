import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../auth/role_access.dart';
import '../utils/salary_calculator.dart';

/// `/my-profile` — fetches `GET /employees/:id/profile` for the logged-in user.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _tabs = [
    'Overview',
    'Employment',
    'Payroll',
    'Attendance',
    'Performance',
    'Documents',
    'Skills',
    'Assets',
    'Access',
    'Activity',
  ];

  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = context.read<AuthSession>();
    final api = session.api;
    final id = session.userId;
    if (api == null || id.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Not signed in';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await api.fetchMyProfile(id);
      if (!mounted) return;
      setState(() {
        _profile = data;
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

    final employee = (_profile?['employee'] as Map?)?.cast<String, dynamic>();
    if (employee == null) {
      return const Center(child: Text('Profile not found', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 20),
        children: [
          _ProfileHero(employee: employee, profile: _profile!),
          const SizedBox(height: 10),
          _TabStrip(
            tabs: _tabs,
            index: _tabIndex,
            onChanged: (i) => setState(() => _tabIndex = i),
          ),
          const SizedBox(height: 10),
          _TabBody(
            tab: _tabs[_tabIndex],
            profile: _profile!,
            employee: employee,
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.employee, required this.profile});
  final Map<String, dynamic> employee;
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final name = profileVal(employee['name']);
    final designation = _designationLabel(employee['designation']);
    final department = profileVal(employee['department']);
    final status = profileVal(employee['employmentStatus'] ?? employee['status'], fallback: 'Active');
    final photo = employee['profilePhoto']?.toString();
    final email = profileVal(employee['email'] ?? employee['officialEmail'] ?? employee['personalEmail']);
    final phone = profileVal(employee['officialMobile'] ?? employee['personalMobile']);
    final empCode = profileVal(employee['employeeCode']);

    final attendance = (profile['attendance'] as Map?)?.cast<String, dynamic>() ?? {};
    final summary = (attendance['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final taskRating = (profile['taskRatingPerformance'] as Map?)?.cast<String, dynamic>() ?? {};
    final projects = profile['assignedProjects'] is List ? (profile['assignedProjects'] as List).length : 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Top Gradient Cover Banner
          Container(
            height: 80,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -20,
                  right: -20,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color.fromARGB(20, 255, 255, 255),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(64, 0, 0, 0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'MY PROFILE',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Profile Content Card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Transform.translate(
                  offset: const Offset(0, -32),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _Avatar(name: name, photoUrl: photo, radius: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 36),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: -0.3,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  _StatusChip(status: status),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                designation,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                department,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -16),
                  child: Column(
                    children: [
                      // Quick info badges
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (empCode != '—')
                            _QuickInfoBadge(icon: Icons.badge_outlined, label: empCode),
                          if (email != '—')
                            _QuickInfoBadge(icon: Icons.email_outlined, label: email),
                          if (phone != '—')
                            _QuickInfoBadge(icon: Icons.phone_outlined, label: phone),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // 4 Mini Stat Cards Grid
                      Row(
                        children: [
                          Expanded(
                            child: _MiniStatCard(
                              label: 'Present',
                              value: '${summary['presentDays'] ?? 0}',
                              icon: Icons.check_circle_outline_rounded,
                              accentColor: const Color(0xFF10B981),
                              bgColor: const Color(0xFFECFDF5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MiniStatCard(
                              label: 'Absent',
                              value: '${summary['absentDays'] ?? 0}',
                              icon: Icons.highlight_off_rounded,
                              accentColor: const Color(0xFFEF4444),
                              bgColor: const Color(0xFFFEF2F2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MiniStatCard(
                              label: 'Projects',
                              value: '$projects',
                              icon: Icons.folder_outlined,
                              accentColor: const Color(0xFF2563EB),
                              bgColor: const Color(0xFFEFF6FF),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MiniStatCard(
                              label: 'Rating',
                              value: taskRating['averageRating'] != null ? '${taskRating['averageRating']}★' : '—',
                              icon: Icons.star_outline_rounded,
                              accentColor: const Color(0xFFF59E0B),
                              bgColor: const Color(0xFFFEF3C7),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.tabs, required this.index, required this.onChanged});
  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (context, _) => const SizedBox(width: 4),
        itemBuilder: (context, i) {
          final selected = i == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            child: Material(
              color: selected ? const Color(0xFF2563EB) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: selected
                        ? const [BoxShadow(color: Color(0x3D2563EB), blurRadius: 6, offset: Offset(0, 2))]
                        : null,
                  ),
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TabBody extends StatelessWidget {
  const _TabBody({required this.tab, required this.profile, required this.employee});
  final String tab;
  final Map<String, dynamic> profile;
  final Map<String, dynamic> employee;

  @override
  Widget build(BuildContext context) {
    switch (tab) {
      case 'Overview':
        return _OverviewTab(profile: profile, employee: employee);
      case 'Employment':
        return _EmploymentTab(profile: profile, employee: employee);
      case 'Payroll':
        return _PayrollTab(profile: profile, employee: employee);
      case 'Attendance':
        return _AttendanceTab(profile: profile);
      case 'Performance':
        return _PerformanceTab(profile: profile, employee: employee);
      case 'Documents':
        return _DocumentsTab(employee: employee);
      case 'Skills':
        return _SkillsTab(employee: employee);
      case 'Assets':
        return _AssetsTab(employee: employee);
      case 'Access':
        return _AccessTab(profile: profile, employee: employee);
      case 'Activity':
        return _ActivityTab(profile: profile, employee: employee);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.profile, required this.employee});
  final Map<String, dynamic> profile;
  final Map<String, dynamic> employee;

  @override
  Widget build(BuildContext context) {
    final payroll = (employee['salaryPayroll'] as Map?)?.cast<String, dynamic>() ?? {};
    final attendance = (profile['attendance'] as Map?)?.cast<String, dynamic>() ?? {};
    final summary = (attendance['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final performance = (employee['performance'] as Map?)?.cast<String, dynamic>() ?? {};
    final reviews = performance['reviews'] is List ? performance['reviews'] as List : [];
    final latestReview = reviews.isNotEmpty ? reviews.last as Map : null;
    final rating = latestReview?['rating'] ?? 0;
    final taskRating = (profile['taskRatingPerformance'] as Map?)?.cast<String, dynamic>() ?? {};

    return Column(
      children: [
        _InfoCard(
          title: 'Personal Information',
          rows: [
            _Row('Full Name', profileVal(employee['name'])),
            _Row('Gender', profileVal(employee['gender'])),
            _Row('Date of Birth', formatProfileDate(employee['dateOfBirth'])),
            _Row('Personal Email', profileVal(employee['personalEmail'])),
            _Row('Personal Mobile', profileVal(employee['personalMobile'])),
          ],
        ),
        const SizedBox(height: 8),
        _InfoCard(
          title: 'Employment Information',
          rows: [
            _Row('Department', profileVal(employee['department'])),
            _Row('Designation', _designationLabel(employee['designation'])),
            _Row('Joining Date', formatProfileDate(employee['dateOfJoining'])),
            _Row('Reporting To', _populatedName(employee['reportingManager'])),
            _Row('Work Location', profileVal(employee['workLocation'])),
          ],
        ),
        const SizedBox(height: 8),
        _InfoCard(
          title: 'Salary Snapshot',
          rows: [
            _Row('Monthly CTC', formatMoney(payroll['monthlyCTC'] ?? payroll['ctc'] ?? employee['salary'])),
            _Row('Basic Salary', formatMoney(payroll['basicSalary'])),
            _Row('HRA', formatMoney(payroll['hra'])),
            _Row('Net Salary', formatMoney(payroll['netSalary'])),
          ],
        ),
        const SizedBox(height: 8),
        _InfoCard(
          title: 'Attendance Summary',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MiniStat(label: 'Present', value: '${summary['presentDays'] ?? 0}'),
              _MiniStat(label: 'Absent', value: '${summary['absentDays'] ?? 0}'),
              _MiniStat(label: 'Late', value: '${summary['lateMarks'] ?? 0}'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _InfoCard(
          title: 'Performance Snapshot',
          rows: [
            _Row('HR Review Rating', rating != 0 ? '$rating / 5' : '—'),
            _Row(
              'Avg Task Rating',
              taskRating['averageRating'] != null ? '${taskRating['averageRating']} / 5' : '—',
            ),
            _Row('Last Review', formatProfileDate(latestReview?['date'])),
          ],
        ),
      ],
    );
  }
}

class _EmploymentTab extends StatelessWidget {
  const _EmploymentTab({required this.profile, required this.employee});
  final Map<String, dynamic> profile;
  final Map<String, dynamic> employee;

  @override
  Widget build(BuildContext context) {
    final access = (profile['access'] as Map?)?.cast<String, dynamic>() ?? (employee['access'] as Map?)?.cast<String, dynamic>() ?? {};
    final projects = profile['assignedProjects'] is List ? profile['assignedProjects'] as List : [];

    return Column(
      children: [
        _InfoCard(
          title: 'Employment Details',
          rows: [
            _Row('Designation', _designationLabel(employee['designation'])),
            _Row('Department', profileVal(employee['department'])),
            _Row('Employee Type', profileVal(employee['employeeType'])),
            _Row('Joining Date', formatProfileDate(employee['dateOfJoining'])),
            _Row('Probation End', formatProfileDate(employee['probationEndDate'])),
            _Row('Reporting Manager', _populatedName(employee['reportingManager'])),
            _Row('Work Shift', profileVal(employee['workShift'] ?? employee['workingHours'])),
          ],
        ),
        const SizedBox(height: 8),
        _InfoCard(
          title: 'Official Information',
          rows: [
            _Row('Official Email', profileVal(employee['email'])),
            _Row('Official Mobile', profileVal(employee['officialMobile'])),
            _Row('Employee Code', profileVal(employee['employeeCode'])),
            _Row('CRM Role', profileVal(access['crmRole'] ?? _designationLabel(employee['designation']))),
          ],
        ),
        const SizedBox(height: 8),
        _InfoCard(
          title: 'Contact & Address',
          rows: [
            _Row('Current Address', profileVal(employee['currentAddress'])),
            _Row('Emergency Contact', _populatedName(employee['emergencyContact'] is Map ? (employee['emergencyContact'] as Map)['name'] : null)),
            _Row('Emergency Mobile', employee['emergencyContact'] is Map ? profileVal((employee['emergencyContact'] as Map)['number']) : '—'),
          ],
        ),
        const SizedBox(height: 8),
        _InfoCard(
          title: 'Assigned Projects',
          child: projects.isEmpty
              ? const Text('No projects assigned.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))
              : Column(
                  children: projects.map((p) {
                    final m = (p as Map).cast<String, dynamic>();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              profileVal(m['projectName']),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                            ),
                          ),
                          Text(
                            '${m['status'] ?? '—'} · ${m['progress'] ?? 0}%',
                            style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _PayrollTab extends StatelessWidget {
  const _PayrollTab({required this.profile, required this.employee});
  final Map<String, dynamic> profile;
  final Map<String, dynamic> employee;

  @override
  Widget build(BuildContext context) {
    final payroll = (employee['salaryPayroll'] as Map?)?.cast<String, dynamic>() ?? {};
    final salaries = profile['salaries'] is List ? profile['salaries'] as List : [];
    final structure = getSalaryStructure({
      ...payroll,
      'monthlyCTC': payroll['monthlyCTC'] ?? payroll['ctc'] ?? employee['salary'] ?? 0,
    });

    return Column(
      children: [
        _InfoCard(
          title: 'Salary & CTC Summary',
          rows: [
            _Row('Gross Salary', formatMoney(structure.grossSalary)),
            _Row('Net Salary', formatMoney(structure.netSalary)),
            _Row('Monthly CTC', formatMoney(structure.monthlyCTC)),
            _Row('Annual CTC', formatMoney(structure.annualCTC)),
          ],
        ),
        const SizedBox(height: 8),
        _InfoCard(
          title: 'Earnings',
          rows: [
            for (final line in structure.components) _Row(line.name, formatMoney(line.amount)),
            for (final line in structure.employerContributions) _Row(line.name, formatMoney(line.amount)),
          ],
        ),
        const SizedBox(height: 8),
        _InfoCard(
          title: 'Deductions',
          rows: [
            for (final line in structure.deductions) _Row(line.name, formatMoney(line.amount)),
            _Row('PAN Number', profileVal(payroll['panNumber'])),
            _Row('PF Number', profileVal(payroll['pfNumber'])),
            _Row('Bank Details', profileVal(payroll['bankAccountDetails'])),
          ],
        ),
        if (salaries.isNotEmpty) ...[
          const SizedBox(height: 8),
          _InfoCard(
            title: 'Salary History',
            child: Column(
              children: salaries.take(12).map((s) {
                final m = (s as Map).cast<String, dynamic>();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${m['month']}/${m['year']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      Text(formatMoney(m['grossSalary'] ?? m['amount']), style: const TextStyle(fontSize: 10, color: Color(0xFF334155))),
                      const SizedBox(width: 8),
                      Text('${m['status'] ?? '—'}', style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _AttendanceTab extends StatelessWidget {
  const _AttendanceTab({required this.profile});
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final attendance = (profile['attendance'] as Map?)?.cast<String, dynamic>() ?? {};
    final summary = (attendance['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final leaveBalance = (attendance['leaveBalance'] as Map?)?.cast<String, dynamic>() ?? {};
    final leaveHistory = attendance['leaveHistory'] is List ? attendance['leaveHistory'] as List : [];

    return Column(
      children: [
        _InfoCard(
          title: 'Attendance Summary',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MiniStat(label: 'Present', value: '${summary['presentDays'] ?? 0}'),
              _MiniStat(label: 'Absent', value: '${summary['absentDays'] ?? 0}'),
              _MiniStat(label: 'Late', value: '${summary['lateMarks'] ?? 0}'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _InfoCard(
          title: 'Leave Balance',
          rows: [
            _Row('Sick Leave', profileVal(leaveBalance['sick'])),
            _Row('Casual Leave', profileVal(leaveBalance['casual'])),
            _Row('Annual Leave', profileVal(leaveBalance['annual'])),
          ],
        ),
        const SizedBox(height: 8),
        _InfoCard(
          title: 'Leave History',
          child: leaveHistory.isEmpty
              ? const Text('No leave records.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))
              : Column(
                  children: leaveHistory.take(10).map((l) {
                    final m = (l as Map).cast<String, dynamic>();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${m['leaveType'] ?? 'Leave'} · ${m['status'] ?? '—'}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${formatProfileDate(m['startDate'])} – ${formatProfileDate(m['endDate'])}',
                            style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _PerformanceTab extends StatelessWidget {
  const _PerformanceTab({required this.profile, required this.employee});
  final Map<String, dynamic> profile;
  final Map<String, dynamic> employee;

  @override
  Widget build(BuildContext context) {
    final performance = (employee['performance'] as Map?)?.cast<String, dynamic>() ?? {};
    final reviews = performance['reviews'] is List ? performance['reviews'] as List : [];
    final goals = performance['goals'] is List ? performance['goals'] as List : [];
    final taskRating = (profile['taskRatingPerformance'] as Map?)?.cast<String, dynamic>() ?? {};
    final tasks = taskRating['assignedTasks'] is List
        ? taskRating['assignedTasks'] as List
        : (profile['tasks'] is List ? profile['tasks'] as List : []);

    return Column(
      children: [
        _InfoCard(
          title: 'Performance Summary',
          rows: [
            _Row('Avg Task Rating', taskRating['averageRating'] != null ? '${taskRating['averageRating']} / 5' : '—'),
            _Row('Rated Tasks', '${taskRating['ratedTaskCount'] ?? 0} of ${taskRating['totalAssignedTasks'] ?? tasks.length}'),
          ],
        ),
        if (reviews.isNotEmpty) ...[
          const SizedBox(height: 8),
          _InfoCard(
            title: 'HR Reviews',
            child: Column(
              children: reviews.take(8).map((r) {
                final m = (r as Map).cast<String, dynamic>();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${formatProfileDate(m['date'])} · Rating ${m['rating'] ?? '—'}: ${m['comments'] ?? ''}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF334155), height: 1.3),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        if (goals.isNotEmpty) ...[
          const SizedBox(height: 8),
          _InfoCard(
            title: 'Goals',
            child: Column(
              children: goals.take(8).map((g) {
                final m = (g as Map).cast<String, dynamic>();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${m['title'] ?? 'Goal'} (${m['status'] ?? '—'})',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF334155)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        if (tasks.isNotEmpty) ...[
          const SizedBox(height: 8),
          _InfoCard(
            title: 'Assigned Tasks',
            child: Column(
              children: tasks.take(10).map((t) {
                final m = (t as Map).cast<String, dynamic>();
                final rating = m['ratingScore'] ?? (m['rating'] is Map ? (m['rating'] as Map)['score'] : null);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profileVal(m['title']),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${m['status'] ?? 'Pending'} · Due ${formatProfileDate(m['dueDate'])} · Rating ${rating ?? '—'}',
                        style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _DocumentsTab extends StatelessWidget {
  const _DocumentsTab({required this.employee});
  final Map<String, dynamic> employee;

  static const _docFields = [
    ('Resume/CV', 'resume'),
    ('Offer Letter', 'offerLetter'),
    ('Appointment Letter', 'appointmentLetter'),
    ('PAN Card', 'panCard'),
    ('Aadhaar Card', 'aadhaarCard'),
    ('Passport', 'passport'),
    ('Driving License', 'drivingLicense'),
    ('Bank Passbook', 'bankPassbook'),
  ];

  @override
  Widget build(BuildContext context) {
    final docs = (employee['documents'] as Map?)?.cast<String, dynamic>() ?? {};
    return Column(
      children: _docFields.map((field) {
        final url = docs[field.$2]?.toString();
        final uploaded = url != null && url.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: uploaded ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                Icon(
                  uploaded ? Icons.check_circle_outline : Icons.upload_file_outlined,
                  size: 16,
                  color: uploaded ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(field.$1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      Text(
                        uploaded ? 'Uploaded' : 'Not uploaded',
                        style: TextStyle(fontSize: 9, color: uploaded ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SkillsTab extends StatelessWidget {
  const _SkillsTab({required this.employee});
  final Map<String, dynamic> employee;

  @override
  Widget build(BuildContext context) {
    final skills = (employee['skills'] as Map?)?.cast<String, dynamic>() ?? {};
    String joinList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).join(', ');
      return profileVal(v);
    }

    return _InfoCard(
      title: 'Skills & Certifications',
      rows: [
        _Row('Skills', joinList(skills['skills'])),
        _Row('Technologies', joinList(skills['technologies'])),
        _Row('Languages', joinList(skills['languages'])),
      ],
    );
  }
}

class _AssetsTab extends StatelessWidget {
  const _AssetsTab({required this.employee});
  final Map<String, dynamic> employee;

  @override
  Widget build(BuildContext context) {
    final assets = (employee['assets'] as Map?)?.cast<String, dynamic>() ?? {};
    return _InfoCard(
      title: 'Asset Records',
      rows: [
        _Row('Laptop', profileVal(assets['laptop'])),
        _Row('Desktop', profileVal(assets['desktop'])),
        _Row('Mobile Phone', profileVal(assets['mobilePhone'])),
        _Row('SIM Card', profileVal(assets['simCard'])),
        _Row('Access Cards', profileVal(assets['accessCards'])),
        _Row('Other Assets', profileVal(assets['other'])),
      ],
    );
  }
}

class _AccessTab extends StatelessWidget {
  const _AccessTab({required this.profile, required this.employee});
  final Map<String, dynamic> profile;
  final Map<String, dynamic> employee;

  @override
  Widget build(BuildContext context) {
    final access = (profile['access'] as Map?)?.cast<String, dynamic>() ?? (employee['access'] as Map?)?.cast<String, dynamic>() ?? {};
    final permissions = access['permissions'];
    return _InfoCard(
      title: 'Access & Permissions',
      rows: [
        _Row('CRM Role', profileVal(access['crmRole'])),
        _Row('Access Role', RoleAccess.accessRole(employee)),
        _Row(
          'Permissions',
          permissions is List ? permissions.map((e) => e.toString()).join(', ') : profileVal(permissions),
        ),
        _Row('Account Status', profileVal(access['accountStatus'])),
        _Row('Last Login', formatProfileDateTime(access['lastLogin'])),
      ],
    );
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({required this.profile, required this.employee});
  final Map<String, dynamic> profile;
  final Map<String, dynamic> employee;

  @override
  Widget build(BuildContext context) {
    final notes = (employee['notes'] as Map?)?.cast<String, dynamic>() ?? {};
    final attendance = (profile['attendance'] as Map?)?.cast<String, dynamic>() ?? {};
    final activities = <Map<String, dynamic>>[];

    void add(dynamic date, String text, String by) {
      if (date == null) return;
      activities.add({'date': date, 'text': text, 'by': by});
    }

    if (notes['activityLog'] is List) {
      for (final a in notes['activityLog'] as List) {
        if (a is Map) add(a['date'], '${a['action']}', '${a['by'] ?? 'System'}');
      }
    }
    if (attendance['leaveHistory'] is List) {
      for (final l in attendance['leaveHistory'] as List) {
        if (l is Map) add(l['createdAt'] ?? l['startDate'], 'Leave applied — ${l['leaveType']}', profileVal(employee['name']));
      }
    }
    add(employee['updatedAt'], 'Profile updated', 'System');

    activities.sort((a, b) {
      final da = DateTime.tryParse('${a['date']}') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = DateTime.tryParse('${b['date']}') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });

    return Column(
      children: [
        _InfoCard(
          title: 'Notes',
          rows: [
            _Row('HR Notes', profileVal(notes['hrNotes'])),
            _Row('Employee Remarks', profileVal(notes['employeeRemarks'])),
          ],
        ),
        const SizedBox(height: 8),
        _InfoCard(
          title: 'Activity Log',
          child: activities.isEmpty
              ? const Text('No activity recorded.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))
              : Column(
                  children: activities.take(10).map((a) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${a['text']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                Text(
                                  '${a['by']} · ${formatProfileDateTime(a['date'])}',
                                  style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _QuickInfoBadge extends StatelessWidget {
  const _QuickInfoBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          ),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withAlpha(38)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: accentColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: accentColor),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, this.rows = const [], this.child});
  final String title;
  final List<_Row> rows;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (child != null) child!,
          for (final row in rows) row,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.photoUrl, this.radius = 28});
  final String name;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFFDBEAFE),
            backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty) ? NetworkImage(photoUrl!) : null,
            child: (photoUrl == null || photoUrl!.isEmpty)
                ? Text(initial, style: TextStyle(fontSize: radius * 0.65, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB)))
                : null,
          ),
        ),
        Positioned(
          right: 2,
          bottom: 2,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final active = status.toLowerCase() == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: active ? const Color(0xFF047857) : const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 8, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

String profileVal(dynamic v, {String fallback = '—'}) {
  if (v == null) return fallback;
  final s = v.toString().trim();
  return s.isEmpty ? fallback : s;
}

String _designationLabel(dynamic d) {
  if (d is Map) return profileVal(d['title'] ?? d['name']);
  return profileVal(d);
}

String _populatedName(dynamic v) {
  if (v is Map) return profileVal(v['name'] ?? v['title']);
  return profileVal(v);
}

String formatProfileDate(dynamic v) {
  if (v == null) return '—';
  final d = DateTime.tryParse(v.toString());
  if (d == null) return v.toString();
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
}

String formatProfileDateTime(dynamic v) {
  if (v == null) return '—';
  final d = DateTime.tryParse(v.toString());
  if (d == null) return v.toString();
  return '${formatProfileDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String formatMoney(dynamic v) {
  if (v == null || v.toString().trim().isEmpty) return '—';
  final n = num.tryParse(v.toString()) ?? 0;
  return '₹${n.round()}';
}
