import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../navigation/app_nav.dart';
import '../utils/project_helpers.dart';

/// Projects Page — supports all projects (`/projects`) or user projects (`/my-projects`).
class MyProjectsPage extends StatefulWidget {
  const MyProjectsPage({super.key, this.isAllProjects = false});

  final bool isAllProjects;

  @override
  State<MyProjectsPage> createState() => _MyProjectsPageState();
}

class _MyProjectsPageState extends State<MyProjectsPage> {
  List<Map<String, dynamic>> _projects = [];
  bool _loading = true;
  String? _error;

  String _filterStatus = 'All';
  String _filterClient = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = context.read<AuthSession>();
    final api = session.api;
    if (api == null || session.userId.isEmpty) {
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
      final items = widget.isAllProjects
          ? await api.fetchProjects()
          : await api.fetchMyProjects(session.userId);
      if (!mounted) return;
      setState(() {
        _projects = items;
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

  List<({String id, String name})> get _clientOptions {
    final map = <String, String>{};
    for (final p in _projects) {
      final id = ProjectHelpers.clientId(p);
      final name = ProjectHelpers.clientName(p);
      if (id != null && id.isNotEmpty && name != '—') map[id] = name;
    }
    final list = map.entries.map((e) => (id: e.key, name: e.value)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<Map<String, dynamic>> get _filteredProjects {
    final q = _searchQuery.trim().toLowerCase();
    return _projects.where((p) {
      if (_filterStatus != 'All' && p['status'] != _filterStatus) return false;
      if (_filterClient != 'All') {
        final cid = ProjectHelpers.clientId(p);
        if (cid != _filterClient) return false;
      }
      if (q.isNotEmpty) {
        final pm = p['projectManager'];
        final pmName = pm is Map ? (pm['name'] ?? '').toString() : '';
        final hay = [
          ProjectHelpers.projectName(p),
          ProjectHelpers.clientName(p),
          pmName,
        ].join(' ').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse('${a['createdAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = DateTime.tryParse('${b['createdAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
          const SizedBox(height: 8),
          TextButton(onPressed: _load, child: const Text('Retry', style: TextStyle(fontSize: 12))),
        ],
      );
    }

    final stats = ProjectHelpers.computeStats(_projects);
    final chartData = ProjectHelpers.statusChartData(_projects);
    final upcoming = ProjectHelpers.upcomingDeadlines(_projects);
    final topClients = ProjectHelpers.topClients(_projects);
    final filtered = _filteredProjects;

    return RefreshIndicator(
      onRefresh: _load,
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 72),
            children: [
              Text(
                widget.isAllProjects
                    ? 'Track and manage all projects in one place.'
                    : 'Projects where you are assigned as project manager or team member.',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35),
              ),
              const SizedBox(height: 8),
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _KpiCard(
                          title: 'Total Projects',
                          value: '${stats.total}',
                          subtitle: stats.growth >= 0 ? '+${stats.growth}% this month' : '${stats.growth}% this month',
                          icon: Icons.folder_outlined,
                          iconBg: const Color(0xFFF3E8FF),
                          iconColor: const Color(0xFF8B5CF6),
                          lineColor: const Color(0xFF10B981),
                          sparklineData: _sparklineForCount(stats.total, stats.total > 0 ? stats.total : 1),
                          onTap: () => setState(() => _filterStatus = 'All'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _KpiCard(
                          title: 'In Progress',
                          value: '${stats.inProgress}',
                          subtitle: '${stats.pct(stats.inProgress)}% of total',
                          icon: Icons.show_chart_rounded,
                          iconBg: const Color(0xFFE8F0FE),
                          iconColor: const Color(0xFF2563EB),
                          lineColor: const Color(0xFF2563EB),
                          sparklineData: _sparklineForCount(stats.inProgress, stats.total > 0 ? stats.total : 1),
                          onTap: () => setState(() => _filterStatus = 'In Progress'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _KpiCard(
                          title: 'Completed',
                          value: '${stats.completed}',
                          subtitle: '${stats.pct(stats.completed)}% of total',
                          icon: Icons.check_circle_outline_rounded,
                          iconBg: const Color(0xFFE6F4EA),
                          iconColor: const Color(0xFF10B981),
                          lineColor: const Color(0xFF10B981),
                          sparklineData: _sparklineForCount(stats.completed, stats.total > 0 ? stats.total : 1),
                          onTap: () => setState(() => _filterStatus = 'Completed'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _KpiCard(
                          title: 'On Hold',
                          value: '${stats.onHold}',
                          subtitle: '${stats.pct(stats.onHold)}% of total',
                          icon: Icons.pause_circle_outline_rounded,
                          iconBg: const Color(0xFFFEF3C7),
                          iconColor: const Color(0xFFF59E0B),
                          lineColor: const Color(0xFFF59E0B),
                          sparklineData: _sparklineForCount(stats.onHold, stats.total > 0 ? stats.total : 1, isIncreasing: false),
                          onTap: () => setState(() => _filterStatus = 'On Hold'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _FiltersBar(
                searchQuery: _searchQuery,
                filterStatus: _filterStatus,
                filterClient: _filterClient,
                clients: _clientOptions,
                onSearchChanged: (v) => setState(() => _searchQuery = v),
                onStatusChanged: (v) => setState(() => _filterStatus = v),
                onClientChanged: (v) => setState(() => _filterClient = v),
                onClear: () => setState(() {
                  _searchQuery = '';
                  _filterStatus = 'All';
                  _filterClient = 'All';
                }),
              ),
              const SizedBox(height: 8),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No projects match your filters',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ),
                )
              else
                ...filtered.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final project = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _ProjectTile(
                      project: project,
                      index: idx,
                      onTap: () => _openProjectDetail(project, idx),
                      onAssignTask: () => AppNavScope.navigate(context, '/assign-task-self'),
                    ),
                  );
                }),
              const SizedBox(height: 10),
              if (chartData.isNotEmpty) _StatusPanel(data: chartData, total: stats.total),
              if (upcoming.isNotEmpty) ...[
                const SizedBox(height: 8),
                _UpcomingPanel(projects: upcoming),
              ],
              if (topClients.isNotEmpty) ...[
                const SizedBox(height: 8),
                _TopClientsPanel(clients: topClients),
              ],
            ],
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton.extended(
              onPressed: () => AppNavScope.navigate(context, '/assign-task-self'),
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.assignment_add, size: 18),
              label: const Text('Assign Task', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openProjectDetail(Map<String, dynamic> project, int index) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProjectDetailSheet(project: project, index: index),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.lineColor,
    required this.sparklineData,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color lineColor;
  final List<double> sparklineData;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: iconColor, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF94A3B8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      height: 18,
                      child: CustomPaint(
                        painter: _MiniSparklinePainter(
                          values: sparklineData,
                          lineColor: lineColor,
                        ),
                      ),
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
}

List<double> _sparklineForCount(int count, int total, {bool isIncreasing = true}) {
  if (total == 0 || count == 0) {
    return const [0.2, 0.2, 0.25, 0.2, 0.3, 0.25, 0.2];
  }
  final ratio = (count / total).clamp(0.1, 1.0);
  if (isIncreasing) {
    return [
      0.2,
      0.25 + (ratio * 0.1),
      0.2 + (ratio * 0.2),
      0.35 + (ratio * 0.15),
      0.3 + (ratio * 0.25),
      0.5 + (ratio * 0.2),
      0.4 + (ratio * 0.45),
    ];
  } else {
    return [
      0.7,
      0.6 - (ratio * 0.1),
      0.5 - (ratio * 0.15),
      0.4 - (ratio * 0.1),
      0.35 - (ratio * 0.15),
      0.25 - (ratio * 0.1),
      0.2,
    ];
  }
}

class _MiniSparklinePainter extends CustomPainter {
  _MiniSparklinePainter({required this.values, required this.lineColor});
  final List<double> values;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final path = Path();
    final stepX = size.width / (values.length - 1);
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - (values[i] * size.height * 0.85);
      points.add(Offset(x, y));
    }

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    final strokePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter oldDelegate) => false;
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.searchQuery,
    required this.filterStatus,
    required this.filterClient,
    required this.clients,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onClientChanged,
    required this.onClear,
  });

  final String searchQuery;
  final String filterStatus;
  final String filterClient;
  final List<({String id, String name})> clients;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onClientChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search projects...',
            hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
          style: const TextStyle(fontSize: 11),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ProjectHelpers.statusOptions.length,
            separatorBuilder: (context, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final s = ProjectHelpers.statusOptions[i];
              final selected = filterStatus == s;
              return FilterChip(
                label: Text(
                  s == 'All' ? 'All Status' : s,
                  style: TextStyle(fontSize: 10, color: selected ? Colors.white : const Color(0xFF475569)),
                ),
                selected: selected,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                selectedColor: const Color(0xFF2563EB),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                showCheckmark: false,
                onSelected: (_) => onStatusChanged(s),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                isDense: true,
                initialValue: filterClient,
                decoration: _filterDecoration('Client'),
                style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                items: [
                  const DropdownMenuItem(value: 'All', child: Text('All Clients', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                  ...clients.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (v) => onClientChanged(v ?? 'All'),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Clear', style: TextStyle(fontSize: 10)),
            ),
          ],
        ),
      ],
    );
  }

  static InputDecoration _filterDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.project,
    required this.index,
    required this.onTap,
    required this.onAssignTask,
  });

  final Map<String, dynamic> project;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onAssignTask;

  @override
  Widget build(BuildContext context) {
    final name = ProjectHelpers.projectName(project);
    final status = (project['status'] ?? 'Not Started').toString();
    final (bg, fg) = ProjectHelpers.statusColors(status);
    final progress = (project['progress'] is num) ? (project['progress'] as num).round() : int.tryParse('${project['progress']}') ?? 0;
    final deadline = project['deadline'] ?? project['endDate'];
    final deadlineColor = ProjectHelpers.deadlineColor(deadline, status);
    final team = ProjectHelpers.teamList(project);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(8)),
                    alignment: Alignment.center,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'P',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                        Text(
                          ProjectHelpers.projectCode(project, index),
                          style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    onSelected: (v) {
                      if (v == 'assign') onAssignTask();
                      if (v == 'detail') onTap();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'detail', child: Text('Details', style: TextStyle(fontSize: 11))),
                      const PopupMenuItem(value: 'assign', child: Text('Assign Task', style: TextStyle(fontSize: 11))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                    child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: fg)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ProjectHelpers.clientName(project),
                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        minHeight: 5,
                        backgroundColor: const Color(0xFFF1F5F9),
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$progress%', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _TeamAvatars(team: team),
                  const Spacer(),
                  Icon(Icons.event, size: 12, color: deadlineColor),
                  const SizedBox(width: 4),
                  Text(
                    ProjectHelpers.formatDeadline(deadline),
                    style: TextStyle(fontSize: 10, color: deadlineColor, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    ProjectHelpers.formatInr(project['budget']),
                    style: const TextStyle(fontSize: 10, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamAvatars extends StatelessWidget {
  const _TeamAvatars({required this.team});

  final List<Map<String, dynamic>> team;

  @override
  Widget build(BuildContext context) {
    if (team.isEmpty) return const Text('—', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8)));
    final shown = team.take(4).toList();
    return SizedBox(
      height: 24,
      width: 24.0 + (shown.length - 1) * 16.0 + (team.length > 4 ? 16.0 : 0),
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 16.0,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFFDBEAFE),
                child: Text(
                  _initials(shown[i]),
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                ),
              ),
            ),
          if (team.length > 4)
            Positioned(
              left: 4 * 16.0,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFFF1F5F9),
                child: Text('+${team.length - 4}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
              ),
            ),
        ],
      ),
    );
  }

  String _initials(Map<String, dynamic> person) {
    final name = (person['name'] ?? '?').toString().trim();
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.data, required this.total});

  final List<({String name, int value, Color color})> data;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Projects by Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...data.map((d) {
            final pct = total == 0 ? 0.0 : d.value / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: d.color, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(d.name, style: const TextStyle(fontSize: 10, color: Color(0xFF475569)))),
                      Text('${d.value}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 4,
                      backgroundColor: const Color(0xFFF1F5F9),
                      color: d.color,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _UpcomingPanel extends StatelessWidget {
  const _UpcomingPanel({required this.projects});

  final List<Map<String, dynamic>> projects;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upcoming Deadlines', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...projects.map((p) {
            final deadline = p['deadline'] ?? p['endDate'];
            final color = ProjectHelpers.deadlineColor(deadline, p['status']?.toString());
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ProjectHelpers.projectName(p),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    ProjectHelpers.formatDeadline(deadline),
                    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TopClientsPanel extends StatelessWidget {
  const _TopClientsPanel({required this.clients});

  final List<({String id, String name, int count})> clients;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Clients', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...clients.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(c.name, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                      child: Text('${c.count}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _ProjectDetailSheet extends StatelessWidget {
  const _ProjectDetailSheet({required this.project, required this.index});

  final Map<String, dynamic> project;
  final int index;

  @override
  Widget build(BuildContext context) {
    final status = (project['status'] ?? 'Not Started').toString();
    final (bg, fg) = ProjectHelpers.statusColors(status);
    final progress = (project['progress'] is num) ? (project['progress'] as num).round() : int.tryParse('${project['progress']}') ?? 0;
    final deadline = project['deadline'] ?? project['endDate'];
    final team = ProjectHelpers.teamList(project);
    final pm = project['projectManager'];
    final pmName = pm is Map ? (pm['name'] ?? '—').toString() : '—';

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(
                ProjectHelpers.projectName(project),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              Text(
                ProjectHelpers.projectCode(project, index),
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
              ),
              const SizedBox(height: 16),
              _DetailRow(label: 'Client', value: ProjectHelpers.clientName(project)),
              _DetailRow(label: 'Project Manager', value: pmName),
              _DetailRow(label: 'Deadline', value: ProjectHelpers.formatDeadline(deadline)),
              _DetailRow(label: 'Budget', value: ProjectHelpers.formatInr(project['budget'])),
              _DetailRow(label: 'Progress', value: '$progress%'),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF1F5F9),
                  color: const Color(0xFF3B82F6),
                ),
              ),
              if (project['description'] != null && '${project['description']}'.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Description', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                Text('${project['description']}', style: const TextStyle(fontSize: 11, height: 1.4)),
              ],
              if (team.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Team', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                ...team.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: const Color(0xFFDBEAFE),
                            child: Text(
                              ((m['name'] ?? '?').toString().trim().isNotEmpty ? (m['name'] as String)[0] : '?').toUpperCase(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text((m['name'] ?? 'Member').toString(), style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    )),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    AppNavScope.navigate(context, '/assign-task-self');
                  },
                  icon: const Icon(Icons.assignment_add, size: 16),
                  label: const Text('Assign Task', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
