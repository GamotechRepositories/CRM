import { SIDEBAR_PARENT_SECTIONS } from './sidebarParentSections'
import { getDashboardKind } from './dashboardRoutes'

const ALL_SECTION_IDS = SIDEBAR_PARENT_SECTIONS.map((section) => section.id)
const EMPTY_SECTION_IDS = []

export const getDesignationTitle = (user) =>
  (user?.designation?.title || user?.designation?.name || '').toLowerCase()

const MANAGER_ADD_PROJECT_DENY = new Set(['engineering manager', 'social media manager'])

export const isSalesManagerTitle = (title = '') => {
  const t = String(title || '').trim().toLowerCase()
  return t.includes('sales') && t.includes('manager')
}

/** Manager / operations roles (excludes HR). Mirrors dashboardRoutes manager detection. */
export const isOperationalManagerUser = (user) => {
  if (!user || isAdminUser(user)) return false
  const accessRole = String(user?.designation?.accessRole || '').toLowerCase()
  const title = getDesignationTitle(user)
  if (title === 'hr manager' || accessRole === 'hr') return false
  if (isSalesManagerTitle(title)) return true
  if (getDashboardKind(user) === 'manager') return true
  if (accessRole === 'manager') return true
  if (title === 'manager') return true
  if (title.includes('manager')) return true
  if (title.includes('operations')) return true
  return false
}

export const isAdminUser = (user) => {
  const title = getDesignationTitle(user)
  const accessRole = String(user?.designation?.accessRole || '').toLowerCase()
  return title === 'admin' || accessRole === 'admin'
}

export const getDesignationPermission = (user, key) => {
  if (isAdminUser(user)) return true
  const val = user?.designation?.permissions?.[key]
  return typeof val === 'boolean' ? val : null
}

export const hasFullAccessForUser = (user) => {
  if (isAdminUser(user)) return true
  // Managers always get full CRM access; do not let designation.hasFullAccess: false block them.
  if (isOperationalManagerUser(user)) return true
  const fromDesignation = user?.designation?.permissions?.hasFullAccess
  if (typeof fromDesignation === 'boolean') return fromDesignation
  const title = getDesignationTitle(user)
  return ['admin', 'hr manager', 'technical lead'].includes(title)
}

export const canViewProjectsForUser = (user) => {
  if (isAdminUser(user)) return true
  const fromDesignation = user?.designation?.permissions?.canViewProjects
  if (typeof fromDesignation === 'boolean') return fromDesignation
  if (isOperationalManagerUser(user)) return true
  const title = getDesignationTitle(user)
  return [
    'admin',
    'hr manager',
    'technical lead',
    'social media manager',
    'product manager',
    'senior software engineer',
    'project manager',
    'engineering manager',
  ].includes(title)
}

export const canAddProjectForUser = (user) => {
  if (isAdminUser(user)) return true
  const fromDesignation = getDesignationPermission(user, 'canAddProject')
  if (fromDesignation === true) return true

  const title = getDesignationTitle(user)
  if (MANAGER_ADD_PROJECT_DENY.has(title)) return false
  if (isOperationalManagerUser(user)) return true

  if (fromDesignation === false) return false
  return [
    'admin',
    'hr manager',
    'technical lead',
    'senior software engineer',
    'product manager',
    'project manager',
  ].includes(title)
}

export const canEditProjectForUser = (user) => {
  if (isAdminUser(user)) return true
  const fromDesignation = getDesignationPermission(user, 'canEditProject')
  if (fromDesignation === true) return true
  if (canAddProjectForUser(user)) return true
  if (isOperationalManagerUser(user)) return true
  const title = getDesignationTitle(user)
  return ['engineering manager', 'project manager'].includes(title)
}

/** Managers who can create projects can also add clients needed for those projects. */
export const canManageClientsForUser = (user) => {
  if (isAdminUser(user)) return true
  if (hasFullAccessForUser(user)) return true
  return canAddProjectForUser(user)
}

