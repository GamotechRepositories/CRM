import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';

const kPlatforms = ['All', 'Instagram', 'Facebook', 'Twitter', 'LinkedIn', 'YouTube', 'Other'];
const kContentTypes = ['Reel', 'Feed Post', 'Carousel', 'Story'];

class SocialMediaPage extends StatefulWidget {
  const SocialMediaPage({super.key});

  @override
  State<SocialMediaPage> createState() => _SocialMediaPageState();
}

class _SocialMediaPageState extends State<SocialMediaPage> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String? _error;

  String _selectedPlatform = 'All';
  String _searchQuery = '';

  final TextEditingController _searchCtrl = TextEditingController();

  final List<Map<String, dynamic>> _demoPosts = [
    {
      'id': '1',
      'title': 'Luxury Penthouse Reel Tour',
      'platform': 'Instagram',
      'contentType': 'Reel',
      'subject': 'Showcasing the top-floor skyline view',
      'scheduledTime': 'Feb 12, 2026 at 06:00 PM',
      'status': 'Accepted',
      'client': 'Skyline Realty',
    },
    {
      'id': '2',
      'title': 'Q1 Investment Market Insights',
      'platform': 'LinkedIn',
      'contentType': 'Carousel',
      'subject': '3 Key real estate market trends in 2026',
      'scheduledTime': 'Feb 14, 2026 at 10:00 AM',
      'status': 'Pending',
      'client': 'Digital Solutions',
    },
    {
      'id': '3',
      'title': 'Weekend Open House Announcement',
      'platform': 'Facebook',
      'contentType': 'Feed Post',
      'subject': 'Join us this Saturday for live walkthroughs',
      'scheduledTime': 'Feb 16, 2026 at 11:30 AM',
      'status': 'Accepted',
      'client': 'E-Commerce Hub',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPosts() async {
    final session = context.read<AuthSession>();
    if (session.api == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await session.api!.fetchSocialCalendar();
      if (!mounted) return;
      setState(() {
        _posts = list.isNotEmpty ? list : _demoPosts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posts = _demoPosts;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredPosts {
    return _posts.where((p) {
      final platform = (p['platform'] ?? 'Other').toString();
      if (_selectedPlatform != 'All' && platform != _selectedPlatform) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final title = (p['title'] ?? '').toString().toLowerCase();
        final subject = (p['subject'] ?? '').toString().toLowerCase();
        final client = (p['client'] ?? '').toString().toLowerCase();

        return title.contains(q) || subject.contains(q) || client.contains(q);
      }
      return true;
    }).toList();
  }

  Color _getPlatformColor(String platform) {
    switch (platform) {
      case 'Instagram':
        return const Color(0xFFE1306C);
      case 'Facebook':
        return const Color(0xFF1877F2);
      case 'Twitter':
        return const Color(0xFF1DA1F2);
      case 'LinkedIn':
        return const Color(0xFF0A66C2);
      case 'YouTube':
        return const Color(0xFFFF0000);
      default:
        return const Color(0xFF9333EA);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPosts;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Social Media Calendar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: () => _showAddPostModal(context),
              icon: const Icon(Icons.add_photo_alternate, size: 16),
              label: const Text('New Post', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
        onRefresh: _fetchPosts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Platform Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: kPlatforms.map((platform) {
                    final selected = _selectedPlatform == platform;
                    final color = _getPlatformColor(platform);

                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: FilterChip(
                        selected: selected,
                        label: Text(platform, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: selected ? Colors.white : color)),
                        backgroundColor: Colors.white,
                        selectedColor: color,
                        side: BorderSide(color: selected ? color : color.withAlpha(100)),
                        onSelected: (val) => setState(() => _selectedPlatform = platform),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // Search Query Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search social posts by title, subject, client...',
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
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 14),

              // Posts List Body
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
                      Icon(Icons.calendar_today_outlined, size: 48, color: Color(0xFF94A3B8)),
                      SizedBox(height: 10),
                      Text(
                        'No social media posts scheduled',
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
                    return _buildPostCard(item);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> p) {
    final title = (p['title'] ?? 'Social Post').toString();
    final platform = (p['platform'] ?? 'Instagram').toString();
    final contentType = (p['contentType'] ?? 'Feed Post').toString();
    final subject = (p['subject'] ?? '').toString();
    final time = (p['scheduledTime'] ?? '—').toString();
    final client = (p['client'] ?? 'Client').toString();
    final status = (p['status'] ?? 'Pending').toString();

    final platformColor = _getPlatformColor(platform);
    final isAccepted = status == 'Accepted';

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
                    color: platformColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.share, color: platformColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text('$client • $contentType', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: platformColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(platform, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
            if (subject.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(subject, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
            ],
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(time, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAccepted ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isAccepted ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isAccepted ? const Color(0xFF047857) : const Color(0xFFB45309)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPostModal(BuildContext context) {
    final titleCtrl = TextEditingController();
    final subjCtrl = TextEditingController();

    String platform = 'Instagram';
    String contentType = 'Feed Post';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Schedule Social Media Post', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(),
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Post Title *', isDense: true)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: platform,
                    decoration: const InputDecoration(labelText: 'Platform', isDense: true),
                    items: kPlatforms.where((p) => p != 'All').map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 11)))).toList(),
                    onChanged: (v) => platform = v ?? platform,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: contentType,
                    decoration: const InputDecoration(labelText: 'Content Type', isDense: true),
                    items: kContentTypes.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 11)))).toList(),
                    onChanged: (v) => contentType = v ?? contentType,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(controller: subjCtrl, decoration: const InputDecoration(labelText: 'Post Caption / Subject', isDense: true)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (titleCtrl.text.trim().isEmpty) return;
                  setState(() {
                    _posts.insert(0, {
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'title': titleCtrl.text.trim(),
                      'platform': platform,
                      'contentType': contentType,
                      'subject': subjCtrl.text.trim(),
                      'scheduledTime': 'Tomorrow at 10:00 AM',
                      'status': 'Accepted',
                      'client': 'Company Marketing',
                    });
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Social post scheduled!')));
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                child: const Text('Schedule Post'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
