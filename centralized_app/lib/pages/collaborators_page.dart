import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_session.dart';

const kCollaboratorRateTypes = ['Per Hour', 'Per Day', 'Per Project', 'Fixed'];
const kCollaboratorIndividualTypes = [
  'Influencer',
  'Model',
  'Video Editor',
  'Cinematographer',
  'Content Writer',
];

class CollaboratorsPage extends StatefulWidget {
  const CollaboratorsPage({super.key});

  @override
  State<CollaboratorsPage> createState() => _CollaboratorsPageState();
}

class _CollaboratorsPageState extends State<CollaboratorsPage> {
  List<Map<String, dynamic>> _collaborators = [];
  bool _loading = true;
  String? _error;

  // Filters
  String _filterRateType = '';
  String _filterIndividualType = '';
  String _filterCity = '';
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchCollaborators();
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCollaborators() async {
    final session = context.read<AuthSession>();
    if (session.api == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await session.api!.getCollaborators(
        rateType: _filterRateType,
        city: _filterCity,
        individualType: _filterIndividualType,
      );
      if (!mounted) return;
      setState(() {
        _collaborators = list;
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

  void _clearFilters() {
    setState(() {
      _filterRateType = '';
      _filterIndividualType = '';
      _filterCity = '';
      _searchQuery = '';
      _cityCtrl.clear();
      _searchCtrl.clear();
    });
    _fetchCollaborators();
  }

  List<Map<String, dynamic>> get _filteredCollaborators {
    if (_searchQuery.trim().isEmpty) return _collaborators;
    final q = _searchQuery.toLowerCase().trim();
    return _collaborators.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final contact = (c['contactNo'] ?? '').toString().toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();
      final city = (c['city'] ?? '').toString().toLowerCase();
      final type = (c['individualType'] ?? '').toString().toLowerCase();
      return name.contains(q) ||
          contact.contains(q) ||
          email.contains(q) ||
          city.contains(q) ||
          type.contains(q);
    }).toList();
  }

  Future<void> _deleteCollaborator(String id, String name) async {
    final session = context.read<AuthSession>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Collaborator', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "$name"?'),
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
      await session.api!.deleteCollaborator(id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Collaborator deleted successfully')),
        );
        _fetchCollaborators();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    }
  }

