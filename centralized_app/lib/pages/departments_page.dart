import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';

class DepartmentsPage extends StatefulWidget {
  const DepartmentsPage({super.key});

  @override
  State<DepartmentsPage> createState() => _DepartmentsPageState();
}

class _DepartmentsPageState extends State<DepartmentsPage> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _designations = [];
  final List<String> _customDepartments = ['Engineering', 'Sales & Marketing', 'Human Resources', 'Operations', 'Finance & Accounts', 'Design & UX'];

  bool _loading = true;
  String? _error;
  final TextEditingController _newDeptCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _newDeptCtrl.dispose();
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
        session.api!.fetchEmployees().catchError((_) => <Map<String, dynamic>>[]),
        session.api!.fetchDesignations().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _employees = results[0];
        _designations = results[1];
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

  List<String> get _allDepartmentNames {
    final set = <String>{};
    for (final d in _customDepartments) {
      if (d.trim().isNotEmpty) set.add(d.trim());
    }
    for (final e in _employees) {
      final dept = (e['department'] ?? '').toString().trim();
      if (dept.isNotEmpty) set.add(dept);
    }
    for (final desig in _designations) {
      final dept = (desig['department'] ?? '').toString().trim();
      if (dept.isNotEmpty) set.add(dept);
    }
    return set.toList()..sort();
  }

  void _addDepartment() {
    final name = _newDeptCtrl.text.trim();
    if (name.isEmpty) return;
    if (!_customDepartments.any((d) => d.toLowerCase() == name.toLowerCase())) {
      setState(() {
        _customDepartments.add(name);
        _newDeptCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Department "$name" added!')));
    }
  }

  void _removeDepartment(String name) {
    setState(() {
      _customDepartments.removeWhere((d) => d == name);
    });
  }

  @override
  Widget build(BuildContext context) {
    final departments = _allDepartmentNames;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Departments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
              // Create Department Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Create New Department', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newDeptCtrl,
                            decoration: InputDecoration(
                              hintText: 'Department name (e.g. Operations)',
                              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addDepartment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Department Count Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.domain, color: Color(0xFF4F46E5), size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Total Active Departments: ${departments.length}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3730A3)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Departments List Body
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
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: departments.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final deptName = departments[idx];
                    final isCustom = _customDepartments.contains(deptName);

                    final empCount = _employees.where((e) {
                      final d = (e['department'] ?? '').toString();
                      return d.toLowerCase() == deptName.toLowerCase();
                    }).length;

                    final desigCount = _designations.where((d) {
                      final dept = (d['department'] ?? '').toString();
                      return dept.toLowerCase() == deptName.toLowerCase();
                    }).length;

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
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.corporate_fare, color: Color(0xFF2563EB), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(deptName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                const SizedBox(height: 2),
                                Text('$empCount employees · $desigCount designations', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          if (isCustom)
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                              onPressed: () => _removeDepartment(deptName),
                              tooltip: 'Remove custom department',
                            ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
