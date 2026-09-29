import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_session.dart';
import '../auth/role_access.dart';
import '../config/company_config.dart';
import 'sidebar_nav.dart';

const _accent = Color(0xFF2563EB);
const _inactive = Color(0xFF8E8E93);
const _barHeight = 64.0;
const _barBottomGap = 10.0;

class BottomTab {
  const BottomTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.path,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// `null` for the "More" tab, which opens a sheet instead of a page.
  final String? path;

  bool get isMore => path == null;
}

const _myTasks = BottomTab(
  label: 'Tasks',
  icon: CupertinoIcons.checkmark_square,
  activeIcon: CupertinoIcons.checkmark_square_fill,
  path: '/my-tasks',
);
const _allTasks = BottomTab(
  label: 'Tasks',
  icon: CupertinoIcons.checkmark_square,
  activeIcon: CupertinoIcons.checkmark_square_fill,
  path: '/tasks',
);
const _myAttendance = BottomTab(
  label: 'Attendance',
  icon: CupertinoIcons.clock,
  activeIcon: CupertinoIcons.clock_fill,
  path: '/my-attendance',
);
const _teamAttendance = BottomTab(
  label: 'Attendance',
  icon: CupertinoIcons.clock,
  activeIcon: CupertinoIcons.clock_fill,
  path: '/attendance',
);
const _chat = BottomTab(
  label: 'Chat',
  icon: CupertinoIcons.chat_bubble_2,
  activeIcon: CupertinoIcons.chat_bubble_2_fill,
  path: '/module/chat',
);
const _leave = BottomTab(
  label: 'Leaves',
  icon: CupertinoIcons.calendar,
  activeIcon: CupertinoIcons.calendar_today,
  path: '/leave',
);
const _leads = BottomTab(
  label: 'Leads',
  icon: CupertinoIcons.person_crop_circle_badge_plus,
  activeIcon: CupertinoIcons.person_crop_circle_fill_badge_plus,
  path: '/leads',
);
const _reports = BottomTab(
  label: 'Reports',
  icon: CupertinoIcons.chart_bar,
  activeIcon: CupertinoIcons.chart_bar_fill,
  path: '/reports',
);
const _employees = BottomTab(
  label: 'Employees',
  icon: CupertinoIcons.person_2,
  activeIcon: CupertinoIcons.person_2_fill,
  path: '/employees',
);
const _payroll = BottomTab(
  label: 'Payroll',
  icon: CupertinoIcons.money_dollar_circle,
  activeIcon: CupertinoIcons.money_dollar_circle_fill,
  path: '/salaries',
);
const _myTeam = BottomTab(
  label: 'My Team',
  icon: CupertinoIcons.person_3,
  activeIcon: CupertinoIcons.person_3_fill,
  path: '/my-team',
);

/// Preferred tabs per dashboard, in priority order; later ones are fallbacks
/// used when the user lacks access to an earlier one.
List<BottomTab> _candidatesFor(DashboardKind kind) => switch (kind) {
      DashboardKind.admin => const [_leads, _allTasks, _reports, _employees, _chat],
      DashboardKind.hr => const [_employees, _teamAttendance, _leave, _payroll, _chat],
      DashboardKind.manager => const [_leads, _allTasks, _teamAttendance, _reports, _myTasks, _chat],
      DashboardKind.teamLeader => const [_myTeam, _myTasks, _leave, _myAttendance, _chat],
      DashboardKind.siteCoordinator => const [_myTasks, _myAttendance, _chat, _leave],
      DashboardKind.employee => const [_myTasks, _myAttendance, _chat, _leave],
    };

