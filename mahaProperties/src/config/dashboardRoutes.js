export const DASHBOARD_PATHS = {
  admin: '/admin-dashboard',
  hr: '/hr-dashboard',
  manager: '/manager-dashboard',
  employee: '/dashboard',
}

const ACCESS_ROLE_DASHBOARD = {
  admin: 'admin',
  technical_lead: 'admin',
  hr: 'hr',
  manager: 'manager',
  employee: 'employee',
}

const isHrTitle = (title = '') => title.toLowerCase() === 'hr manager'

const isManagerTitle = (title = '') => {
  const t = title.toLowerCase()
  if (isHrTitle(t)) return false
  if (['admin', 'technical lead'].includes(t)) return false
  if (t.includes('manager')) return true
  if (t.includes('operations')) return true
  return false
}

export const getDashboardKind = (user) => {
  const title = (user?.designation?.title || user?.designation?.name || '').toLowerCase()
  const accessRole = user?.designation?.accessRole

  if (accessRole === 'admin' || accessRole === 'technical_lead' || title === 'admin' || title === 'technical lead') {
    return 'admin'
  }
  if (accessRole === 'hr' || isHrTitle(title)) {
    return 'hr'
  }
  if (accessRole === 'manager' || isManagerTitle(title)) {
    return 'manager'
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
