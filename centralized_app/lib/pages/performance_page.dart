import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../auth/role_access.dart';
import '../utils/task_status.dart';

class PerformancePage extends StatefulWidget {
  const PerformancePage({super.key});

  @override
  State<PerformancePage> createState() => _PerformancePageState();
}

class _PerformancePageState extends State<PerformancePage> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  String? _error;

  String _selectedEmployeeId = '';
  String _searchQuery = '';

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
        session.api!.fetchTasks(),
      ]);

      if (!mounted) return;
      setState(() {
        _employees = results[0];
        _tasks = results[1];
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

  List<Map<String, dynamic>> get _employeePerformanceList {
    final map = <String, Map<String, dynamic>>{};

    for (final emp in _employees) {
      final id = (emp['_id'] ?? '').toString();
      if (id.isEmpty) continue;
      map[id] = {
        'employee': emp,
        'completedTasks': 0,
        'totalTasks': 0,
        'onTimeTasks': 0,
        'totalRating': 0.0,
        'ratedCount': 0,
      };
    }

    for (final task in _tasks) {
      final emp = task['employee'] ?? task['assignedTo'];
      final empId = emp is Map ? (emp['_id'] ?? '').toString() : (emp ?? '').toString();
      if (empId.isEmpty || !map.containsKey(empId)) continue;

      final data = map[empId]!;
      data['totalTasks'] = (data['totalTasks'] as int) + 1;

      final status = TaskStatus.normalize(task['status']);
      if (status == 'Completed') {
        data['completedTasks'] = (data['completedTasks'] as int) + 1;

        final rating = double.tryParse('${task['rating']}') ?? 0.0;
        if (rating > 0) {
          data['totalRating'] = (data['totalRating'] as double) + rating;
          data['ratedCount'] = (data['ratedCount'] as int) + 1;
        }

        if (!TaskStatus.isDelayed(task)) {
          data['onTimeTasks'] = (data['onTimeTasks'] as int) + 1;
        }
      }
    }

    var list = map.values.where((item) {
      if (_selectedEmployeeId.isNotEmpty) {
        final empId = (item['employee']['_id'] ?? '').toString();
        if (empId != _selectedEmployeeId) return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final name = (item['employee']['name'] ?? '').toString().toLowerCase();
        final email = (item['employee']['email'] ?? '').toString().toLowerCase();
        final desig = RoleAccess.designationTitle(item['employee']).toLowerCase();
        return name.contains(q) || email.contains(q) || desig.contains(q);
      }
      return true;
    }).toList();

    list.sort((a, b) => (b['completedTasks'] as int).compareTo(a['completedTasks'] as int));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final performanceList = _employeePerformanceList;
    final totalCompleted = performanceList.fold<int>(0, (sum, i) => sum + (i['completedTasks'] as int));
    final totalAssigned = performanceList.fold<int>(0, (sum, i) => sum + (i['totalTasks'] as int));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Employee Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
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
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Tasks Delivered',
                      value: '$totalCompleted',
                      subtitle: 'Of $totalAssigned assigned',
                      icon: Icons.task_alt,
                      iconBg: const Color(0xFFECFDF5),
                      iconColor: const Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Avg On-Time Rate',
                      value: totalCompleted > 0
                          ? '${((performanceList.fold<int>(0, (sum, i) => sum + (i['onTimeTasks'] as int)) / totalCompleted) * 100).toStringAsFixed(0)}%'
                          : '100%',
                      subtitle: 'On-schedule delivery',
                      icon: Icons.bolt,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Filter Toolbar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search employee performance...',
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _selectedEmployeeId,
                            decoration: InputDecoration(
                              labelText: 'Employee',
                              labelStyle: const TextStyle(fontSize: 11),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: [
                              const DropdownMenuItem(value: '', child: Text('All Employees', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              ..._employees.map((e) => DropdownMenuItem(
                                    value: (e['_id'] ?? '').toString(),
                                    child: Text((e['name'] ?? '—').toString(), style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                                  )),
                            ],
                            onChanged: (v) => setState(() => _selectedEmployeeId = v ?? ''),
                          ),
                        ),
                        if (_selectedEmployeeId.isNotEmpty || _searchQuery.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => setState(() {
                              _selectedEmployeeId = '';
                              _searchQuery = '';
                              _searchCtrl.clear();
                            }),
                            child: const Text('Reset', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Performance Cards List
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text('Error: $_error', style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
                )
              else if (performanceList.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.stars_outlined, size: 48, color: Color(0xFF94A3B8)),
                      SizedBox(height: 10),
                      Text(
                        'No performance records found',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: performanceList.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final item = performanceList[idx];
                    return _buildPerformanceCard(item);
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(Map<String, dynamic> item) {
    final emp = item['employee'] as Map<String, dynamic>;
    final name = (emp['name'] ?? 'Unnamed Employee').toString();
    final desig = RoleAccess.designationTitle(emp);
    final dept = (emp['department'] ?? 'General').toString();
    final photo = emp['profilePhoto']?.toString();

    final completed = item['completedTasks'] as int;
    final total = item['totalTasks'] as int;
    final onTime = item['onTimeTasks'] as int;
    final ratedCount = item['ratedCount'] as int;
    final totalRating = item['totalRating'] as double;
    final avgRating = ratedCount > 0 ? totalRating / ratedCount : 4.5;
    final onTimePct = completed > 0 ? ((onTime / completed) * 100).round() : 100;

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
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFDBEAFE),
                  backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
                  child: photo == null || photo.isEmpty
                      ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'E', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text('$desig · $dept', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                _buildStarRating(avgRating),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tasks Done', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      Text('$completed / $total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('On-Time Delivery', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      Text('$onTimePct%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Avg Rating', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      Text('${avgRating.toStringAsFixed(1)} ★', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        return Icon(
          starValue <= rating.round() ? Icons.star : Icons.star_border,
          size: 16,
          color: const Color(0xFFF59E0B),
        );
      }),
    );
  }
}