  Future<void> _launchUrlString(String urlStr) async {
    if (urlStr.isEmpty) return;
    var formatted = urlStr.trim();
    if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
      formatted = 'https://$formatted';
    }
    final uri = Uri.parse(formatted);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $urlStr')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredCollaborators;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Collaborators', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: () => _showCollaboratorModal(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Collaborator', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
        onRefresh: _fetchCollaborators,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF334155)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 3)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.people_alt, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Collaborator Contacts',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Manage influencers, models, editors, and photographers.',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${items.length} Total',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Filter & Search Controls
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    // Search Bar
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search by name, phone, email, city...',
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
                    const SizedBox(height: 10),

                    // Dropdowns row
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _filterIndividualType,
                            decoration: InputDecoration(
                              labelText: 'Individual Type',
                              labelStyle: const TextStyle(fontSize: 11),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: [
                              const DropdownMenuItem(value: '', child: Text('All Types', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              ...kCollaboratorIndividualTypes.map((t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                                  )),
                            ],
                            onChanged: (v) {
                              setState(() => _filterIndividualType = v ?? '');
                              _fetchCollaborators();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _filterRateType,
                            decoration: InputDecoration(
                              labelText: 'Rate Type',
                              labelStyle: const TextStyle(fontSize: 11),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: [
                              const DropdownMenuItem(value: '', child: Text('All Rates', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              ...kCollaboratorRateTypes.map((r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                                  )),
                            ],
                            onChanged: (v) {
                              setState(() => _filterRateType = v ?? '');
                              _fetchCollaborators();
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // City Filter & Reset button
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cityCtrl,
                            onSubmitted: (v) {
                              setState(() => _filterCity = v.trim());
                              _fetchCollaborators();
                            },
                            decoration: InputDecoration(
                              labelText: 'Filter City',
                              labelStyle: const TextStyle(fontSize: 11),
                              isDense: true,
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.check, size: 16, color: Color(0xFF2563EB)),
                                onPressed: () {
                                  setState(() => _filterCity = _cityCtrl.text.trim());
                                  _fetchCollaborators();
                                },
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        if (_filterRateType.isNotEmpty ||
                            _filterIndividualType.isNotEmpty ||
                            _filterCity.isNotEmpty ||
                            _searchQuery.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.restart_alt, size: 14, color: Color(0xFFEF4444)),
                            label: const Text('Reset', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),


              // Collaborators List Body
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text('Error: $_error', style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
                )
              else if (items.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.folder_open, size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 10),
                      const Text(
                        'No collaborators found',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Add a collaborator or adjust your filters.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () => _showCollaboratorModal(context),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Collaborator', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final c = items[idx];
                    return _buildCollaboratorCard(c);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollaboratorCard(Map<String, dynamic> c) {
    final id = (c['_id'] ?? '').toString();
    final name = (c['name'] ?? 'Unnamed Collaborator').toString();
    final contactNo = (c['contactNo'] ?? '').toString();
    final email = (c['email'] ?? '').toString();
    final city = (c['city'] ?? '').toString();
    final state = (c['state'] ?? '').toString();
    final pincode = (c['pincode'] ?? '').toString();
    final rate = c['rate'];
    final rateType = (c['rateType'] ?? '').toString();
    final individualType = (c['individualType'] ?? '').toString();
    final socialMediaLink = (c['socialMediaLink'] ?? '').toString();
    final portfolioLink = (c['portfolioLink'] ?? '').toString();
    final description = (c['description'] ?? '').toString();

    final locationStr = [city, state, pincode].where((s) => s.isNotEmpty).join(', ');

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
            // Top Header: Name + Badge & Actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'C',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 16),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      if (individualType.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            individualType,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                      onPressed: () => _showCollaboratorModal(context, collaborator: c),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                      onPressed: () => _deleteCollaborator(id, name),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 18),

            // Contact & Location Details
            if (contactNo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(contactNo, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                    ),
                  ],
                ),
              ),

            if (email.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.email_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                    ),
                  ],
                ),
              ),

            if (locationStr.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(locationStr, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                    ),
                  ],
                ),
              ),

            if (rate != null && rate.toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.payments_outlined, size: 14, color: Color(0xFF16A34A)),
                    const SizedBox(width: 6),
                    Text(
                      'Rate: ${rateType.isNotEmpty ? '$rateType ' : ''}₹$rate',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                    ),
                  ],
                ),
              ),

            // Description
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  description,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                ),
              ),
            ],

            // Social & Portfolio Links
            if (socialMediaLink.isNotEmpty || portfolioLink.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (socialMediaLink.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => _launchUrlString(socialMediaLink),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.link, size: 12, color: Color(0xFF2563EB)),
                              SizedBox(width: 4),
                              Text('Social Link', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (portfolioLink.isNotEmpty)
                    InkWell(
                      onTap: () => _launchUrlString(portfolioLink),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.work_outline, size: 12, color: Color(0xFF16A34A)),
                            SizedBox(width: 4),
                            Text('Portfolio', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- ADD / EDIT COLLABORATOR MODAL ---
  void _showCollaboratorModal(BuildContext context, {Map<String, dynamic>? collaborator}) {
    final isEdit = collaborator != null;
    final id = isEdit ? (collaborator['_id'] ?? '').toString() : '';

    final nameCtrl = TextEditingController(text: isEdit ? (collaborator['name'] ?? '').toString() : '');
    final contactCtrl = TextEditingController(text: isEdit ? (collaborator['contactNo'] ?? '').toString() : '');
    final emailCtrl = TextEditingController(text: isEdit ? (collaborator['email'] ?? '').toString() : '');
    final cityCtrl = TextEditingController(text: isEdit ? (collaborator['city'] ?? '').toString() : '');
    final stateCtrl = TextEditingController(text: isEdit ? (collaborator['state'] ?? '').toString() : '');
    final pincodeCtrl = TextEditingController(text: isEdit ? (collaborator['pincode'] ?? '').toString() : '');
    final rateCtrl = TextEditingController(text: isEdit && collaborator['rate'] != null ? collaborator['rate'].toString() : '');
    final socialCtrl = TextEditingController(text: isEdit ? (collaborator['socialMediaLink'] ?? '').toString() : '');
    final portfolioCtrl = TextEditingController(text: isEdit ? (collaborator['portfolioLink'] ?? '').toString() : '');
    final descCtrl = TextEditingController(text: isEdit ? (collaborator['description'] ?? '').toString() : '');

    String rateType = isEdit ? (collaborator['rateType'] ?? '').toString() : '';
    String individualType = isEdit ? (collaborator['individualType'] ?? '').toString() : '';

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
                        Text(
                          isEdit ? 'Edit Collaborator' : 'Add Collaborator',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name *', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: contactCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Contact Number', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: individualType.isEmpty ? null : individualType,
                      decoration: const InputDecoration(labelText: 'Individual Type', isDense: true),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('None', style: TextStyle(fontSize: 11))),
                        ...kCollaboratorIndividualTypes.map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t, style: const TextStyle(fontSize: 11)),
                            )),
                      ],
                      onChanged: (v) => individualType = v ?? '',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: rateType.isEmpty ? null : rateType,
                            decoration: const InputDecoration(labelText: 'Rate Type', isDense: true),
                            items: [
                              const DropdownMenuItem(value: '', child: Text('None', style: TextStyle(fontSize: 11))),
                              ...kCollaboratorRateTypes.map((r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r, style: const TextStyle(fontSize: 11)),
                                  )),
                            ],
                            onChanged: (v) => rateType = v ?? '',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: rateCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Rate Amount (₹)', isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cityCtrl,
                            decoration: const InputDecoration(labelText: 'City', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: stateCtrl,
                            decoration: const InputDecoration(labelText: 'State', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: pincodeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Pincode', isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: socialCtrl,
                      decoration: const InputDecoration(labelText: 'Social Media Link', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: portfolioCtrl,
                      decoration: const InputDecoration(labelText: 'Portfolio Link', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Description / Notes', isDense: true),
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
                                    const SnackBar(content: Text('Name is required')),
                                  );
                                  return;
                                }

                                final pincode = pincodeCtrl.text.trim();
                                if (pincode.isNotEmpty && (pincode.length != 6 || int.tryParse(pincode) == null)) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Please enter a valid 6-digit pincode')),
                                  );
                                  return;
                                }

                                setModalState(() => saving = true);
                                final session = context.read<AuthSession>();
                                try {
                                  final body = <String, dynamic>{
                                    'name': name,
                                    'contactNo': contactCtrl.text.trim(),
                                    'email': emailCtrl.text.trim(),
                                    'city': cityCtrl.text.trim(),
                                    'state': stateCtrl.text.trim(),
                                    'pincode': pincode,
                                    'rateType': rateType,
                                    'rate': rateCtrl.text.trim().isNotEmpty ? double.tryParse(rateCtrl.text.trim()) : null,
                                    'individualType': individualType,
                                    'socialMediaLink': socialCtrl.text.trim(),
                                    'portfolioLink': portfolioCtrl.text.trim(),
                                    'description': descCtrl.text.trim(),
                                  };

                                  if (isEdit) {
                                    await session.api!.updateCollaborator(id, body);
                                  } else {
                                    await session.api!.createCollaborator(body);
                                  }

                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text(isEdit ? 'Collaborator updated!' : 'Collaborator created!')),
                                    );
                                    Navigator.pop(ctx);
                                  }
                                  if (mounted) {
                                    _fetchCollaborators();
                                  }
                                } catch (e) {
                                  setModalState(() => saving = false);
                                  if (ctx.mounted) {
                                    final errMsg = e.toString().replaceFirst('Exception: ', '');
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Error: $errMsg')),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(saving ? 'Saving...' : (isEdit ? 'Update Collaborator' : 'Create Collaborator')),
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
