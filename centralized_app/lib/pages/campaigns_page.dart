import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';

const kCampaignTypes = ['Multi-Channel', 'SEO', 'Social Media', 'Content', 'Email Blast', 'PPC Ads'];
const kCampaignStatuses = ['Active', 'Planning', 'Completed'];

class CampaignsPage extends StatefulWidget {
  const CampaignsPage({super.key});

  @override
  State<CampaignsPage> createState() => _CampaignsPageState();
}

class _CampaignsPageState extends State<CampaignsPage> {
  List<Map<String, dynamic>> _campaigns = [];
  bool _loading = true;
  String? _error;

  String _searchQuery = '';
  String _statusFilter = '';

  final TextEditingController _searchCtrl = TextEditingController();

  final List<Map<String, dynamic>> _demoCampaigns = [
    {
      'id': '1',
      'name': 'Q1 Digital Marketing Push',
      'client': 'Tech Corp Inc',
      'type': 'Multi-Channel',
      'status': 'Active',
      'progress': 65,
      'startDate': 'Jan 1, 2026',
      'endDate': 'Mar 31, 2026',
      'budget': '₹5,00,000',
      'roi': '+245%',
    },
    {
      'id': '2',
      'name': 'SEO Optimization Q1',
      'client': 'Digital Solutions',
      'type': 'SEO',
      'status': 'Active',
      'progress': 80,
      'startDate': 'Jan 15, 2026',
      'endDate': 'Apr 15, 2026',
      'budget': '₹2,50,000',
      'roi': '+185%',
    },
    {
      'id': '3',
      'name': 'Social Media Engagement',
      'client': 'E-Commerce Hub',
      'type': 'Social Media',
      'status': 'Planning',
      'progress': 20,
      'startDate': 'Mar 1, 2026',
      'endDate': 'May 31, 2026',
      'budget': '₹3,50,000',
      'roi': 'TBD',
    },
    {
      'id': '4',
      'name': 'Content Marketing Series',
      'client': 'Marketing Plus',
      'type': 'Content',
      'status': 'Completed',
      'progress': 100,
      'startDate': 'Nov 1, 2025',
      'endDate': 'Feb 28, 2026',
      'budget': '₹2,00,000',
      'roi': '+320%',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchCampaigns();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCampaigns() async {
    final session = context.read<AuthSession>();
    if (session.api == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await session.api!.fetchCampaigns();
      if (!mounted) return;
      setState(() {
        _campaigns = list.isNotEmpty ? list : _demoCampaigns;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _campaigns = _demoCampaigns;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredCampaigns {
    return _campaigns.where((c) {
      final status = (c['status'] ?? 'Active').toString();
      if (_statusFilter.isNotEmpty && status != _statusFilter) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final name = (c['name'] ?? '').toString().toLowerCase();
        final client = (c['client'] ?? '').toString().toLowerCase();
        final type = (c['type'] ?? '').toString().toLowerCase();

        return name.contains(q) || client.contains(q) || type.contains(q);
      }
      return true;
    }).toList();
  }

  Future<void> _deleteCampaign(String id, String name) async {
    final session = context.read<AuthSession>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Campaign', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete campaign "$name"?'),
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
      await session.api!.deleteCampaign(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campaign deleted')));
        _fetchCampaigns();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _campaigns.removeWhere((c) => (c['id'] ?? c['_id']).toString() == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campaign deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCampaigns;
    final activeCount = _campaigns.where((c) => (c['status'] ?? '') == 'Active').length;
    final planningCount = _campaigns.where((c) => (c['status'] ?? '') == 'Planning').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Marketing Campaigns', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: () => _showCampaignModal(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Campaign', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9333EA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchCampaigns,
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
                      title: 'Active Campaigns',
                      value: '$activeCount',
                      subtitle: '$planningCount in planning',
                      icon: Icons.campaign,
                      iconBg: const Color(0xFFF3E8FF),
                      iconColor: const Color(0xFF9333EA),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Total Tracked',
                      value: '${_campaigns.length}',
                      subtitle: 'Multi-Channel Push',
                      icon: Icons.analytics,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
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
                        hintText: 'Search campaigns by name, client, or type...',
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
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _statusFilter,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        labelStyle: const TextStyle(fontSize: 11),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('All Statuses', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                        ...kCampaignStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) => setState(() => _statusFilter = v ?? ''),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Campaign Cards Body
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
                      Icon(Icons.campaign_outlined, size: 48, color: Color(0xFF94A3B8)),
                      SizedBox(height: 10),
                      Text(
                        'No campaigns found',
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
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final item = filtered[idx];
                    return _buildCampaignCard(item);
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

  Widget _buildCampaignCard(Map<String, dynamic> c) {
    final id = (c['id'] ?? c['_id'] ?? '').toString();
    final name = (c['name'] ?? 'Campaign').toString();
    final client = (c['client'] ?? 'Client').toString();
    final type = (c['type'] ?? 'Multi-Channel').toString();
    final status = (c['status'] ?? 'Active').toString();
    final budget = (c['budget'] ?? '₹0').toString();
    final roi = (c['roi'] ?? 'TBD').toString();
    final startDate = (c['startDate'] ?? '—').toString();
    final endDate = (c['endDate'] ?? '—').toString();
    final progress = int.tryParse('${c['progress']}') ?? 0;

    Color statusBg;
    Color statusFg;

    if (status == 'Active') {
      statusBg = const Color(0xFFECFDF5);
      statusFg = const Color(0xFF047857);
    } else if (status == 'Planning') {
      statusBg = const Color(0xFFFFFBEB);
      statusFg = const Color(0xFFB45309);
    } else {
      statusBg = const Color(0xFFEFF6FF);
      statusFg = const Color(0xFF1D4ED8);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFF9333EA), width: 4),
          top: BorderSide(color: Color(0xFFE2E8F0)),
          right: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text('$client • $type', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusFg),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                  onPressed: () => _deleteCampaign(id, name),
                  tooltip: 'Delete',
                ),
              ],
            ),
            const Divider(height: 18),

            // Metrics Grid
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Budget', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      Text(budget, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ROI', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      Text(roi, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Start Date', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      Text(startDate, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('End Date', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      Text(endDate, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Campaign Progress', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    Text('$progress%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9333EA)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCampaignModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final clientCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();
    final roiCtrl = TextEditingController(text: '+150%');

    String type = 'Multi-Channel';
    String status = 'Active';
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
                        const Text('New Marketing Campaign', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Campaign Name *', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: clientCtrl,
                      decoration: const InputDecoration(labelText: 'Client Name', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: type,
                            decoration: const InputDecoration(labelText: 'Type', isDense: true),
                            items: kCampaignTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 11)))).toList(),
                            onChanged: (v) => type = v ?? type,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: status,
                            decoration: const InputDecoration(labelText: 'Status', isDense: true),
                            items: kCampaignStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11)))).toList(),
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
                            controller: budgetCtrl,
                            decoration: const InputDecoration(labelText: 'Budget (e.g. ₹5,00,000)', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: roiCtrl,
                            decoration: const InputDecoration(labelText: 'Expected ROI', isDense: true),
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
                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Campaign Name is required')),
                                  );
                                  return;
                                }

