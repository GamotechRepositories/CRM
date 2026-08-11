import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';

const kAssetTypes = ['Laptop', 'Desktop', 'Mobile Phone', 'SIM Card', 'Access Card', 'Monitor', 'Other'];
const kAssetStatuses = ['Available', 'Assigned', 'Maintenance', 'Retired'];

class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key});

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  List<Map<String, dynamic>> _assets = [];
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  String? _error;

  String _searchQuery = '';
  String _typeFilter = '';
  String _statusFilter = '';

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
      final results = await Future.wait([
        session.api!.fetchAssets(),
        session.api!.fetchEmployees().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _assets = results[0];
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

  List<Map<String, dynamic>> get _filteredAssets {
    return _assets.where((asset) {
      final status = (asset['status'] ?? 'Available').toString();
      if (_statusFilter.isNotEmpty && status != _statusFilter) return false;

      final type = (asset['assetType'] ?? '').toString();
      if (_typeFilter.isNotEmpty && type != _typeFilter) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final name = (asset['name'] ?? '').toString().toLowerCase();
        final tag = (asset['assetTag'] ?? '').toString().toLowerCase();
        final serial = (asset['serialNumber'] ?? '').toString().toLowerCase();
        final brand = (asset['brand'] ?? '').toString().toLowerCase();

        final assigned = asset['assignedTo'];
        final assignedName = assigned is Map ? (assigned['name'] ?? '').toString().toLowerCase() : '';

        return name.contains(q) || tag.contains(q) || serial.contains(q) || brand.contains(q) || assignedName.contains(q);
      }

      return true;
    }).toList();
  }

  Map<String, dynamic> get _stats {
    final total = _assets.length;
    final available = _assets.where((a) => (a['status'] ?? '') == 'Available').length;
    final assigned = _assets.where((a) => (a['status'] ?? '') == 'Assigned').length;
    final maintenance = _assets.where((a) => (a['status'] ?? '') == 'Maintenance').length;

    return {
      'total': total,
      'available': available,
      'assigned': assigned,
      'maintenance': maintenance,
    };
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _typeFilter = '';
      _statusFilter = '';
      _searchCtrl.clear();
    });
  }

  IconData _getAssetIcon(String type) {
    switch (type) {
      case 'Laptop':
        return Icons.laptop_mac;
      case 'Desktop':
        return Icons.desktop_windows;
      case 'Mobile Phone':
        return Icons.smartphone;
      case 'SIM Card':
        return Icons.sim_card;
      case 'Access Card':
        return Icons.badge;
      case 'Monitor':
        return Icons.monitor;
      default:
        return Icons.devices_other;
    }
  }

  Future<void> _deleteAsset(String id, String name) async {
    final session = context.read<AuthSession>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Asset', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete asset "$name"?'),
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
      await session.api!.deleteAsset(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asset deleted successfully')),
        );
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
    final filtered = _filteredAssets;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Company Assets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: () => _showAssetModal(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Asset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                      title: 'Total',
                      value: '${stats['total']}',
                      icon: Icons.inventory_2,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Available',
                      value: '${stats['available']}',
                      icon: Icons.check_circle_outline,
                      iconBg: const Color(0xFFECFDF5),
                      iconColor: const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Assigned',
                      value: '${stats['assigned']}',
                      icon: Icons.person_pin,
                      iconBg: const Color(0xFFEEF2FF),
                      iconColor: const Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Maintenance',
                      value: '${stats['maintenance']}',
                      icon: Icons.build_circle_outlined,
                      iconBg: const Color(0xFFFFFBEB),
                      iconColor: const Color(0xFFF59E0B),
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
                        hintText: 'Search by asset name, tag, serial number...',
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
                            initialValue: _typeFilter,
                            decoration: InputDecoration(
                              labelText: 'Asset Type',
                              labelStyle: const TextStyle(fontSize: 11),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: [
                              const DropdownMenuItem(value: '', child: Text('All Types', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              ...kAssetTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (v) => setState(() => _typeFilter = v ?? ''),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
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
                              const DropdownMenuItem(value: '', child: Text('All Status', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              ...kAssetStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (v) => setState(() => _statusFilter = v ?? ''),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty || _typeFilter.isNotEmpty || _statusFilter.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.restart_alt, size: 18, color: Color(0xFFEF4444)),
                            onPressed: _clearFilters,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Asset Cards List
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
                      Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF94A3B8)),
                      SizedBox(height: 10),
                      Text(
                        'No assets found',
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
                    final asset = filtered[idx];
                    return _buildAssetCard(asset);
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
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
            child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetCard(Map<String, dynamic> asset) {
    final id = (asset['_id'] ?? '').toString();
    final name = (asset['name'] ?? 'Unnamed Asset').toString();
    final type = (asset['assetType'] ?? 'Other').toString();
    final tag = (asset['assetTag'] ?? '').toString();
    final brand = (asset['brand'] ?? '').toString();
    final model = (asset['model'] ?? '').toString();
    final status = (asset['status'] ?? 'Available').toString();

    final assigned = asset['assignedTo'];
    final assignedName = assigned is Map ? (assigned['name'] ?? '—').toString() : 'Unassigned';

    Color statusBg;
    Color statusFg;
    Color statusBorder;

    if (status == 'Available') {
      statusBg = const Color(0xFFECFDF5);
      statusFg = const Color(0xFF047857);
      statusBorder = const Color(0xFFA7F3D0);
    } else if (status == 'Assigned') {
      statusBg = const Color(0xFFEFF6FF);
      statusFg = const Color(0xFF1D4ED8);
      statusBorder = const Color(0xFFBFDBFE);
    } else if (status == 'Maintenance') {
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_getAssetIcon(type), color: const Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
                      const SizedBox(height: 2),
                      Text(
                        '$type ${tag.isNotEmpty ? '· Tag: $tag' : ''}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 18),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Brand & Model', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      Text(brand.isNotEmpty ? '$brand $model' : '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Assigned To', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      Text(assignedName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showAssignModal(context, asset),
                  icon: const Icon(Icons.person_add_alt, size: 14),
                  label: const Text('Assign', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF059669)),
                ),
                TextButton.icon(
                  onPressed: () => _showAssetModal(context, asset: asset),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                  onPressed: () => _deleteAsset(id, name),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- ADD / EDIT ASSET MODAL ---
  void _showAssetModal(BuildContext context, {Map<String, dynamic>? asset}) {
    final isEdit = asset != null;
    final id = isEdit ? (asset['_id'] ?? '').toString() : '';

    final nameCtrl = TextEditingController(text: isEdit ? (asset['name'] ?? '').toString() : '');
    final tagCtrl = TextEditingController(text: isEdit ? (asset['assetTag'] ?? '').toString() : '');
    final serialCtrl = TextEditingController(text: isEdit ? (asset['serialNumber'] ?? '').toString() : '');
    final brandCtrl = TextEditingController(text: isEdit ? (asset['brand'] ?? '').toString() : '');
    final modelCtrl = TextEditingController(text: isEdit ? (asset['model'] ?? '').toString() : '');

    String type = isEdit ? (asset['assetType'] ?? 'Laptop').toString() : 'Laptop';
    String status = isEdit ? (asset['status'] ?? 'Available').toString() : 'Available';
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
                          isEdit ? 'Edit Asset' : 'Add New Asset',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Asset Name *', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: type,
                            decoration: const InputDecoration(labelText: 'Asset Type', isDense: true),
                            items: kAssetTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 11)))).toList(),
                            onChanged: (v) => type = v ?? type,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: status,
                            decoration: const InputDecoration(labelText: 'Status', isDense: true),
                            items: kAssetStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11)))).toList(),
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
                            controller: tagCtrl,
                            decoration: const InputDecoration(labelText: 'Asset Tag (ID)', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: serialCtrl,
                            decoration: const InputDecoration(labelText: 'Serial Number', isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: brandCtrl,
                            decoration: const InputDecoration(labelText: 'Brand', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: modelCtrl,
                            decoration: const InputDecoration(labelText: 'Model', isDense: true),
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
                                    const SnackBar(content: Text('Asset Name is required')),
                                  );
                                  return;
                                }

                                setModalState(() => saving = true);
                                final session = context.read<AuthSession>();
                                try {
                                  final body = <String, dynamic>{
                                    'name': name,
                                    'assetType': type,
                                    'status': status,
                                    'assetTag': tagCtrl.text.trim(),
                                    'serialNumber': serialCtrl.text.trim(),
                                    'brand': brandCtrl.text.trim(),
                                    'model': modelCtrl.text.trim(),
                                  };

                                  if (isEdit) {
                                    await session.api!.updateAsset(id, body);
                                  } else {
                                    await session.api!.createAsset(body);
                                  }

                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text(isEdit ? 'Asset updated!' : 'Asset created!')),
                                    );
                                    Navigator.pop(ctx);
                                  }
                                  if (mounted) {
                                    _fetchData();
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
                        child: Text(saving ? 'Saving...' : (isEdit ? 'Update Asset' : 'Create Asset')),
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

  // --- ASSIGN ASSET MODAL ---
  void _showAssignModal(BuildContext context, Map<String, dynamic> asset) {
    final assetId = (asset['_id'] ?? '').toString();
    final assetName = (asset['name'] ?? 'Asset').toString();
    String selectedEmpId = '';
    bool assigning = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Assign "$assetName"', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedEmpId,
                    decoration: const InputDecoration(labelText: 'Select Employee', isDense: true),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Unassigned', style: TextStyle(fontSize: 11))),
                      ..._employees.map((e) => DropdownMenuItem(
                            value: (e['_id'] ?? '').toString(),
                            child: Text((e['name'] ?? '—').toString(), style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => selectedEmpId = v ?? '',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: assigning
                          ? null
                          : () async {
                              setModalState(() => assigning = true);
                              final session = context.read<AuthSession>();
                              try {
                                await session.api!.assignAsset(assetId, selectedEmpId);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Asset assigned successfully!')),
                                  );
                                  Navigator.pop(ctx);
                                }
                                if (mounted) {
                                  _fetchData();
                                }
                              } catch (e) {
                                setModalState(() => assigning = false);
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
                      child: Text(assigning ? 'Assigning...' : 'Confirm Assignment'),
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
}
