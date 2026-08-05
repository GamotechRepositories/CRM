export const DASHBOARD_PATHS = {
  admin: '/admin-dashboard',
  hr: '/hr-dashboard',
  manager: '/manager-dashboard',
  team_leader: '/team-leader-dashboard',
  site_coordinator: '/site-coordinator-dashboard',
  employee: '/dashboard',
}

const ACCESS_ROLE_DASHBOARD = {
  admin: 'admin',
  technical_lead: 'admin',
  hr: 'hr',
  manager: 'manager',
  team_leader: 'team_leader',
  site_coordinator: 'site_coordinator',
  employee: 'employee',
}

const isHrTitle = (title = '') => title.toLowerCase() === 'hr manager'

const isTeamLeaderTitle = (title = '') => {
  const t = title.toLowerCase()
  if (t === 'technical lead') return false
  return t.includes('team lead') || t === 'team leader'
}

const isManagerTitle = (title = '') => {
  const t = title.toLowerCase()
  if (isHrTitle(t)) return false
  if (['admin', 'technical lead'].includes(t)) return false
  if (t.includes('manager')) return true
  if (t.includes('operations')) return true
  return false
}

const normalizeKey = (value = '') =>
  String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '')

/** Site Co-ordinator / Site Coordinator / Site Reliability Engineer */
export const isSiteCoordinatorUser = (user) => {
  const raw = user?.designation
  const title = String(
    typeof raw === 'string' ? raw : raw?.title || raw?.name || ''
  ).trim()
  const key = normalizeKey(title)
  const accessRole = String(raw?.accessRole || '').trim().toLowerCase()
  if (accessRole === 'site_coordinator') return true
  return (
    key.includes('sitecoordinator') ||
    key.includes('sitereliabilityengineer') ||
    (key.includes('sitereliability') && key.includes('engineer'))
  )
}

/** Sales department employees get travel allowance + route map on their dashboard. */
export const isSalesDepartmentUser = (user) => {
  const dept = String(
    user?.department || user?.designation?.department || ''
  ).trim()
  return /sales/i.test(dept)
}

/** Dedicated SC dashboard, or travel section for any Sales employee. */
export const hasTravelDashboard = (user) =>
  isSiteCoordinatorUser(user) || isSalesDepartmentUser(user)

export const getDashboardKind = (user) => {
  const rawDesignation = user?.designation
  const title = String(
    typeof rawDesignation === 'string'
      ? rawDesignation
      : rawDesignation?.title || rawDesignation?.name || ''
  ).trim().toLowerCase()
  const accessRole = String(rawDesignation?.accessRole || '').trim().toLowerCase()

  if (accessRole === 'admin' || accessRole === 'technical_lead' || title === 'admin' || title === 'technical lead') {
    return 'admin'
  }
  if (accessRole === 'hr' || isHrTitle(title)) {
    return 'hr'
  }
  if (accessRole === 'team_leader' || isTeamLeaderTitle(title)) {
    return 'team_leader'
  }
  if (accessRole === 'manager' || isManagerTitle(title)) {
    return 'manager'
  }
  if (isSiteCoordinatorUser(user)) {
    return 'site_coordinator'
  }

  if (accessRole && ACCESS_ROLE_DASHBOARD[accessRole]) {
    return ACCESS_ROLE_DASHBOARD[accessRole]
  }

  return 'employee'
}

export const getDashboardPathForUser = (user) => DASHBOARD_PATHS[getDashboardKind(user)]

export const isDashboardRoute = (pathname = '') =>
  pathname === '/dashboard'
  || pathname === '/admin-dashboard'
  || pathname === '/hr-dashboard'
  || pathname === '/manager-dashboard'
  || pathname === '/team-leader-dashboard'
  || pathname === '/site-coordinator-dashboard'