/// Home + up to three role-specific tabs + More. Only paths the user can
/// actually reach in [nav] are included.
List<BottomTab> bottomTabsFor(DashboardKind kind, List<SidebarEntry> nav, String dashboardPath) {
  bool available(String path) => SidebarNav.labelForPath(nav, path) != null;
  final seen = <String>{dashboardPath};
  final picked = <BottomTab>[];
  for (final tab in _candidatesFor(kind)) {
    if (picked.length == 3) break;
    if (!available(tab.path!) || !seen.add(tab.path!)) continue;
    picked.add(tab);
  }

  return [
    BottomTab(
      label: 'Home',
      icon: CupertinoIcons.house,
      activeIcon: CupertinoIcons.house_fill,
      path: dashboardPath,
    ),
    ...picked,
    const BottomTab(
      label: 'More',
      icon: CupertinoIcons.square_grid_2x2,
      activeIcon: CupertinoIcons.square_grid_2x2_fill,
    ),
  ];
}

/// Floating frosted-glass tab bar in the style of iOS.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<BottomTab> tabs;

  /// Index of the active tab, or -1 when the current page isn't a tab.
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, _barBottomGap + bottomInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: _barHeight,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 0.8),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    Expanded(
                      child: _TabItem(
                        tab: tabs[i],
                        selected: i == selectedIndex,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onTap(i);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.tab, required this.selected, required this.onTap});

  final BottomTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _accent : _inactive;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? _accent.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedScale(
                scale: selected ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: Icon(selected ? tab.activeIcon : tab.icon, size: 22, color: color),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: 10,
                letterSpacing: -0.1,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
              child: Text(tab.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

/// iOS-style grouped sheet listing every section not already on the tab bar.
Future<void> showMoreSheet({
  required BuildContext context,
  required AuthSession session,
  required List<SidebarEntry> nav,
  required Set<String> tabPaths,
  required String selectedPath,
  required ValueChanged<String> onSelect,
  required VoidCallback onSettings,
  required VoidCallback onLogout,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (_) => _MoreSheet(
      session: session,
      nav: nav,
      tabPaths: tabPaths,
      selectedPath: selectedPath,
      onSelect: onSelect,
      onSettings: onSettings,
      onLogout: onLogout,
    ),
  );
}

typedef _MoreItem = ({String label, String path});

class _MoreSection {
  const _MoreSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.items,
    required this.isGroup,
  });

  final String id;
  final String title;
  final String icon;
  final List<_MoreItem> items;

  /// `false` for single links (e.g. Reports) that open directly.
  final bool isGroup;
}

class _MoreSheet extends StatefulWidget {
  const _MoreSheet({
    required this.session,
    required this.nav,
    required this.tabPaths,
    required this.selectedPath,
    required this.onSelect,
    required this.onSettings,
    required this.onLogout,
  });

  final AuthSession session;
  final List<SidebarEntry> nav;
  final Set<String> tabPaths;
  final String selectedPath;
  final ValueChanged<String> onSelect;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  @override
  State<_MoreSheet> createState() => _MoreSheetState();
}

