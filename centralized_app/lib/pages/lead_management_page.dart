import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_session.dart';
import '../auth/role_access.dart';

const List<String> kLeadStatusOptions = [
  'Call not Received',
  'Call You After Sometime',
  'Interested',
  'Not Interested',
  'Meeting Schedule',
  'Site Visit',
  'Zoom Meeting',
  'Booking Done',
  'Token Done',
  'Pending',
];

class LeadManagementPage extends StatefulWidget {
  const LeadManagementPage({super.key});

  @override
  State<LeadManagementPage> createState() => _LeadManagementPageState();
}

class _LeadManagementPageState extends State<LeadManagementPage> {
  List<Map<String, dynamic>> _leads = [];
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  String? _error;
  bool _showFilters = false;

  // Filters state
  String _search = '';
  String _status = '';
  String _date = '';
  String _dateFrom = '';
  String _dateTo = '';
  String _employee = '';
  String _assignedTo = '';
  String _unassigned = '';
  String _businessType = '';
  String _leadSource = '';
  String _city = '';
  String _state = '';

  // Controllers for search & inputs
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _businessTypeCtrl = TextEditingController();
  final TextEditingController _leadSourceCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _stateCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchEmployees();
      _fetchLeads();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _businessTypeCtrl.dispose();
    _leadSourceCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _salesEmployees {
    return _employees.where((e) {
      final dept = (e['department'] ?? '').toString();
      return dept.toLowerCase().contains('sales');
    }).toList();
  }

  Future<void> _fetchEmployees() async {
    final session = context.read<AuthSession>();
    try {
      final emps = await session.api!.fetchEmployees();
      if (mounted) {
        setState(() => _employees = emps);
      }
    } catch (_) {
      // Soft fail for employees list
    }
  }