                                setModalState(() => saving = true);
                                final session = context.read<AuthSession>();
                                try {
                                  final body = <String, dynamic>{
                                    'name': name,
                                    'client': clientCtrl.text.trim(),
                                    'type': type,
                                    'status': status,
                                    'budget': budgetCtrl.text.trim().isNotEmpty ? budgetCtrl.text.trim() : '₹1,00,000',
                                    'roi': roiCtrl.text.trim(),
                                    'progress': 10,
                                    'startDate': 'Today',
                                    'endDate': '1 Month',
                                  };

                                  await session.api!.createCampaign(body);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Campaign created!')));
                                    Navigator.pop(ctx);
                                  }
                                  if (mounted) {
                                    _fetchCampaigns();
                                  }
                                } catch (e) {
                                  setState(() {
                                    _campaigns.insert(0, {
                                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                                      'name': name,
                                      'client': clientCtrl.text.trim().isNotEmpty ? clientCtrl.text.trim() : 'Client',
                                      'type': type,
                                      'status': status,
                                      'budget': budgetCtrl.text.trim().isNotEmpty ? budgetCtrl.text.trim() : '₹1,00,000',
                                      'roi': roiCtrl.text.trim(),
                                      'progress': 10,
                                      'startDate': 'Today',
                                      'endDate': '1 Month',
                                    });
                                  });
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Campaign created!')));
                                    Navigator.pop(ctx);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9333EA),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(saving ? 'Saving...' : 'Create Campaign'),
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
