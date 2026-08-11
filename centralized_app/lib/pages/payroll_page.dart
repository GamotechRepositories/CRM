import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../auth/role_access.dart';

const kMonthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class PayrollPage extends StatefulWidget {
  const PayrollPage({super.key});

  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  List<Map<String, dynamic>> _salaries = [];
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = '';

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
        session.api!.fetchSalaries(),
        session.api!.fetchEmployees().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _salaries = results[0];
        _employees = results[1];
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

  List<Map<String, dynamic>> get _filteredSalaries {
    return _salaries.where((s) {
      final status = (s['status'] ?? 'Unpaid').toString();
      if (_statusFilter.isNotEmpty && status != _statusFilter) return false;
      return true;
    }).toList();
  }

  Map<String, dynamic> get _stats {
    final total = _salaries.length;
    final paid = _salaries.where((s) => (s['status'] ?? '') == 'Paid').length;
    final unpaid = total - paid;
    final totalAmount = _salaries.fold<double>(0.0, (sum, s) => sum + (double.tryParse('${s['amount']}') ?? 0.0));

    return {
      'total': total,
      'paid': paid,
      'unpaid': unpaid,
      'amount': totalAmount,
    };
  }

  String _fmtINR(num n) {
    return '₹${n.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  Future<void> _toggleStatus(Map<String, dynamic> salary) async {
    final session = context.read<AuthSession>();
    final id = (salary['_id'] ?? '').toString();
    final currentStatus = (salary['status'] ?? 'Unpaid').toString();
    final newStatus = currentStatus == 'Paid' ? 'Unpaid' : 'Paid';

    try {
      await session.api!.updateSalary(id, {
        ...salary,
        'status': newStatus,
      });
      if (mounted) {
        _fetchData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    }
  }

  Future<void> _deleteSalary(String id) async {
    final session = context.read<AuthSession>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Salary Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this salary record?'),
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
      await session.api!.deleteSalary(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salary record deleted')));
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

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final filtered = _filteredSalaries;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Employee Payroll & Salaries', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: () => _showAddSalaryModal(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Salary', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
              // Stat Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Total Payroll',
                      value: _fmtINR(stats['amount'] as num),
                      subtitle: '${stats['total']} records',
                      icon: Icons.payments,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Paid / Pending',
                      value: '${stats['paid']} Paid',
                      subtitle: '${stats['unpaid']} Pending Unpaid',
                      icon: Icons.check_circle,
                      iconBg: const Color(0xFFECFDF5),
                      iconColor: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Filter Controls
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _statusFilter,
                  decoration: InputDecoration(
                    labelText: 'Payment Status',
                    labelStyle: const TextStyle(fontSize: 11),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All Statuses', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Paid', child: Text('Paid', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Unpaid', child: Text('Unpaid', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _statusFilter = v ?? ''),
                ),
              ),
              const SizedBox(height: 14),

              // Salary Records Body
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
                    children: const [
                      Icon(Icons.badge_outlined, size: 48, color: Color(0xFF94A3B8)),
                      SizedBox(height: 10),
                      Text(
                        'No salary records found',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
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
                    final item = filtered[idx];
                    return _buildSalaryCard(item);
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

  Widget _buildSalaryCard(Map<String, dynamic> item) {
    final id = (item['_id'] ?? '').toString();
    final emp = item['employee'];
    final empName = emp is Map ? (emp['name'] ?? 'Employee').toString() : 'Employee';
    final desig = emp is Map ? RoleAccess.designationTitle(emp.cast<String, dynamic>()) : '';
    final amount = double.tryParse('${item['amount']}') ?? 0.0;
    final status = (item['status'] ?? 'Unpaid').toString();
    final monthIdx = int.tryParse('${item['month']}') ?? 0;
    final monthName = (monthIdx >= 1 && monthIdx <= 12) ? kMonthNames[monthIdx] : '—';
    final year = (item['year'] ?? '').toString();

    final isPaid = status == 'Paid';

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
                  radius: 18,
                  backgroundColor: const Color(0xFFEEF2FF),
                  child: Text(
                    empName.isNotEmpty ? empName[0].toUpperCase() : 'E',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5), fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(empName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      if (desig.isNotEmpty)
                        Text(desig, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPaid ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isPaid ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isPaid ? const Color(0xFF047857) : const Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Period', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    Text('$monthName $year', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Salary Amount', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    Text(_fmtINR(amount), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _toggleStatus(item),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: isPaid ? const Color(0xFFB45309) : const Color(0xFF059669),
                  ),
                  child: Text(isPaid ? 'Mark Unpaid' : 'Mark Paid', style: const TextStyle(fontSize: 11)),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                  onPressed: () => _deleteSalary(id),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSalaryModal(BuildContext context) {
    String empId = '';
    final amountCtrl = TextEditingController();
    int month = DateTime.now().month;
    int year = DateTime.now().year;
    String status = 'Unpaid';
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
                        const Text('Add Salary Record', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: empId,
                      decoration: const InputDecoration(labelText: 'Employee *', isDense: true),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('Select Employee', style: TextStyle(fontSize: 11))),
                        ..._employees.map((e) => DropdownMenuItem(
                              value: (e['_id'] ?? '').toString(),
                              child: Text((e['name'] ?? '—').toString(), style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (v) => empId = v ?? '',
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Salary Amount (₹) *', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            initialValue: month,
                            decoration: const InputDecoration(labelText: 'Month', isDense: true),
                            items: List.generate(12, (index) => index + 1)
                                .map((m) => DropdownMenuItem(value: m, child: Text(kMonthNames[m], style: const TextStyle(fontSize: 11))))
                                .toList(),
                            onChanged: (v) => month = v ?? month,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            initialValue: year,
                            decoration: const InputDecoration(labelText: 'Year', isDense: true),
                            items: [year - 1, year, year + 1]
                                .map((y) => DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 11))))
                                .toList(),
                            onChanged: (v) => year = v ?? year,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Initial Status', isDense: true),
                      items: const [
                        DropdownMenuItem(value: 'Unpaid', child: Text('Unpaid', style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(value: 'Paid', child: Text('Paid', style: TextStyle(fontSize: 11))),
                      ],
                      onChanged: (v) => status = v ?? status,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                                if (empId.isEmpty || amt <= 0) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Employee and Valid Amount are required')),
                                  );
                                  return;
                                }

                                setModalState(() => saving = true);
                                final session = context.read<AuthSession>();
                                try {
                                  await session.api!.createSalary({
                                    'employee': empId,
                                    'amount': amt,
                                    'month': month,
                                    'year': year,
                                    'status': status,
                                  });

                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Salary record created!')));
                                    Navigator.pop(ctx);
                                  }
                                  if (mounted) {
                                    _fetchData();
                                  }
                                } catch (e) {
                                  setModalState(() => saving = false);
                                  if (ctx.mounted) {
                                    final errMsg = e.toString().replaceFirst('Exception: ', '');
                                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $errMsg')));
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(saving ? 'Saving...' : 'Add Salary Record'),
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