  Future<void> _fetchLeads() async {
    final session = context.read<AuthSession>();
    final canManage = RoleAccess.canManageLeads(session.user);

    setState(() {
      _loading = true;
      _error = null;
    });

    final filters = <String, String>{};
    if (_search.isNotEmpty) filters['search'] = _search;
    if (_status.isNotEmpty) filters['status'] = _status;
    if (_date.isNotEmpty) filters['date'] = _date;
    if (_dateFrom.isNotEmpty) filters['dateFrom'] = _dateFrom;
    if (_dateTo.isNotEmpty) filters['dateTo'] = _dateTo;
    if (_businessType.isNotEmpty) filters['businessType'] = _businessType;
    if (_leadSource.isNotEmpty) filters['leadSource'] = _leadSource;
    if (_city.isNotEmpty) filters['city'] = _city;
    if (_state.isNotEmpty) filters['state'] = _state;

    if (canManage) {
      if (_employee.isNotEmpty) filters['employee'] = _employee;
      if (_assignedTo.isNotEmpty) filters['assignedTo'] = _assignedTo;
      if (_unassigned.isNotEmpty) filters['unassigned'] = _unassigned;
    }

    try {
      final leads = await session.api!.fetchLeads(
        viewerId: session.userId,
        filters: filters,
      );
      if (mounted) {
        setState(() {
          _leads = leads;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _search = '';
      _status = '';
      _date = '';
      _dateFrom = '';
      _dateTo = '';
      _employee = '';
      _assignedTo = '';
      _unassigned = '';
      _businessType = '';
      _leadSource = '';
      _city = '';
      _state = '';

      _searchCtrl.clear();
      _businessTypeCtrl.clear();
      _leadSourceCtrl.clear();
      _cityCtrl.clear();
      _stateCtrl.clear();
    });
    _fetchLeads();
  }

  Future<void> _makeCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanNumber.isEmpty) return;
    final uri = Uri.parse('tel:$cleanNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot initiate call to $phoneNumber')),
        );
      }
    }
  }

  int get _activeFilterCount {
    int count = 0;
    if (_search.isNotEmpty) count++;
    if (_status.isNotEmpty) count++;
    if (_date.isNotEmpty) count++;
    if (_dateFrom.isNotEmpty) count++;
    if (_dateTo.isNotEmpty) count++;
    if (_employee.isNotEmpty) count++;
    if (_assignedTo.isNotEmpty) count++;
    if (_unassigned.isNotEmpty) count++;
    if (_businessType.isNotEmpty) count++;
    if (_leadSource.isNotEmpty) count++;
    if (_city.isNotEmpty) count++;
    if (_state.isNotEmpty) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    final canManage = RoleAccess.canManageLeads(session.user);

    final totalCount = _leads.length;
    final interestedCount = _leads.where((l) => l['status'] == 'Interested').length;
    final meetingCount = _leads.where((l) => l['status'] == 'Meeting Schedule').length;
    final notInterestedCount = _leads.where((l) => l['status'] == 'Not Interested').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _fetchLeads,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Title & Actions
              _buildHeader(canManage),
              const SizedBox(height: 16),

              // 2. Stat Summary Cards Grid
              _buildStatCardsRow(
                total: totalCount,
                interested: interestedCount,
                meeting: meetingCount,
                notInterested: notInterestedCount,
              ),
              const SizedBox(height: 16),

              // 3. Search & Filter Bar
              _buildFilterSection(canManage),
              const SizedBox(height: 16),

              // 4. Leads Content Area
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_error != null)
                _buildErrorCard()
              else if (_leads.isEmpty)
                _buildEmptyState()
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _leads.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final lead = _leads[index];
                    return _buildLeadCard(lead);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HEADER WIDGET ---
  Widget _buildHeader(bool canManage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Lead Management',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage and qualify sales leads.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (canManage)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showAddLeadModal(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Lead'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showDistributeModal(context),
                icon: const Icon(Icons.hub_outlined, size: 16),
                label: const Text('Distribute Leads'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showCsvImportModal(context),
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text('Upload CSV'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  side: const BorderSide(color: Color(0xFF6366F1)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'Showing leads assigned to you',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ),
      ],
    );
  }

  // --- STAT CARDS ---
  Widget _buildStatCardsRow({
    required int total,
    required int interested,
    required int meeting,
    required int notInterested,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildStatCard('Total Leads', total.toString(), const Color(0xFF3B82F6)),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildStatCard('Interested', interested.toString(), const Color(0xFF22C55E)),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildStatCard('Meeting Schedule', meeting.toString(), const Color(0xFFF59E0B)),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildStatCard('Not Interested', notInterested.toString(), const Color(0xFF9CA3AF)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String count, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          const Text(
            'Based on current filters',
            style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  // --- FILTERS SECTION ---
  Widget _buildFilterSection(bool canManage) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) {
                    _search = val;
                  },
                  onSubmitted: (_) => _fetchLeads(),
                  decoration: InputDecoration(
                    hintText: 'Search name, business, contact, source...',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              _search = '';
                              _fetchLeads();
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _fetchLeads,
                icon: const Icon(Icons.arrow_forward, color: Color(0xFF4F46E5)),
                tooltip: 'Apply Search',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _status.isEmpty ? null : _status,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    labelStyle: const TextStyle(fontSize: 11),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All status', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                    ...kLeadStatusOptions.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() => _status = val ?? '');
                    _fetchLeads();
                  },
                ),
              ),

              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => setState(() => _showFilters = !_showFilters),
                icon: Icon(
                  _showFilters ? Icons.filter_list_off : Icons.filter_list,
                  size: 16,
                ),
                label: Text(
                  _activeFilterCount > 0 ? 'Filters ($_activeFilterCount)' : 'More Filters',
                  style: const TextStyle(fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          if (_showFilters) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildAdvancedFilters(canManage),
          ],
        ],
      ),
    );
  }

  Widget _buildAdvancedFilters(bool canManage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                readOnly: true,
                controller: TextEditingController(text: _dateFrom),
                decoration: InputDecoration(
                  labelText: 'Date From',
                  labelStyle: const TextStyle(fontSize: 11),
                  isDense: true,
                  suffixIcon: const Icon(Icons.calendar_today, size: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 11),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() => _dateFrom = picked.toIso8601String().split('T').first);
                    _fetchLeads();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                readOnly: true,
                controller: TextEditingController(text: _dateTo),
                decoration: InputDecoration(
                  labelText: 'Date To',
                  labelStyle: const TextStyle(fontSize: 11),
                  isDense: true,
                  suffixIcon: const Icon(Icons.calendar_today, size: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 11),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() => _dateTo = picked.toIso8601String().split('T').first);
                    _fetchLeads();
                  }
                },
              ),
            ),
          ],
        ),
        if (canManage) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _assignedTo.isEmpty ? null : _assignedTo,
            decoration: InputDecoration(
              labelText: 'Assigned To (Sales)',
              labelStyle: const TextStyle(fontSize: 11),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('All assignees', style: TextStyle(fontSize: 11))),
              ..._salesEmployees.map((e) => DropdownMenuItem(
                    value: e['_id'].toString(),
                    child: Text((e['name'] ?? '').toString(), style: const TextStyle(fontSize: 11)),
                  )),
            ],
            onChanged: (val) {
              setState(() {
                _assignedTo = val ?? '';
                if (_assignedTo.isNotEmpty) _unassigned = '';
              });
              _fetchLeads();
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _unassigned.isEmpty ? null : _unassigned,
            decoration: InputDecoration(
              labelText: 'Assignment Status',
              labelStyle: const TextStyle(fontSize: 11),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: const [
              DropdownMenuItem(value: '', child: Text('All', style: TextStyle(fontSize: 11))),
              DropdownMenuItem(value: 'true', child: Text('Unassigned only', style: TextStyle(fontSize: 11))),
            ],
            onChanged: (val) {
              setState(() {
                _unassigned = val ?? '';
                if (_unassigned.isNotEmpty) _assignedTo = '';
              });
              _fetchLeads();
            },
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _businessTypeCtrl,
                onChanged: (v) => _businessType = v,
                onSubmitted: (_) => _fetchLeads(),
                decoration: InputDecoration(
                  labelText: 'Business Type',
                  labelStyle: const TextStyle(fontSize: 11),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _leadSourceCtrl,
                onChanged: (v) => _leadSource = v,
                onSubmitted: (_) => _fetchLeads(),
                decoration: InputDecoration(
                  labelText: 'Lead Source',
                  labelStyle: const TextStyle(fontSize: 11),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cityCtrl,
                onChanged: (v) => _city = v,
                onSubmitted: (_) => _fetchLeads(),
                decoration: InputDecoration(
                  labelText: 'City',
                  labelStyle: const TextStyle(fontSize: 11),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _stateCtrl,
                onChanged: (v) => _state = v,
                onSubmitted: (_) => _fetchLeads(),
                decoration: InputDecoration(
                  labelText: 'State',
                  labelStyle: const TextStyle(fontSize: 11),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.restart_alt, size: 14, color: Color(0xFFEF4444)),
            label: const Text('Reset Filters', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
          ),
        ),
      ],
    );
  }

  // --- LEAD CARD ---
  Widget _buildLeadCard(Map<String, dynamic> lead) {
    final name = (lead['name'] ?? 'Unnamed Lead').toString();
    final businessName = (lead['businessName'] ?? '').toString();
    final contactNumber = (lead['contactNumber'] ?? '').toString();
    final status = (lead['status'] ?? 'Pending').toString();
    final leadSource = (lead['leadSource'] ?? '').toString();
    final businessType = (lead['businessType'] ?? '').toString();
    final city = (lead['city'] ?? '').toString();

    final assignedTo = lead['assignedTo'];
    final assignedName = assignedTo is Map ? (assignedTo['name'] ?? '').toString() : '';
    final siteCoord = lead['siteCoordinator'];
    final siteCoordName = siteCoord is Map ? (siteCoord['name'] ?? '').toString() : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showLeadDetailsModal(lead),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Lead Name & Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusChip(status),
                  ],
                ),
                if (businessName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    businessName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
                const SizedBox(height: 8),

                // Contact & Quick Call Row
                if (contactNumber.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        contactNumber,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _makeCall(contactNumber),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.call, size: 10, color: Color(0xFF2563EB)),
                              SizedBox(width: 2),
                              Text('Call', style: TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),

                // Chips Row: Source, Business Type, City
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (leadSource.isNotEmpty)
                      _buildInfoChip(Icons.source, leadSource, const Color(0xFFF1F5F9), const Color(0xFF475569)),
                    if (businessType.isNotEmpty)
                      _buildInfoChip(Icons.business_center, businessType, const Color(0xFFF1F5F9), const Color(0xFF475569)),
                    if (city.isNotEmpty)
                      _buildInfoChip(Icons.location_on_outlined, city, const Color(0xFFF1F5F9), const Color(0xFF475569)),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // Footer Row: Assignment & Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assigned: ${assignedName.isNotEmpty ? assignedName : 'Unassigned'}',
                            style: TextStyle(
                              fontSize: 10,
                              color: assignedName.isNotEmpty ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (siteCoordName.isNotEmpty)
                            Text(
                              'Site Coord: $siteCoordName',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                          icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF4F46E5)),
                          onPressed: () => _showLeadDetailsModal(lead),
                          tooltip: 'View details',
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                          onPressed: () => _showEditLeadModal(lead),
                          tooltip: 'Edit lead',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg = const Color(0xFFEFF6FF);
    Color text = const Color(0xFF1D4ED8);

    if (status == 'Interested') {
      bg = const Color(0xFFDCFCE7);
      text = const Color(0xFF15803D);
    } else if (status == 'Meeting Schedule' || status == 'Site Visit' || status == 'Zoom Meeting') {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFFB45309);
    } else if (status == 'Booking Done' || status == 'Token Done') {
      bg = const Color(0xFFDCFCE7);
      text = const Color(0xFF166534);
    } else if (status == 'Not Interested') {
      bg = const Color(0xFFF1F5F9);
      text = const Color(0xFF64748B);
    } else if (status == 'Call not Received' || status == 'Pending') {
      bg = const Color(0xFFFEE2E2);
      text = const Color(0xFFB91C1C);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: text),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, color: text, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: const [
            Icon(Icons.inbox, size: 40, color: Color(0xFFCBD5E1)),
            SizedBox(height: 8),
            Text(
              'No leads found matching your criteria.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
            ),
          ),
          TextButton(
            onPressed: _fetchLeads,
            child: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // --- MODALS ---

  // 1. Lead Details Modal
  void _showLeadDetailsModal(Map<String, dynamic> lead) {
    final session = context.read<AuthSession>();
    final leadId = (lead['_id'] ?? '').toString();
    final followUps = (lead['followUps'] as List?)?.whereType<Map>().toList() ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final followUpCtrl = TextEditingController();
        String followUpStatus = (lead['status'] ?? 'Pending').toString();
        bool adding = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          (lead['name'] ?? 'Lead Details').toString(),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: [
                        _detailRow('Business Name', lead['businessName']),
                        _detailRow('Contact Number', lead['contactNumber']),
                        _detailRow('Email', lead['email']),
                        _detailRow('Status', lead['status']),
                        _detailRow('Business Type', lead['businessType']),
                        _detailRow('Lead Source', lead['leadSource']),
                        _detailRow('City / State', '${lead['city'] ?? '—'}, ${lead['state'] ?? '—'}'),
                        _detailRow('Assigned To', lead['assignedTo'] is Map ? lead['assignedTo']['name'] : 'Unassigned'),
                        _detailRow('Site Coordinator', lead['siteCoordinator'] is Map ? lead['siteCoordinator']['name'] : '—'),
                        _detailRow('Generated By', lead['generatedBy'] is Map ? lead['generatedBy']['name'] : '—'),
                        _detailRow('Description', lead['description']),
                        const SizedBox(height: 16),
                        const Text('Follow Up Notes & History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (followUps.isEmpty)
                          const Text('No follow ups recorded yet.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))
                        else
                          ...followUps.map((f) => Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (f['note'] ?? f['comment'] ?? '').toString(),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Status: ${f['status'] ?? '—'} · ${_fmtDate(f['createdAt'])}',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              )),
                        const SizedBox(height: 16),
                        const Text('Add Follow-Up Note', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: followUpStatus,
                          decoration: InputDecoration(
                            labelText: 'New Status',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: kLeadStatusOptions
                              .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11))))
                              .toList(),
                          onChanged: (v) => followUpStatus = v ?? followUpStatus,
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: followUpCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Enter follow up details / call notes...',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: adding
                              ? null
                              : () async {
                                  if (followUpCtrl.text.trim().isEmpty) return;
                                  setModalState(() => adding = true);
                                  try {
                                    await session.api!.addLeadFollowUp(leadId, {
                                      'note': followUpCtrl.text.trim(),
                                      'status': followUpStatus,
                                      'updatedBy': session.userId,
                                    });
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                    }
                                    if (mounted) {
                                      _fetchLeads();
                                    }
                                  } catch (_) {
                                    setModalState(() => adding = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(adding ? 'Saving...' : 'Add Note'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String title, dynamic val) {
    final v = val?.toString();
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // 2. Add Lead Modal

  void _showAddLeadModal(BuildContext context) {
    final session = context.read<AuthSession>();
    final nameCtrl = TextEditingController();
    final businessCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final businessTypeCtrl = TextEditingController();
    final leadSourceCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    String status = 'Call not Received';
    String? assignedTo;
    String? generatedBy = session.userId.isNotEmpty
        ? session.userId
        : (_employees.isNotEmpty ? _employees.first['_id']?.toString() : null);

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
                        const Text('Add New Lead', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Lead Name *', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: businessCtrl,
                      decoration: const InputDecoration(labelText: 'Business Name (Optional - defaults to Lead Name)', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: contactCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Contact Number *', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    if (_employees.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        initialValue: generatedBy,
                        decoration: const InputDecoration(labelText: 'Lead Generated By *', isDense: true),
                        items: _employees.map((e) => DropdownMenuItem(
                              value: e['_id'].toString(),
                              child: Text((e['name'] ?? 'Employee').toString(), style: const TextStyle(fontSize: 11)),
                            )).toList(),
                        onChanged: (v) => generatedBy = v,
                      ),
                      const SizedBox(height: 8),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Status', isDense: true),
                      items: kLeadStatusOptions
                          .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11))))
                          .toList(),
                      onChanged: (v) => status = v ?? status,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: assignedTo,
                      decoration: const InputDecoration(labelText: 'Assigned To (Sales)', isDense: true),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Unassigned', style: TextStyle(fontSize: 11))),
                        ..._salesEmployees.map((e) => DropdownMenuItem(
                              value: e['_id'].toString(),
                              child: Text((e['name'] ?? '').toString(), style: const TextStyle(fontSize: 11)),
                            )),
                      ],
                      onChanged: (v) => assignedTo = v,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: businessTypeCtrl, decoration: const InputDecoration(labelText: 'Business Type', isDense: true))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: leadSourceCtrl, decoration: const InputDecoration(labelText: 'Lead Source', isDense: true))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'City', isDense: true))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: stateCtrl, decoration: const InputDecoration(labelText: 'State', isDense: true))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Description / Requirement', isDense: true),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                final contact = contactCtrl.text.trim();
                                final bName = businessCtrl.text.trim().isNotEmpty
                                    ? businessCtrl.text.trim()
                                    : name;

                                if (name.isEmpty || contact.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Lead Name and Contact Number are required')),
                                  );
                                  return;
                                }

                                final genBy = (generatedBy != null && generatedBy!.isNotEmpty)
                                    ? generatedBy!
                                    : session.userId;

                                if (genBy.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Please select who generated this lead')),
                                  );
                                  return;
                                }

                                setModalState(() => saving = true);
                                try {
                                  final body = <String, dynamic>{
                                    'name': name,
                                    'businessName': bName,
                                    'contactNumber': contact,
                                    'status': status,
                                    'generatedBy': genBy,
                                  };
                                  if (emailCtrl.text.trim().isNotEmpty) body['email'] = emailCtrl.text.trim();
                                  if (businessTypeCtrl.text.trim().isNotEmpty) body['businessType'] = businessTypeCtrl.text.trim();
                                  if (leadSourceCtrl.text.trim().isNotEmpty) body['leadSource'] = leadSourceCtrl.text.trim();
                                  if (cityCtrl.text.trim().isNotEmpty) body['city'] = cityCtrl.text.trim();
                                  if (stateCtrl.text.trim().isNotEmpty) body['state'] = stateCtrl.text.trim();
                                  if (descCtrl.text.trim().isNotEmpty) body['description'] = descCtrl.text.trim();
                                  if (assignedTo != null && assignedTo!.trim().isNotEmpty) {
                                    body['assignedTo'] = assignedTo!.trim();
                                  }

                                  await session.api!.createLead(body);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(content: Text('Lead created successfully!')),
                                    );
                                    Navigator.pop(ctx);
                                  }
                                  if (mounted) {
                                    _fetchLeads();
                                  }

                                } catch (e) {
                                  setModalState(() => saving = false);
                                  if (ctx.mounted) {
                                    final errMsg = e.toString().replaceFirst('Exception: ', '');
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Failed to create lead: $errMsg')),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(saving ? 'Saving...' : 'Create Lead'),
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

  // 3. Edit Lead Modal
  void _showEditLeadModal(Map<String, dynamic> lead) {
    final session = context.read<AuthSession>();
    final leadId = (lead['_id'] ?? '').toString();

    final nameCtrl = TextEditingController(text: (lead['name'] ?? '').toString());
    final businessCtrl = TextEditingController(text: (lead['businessName'] ?? '').toString());
    final contactCtrl = TextEditingController(text: (lead['contactNumber'] ?? '').toString());
    final emailCtrl = TextEditingController(text: (lead['email'] ?? '').toString());
    final businessTypeCtrl = TextEditingController(text: (lead['businessType'] ?? '').toString());
    final leadSourceCtrl = TextEditingController(text: (lead['leadSource'] ?? '').toString());
    final cityCtrl = TextEditingController(text: (lead['city'] ?? '').toString());
    final stateCtrl = TextEditingController(text: (lead['state'] ?? '').toString());
    final descCtrl = TextEditingController(text: (lead['description'] ?? '').toString());

    String status = (lead['status'] ?? 'Call not Received').toString();
    final rawAssigned = lead['assignedTo'];
    String? assignedTo = rawAssigned is Map ? rawAssigned['_id']?.toString() : rawAssigned?.toString();

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
                        const Text('Edit Lead', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Lead Name *', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: businessCtrl,
                      decoration: const InputDecoration(labelText: 'Business Name', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: contactCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Contact Number *', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Status', isDense: true),
                      items: kLeadStatusOptions
                          .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11))))
                          .toList(),
                      onChanged: (v) => status = v ?? status,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: assignedTo,
                      decoration: const InputDecoration(labelText: 'Assigned To (Sales)', isDense: true),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Unassigned', style: TextStyle(fontSize: 11))),
                        ..._salesEmployees.map((e) => DropdownMenuItem(
                              value: e['_id'].toString(),
                              child: Text((e['name'] ?? '').toString(), style: const TextStyle(fontSize: 11)),
                            )),
                      ],
                      onChanged: (v) => assignedTo = v,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: businessTypeCtrl, decoration: const InputDecoration(labelText: 'Business Type', isDense: true))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: leadSourceCtrl, decoration: const InputDecoration(labelText: 'Lead Source', isDense: true))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'City', isDense: true))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: stateCtrl, decoration: const InputDecoration(labelText: 'State', isDense: true))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Description', isDense: true),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                final contact = contactCtrl.text.trim();
                                final bName = businessCtrl.text.trim().isNotEmpty
                                    ? businessCtrl.text.trim()
                                    : name;

                                if (name.isEmpty || contact.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Lead Name and Contact Number are required')),
                                  );
                                  return;
                                }

                                setModalState(() => saving = true);
                                try {
                                  final body = <String, dynamic>{
                                    'name': name,
                                    'businessName': bName,
                                    'contactNumber': contact,
                                    'status': status,
                                  };
                                  if (emailCtrl.text.trim().isNotEmpty) body['email'] = emailCtrl.text.trim();
                                  if (businessTypeCtrl.text.trim().isNotEmpty) body['businessType'] = businessTypeCtrl.text.trim();
                                  if (leadSourceCtrl.text.trim().isNotEmpty) body['leadSource'] = leadSourceCtrl.text.trim();
                                  if (cityCtrl.text.trim().isNotEmpty) body['city'] = cityCtrl.text.trim();
                                  if (stateCtrl.text.trim().isNotEmpty) body['state'] = stateCtrl.text.trim();
                                  if (descCtrl.text.trim().isNotEmpty) body['description'] = descCtrl.text.trim();
                                  if (assignedTo != null && assignedTo!.trim().isNotEmpty) {
                                    body['assignedTo'] = assignedTo!.trim();
                                  } else {
                                    body['assignedTo'] = null;
                                  }

                                  await session.api!.updateLead(leadId, body);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(content: Text('Lead updated successfully!')),
                                    );
                                    Navigator.pop(ctx);
                                  }
                                  if (mounted) {
                                    _fetchLeads();
                                  }

                                } catch (e) {
                                  setModalState(() => saving = false);
                                  if (ctx.mounted) {
                                    final errMsg = e.toString().replaceFirst('Exception: ', '');
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Failed to update lead: $errMsg')),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(saving ? 'Saving...' : 'Update Lead'),
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


  // 4. Distribute Leads Modal

  void _showDistributeModal(BuildContext context) async {
    final session = context.read<AuthSession>();
    bool loadingPreview = true;
    bool distributing = false;
    Map<String, dynamic>? preview;
    String? previewError;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (loadingPreview) {
              session.api!.fetchDistributionPreview(session.userId).then((res) {
                if (ctx.mounted) {
                  setModalState(() {
                    preview = res;
                    loadingPreview = false;
                  });
                }
              }).catchError((err) {
                if (ctx.mounted) {
                  setModalState(() {
                    previewError = err.toString().replaceFirst('Exception: ', '');
                    loadingPreview = false;
                  });
                }
              });
            }

            final totalUnassigned = preview?['totalLeads'] ?? 0;
            final teamLeaders = preview?['teamLeaderCount'] ?? 0;
            final plan = (preview?['plan'] as List?)?.whereType<Map>().toList() ?? [];

            return AlertDialog(
              title: const Text('Distribute Today\'s Leads', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: loadingPreview
                    ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
                    : previewError != null
                        ? Text(previewError!, style: const TextStyle(color: Colors.red, fontSize: 12))
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Unassigned leads are split equally across Sales Team Leaders, then only to Sales Executives on each team.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _statBox('Today\'s Unassigned', totalUnassigned.toString()),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _statBox('Team Leaders', teamLeaders.toString()),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (plan.isEmpty)
                                  const Text('No unassigned leads for today to distribute.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))
                                else
                                  ...plan.map((block) {
                                    final tlName = (block['teamLeader']?['name'] ?? 'Team Leader').toString();
                                    final leadCount = block['leadCount'] ?? 0;
                                    final members = (block['members'] as List?)?.whereType<Map>().toList() ?? [];

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$tlName — $leadCount lead(s)',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          ...members.map((m) => Padding(
                                                padding: const EdgeInsets.only(left: 8, bottom: 2),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text((m['employee']?['name'] ?? '').toString(), style: const TextStyle(fontSize: 10)),
                                                    Text('${m['leadCount'] ?? 0}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                              )),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                if (!loadingPreview && previewError == null && totalUnassigned > 0)
                  ElevatedButton(
                    onPressed: distributing
                        ? null
                        : () async {
                            setModalState(() => distributing = true);
                            try {
                              await session.api!.distributeLeads(session.userId);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Leads distributed successfully!')),
                                );
                              }
                              if (mounted) {
                                _fetchLeads();
                              }
                            } catch (e) {
                              setModalState(() => distributing = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(distributing ? 'Distributing...' : 'Confirm Distribute'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _statBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // 5. CSV Importer Modal
  void _showCsvImportModal(BuildContext context) {
    final session = context.read<AuthSession>();
    final csvCtrl = TextEditingController();
    bool uploading = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Upload Google Sheet (CSV)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paste your Google Sheet exported CSV text below to import leads into CRM:',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: csvCtrl,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        hintText: 'Timestamp, Name, Contact, Business Name, Status...',
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: uploading
                      ? null
                      : () async {
                          final text = csvCtrl.text.trim();
                          if (text.isEmpty) return;
                          setModalState(() => uploading = true);
                          try {
                            final res = await session.api!.importLeadsCsv(
                              csvText: text,
                              fileName: 'mobile_import.csv',
                              importedBy: session.userId,
                            );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              final total = res['summary']?['totalParsed'] ?? 0;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Successfully imported $total lead(s)!')),
                              );
                            }
                            if (mounted) {
                              _fetchLeads();
                            }
                          } catch (e) {
                            setModalState(() => uploading = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(uploading ? 'Importing...' : 'Import Leads'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    final d = DateTime.tryParse(v.toString());
    if (d == null) return v.toString();
    return '${d.day}/${d.month}/${d.year}';
  }
}
