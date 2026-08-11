import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';

const kQuotationStatuses = ['Draft', 'Sent', 'Accepted', 'Rejected', 'Expired', 'Revised'];

class QuotationsPage extends StatefulWidget {
  const QuotationsPage({super.key});

  @override
  State<QuotationsPage> createState() => _QuotationsPageState();
}

class _QuotationsPageState extends State<QuotationsPage> {
  List<Map<String, dynamic>> _quotations = [];
  List<Map<String, dynamic>> _clients = [];
  bool _loading = true;
  String? _error;

  String _searchQuery = '';
  String _filterStatus = '';
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
      if (_filterStatus.isNotEmpty) queryParams['status'] = _filterStatus;
      if (_filterClientId.isNotEmpty) queryParams['client'] = _filterClientId;

      final results = await Future.wait([
        session.api!.fetchQuotations(query: queryParams),
        session.api!.fetchClients().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _quotations = results[0];
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

  List<Map<String, dynamic>> get _filteredQuotations {
    return _quotations.where((q) {
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final numStr = (q['quotationNumber'] ?? '').toString().toLowerCase();
        final subject = (q['subject'] ?? '').toString().toLowerCase();
        final client = q['client'];
        final clientName = (client is Map ? (client['clientName'] ?? client['name']) : '').toString().toLowerCase();

        if (!numStr.contains(query) && !subject.contains(query) && !clientName.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  Map<String, dynamic> get _stats {
    final total = _quotations.length;
    final accepted = _quotations.where((q) => (q['status'] ?? '') == 'Accepted').length;
    final sent = _quotations.where((q) => (q['status'] ?? '') == 'Sent').length;

    double acceptedValue = 0;
    for (final q in _quotations) {
      if ((q['status'] ?? '') == 'Accepted') {
        acceptedValue += double.tryParse('${q['grandTotal']}') ?? 0.0;
      }
    }

    return {
      'total': total,
      'accepted': accepted,
      'sent': sent,
      'acceptedValue': acceptedValue,
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

  Future<void> _deleteQuotation(String id, String qNum) async {
    final session = context.read<AuthSession>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quotation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete quotation "$qNum"?'),
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
      await session.api!.deleteQuotation(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quotation deleted')));
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
    final filtered = _filteredQuotations;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Sales Quotations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: () => _showQuotationModal(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Quotation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                      title: 'Total Proposals',
                      value: '${stats['total']}',
                      subtitle: '${stats['sent']} Sent proposals',
                      icon: Icons.request_quote,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Accepted Value',
                      value: _fmtINR(stats['acceptedValue'] as num),
                      subtitle: '${stats['accepted']} Deals Won',
                      icon: Icons.verified_user,
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
                        hintText: 'Search quotations by number or subject...',
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
                            initialValue: _filterStatus,
                            decoration: InputDecoration(
                              labelText: 'Status',
                              labelStyle: const TextStyle(fontSize: 11),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: [
                              const DropdownMenuItem(value: '', child: Text('All Statuses', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              ...kQuotationStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (v) {
                              setState(() => _filterStatus = v ?? '');
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

              // Quotations List Body
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
                      Icon(Icons.request_quote_outlined, size: 48, color: Color(0xFF94A3B8)),
                      SizedBox(height: 10),
                      Text(
                        'No sales quotations found',
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
                    return _buildQuotationCard(item);
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

  Widget _buildQuotationCard(Map<String, dynamic> q) {
    final id = (q['_id'] ?? '').toString();
    final qNum = (q['quotationNumber'] ?? 'QT-000').toString();
    final subject = (q['subject'] ?? 'Sales Quotation').toString();

    final client = q['client'];
    final clientName = client is Map ? (client['clientName'] ?? client['name'] ?? 'Client').toString() : 'Client';
    final status = (q['status'] ?? 'Draft').toString();

    final date = _fmtDate(q['quotationDate'] ?? q['createdAt']);
    final validUntil = _fmtDate(q['validUntil']);
    final grandTotal = double.tryParse('${q['grandTotal']}') ?? 0.0;

    Color statusBg;
    Color statusFg;
    Color statusBorder;

    if (status == 'Accepted') {
      statusBg = const Color(0xFFECFDF5);
      statusFg = const Color(0xFF047857);
      statusBorder = const Color(0xFFA7F3D0);
    } else if (status == 'Sent') {
      statusBg = const Color(0xFFEFF6FF);
      statusFg = const Color(0xFF1D4ED8);
      statusBorder = const Color(0xFFBFDBFE);
    } else if (status == 'Rejected') {
      statusBg = const Color(0xFFFEF2F2);
      statusFg = const Color(0xFFB91C1C);
      statusBorder = const Color(0xFFFCA5A5);
    } else if (status == 'Expired') {
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
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.request_quote, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subject, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text('#$qNum · $clientName', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
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
                    status,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusFg),
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
                    const Text('Dates', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    Text('$date (Valid: $validUntil)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Grand Total', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    Text(_fmtINR(grandTotal), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                  onPressed: () => _deleteQuotation(id, qNum),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQuotationModal(BuildContext context) {
    String clientId = '';
    final subjectCtrl = TextEditingController();
    final grandTotalCtrl = TextEditingController();
    String status = 'Sent';
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
                        const Text('New Quotation Proposal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(),
                    TextField(
                      controller: subjectCtrl,
                      decoration: const InputDecoration(labelText: 'Subject / Project Proposal Title *', isDense: true),
                    ),
                    const SizedBox(height: 8),
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
                          child: TextField(
                            controller: grandTotalCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Grand Total Amount (₹) *', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: status,
                            decoration: const InputDecoration(labelText: 'Status', isDense: true),
                            items: kQuotationStatuses
                                .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11))))
                                .toList(),
                            onChanged: (v) => status = v ?? status,
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
                                final subj = subjectCtrl.text.trim();
                                final amt = double.tryParse(grandTotalCtrl.text.trim()) ?? 0;
                                if (subj.isEmpty || clientId.isEmpty || amt <= 0) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Subject, Client, and Valid Amount are required')),
                                  );
                                  return;
                                }

                                setModalState(() => saving = true);
                                final session = context.read<AuthSession>();
                                try {
                                  await session.api!.createQuotation({
                                    'subject': subj,
                                    'client': clientId,
                                    'grandTotal': amt,
                                    'status': status,
                                    'quotationDate': DateTime.now().toIso8601String(),
                                  });

                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Quotation created!')));
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
                        child: Text(saving ? 'Saving...' : 'Create Proposal'),
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
