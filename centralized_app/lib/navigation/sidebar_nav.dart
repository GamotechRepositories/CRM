class SidebarChildItem {
  const SidebarChildItem({
    required this.id,
    required this.label,
    required this.path,
    this.requiresFullAccess = false,
    this.requiresProjectAccess = false,
  });

  final String id;
  final String label;
  final String path;
  final bool requiresFullAccess;
  final bool requiresProjectAccess;
}

class SidebarEntry {
  const SidebarEntry.link({
    required this.id,
    required this.label,
    required this.icon,
    required this.path,
    this.requiresFullAccess = false,
    this.alwaysVisible = false,
  })  : type = SidebarEntryType.link,
        children = const [];

  const SidebarEntry.group({
    required this.id,
    required this.label,
    required this.icon,
    required this.children,
    this.requiresFullAccess = false,
    this.alwaysVisible = false,
  })  : type = SidebarEntryType.group,
        path = null;

  final String id;
  final String label;
  final String icon;
  final SidebarEntryType type;
  final String? path;
  final List<SidebarChildItem> children;
  final bool requiresFullAccess;
  final bool alwaysVisible;
}

enum SidebarEntryType { link, group }

class SidebarNavContext {
  const SidebarNavContext({
    required this.fullAccess,
    required this.canViewProjects,
    required this.isTeamLeader,
    required this.dashboardPath,
    required this.includeProperties,
    this.allowedSections,
  });

  final bool fullAccess;
  final bool canViewProjects;
  final bool isTeamLeader;
  final String dashboardPath;
  final bool includeProperties;
  final List<String>? allowedSections;
}

/// Mirrors web `sidebarNav.js` — one config for all companies.
class SidebarNav {
  SidebarNav._();

