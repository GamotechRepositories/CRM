import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../auth/role_access.dart';
import '../config/company_config.dart';
import 'sidebar_nav.dart';

/// Compact drawer sidebar — same menu tree for every company.
class AppSidebar extends StatefulWidget {
  const AppSidebar({
    super.key,
    required this.nav,
    required this.selectedPath,
    required this.onSelect,
    required this.onSettings,
    required this.onLogout,
  });

  final List<SidebarEntry> nav;
  final String selectedPath;
  final ValueChanged<String> onSelect;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    final company = session.company;

    return Drawer(
      width: 248,
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (company != null)
                        CompanyLogoWidget(company: company, size: 36)
                      else
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.business_rounded, color: Colors.white, size: 20),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              company?.displayName ?? 'MultiCRM',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (company != null) ...[
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: company.primaryColor.withAlpha(50),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: company.primaryColor.withAlpha(100)),
                                ),
                                child: Text(
                                  company.shortName,
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: company.primaryColor),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: const Color(0xFF334155),
                          child: Text(
                            session.userName.isNotEmpty ? session.userName[0].toUpperCase() : 'U',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.userName.isEmpty ? 'Logged User' : session.userName,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                session.userEmail,
                                style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF1E293B)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: [
                  for (final entry in widget.nav) _buildEntry(entry),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF1E293B)),
            _footerTile(Icons.settings_outlined, 'Settings', widget.onSettings),
            _footerTile(Icons.logout, 'Logout', widget.onLogout, danger: true),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildEntry(SidebarEntry entry) {
    if (entry.type == SidebarEntryType.link) {
      return _linkTile(
        icon: entry.icon,
        label: entry.label,
        path: entry.path!,
        selected: widget.selectedPath == entry.path,
      );
    }

    final expanded = _expanded.contains(entry.id);
    final childSelected = entry.children.any((c) => c.path == widget.selectedPath);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() {
            if (expanded) {
              _expanded.remove(entry.id);
            } else {
              _expanded.clear();
              _expanded.add(entry.id);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Text(entry.icon, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: childSelected ? Colors.white : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          for (final child in entry.children)
            _linkTile(
              icon: '•',
              label: child.label,
              path: child.path,
              selected: widget.selectedPath == child.path,
              nested: true,
            ),
      ],
    );
  }

  Widget _linkTile({
    required String icon,
    required String label,
    required String path,
    required bool selected,
    bool nested = false,
  }) {
    return Material(
      color: selected ? const Color(0xFF2563EB) : Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          widget.onSelect(path);
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(nested ? 28 : 12, 7, 12, 7),
          child: Row(
            children: [
              if (!nested) Text(icon, style: const TextStyle(fontSize: 13)),
              if (nested)
                const Text('•', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: nested ? 10 : 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? Colors.white : const Color(0xFFCBD5E1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footerTile(IconData icon, String label, VoidCallback onTap, {bool danger = false}) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      minLeadingWidth: 22,
      leading: Icon(icon, size: 16, color: danger ? const Color(0xFFFCA5A5) : const Color(0xFF94A3B8)),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: danger ? const Color(0xFFFCA5A5) : const Color(0xFFCBD5E1),
        ),
      ),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }
}

SidebarNavContext sidebarContextForSession(AuthSession session) {
  final user = session.user;
  final company = session.company;
  return SidebarNavContext(
    fullAccess: RoleAccess.hasFullAccess(user),
    canViewProjects: RoleAccess.canViewProjects(user),
    isTeamLeader: RoleAccess.isTeamLeader(user),
    canViewTravelAndRouteMap: RoleAccess.canViewTravelAndRouteMap(user),
    dashboardPath: RoleAccess.dashboardPath(user),
    includeProperties: company?.id != CompanyId.adsResearchGlobal,
    allowedSections: RoleAccess.sidebarSections(user),
  );
}
