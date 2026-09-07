/**
 * Maps each company CRM admin (full-access) sidebar to central /admin panel.
 * Nav items: `{ type: 'link' }` or `{ type: 'group', children: [...] }`.
 */
export const ADMIN_FEATURE_MATRIX = {
  dashboard: { label: 'Dashboard', crud: ['read'] },
  employees: { label: 'Employees / Directory', crud: ['read', 'create', 'update'] },
  attendance: { label: 'Attendance', crud: ['read'] },
  leaves: { label: 'Leave', crud: ['read', 'update'] },
  performance: { label: 'Performance', crud: ['read'] },
  clients: { label: 'Customers / Clients', crud: ['read', 'create', 'update'] },
  projects: { label: 'Projects', crud: ['read', 'create', 'update'] },
  leads: { label: 'Leads', crud: ['read', 'create', 'update'] },
  tasks: { label: 'Tasks', crud: ['read'] },
  invoices: { label: 'Invoices / Billings', crud: ['read'] },
  expenses: { label: 'Expenses', crud: ['read'] },
  salaries: { label: 'Payroll / Salaries', crud: ['read'] },
  properties: { label: 'Property Listings', crud: ['read'], tenants: ['bangarProperties', 'mahaProperties', 'salesTechReality'] },
  quotations: { label: 'Quotations', crud: ['read'] },
  reports: { label: 'Reports & Analytics', crud: ['read'] },
  settings: { label: 'Company Settings', crud: ['read'] },
}

const EMPLOYEES_GROUP = {
  id: 'employees-group',
  label: 'Employees',
  icon: 'employees',
  type: 'group',
  children: [
    { id: 'employees', label: 'Directory', path: 'employees', crud: ['read', 'create', 'update'] },
    { id: 'attendance', label: 'Attendance', path: 'attendance', crud: ['read'] },
    { id: 'leaves', label: 'Leave', path: 'leaves', crud: ['read', 'update'] },
    { id: 'performance', label: 'Performance', path: 'performance', crud: ['read'] },
  ],
}

const BASE_NAV = [
  { id: 'home', label: 'Home', icon: 'home', type: 'link', absolutePath: '/' },
  { id: 'dashboard', label: 'Dashboard', icon: 'dashboard', type: 'link', path: '' },
  EMPLOYEES_GROUP,
  { id: 'clients', label: 'Clients', icon: 'clients', type: 'link', path: 'clients', crud: ['read', 'create', 'update'] },
  { id: 'projects', label: 'Projects', icon: 'projects', type: 'link', path: 'projects', crud: ['read', 'create', 'update'] },
  { id: 'leads', label: 'Leads', icon: 'leads', type: 'link', path: 'leads', crud: ['read', 'create', 'update'] },
  { id: 'tasks', label: 'Tasks', icon: 'tasks', type: 'link', path: 'tasks', crud: ['read'] },
  { id: 'invoices', label: 'Invoices', icon: 'invoices', type: 'link', path: 'invoices', crud: ['read'] },
  { id: 'expenses', label: 'Expenses', icon: 'expenses', type: 'link', path: 'expenses', crud: ['read'] },
  { id: 'salaries', label: 'Payroll', icon: 'revenue', type: 'link', path: 'salaries', crud: ['read'] },
  { id: 'quotations', label: 'Quotations', icon: 'invoices', type: 'link', path: 'quotations', crud: ['read'] },
  { id: 'reports', label: 'Reports', icon: 'reports', type: 'link', path: 'reports', crud: ['read'] },
  { id: 'settings', label: 'Settings', icon: 'settings', type: 'link', path: 'settings', crud: ['read'] },
]

const PROPERTY_NAV = {
  id: 'properties',
  label: 'Properties',
  icon: 'companies',
  type: 'link',
  path: 'properties',
  crud: ['read'],
}

const PROPERTY_TENANTS = new Set(['bangarProperties', 'mahaProperties', 'salesTechReality'])

export const flattenNavItems = (items) =>
  items.flatMap((item) => (item.type === 'group' ? item.children : [item]))

export const findNavItem = (items, navId) =>
  flattenNavItems(items).find((item) => item.id === navId)

export const getCompanyAdminNav = (tenantId) => {
  const items = [...BASE_NAV]
  if (PROPERTY_TENANTS.has(tenantId)) {
    const leadsIndex = items.findIndex((item) => item.id === 'leads')
    items.splice(leadsIndex + 1, 0, PROPERTY_NAV)
  }
  return items
}

export const moduleSupportsCrud = (moduleId, action = 'read') => {
  const meta = ADMIN_FEATURE_MATRIX[moduleId]
  if (!meta) return false
  return meta.crud.includes(action)
}

export const tenantHasModule = (tenantId, moduleId) => {
  const meta = ADMIN_FEATURE_MATRIX[moduleId]
  if (!meta) return false
  if (meta.tenants && !meta.tenants.includes(tenantId)) return false
  return true
}

export const getNavGroupForActiveId = (items, activeNav) => {
  for (const item of items) {
    if (item.type !== 'group') continue
    if (item.children.some((child) => child.id === activeNav)) return item.id
  }
  return null
}