class _MoreSheetState extends State<_MoreSheet> {
  late final List<_MoreSection> _sections;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _sections = [
      for (final entry in widget.nav)
        if (_visibleItems(entry).isNotEmpty)
          _MoreSection(
            id: entry.id,
            title: entry.label,
            icon: entry.icon,
            items: _visibleItems(entry),
            isGroup: entry.type == SidebarEntryType.group,
          ),
    ];
    for (final s in _sections) {
      if (s.isGroup && s.items.any((i) => i.path == widget.selectedPath)) _expanded.add(s.id);
    }
  }

  List<_MoreItem> _visibleItems(SidebarEntry entry) {
    final items = entry.type == SidebarEntryType.link
        ? [(label: entry.label, path: entry.path!)]
        : [for (final c in entry.children) (label: c.label, path: c.path)];
    return items.where((i) => !widget.tabPaths.contains(i.path)).toList();
  }

  void _pick(VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  void _toggle(String id) {
    HapticFeedback.selectionClick();
    setState(() => _expanded.contains(id) ? _expanded.remove(id) : _expanded.add(id));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: ColoredBox(
          color: const Color(0xFFF2F2F7),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC7C7CC),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              _ProfileCard(session: widget.session),
              const SizedBox(height: 18),
              if (_sections.isNotEmpty) ...[
                const _GroupHeader(title: 'Menu'),
                _GroupCard(
                  children: [
                    for (final section in _sections) _buildSection(section),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              _GroupCard(
                children: [
                  _SheetRow(
                    icon: CupertinoIcons.gear_alt_fill,
                    iconColor: const Color(0xFF8E8E93),
                    label: 'Settings',
                    selected: widget.selectedPath == '/settings',
                    onTap: () => _pick(widget.onSettings),
                  ),
                  _SheetRow(
                    icon: CupertinoIcons.square_arrow_right,
                    iconColor: const Color(0xFFFF3B30),
                    label: 'Log out',
                    destructive: true,
                    showChevron: false,
                    onTap: () => _pick(widget.onLogout),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(_MoreSection section) {
    if (!section.isGroup) {
      final item = section.items.first;
      return _SheetRow(
        emoji: section.icon,
        label: item.label,
        selected: item.path == widget.selectedPath,
        onTap: () => _pick(() => widget.onSelect(item.path)),
      );
    }

    final open = _expanded.contains(section.id);
    final hasSelected = section.items.any((i) => i.path == widget.selectedPath);
    return Column(
      children: [
        _SheetRow(
          emoji: section.icon,
          label: section.title,
          selected: hasSelected && !open,
          showChevron: false,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${section.items.length}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: open ? 0.25 : 0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: const Icon(CupertinoIcons.chevron_forward, size: 15, color: Color(0xFFC7C7CC)),
              ),
            ],
          ),
          onTap: () => _toggle(section.id),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: open
              ? ColoredBox(
                  color: const Color(0xFFFAFAFC),
                  child: Column(
                    children: [
                      for (final item in section.items)
                        _SheetRow(
                          label: item.label,
                          nested: true,
                          selected: item.path == widget.selectedPath,
                          onTap: () => _pick(() => widget.onSelect(item.path)),
                        ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final company = session.company;
    final name = session.userName.isEmpty ? 'Employee' : session.userName;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _accent.withValues(alpha: 0.12),
            child: Text(
              name[0].toUpperCase(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  session.userEmail,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (company != null) CompanyLogoWidget(company: company, size: 34),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: Color(0xFF8E8E93),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: Colors.white,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 0.5, thickness: 0.5, indent: 52, color: Color(0xFFE5E5EA)),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.label,
    required this.onTap,
    this.emoji,
    this.icon,
    this.iconColor,
    this.selected = false,
    this.destructive = false,
    this.showChevron = true,
    this.nested = false,
    this.trailing,
  });

  final String label;
  final VoidCallback onTap;
  final String? emoji;
  final IconData? icon;
  final Color? iconColor;
  final bool selected;
  final bool destructive;
  final bool showChevron;

  /// Child row inside an expanded group: indented, no icon tile.
  final bool nested;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tint = iconColor ?? _accent;
    final baseColor = nested ? const Color(0xFFFAFAFC) : Colors.white;
    return Material(
      color: selected ? _accent.withValues(alpha: 0.06) : baseColor,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(nested ? 52 : 12, nested ? 9 : 10, 12, nested ? 9 : 10),
          child: Row(
            children: [
              if (!nested) ...[
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: icon != null
                      ? Icon(icon, size: 16, color: tint)
                      : Text(emoji ?? '•', style: const TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: nested ? 13 : 14,
                    letterSpacing: -0.2,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: destructive
                        ? const Color(0xFFFF3B30)
                        : selected
                            ? _accent
                            : const Color(0xFF1C1C1E),
                  ),
                ),
              ),
              ?trailing,
              if (showChevron && trailing == null)
                const Icon(CupertinoIcons.chevron_forward, size: 15, color: Color(0xFFC7C7CC)),
            ],
          ),
        ),
      ),
    );
  }
}