  static List<SidebarEntry> build(SidebarNavContext ctx) {
    final useSectionFilter =
        ctx.allowedSections != null && ctx.allowedSections!.isNotEmpty && !ctx.fullAccess;
    bool sectionAllowed(SidebarEntry section) {
      if (section.alwaysVisible) return true;
      if (!useSectionFilter) return true;
      return ctx.allowedSections!.contains(section.id);
    }

    bool itemAllowed(SidebarChildItem item) {
      if (item.requiresFullAccess && !ctx.fullAccess) return false;
      if (item.requiresProjectAccess && !ctx.canViewProjects) return false;
      return true;
    }

    SidebarEntry? filterGroup(SidebarEntry group) {
      if (group.requiresFullAccess && !ctx.fullAccess) return null;
      final children = group.children.where(itemAllowed).toList();
      if (children.isEmpty) return null;
      return SidebarEntry.group(
        id: group.id,
        label: group.label,
        icon: group.icon,
        requiresFullAccess: group.requiresFullAccess,
        alwaysVisible: group.alwaysVisible,
        children: children,
      );
    }

    final sections = <SidebarEntry>[
      SidebarEntry.link(
        id: 'dashboard',
        label: 'Dashboard',
        icon: '🏠',
        path: ctx.dashboardPath,
        alwaysVisible: true,
      ),
      if (ctx.isTeamLeader)
        SidebarEntry.group(
          id: 'my-team',
          label: 'My Team',
          icon: '👥',
          alwaysVisible: true,
          children: const [
            SidebarChildItem(id: 'team-members', label: 'Team Members', path: '/my-team'),
            SidebarChildItem(id: 'team-leave', label: 'Leave', path: '/leave'),
          ],
        ),
      SidebarEntry.group(
        id: 'workspace',
        label: 'My Workspace',
        icon: '👤',
        alwaysVisible: true,
        children: const [
          SidebarChildItem(id: 'my-profile', label: 'My Profile', path: '/my-profile'),
          SidebarChildItem(id: 'my-tasks', label: 'My Tasks', path: '/my-tasks'),
          SidebarChildItem(id: 'assign-task', label: 'Assign Task', path: '/assign-task'),
          SidebarChildItem(id: 'my-calendar', label: 'My Calendar', path: '/calendar'),
          SidebarChildItem(id: 'my-leaves', label: 'My Leaves', path: '/leave'),
          SidebarChildItem(id: 'my-attendance', label: 'My Attendance', path: '/my-attendance'),
          SidebarChildItem(id: 'my-projects', label: 'My Projects', path: '/my-projects'),
        ],
      ),
      SidebarEntry.group(
        id: 'crm',
        label: 'CRM',
        icon: '🎯',
        children: const [
          SidebarChildItem(id: 'leads', label: 'Leads', path: '/leads'),
          SidebarChildItem(
            id: 'contacts',
            label: 'Contacts',
            path: '/collaborators',
            requiresFullAccess: true,
          ),
          SidebarChildItem(
            id: 'companies',
            label: 'Companies',
            path: '/companies',
            requiresFullAccess: true,
          ),
          SidebarChildItem(
            id: 'quotations',
            label: 'Quotations',
            path: '/quotations',
            requiresFullAccess: true,
          ),
        ],
      ),
      if (ctx.includeProperties)
        SidebarEntry.group(
          id: 'properties',
          label: 'Property Listing',
          icon: '🏘',
          children: const [
            SidebarChildItem(id: 'property-listings', label: 'All Properties', path: '/properties'),
            SidebarChildItem(id: 'add-property', label: 'Add Property', path: '/add-property'),
            SidebarChildItem(id: 'site-visits', label: 'Site Visits', path: '/site-visits'),
            SidebarChildItem(
              id: 'schedule-site-visit',
              label: 'Schedule Visit',
              path: '/schedule-site-visit',
            ),
          ],
        ),
      SidebarEntry.group(
        id: 'projects',
        label: 'Projects',
        icon: '📁',
        children: const [
          SidebarChildItem(
            id: 'projects-list',
            label: 'Projects',
            path: '/projects',
            requiresProjectAccess: true,
          ),
          SidebarChildItem(id: 'tasks', label: 'Tasks', path: '/tasks', requiresFullAccess: true),
          SidebarChildItem(
            id: 'milestones',
            label: 'Milestones',
            path: '/module/milestones',
            requiresFullAccess: true,
          ),
          SidebarChildItem(id: 'timesheets', label: 'Timesheets', path: '/module/timesheets'),
        ],
      ),
      if (!ctx.isTeamLeader)
        SidebarEntry.group(
          id: 'employees',
          label: 'Employees',
          icon: '👨',
          children: const [
            SidebarChildItem(
              id: 'directory',
              label: 'Directory',
              path: '/employees',
              requiresFullAccess: true,
            ),
            SidebarChildItem(id: 'attendance', label: 'Attendance', path: '/attendance'),
            SidebarChildItem(id: 'leave', label: 'Leave', path: '/leave'),
            SidebarChildItem(
              id: 'performance',
              label: 'Performance',
              path: '/module/performance',
              requiresFullAccess: true,
            ),
            SidebarChildItem(
              id: 'assets',
              label: 'Assets',
              path: '/module/assets',
              requiresFullAccess: true,
            ),
          ],
        ),
      SidebarEntry.group(
        id: 'finance',
        label: 'Finance',
        icon: '💰',
        requiresFullAccess: true,
        children: const [
          SidebarChildItem(id: 'invoices', label: 'Invoices', path: '/billings'),
          SidebarChildItem(id: 'expenses', label: 'Expenses', path: '/expenses'),
          SidebarChildItem(id: 'payments', label: 'Revenue', path: '/revenue'),
          SidebarChildItem(id: 'payroll', label: 'Payroll', path: '/salaries'),
          SidebarChildItem(id: 'gst', label: 'GST / Taxes', path: '/module/gst'),
        ],
      ),
      SidebarEntry.group(
        id: 'sales',
        label: 'Sales',
        icon: '🛒',
        children: const [
          SidebarChildItem(id: 'orders', label: 'Orders', path: '/module/orders', requiresFullAccess: true),
          SidebarChildItem(id: 'customers', label: 'Customers', path: '/clients', requiresFullAccess: true),
          SidebarChildItem(id: 'pipeline', label: 'Sales Pipeline', path: '/lead-management'),
        ],
      ),
      SidebarEntry.group(
        id: 'marketing',
        label: 'Marketing',
        icon: '📢',
        children: const [
          SidebarChildItem(id: 'campaigns', label: 'Campaigns', path: '/campaigns', requiresFullAccess: true),
          SidebarChildItem(id: 'email', label: 'Email', path: '/module/email', requiresFullAccess: true),
          SidebarChildItem(id: 'sms', label: 'SMS', path: '/module/sms', requiresFullAccess: true),
          SidebarChildItem(id: 'whatsapp', label: 'WhatsApp', path: '/module/whatsapp', requiresFullAccess: true),
          SidebarChildItem(id: 'social', label: 'Social Media', path: '/social-calendar'),
        ],
      ),
      SidebarEntry.group(
        id: 'communication',
        label: 'Communication',
        icon: '💬',
        children: const [
          SidebarChildItem(id: 'chat', label: 'Chat', path: '/module/chat'),
          SidebarChildItem(id: 'announcements', label: 'Announcements', path: '/module/announcements'),
        ],
      ),
      SidebarEntry.link(
        id: 'reports',
        label: 'Reports & Analytics',
        icon: '📊',
        path: '/reports',
        requiresFullAccess: true,
      ),
      SidebarEntry.group(
        id: 'administration',
        label: 'Administration',
        icon: '⚙',
        requiresFullAccess: true,
        children: const [
          SidebarChildItem(id: 'users', label: 'Users', path: '/employees'),
          SidebarChildItem(id: 'departments', label: 'Departments', path: '/module/departments'),
          SidebarChildItem(id: 'designations', label: 'Designations', path: '/module/designations'),
          SidebarChildItem(id: 'settings', label: 'Settings', path: '/settings'),
        ],
      ),
    ];

    final out = <SidebarEntry>[];
    for (final section in sections) {
      if (ctx.isTeamLeader && section.id == 'employees') continue;
      if (section.type == SidebarEntryType.link) {
        if (section.requiresFullAccess && !ctx.fullAccess) continue;
        if (!sectionAllowed(section)) continue;
        out.add(section);
        continue;
      }
      final filtered = filterGroup(section);
      if (filtered == null) continue;
      if (!sectionAllowed(filtered)) continue;
      out.add(filtered);
    }
    return out;
  }

  static String? labelForPath(List<SidebarEntry> nav, String path) {
    for (final entry in nav) {
      if (entry.type == SidebarEntryType.link && entry.path == path) {
        return entry.label;
      }
      for (final child in entry.children) {
        if (child.path == path) return child.label;
      }
    }
    return null;
  }
}