/** Any logged-in employee can assign tasks to other employees. */
export const canAssignTaskForUser = (user) => Boolean(user?._id)

/** Rating stays limited to admins / designations with assign permission historically. */
export const canRateTaskForUser = (user) => {
  if (isAdminUser(user)) return true
  const fromDesignation = getDesignationPermission(user, 'canAssignTask')
  if (fromDesignation !== null) return fromDesignation
  const title = getDesignationTitle(user)
  return [
    'admin',
    'social media manager',
    'hr manager',
    'technical lead',
    'product manager',
    'senior software engineer',
    'project manager',
    'engineering manager',
  ].includes(title)
}

export const canApproveLeaveForUser = (user) => {
  if (isAdminUser(user)) return true
  const accessRole = String(user?.designation?.accessRole || '').toLowerCase()
  const title = getDesignationTitle(user)
  if (['team_leader', 'manager', 'hr'].includes(accessRole)) return true
  if (title.includes('team lead') || title.includes('manager')) return true
  const fromDesignation = getDesignationPermission(user, 'canApproveLeave')
  if (fromDesignation !== null) return fromDesignation
  return [
    'admin',
    'hr manager',
    'project manager',
    'technical lead',
    'engineering manager',
    'product manager',
    'senior software engineer',
  ].includes(title)
}

export const canManageEmployeesForUser = (user) => {
  if (isAdminUser(user)) return true
  if (isOperationalManagerUser(user)) return true
  const fromDesignation = getDesignationPermission(user, 'canManageEmployees')
  if (fromDesignation !== null) return fromDesignation
  const title = getDesignationTitle(user)
  return ['admin', 'hr manager'].includes(title)
}

/** HR / leadership can open any employee's paid salary slip (not just their own). */
export const canViewAllSalarySlipsForUser = (user) => {
  if (!user) return false
  if (isAdminUser(user)) return true
  const accessRole = String(user?.designation?.accessRole || '').toLowerCase()
  const title = getDesignationTitle(user)
  if (accessRole === 'hr' || title === 'hr manager') return true
  if (accessRole === 'technical_lead' || title === 'technical lead') return true
  if (
    ['chief executive officer', 'chief operating officer', 'chief financial officer'].includes(title)
  ) {
    return true
  }
  return false
}

/** Admin, Sales Manager, or Sales Team Lead — upload/distribute leads & view all. */
export const canManageLeadsForUser = (user) => {
  if (!user) return false
  if (isAdminUser(user)) return true

  const accessRole = String(user?.designation?.accessRole || '').toLowerCase().trim()
  const title = getDesignationTitle(user)
  const department = String(user?.department || user?.designation?.department || '')
  const inSales = /sales/i.test(department)

  // Title can identify sales roles even if department field is empty
  if (isSalesManagerTitle(title)) return true
  if (
    title.includes('sales team lead') ||
    (inSales && (title.includes('team leader') || title.includes('team lead')))
  ) {
    return true
  }

  const isSalesManager = inSales && (accessRole === 'manager' || title.includes('manager'))
  const isSalesTeamLead = inSales && accessRole === 'team_leader'

  return Boolean(isSalesManager || isSalesTeamLead)
}

export const getSidebarSectionsForUser = (user) => {
  if (isAdminUser(user)) return ALL_SECTION_IDS
  if (isOperationalManagerUser(user)) return ALL_SECTION_IDS
  const sections = user?.access?.sidebarSections
  return sections?.length ? sections : EMPTY_SECTION_IDS
}

/** Team leaders and operational managers see the My Team sidebar section. */
export const showsMyTeamForUser = (user) => {
  if (!user?._id) return false
  const accessRole = String(user?.designation?.accessRole || '').trim().toLowerCase()
  if (accessRole === 'team_leader') return true
  if (isOperationalManagerUser(user)) return true
  const title = getDesignationTitle(user)
  if (title.includes('team lead') || title === 'team leader') return true
  return false
}
