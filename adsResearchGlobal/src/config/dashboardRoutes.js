export const DASHBOARD_PATHS = {
  admin: '/admin-dashboard',
  hr: '/hr-dashboard',
  employee: '/dashboard',
}

const ACCESS_ROLE_DASHBOARD = {
  admin: 'admin',
  technical_lead: 'admin',
  hr: 'hr',
  manager: 'employee',
  employee: 'employee',
}

export const getDashboardKind = (user) => {
  const accessRole = user?.designation?.accessRole
  if (accessRole && ACCESS_ROLE_DASHBOARD[accessRole]) {
    return ACCESS_ROLE_DASHBOARD[accessRole]
  }

  const title = (user?.designation?.title || user?.designation?.name || '').toLowerCase()
  if (title === 'admin' || title === 'technical lead') return 'admin'
  if (title === 'hr manager') return 'hr'
  return 'employee'
}

export const getDashboardPathForUser = (user) => DASHBOARD_PATHS[getDashboardKind(user)]

export const isDashboardRoute = (pathname = '') =>
  pathname === '/dashboard' || pathname === '/admin-dashboard' || pathname === '/hr-dashboard'
