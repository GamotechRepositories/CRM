import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  List<Map<String, dynamic>> _billings = [];
  List<Map<String, dynamic>> _clients = [];
  bool _loading = true;
  String? _error;

  String _searchQuery = '';
  String _filterType = '';
  String _filterClientId = '';

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
      final queryParams = <String, String>{};
      if (_filterType.isNotEmpty) queryParams['billType'] = _filterType;
      if (_filterClientId.isNotEmpty) queryParams['clientId'] = _filterClientId;

      final results = await Future.wait([
        session.api!.fetchBillings(query: queryParams),
        session.api!.fetchClients().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _billings = results[0];
        _clients = results[1];
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

  List<Map<String, dynamic>> get _filteredBillings {
    return _billings.where((b) {
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final client = b['client'];
        final clientName = (client is Map ? (client['clientName'] ?? client['name']) : '').toString().toLowerCase();
        final billType = (b['billType'] ?? '').toString().toLowerCase();
        final amount = (b['paymentDetails'] is Map ? b['paymentDetails']['amount'] : '').toString();

        if (!clientName.contains(q) && !billType.contains(q) && !amount.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Map<String, dynamic> get _stats {
    final totalCount = _billings.length;
    final gstCount = _billings.where((b) => (b['billType'] ?? '') == 'GST').length;
    final nonGstCount = totalCount - gstCount;

    double totalAmount = 0;
    for (final b in _billings) {
      final pay = b['paymentDetails'];
      if (pay is Map) {
        totalAmount += double.tryParse('${pay['amount']}') ?? 0.0;
      }
    }

    return {
      'total': totalCount,
      'gst': gstCount,
      'nonGst': nonGstCount,
      'amount': totalAmount,
    };
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

  Future<void> _deleteBilling(String id) async {
    final session = context.read<AuthSession>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this billing invoice?'),
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
      await session.api!.deleteBilling(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice deleted')));
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
    final filtered = _filteredBillings;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Invoices & Billing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: () => _showAddBillingModal(context),
              icon: const Icon(Icons.receipt_long, size: 16),
              label: const Text('Add Invoice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                      title: 'Total Invoiced',
                      value: _fmtINR(stats['amount'] as num),
                      subtitle: '${stats['total']} bills',
                      icon: Icons.account_balance_wallet,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      title: 'GST Bills',
                      value: '${stats['gst']}',
                      subtitle: '${stats['nonGst']} Non-GST',
                      icon: Icons.receipt,
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
                child: Column(
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search invoices by client or amount...',
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
                            initialValue: _filterClientId,
                            decoration: InputDecoration(
                              labelText: 'Client',
                              labelStyle: const TextStyle(fontSize: 11),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: [
                              const DropdownMenuItem(value: '', child: Text('All Clients', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              ..._clients.map((c) => DropdownMenuItem(
                                    value: (c['_id'] ?? '').toString(),
                                    child: Text((c['clientName'] ?? c['name'] ?? '—').toString(), style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                                  )),
                            ],
                            onChanged: (v) {
                              setState(() => _filterClientId = v ?? '');
                              _fetchData();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _filterType,
                            decoration: InputDecoration(
                              labelText: 'Bill Type',
                              labelStyle: const TextStyle(fontSize: 11),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: const [
                              DropdownMenuItem(value: '', child: Text('All Types', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'GST', child: Text('GST', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'Non-GST', child: Text('Non-GST', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (v) {
                              setState(() => _filterType = v ?? '');
                              _fetchData();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Billing List Body
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
                      Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFF94A3B8)),
                      SizedBox(height: 10),
                      Text(
                        'No invoices found',
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
                    return _buildInvoiceCard(item);
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

  Widget _buildInvoiceCard(Map<String, dynamic> b) {
    final id = (b['_id'] ?? '').toString();
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: billType == 'GST' ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    billType == 'GST' ? Icons.verified : Icons.receipt,
                    color: billType == 'GST' ? const Color(0xFF059669) : const Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(clientName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text('Date: $date', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: billType == 'GST' ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: billType == 'GST' ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    billType,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: billType == 'GST' ? const Color(0xFF047857) : const Color(0xFF475569),
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
                    const Text('Payment Mode', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    Text(mode, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Invoice Amount', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    Text(_fmtINR(amount), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                  onPressed: () => _deleteBilling(id),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBillingModal(BuildContext context) {
    String billType = 'Non-GST';
    String clientId = '';
    final amountCtrl = TextEditingController();
    String mode = 'Bank Transfer';
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
                        const Text('Create Invoice', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: clientId,
                      decoration: const InputDecoration(labelText: 'Client *', isDense: true),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('Select Client', style: TextStyle(fontSize: 11))),
                        ..._clients.map((c) => DropdownMenuItem(
                              value: (c['_id'] ?? '').toString(),
                              child: Text((c['clientName'] ?? c['name'] ?? '—').toString(), style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (v) => clientId = v ?? '',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: billType,
                            decoration: const InputDecoration(labelText: 'Bill Type', isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'GST', child: Text('GST', style: TextStyle(fontSize: 11))),
                              DropdownMenuItem(value: 'Non-GST', child: Text('Non-GST', style: TextStyle(fontSize: 11))),
                            ],
                            onChanged: (v) => billType = v ?? billType,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: mode,
                            decoration: const InputDecoration(labelText: 'Payment Mode', isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer', style: TextStyle(fontSize: 11))),
                              DropdownMenuItem(value: 'UPI', child: Text('UPI', style: TextStyle(fontSize: 11))),
                              DropdownMenuItem(value: 'Cash', child: Text('Cash', style: TextStyle(fontSize: 11))),
                              DropdownMenuItem(value: 'Cheque', child: Text('Cheque', style: TextStyle(fontSize: 11))),
                            ],
                            onChanged: (v) => mode = v ?? mode,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Payment Amount (₹) *', isDense: true),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                                if (clientId.isEmpty || amt <= 0) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Client and Valid Amount are required')),
                                  );
                                  return;
                                }

                                setModalState(() => saving = true);
                                final session = context.read<AuthSession>();
                                try {
                                  await session.api!.createBilling({
                                    'client': clientId,
                                    'billType': billType,
                                    'paymentDetails': {
                                      'amount': amt,
                                      'paymentMode': mode,
                                      'paymentDate': DateTime.now().toIso8601String(),
                                    },
                                  });

                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Invoice created!')));
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
                        child: Text(saving ? 'Saving...' : 'Create Invoice'),
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
