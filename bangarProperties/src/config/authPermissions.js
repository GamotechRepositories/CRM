export const getDesignationTitle = (user) =>
  (user?.designation?.title || user?.designation?.name || '').toLowerCase()

export const getDesignationPermission = (user, key) => {
  const val = user?.designation?.permissions?.[key]
  return typeof val === 'boolean' ? val : null
}

export const canAddProjectForUser = (user) => {
  const fromDesignation = getDesignationPermission(user, 'canAddProject')
  if (fromDesignation !== null) return fromDesignation
  const title = getDesignationTitle(user)
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
  const fromDesignation = getDesignationPermission(user, 'canEditProject')
  if (fromDesignation === true) return true
  if (canAddProjectForUser(user)) return true
  const title = getDesignationTitle(user)
  return ['engineering manager', 'project manager'].includes(title)
}

export const canAssignTaskForUser = (user) => {
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

export const canRateTaskForUser = (user) => canAssignTaskForUser(user)
