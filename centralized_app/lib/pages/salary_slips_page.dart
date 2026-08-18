import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../auth/role_access.dart';
import '../utils/salary_calculator.dart';

const _monthNames = [
  '',
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// `/salary-slips` — payslips for the signed-in employee (mirrors web `SalarySlipPage`).
class SalarySlipsPage extends StatefulWidget {
  const SalarySlipsPage({super.key});

  @override
  State<SalarySlipsPage> createState() => _SalarySlipsPageState();
}

class _SalarySlipsPageState extends State<SalarySlipsPage> {
  List<Map<String, dynamic>> _salaries = [];
  List<Map<String, dynamic>> _designations = [];
  Map<String, dynamic> _company = {};
  Map<String, dynamic>? _employee;
  Map<String, dynamic>? _selected;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = context.read<AuthSession>();
    final api = session.api;
    final userId = session.userId;
    if (api == null || userId.isEmpty) {
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
      final salariesFuture = api.fetchSalaries(query: {'employee': userId});
      final companyFuture = api.fetchCompanyProfile();
      final designationsFuture = api.fetchDesignations();
      final profileFuture = api.fetchMyProfile(userId).then(
            (v) => v,
            onError: (_) => <String, dynamic>{},
          );

      final rawSalaries = await salariesFuture;
      final company = await companyFuture;
      final designations = await designationsFuture;
      final profile = await profileFuture;
      final employee = profile['employee'] is Map
          ? Map<String, dynamic>.from(profile['employee'] as Map)
          : session.user;

      final mine = rawSalaries.where((s) => _belongsTo(s, userId)).toList()
        ..sort((a, b) {
          final yearCmp = _int(b['year']).compareTo(_int(a['year']));
          if (yearCmp != 0) return yearCmp;
          return _int(b['month']).compareTo(_int(a['month']));
        });

      Map<String, dynamic>? selected;
      if (mine.isNotEmpty) {
        selected = mine.where((s) => (s['status'] ?? '').toString() == 'Paid').firstOrNull ?? mine.first;
      }

      if (!mounted) return;
      setState(() {
        _salaries = mine;
        _company = company;
        _designations = designations;
        _employee = employee;
        _selected = selected;
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

  bool _belongsTo(Map<String, dynamic> salary, String userId) {
    final empId = _idOf(salary['employee']);
    if (empId.isEmpty) return true;
    return empId == userId;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null && _salaries.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
          const SizedBox(height: 8),
          TextButton(onPressed: _load, child: const Text('Retry', style: TextStyle(fontSize: 12))),
        ],
      );
    }

    final selected = _selected;
    final isPaid = (selected?['status'] ?? '').toString() == 'Paid';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 20),
        children: [
          const Text(
            'My Workspace › Salary Slips',
            style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 4),
          const Text(
            'View your monthly salary slips once HR marks them as paid.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(_error!, style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C))),
            ),
          ],
          const SizedBox(height: 10),
          _RecordsCard(
            salaries: _salaries,
            selected: selected,
            fallbackName: (_employee?['name'] ?? context.read<AuthSession>().userName).toString(),
            onSelect: (s) => setState(() => _selected = s),
          ),
          const SizedBox(height: 10),
          if (selected == null)
            _emptyCard('Select a salary record to view the salary slip.')
          else if (!isPaid)
            _pendingCard(selected)
          else
            _PayslipCard(
              salary: selected,
              employee: _employeeForSlip(selected),
              company: _company,
              designations: _designations,
              sessionUser: context.read<AuthSession>().user,
            ),
        ],
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      ),
    );
  }

  Widget _pendingCard(Map<String, dynamic> salary) {
    final month = _monthLabel(salary['month']);
    final year = salary['year'] ?? '';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xFFFEF3C7), shape: BoxShape.circle),
            child: const Text('⏳', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Salary Payment Pending',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF78350F)),
          ),
          const SizedBox(height: 4),
          Text(
            'Your salary slip for $month $year will become available once HR marks the payment status as Paid.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Color(0xFFB45309), height: 1.4),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _employeeForSlip(Map<String, dynamic> salary) {
    final fromSalary = salary['employee'] is Map
        ? Map<String, dynamic>.from(salary['employee'] as Map)
        : <String, dynamic>{};
    final fromProfile = _employee ?? {};
    return {
      ...fromProfile,
      ...fromSalary,
      if (fromSalary['salaryPayroll'] == null && fromProfile['salaryPayroll'] != null)
        'salaryPayroll': fromProfile['salaryPayroll'],
    };
  }
}

