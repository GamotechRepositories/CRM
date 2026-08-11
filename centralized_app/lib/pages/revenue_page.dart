import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';

class RevenuePage extends StatefulWidget {
  const RevenuePage({super.key});

  @override
  State<RevenuePage> createState() => _RevenuePageState();
}

class _RevenuePageState extends State<RevenuePage> {
  List<Map<String, dynamic>> _billings = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _expenses = [];
  bool _loading = true;
  String? _error;

  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, 1);
    _dateTo = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
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
      ]);

      if (!mounted) return;
      setState(() {
        _billings = results[0];
        _employees = results[1];
        _expenses = results[2];
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

  bool _isWithinRange(dynamic raw) {
    if (raw == null) return false;
    final d = DateTime.tryParse(raw.toString());
    if (d == null) return false;

    if (_dateFrom != null && d.isBefore(_dateFrom!)) return false;
    if (_dateTo != null && d.isAfter(_dateTo!)) return false;
    return true;
  }

  List<Map<String, dynamic>> get _filteredBillings => _billings.where((b) {
        final pay = b['paymentDetails'];
        final date = pay is Map ? (pay['paymentDate'] ?? b['createdAt']) : b['createdAt'];
        return _isWithinRange(date);
      }).toList();

  List<Map<String, dynamic>> get _filteredExpenses => _expenses.where((e) {
        return _isWithinRange(e['date'] ?? e['createdAt']);
      }).toList();

  double get _totalRevenue {
    double sum = 0;
    for (final b in _filteredBillings) {
      final pay = b['paymentDetails'];
      if (pay is Map) {
        sum += double.tryParse('${pay['amount']}') ?? 0.0;
      }
    }
    return sum;
  }

  double get _totalSalaries {
    double sum = 0;
    for (final emp in _employees) {
      sum += double.tryParse('${emp['salary']}') ?? 0.0;
    }
    return sum;
  }

  double get _totalExpenses {
    double sum = 0;
    for (final e in _filteredExpenses) {
      sum += double.tryParse('${e['amount']}') ?? 0.0;
    }
    return sum;
  }

  String _fmtINR(num n) {
    return '₹${n.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  String _fmtDate(dynamic raw) {
    if (raw == null) return '—';
    final d = DateTime.tryParse(raw.toString());
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final revenue = _totalRevenue;
    final salaries = _totalSalaries;
    final expenses = _totalExpenses;
    final netAmount = revenue - salaries - expenses;

    final transactions = _filteredBillings.where((b) {
      final pay = b['paymentDetails'];
      return pay is Map && (double.tryParse('${pay['amount']}') ?? 0) > 0;
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse('${a['paymentDetails']?['paymentDate'] ?? a['createdAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = DateTime.tryParse('${b['paymentDetails']?['paymentDate'] ?? b['createdAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Revenue & Financial Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
              // Date Filter Container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dateFrom == null ? 'All Time' : 'Range: ${_fmtDate(_dateFrom)} - ${_fmtDate(_dateTo)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          final now = DateTime.now();
                          _dateFrom = DateTime(now.year, now.month, 1);
                          _dateTo = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('Current Month', style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _dateFrom = null;
                          _dateTo = null;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('All Time', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // KPI Stats Grid
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
                          title: 'Total Revenue',
                          value: _fmtINR(revenue),
                          subtitle: '${transactions.length} payments',
                          icon: Icons.trending_up,
                          iconBg: const Color(0xFFECFDF5),
                          iconColor: const Color(0xFF059669),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _buildStatCard(
                          title: 'Total Salaries',
                          value: _fmtINR(salaries),
                          subtitle: 'Payroll Expenses',
                          icon: Icons.badge,
                          iconBg: const Color(0xFFFFFBEB),
                          iconColor: const Color(0xFFD97706),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _buildStatCard(
                          title: 'Other Expenses',
                          value: _fmtINR(expenses),
                          subtitle: 'Operational',
                          icon: Icons.money_off,
                          iconBg: const Color(0xFFFEF2F2),
                          iconColor: const Color(0xFFDC2626),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _buildStatCard(
                          title: 'Net Profit / Amount',
                          value: _fmtINR(netAmount),
                          subtitle: netAmount >= 0 ? 'Positive Margin' : 'Deficit',
                          icon: netAmount >= 0 ? Icons.account_balance : Icons.warning_amber,
                          iconBg: netAmount >= 0 ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2),
                          iconColor: netAmount >= 0 ? const Color(0xFF2563EB) : const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),

              // Revenue Transactions Header
              const Text('Revenue Payment Entries', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 8),

              // Body content
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
              else if (transactions.isEmpty)
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
                      Icon(Icons.payments_outlined, size: 48, color: Color(0xFF94A3B8)),
                      SizedBox(height: 10),
                      Text(
                        'No revenue payments in selected range',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final item = transactions[idx];
                    return _buildRevenueCard(item);
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

  Widget _buildRevenueCard(Map<String, dynamic> b) {
    final client = b['client'];
    final clientName = client is Map ? (client['clientName'] ?? client['name'] ?? 'Client').toString() : 'Client';
    final billType = (b['billType'] ?? 'Non-GST').toString();

    final pay = b['paymentDetails'] is Map ? b['paymentDetails'] as Map : {};
    final amount = double.tryParse('${pay['amount']}') ?? 0.0;
    final mode = (pay['paymentMode'] ?? 'Bank Transfer').toString();
    final date = _fmtDate(pay['paymentDate'] ?? b['createdAt']);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_downward, color: Color(0xFF059669), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(clientName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text('$mode · $billType · $date', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ),
            Text(_fmtINR(amount), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
          ],
        ),
      ),
    );
  }
}
