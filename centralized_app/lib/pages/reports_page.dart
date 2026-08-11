import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../auth/role_access.dart';

const kMonthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  List<Map<String, dynamic>> _billings = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _salaries = [];

  bool _loading = true;
  String? _error;

  String _periodType = 'monthly'; // 'monthly', 'quarterly', 'yearly'
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month - 1; // 0-based
  int _selectedQuarter = ((DateTime.now().month - 1) ~/ 3) + 1; // 1..4
  String _reportTab = 'finance'; // 'finance', 'employees'

  @override
  void initState() {
    super.initState();
    _fetchData();
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
        session.api!.fetchBillings(),
        session.api!.fetchEmployees().catchError((_) => <Map<String, dynamic>>[]),
        session.api!.fetchExpenses().catchError((_) => <Map<String, dynamic>>[]),
        session.api!.fetchTasks().catchError((_) => <Map<String, dynamic>>[]),
        session.api!.fetchSalaries().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _billings = results[0];
        _employees = results[1];
        _expenses = results[2];
        _tasks = results[3];
        _salaries = results[4];
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

  bool _isInPeriod(DateTime date) {
    if (_periodType == 'monthly') {
      return date.year == _selectedYear && date.month == (_selectedMonth + 1);
    } else if (_periodType == 'quarterly') {
      if (date.year != _selectedYear) return false;
      final q = ((date.month - 1) ~/ 3) + 1;
      return q == _selectedQuarter;
    } else {
      return date.year == _selectedYear;
    }
  }

  bool _isRawDateInPeriod(dynamic raw) {
    if (raw == null) return false;
    final d = DateTime.tryParse(raw.toString());
    if (d == null) return false;
    return _isInPeriod(d);
  }

  List<Map<String, dynamic>> get _periodBillings => _billings.where((b) {
        final pay = b['paymentDetails'];
        final date = pay is Map ? (pay['paymentDate'] ?? b['createdAt']) : b['createdAt'];
        return _isRawDateInPeriod(date);
      }).toList();

  List<Map<String, dynamic>> get _periodExpenses => _expenses.where((e) {
        return _isRawDateInPeriod(e['date'] ?? e['createdAt']);
      }).toList();

  List<Map<String, dynamic>> get _periodSalaries => _salaries.where((s) {
        final yr = int.tryParse('${s['year']}') ?? 0;
        final m = int.tryParse('${s['month']}') ?? 0;
        if (yr != _selectedYear) return false;
        if (_periodType == 'monthly') return m == (_selectedMonth + 1);
        if (_periodType == 'quarterly') return ((m - 1) ~/ 3) + 1 == _selectedQuarter;
        return true;
      }).toList();

  List<Map<String, dynamic>> get _periodTasks => _tasks.where((t) {
        return _isRawDateInPeriod(t['completedAt'] ?? t['updatedAt'] ?? t['createdAt']);
      }).toList();

  double get _totalRevenue {
    double sum = 0;
    for (final b in _periodBillings) {
      final pay = b['paymentDetails'];
      if (pay is Map) {
        sum += double.tryParse('${pay['amount']}') ?? 0.0;
      }
    }
    return sum;
  }

  double get _totalSalaries {
    double sum = 0;
    for (final s in _periodSalaries) {
      sum += double.tryParse('${s['amount']}') ?? 0.0;
    }
    return sum;
  }

  double get _totalExpenses {
    double sum = 0;
    for (final e in _periodExpenses) {
      sum += double.tryParse('${e['amount']}') ?? 0.0;
    }
    return sum;
  }

  List<Map<String, dynamic>> get _revenueByClient {
    final clientMap = <String, Map<String, dynamic>>{};
    final totalRev = _totalRevenue;

    for (final b in _periodBillings) {
      final pay = b['paymentDetails'];
      final amt = pay is Map ? (double.tryParse('${pay['amount']}') ?? 0.0) : 0.0;
      if (amt <= 0) continue;

      final client = b['client'];
      final name = client is Map ? (client['clientName'] ?? client['name'] ?? 'Client').toString() : 'Client';

      if (!clientMap.containsKey(name)) {
        clientMap[name] = {'client': name, 'amount': 0.0, 'count': 0};
      }
      clientMap[name]!['amount'] = (clientMap[name]!['amount'] as double) + amt;
      clientMap[name]!['count'] = (clientMap[name]!['count'] as int) + 1;
    }

    final list = clientMap.values.map((item) {
      final amt = item['amount'] as double;
      final pct = totalRev > 0 ? (amt / totalRev) * 100 : 0.0;
      return {
        ...item,
        'percentage': pct,
      };
    }).toList();

    list.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
    return list;
  }

  List<Map<String, dynamic>> get _expenseByCategory {
    final catMap = <String, double>{};

    for (final e in _periodExpenses) {
      final cat = (e['category'] ?? 'Other').toString();
      final amt = double.tryParse('${e['amount']}') ?? 0.0;
      catMap[cat] = (catMap[cat] ?? 0.0) + amt;
    }

    final list = catMap.entries.map((e) => {'category': e.key, 'amount': e.value}).toList();
    list.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
    return list;
  }

  String _fmtINR(num n) {
    return '₹${n.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  String get _periodLabel {
    if (_periodType == 'monthly') {
      return '${kMonthNames[_selectedMonth]} $_selectedYear';
    } else if (_periodType == 'quarterly') {
      return 'Q$_selectedQuarter $_selectedYear';
    } else {
      return 'Year $_selectedYear';
    }
  }

  @override
  Widget build(BuildContext context) {
    final revenue = _totalRevenue;
    final salaries = _totalSalaries;
    final expenses = _totalExpenses;
    final netAmount = revenue - salaries - expenses;

    final revClients = _revenueByClient;
    final expCats = _expenseByCategory;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Reports & Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
              // Period Filter Toolbar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                _periodTypeButton('monthly', 'Monthly'),
                                _periodTypeButton('quarterly', 'Quarterly'),
                                _periodTypeButton('yearly', 'Yearly'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            initialValue: _selectedYear,
                            decoration: const InputDecoration(labelText: 'Year', isDense: true),
                            items: [2024, 2025, 2026, 2027]
                                .map((y) => DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 11))))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedYear = v ?? _selectedYear),
                          ),
                        ),
                        if (_periodType == 'monthly') ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              initialValue: _selectedMonth,
                              decoration: const InputDecoration(labelText: 'Month', isDense: true),
                              items: List.generate(12, (i) => i)
                                  .map((i) => DropdownMenuItem(value: i, child: Text(kMonthNames[i], style: const TextStyle(fontSize: 11))))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedMonth = v ?? _selectedMonth),
                            ),
                          ),
                        ],
                        if (_periodType == 'quarterly') ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              initialValue: _selectedQuarter,
                              decoration: const InputDecoration(labelText: 'Quarter', isDense: true),
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('Q1 (Jan–Mar)', style: TextStyle(fontSize: 11))),
                                DropdownMenuItem(value: 2, child: Text('Q2 (Apr–Jun)', style: TextStyle(fontSize: 11))),
                                DropdownMenuItem(value: 3, child: Text('Q3 (Jul–Sep)', style: TextStyle(fontSize: 11))),
                                DropdownMenuItem(value: 4, child: Text('Q4 (Oct–Dec)', style: TextStyle(fontSize: 11))),
                              ],
                              onChanged: (v) => setState(() => _selectedQuarter = v ?? _selectedQuarter),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Report Tab Switcher
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() => _reportTab = 'finance'),
                      icon: const Icon(Icons.attach_money, size: 16),
                      label: const Text('Finance Report', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _reportTab == 'finance' ? const Color(0xFF2563EB) : Colors.white,
                        foregroundColor: _reportTab == 'finance' ? Colors.white : const Color(0xFF475569),
                        elevation: 0,
                        side: BorderSide(color: _reportTab == 'finance' ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() => _reportTab = 'employees'),
                      icon: const Icon(Icons.people_alt, size: 16),
                      label: const Text('Employee Report', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _reportTab == 'employees' ? const Color(0xFF2563EB) : Colors.white,
                        foregroundColor: _reportTab == 'employees' ? Colors.white : const Color(0xFF475569),
                        elevation: 0,
                        side: BorderSide(color: _reportTab == 'employees' ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

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
              else if (_reportTab == 'finance') ...[
                // FINANCE REPORT TAB
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
                            title: 'Revenue Generated',
                            value: _fmtINR(revenue),
                            subtitle: '${_periodBillings.length} billings · $_periodLabel',
                            icon: Icons.trending_up,
                            iconBg: const Color(0xFFECFDF5),
                            iconColor: const Color(0xFF059669),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            title: 'Payroll Salaries',
                            value: _fmtINR(salaries),
                            subtitle: '${_periodSalaries.length} records',
                            icon: Icons.payments,
                            iconBg: const Color(0xFFFFFBEB),
                            iconColor: const Color(0xFFD97706),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            title: 'Other Expenses',
                            value: _fmtINR(expenses),
                            subtitle: '${_periodExpenses.length} records',
                            icon: Icons.money_off,
                            iconBg: const Color(0xFFFEF2F2),
                            iconColor: const Color(0xFFDC2626),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            title: 'Net Margin',
                            value: _fmtINR(netAmount),
                            subtitle: 'Rev − Salary − Exp',
                            icon: netAmount >= 0 ? Icons.account_balance : Icons.warning_amber,
                            iconBg: netAmount >= 0 ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2),
                            iconColor: netAmount >= 0 ? const Color(0xFF2563EB) : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Revenue by Client Progress Cards
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Revenue by Client', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text(_periodLabel, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (revClients.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: Text('No client revenue in this period', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: revClients.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 10),
                          itemBuilder: (context, idx) {
                            final item = revClients[idx];
                            final clientName = item['client'] as String;
                            final amt = item['amount'] as double;
                            final pct = item['percentage'] as double;
                            final count = item['count'] as int;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(clientName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                    Text('${_fmtINR(amt)} (${pct.toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: (pct / 100).clamp(0.02, 1.0),
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  color: const Color(0xFF2563EB),
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                const SizedBox(height: 2),
                                Text('$count payment(s)', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Expense by Category Breakdown
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
                      const Text('Expense by Category', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 12),
                      if (expCats.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: Text('No expenses recorded in this period', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: expCats.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final item = expCats[idx];
                            final cat = item['category'] as String;
                            final amt = item['amount'] as double;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(cat, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                  Text(_fmtINR(amt), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ] else ...[
                // EMPLOYEE REPORT TAB
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Active Team',
                        value: '${_employees.length}',
                        subtitle: 'Employees',
                        icon: Icons.people,
                        iconBg: const Color(0xFFEFF6FF),
                        iconColor: const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Tasks Delivered',
                        value: '${_periodTasks.length}',
                        subtitle: 'In $_periodLabel',
                        icon: Icons.task_alt,
                        iconBg: const Color(0xFFECFDF5),
                        iconColor: const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _employees.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final emp = _employees[idx];
                    final name = (emp['name'] ?? 'Employee').toString();
                    final desig = RoleAccess.designationTitle(emp);
                    final empId = (emp['_id'] ?? '').toString();

                    final empTasks = _periodTasks.where((t) {
                      final assigned = t['employee'] ?? t['assignedTo'];
                      final id = assigned is Map ? (assigned['_id'] ?? '').toString() : (assigned ?? '').toString();
                      return id == empId;
                    }).toList();

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFDBEAFE),
                            child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'E', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                Text(desig, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${empTasks.length} tasks', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                              const Text('Completed', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodTypeButton(String type, String label) {
    final active = _periodType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _periodType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: active ? Colors.white : const Color(0xFF64748B)),
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
      padding: const EdgeInsets.all(10),
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
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 14, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ),
          Text(subtitle, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}