class _RecordsCard extends StatelessWidget {
  const _RecordsCard({
    required this.salaries,
    required this.selected,
    required this.fallbackName,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> salaries;
  final Map<String, dynamic>? selected;
  final String fallbackName;
  final ValueChanged<Map<String, dynamic>> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Records',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          if (salaries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No salary records found.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ),
            )
          else
            ...salaries.map((s) {
              final selectedId = _idOf(selected);
              final isSelected = selectedId.isNotEmpty && _idOf(s) == selectedId;
              final paid = (s['status'] ?? '').toString() == 'Paid';
              final emp = s['employee'];
              final name = emp is Map ? (emp['name'] ?? fallbackName).toString() : fallbackName;
              final amount = _num(s['grossSalary'] ?? s['amount']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () => onSelect(s),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_monthLabel(s['month'])} ${s['year'] ?? ''}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                              Text(name, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                              const SizedBox(height: 2),
                              Text(
                                _fmtINR(amount),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: paid ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            (s['status'] ?? 'Unpaid').toString(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: paid ? const Color(0xFF047857) : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _PayslipCard extends StatelessWidget {
  const _PayslipCard({
    required this.salary,
    required this.employee,
    required this.company,
    required this.designations,
    required this.sessionUser,
  });

  final Map<String, dynamic> salary;
  final Map<String, dynamic> employee;
  final Map<String, dynamic> company;
  final List<Map<String, dynamic>> designations;
  final Map<String, dynamic>? sessionUser;

  @override
  Widget build(BuildContext context) {
    final structure = getSalaryStructure({
      ...salary,
      if (salary['components'] == null && employee['salaryPayroll'] is Map)
        'salaryPayroll': employee['salaryPayroll'],
    });
    final payroll = employee['salaryPayroll'] is Map
        ? Map<String, dynamic>.from(employee['salaryPayroll'] as Map)
        : const <String, dynamic>{};
    final companyName = (company['companyName'] ?? 'Organization').toString();
    final month = _monthLabel(salary['month']);
    final year = salary['year'] ?? '';
    final rowCount = structure.components.length > structure.deductions.length
        ? structure.components.length
        : structure.deductions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: _cardDecoration,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Salary Slip — $month $year',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const Text(
                      '✓ Status: Paid',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD1D5DB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_str(company['companyLogo']).isNotEmpty) ...[
                          Image.network(
                            _str(company['companyLogo']),
                            height: 36,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          companyName.toUpperCase(),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                        ),
                        if (_str(company['address']).isNotEmpty)
                          Text(_str(company['address']), style: const TextStyle(fontSize: 10, color: Color(0xFF374151))),
                        if (_str(company['email']).isNotEmpty)
                          Text('Email: ${_str(company['email'])}', style: const TextStyle(fontSize: 10, color: Color(0xFF4B5563))),
                        if (_str(company['phone']).isNotEmpty)
                          Text('Phone: ${_str(company['phone'])}', style: const TextStyle(fontSize: 10, color: Color(0xFF4B5563))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.only(left: 10),
                    decoration: const BoxDecoration(
                      border: Border(left: BorderSide(color: Color(0xFF2563EB), width: 2)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('OFFICIAL DOCUMENT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                        Text('PAYSLIP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('$month $year', style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563))),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    _meta('Employee Name', _str(employee['name'] ?? sessionUser?['name'], fallback: '—')),
                    _meta('Employee Code / ID', _str(employee['employeeCode'] ?? employee['_id'] ?? employee['id'])),
                    _meta('Designation', _designationTitle(employee['designation'], designations)),
                    _meta('Department', _str(employee['department'])),
                    _meta('Date of Joining', _fmtDate(employee['dateOfJoining'])),
                    _meta('Employee PAN', _str(payroll['panNumber'] ?? employee['panNumber'])),
                    _meta('Bank Account Details', _str(payroll['bankAccountDetails'] ?? employee['bankAccountNumber'])),
                    _meta('Payment Method', _str(salary['paymentMode'], fallback: 'Bank Transfer')),
                    _meta('Payment Status', 'PAID', valueColor: const Color(0xFF15803D)),
                    _meta('Payment Date', _fmtDate(salary['paymentDate'] ?? salary['updatedAt'])),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'EARNINGS & EMPLOYEE DEDUCTIONS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: Color(0xFF1F2937)),
              ),
              const SizedBox(height: 6),
              Table(
                border: TableBorder.all(color: const Color(0xFFD1D5DB), width: 0.6),
                columnWidths: const {
                  0: FlexColumnWidth(1.4),
                  1: FlexColumnWidth(0.9),
                  2: FlexColumnWidth(1.4),
                  3: FlexColumnWidth(0.9),
                },
                children: [
                  _tableHeader(['EARNINGS', 'AMOUNT', 'DEDUCTION', 'AMOUNT']),
                  for (var i = 0; i < rowCount; i++)
                    _tableRow([
                      i < structure.components.length ? structure.components[i].name : '—',
                      i < structure.components.length ? _fmtINR(structure.components[i].amount) : '—',
                      i < structure.deductions.length ? structure.deductions[i].name : '—',
                      i < structure.deductions.length ? _fmtINR(structure.deductions[i].amount) : '—',
                    ]),
                  _tableRow(
                    [
                      'GROSS SALARY',
                      _fmtINR(structure.grossSalary),
                      'TOTAL DEDUCTIONS',
                      _fmtINR(structure.totalDeductions),
                    ],
                    bold: true,
                    fill: const Color(0xFFF9FAFB),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'EMPLOYER CONTRIBUTIONS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: Color(0xFF1F2937)),
              ),
              const SizedBox(height: 6),
              Table(
                border: TableBorder.all(color: const Color(0xFFD1D5DB), width: 0.6),
                columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
                children: [
                  _tableHeader(['CONTRIBUTION TYPE', 'AMOUNT']),
                  for (final line in structure.employerContributions)
                    _tableRow([line.name, _fmtINR(line.amount)]),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _summaryChip('Net Salary', structure.netSalary, const Color(0xFFF0FDF4), const Color(0xFF15803D))),
                  const SizedBox(width: 6),
                  Expanded(child: _summaryChip('Monthly CTC', structure.monthlyCTC, const Color(0xFFEFF6FF), const Color(0xFF1D4ED8))),
                  const SizedBox(width: 6),
                  Expanded(child: _summaryChip('Annual CTC', structure.annualCTC, const Color(0xFFFAF5FF), const Color(0xFF7E22CE))),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'This is a computer-generated payslip issued by $companyName and does not require a physical ink signature.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _meta(String label, String value, {Color? valueColor}) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
          Text(
            value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: valueColor ?? const Color(0xFF111827)),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, double amount, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(height: 2),
          FittedBox(
            child: Text(_fmtINR(amount), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: fg)),
          ),
        ],
      ),
    );
  }
}

TableRow _tableHeader(List<String> cells) {
  return TableRow(
    decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
    children: cells
        .map(
          (c) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            child: Text(c, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
          ),
        )
        .toList(),
  );
}

TableRow _tableRow(List<String> cells, {bool bold = false, Color? fill}) {
  return TableRow(
    decoration: fill != null ? BoxDecoration(color: fill) : null,
    children: cells.asMap().entries.map((e) {
      final right = e.key.isOdd;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Text(
          e.value,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontSize: 10,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: const Color(0xFF111827),
          ),
        ),
      );
    }).toList(),
  );
}

final _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(10),
  border: Border.all(color: const Color(0xFFE2E8F0)),
);

String _idOf(dynamic v) {
  if (v is Map) return '${v['_id'] ?? v['id'] ?? ''}';
  return v?.toString() ?? '';
}

int _int(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? 0}') ?? 0;
}

String _str(dynamic v, {String fallback = '—'}) {
  if (v == null) return fallback;
  final s = v.toString().trim();
  return s.isEmpty ? fallback : s;
}

String _monthLabel(dynamic month) {
  final i = _int(month);
  if (i >= 1 && i <= 12) return _monthNames[i];
  return '—';
}

String _fmtINR(num n) {
  final rounded = n.round().toString();
  final withCommas = rounded.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  return '₹$withCommas';
}

String _fmtDate(dynamic v) {
  if (v == null || v.toString().trim().isEmpty) return '—';
  final d = DateTime.tryParse(v.toString());
  if (d == null) return v.toString();
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String _designationTitle(dynamic desig, List<Map<String, dynamic>> designations) {
  if (desig is Map) {
    return RoleAccess.designationTitle(desig.cast<String, dynamic>());
  }
  final raw = desig?.toString().trim() ?? '';
  if (raw.isEmpty) return '—';
  if (RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(raw)) {
    for (final d in designations) {
      if (_idOf(d) == raw) {
        return (d['title'] ?? d['designationName'] ?? d['name'] ?? '—').toString();
      }
    }
    return '—';
  }
  return raw;
}
