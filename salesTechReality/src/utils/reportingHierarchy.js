/** Shared helpers for reportingManager org tree (salesTechReality). */

export const refEmployeeId = (value) => String(value?._id || value || '')

const normalizeTitle = (employee) =>
  String(
    employee?.designation?.title || employee?.designation?.name || ''
  )
    .trim()
    .toLowerCase()

export const isTeamLeaderEmployee = (employee) => {
  const accessRole = String(employee?.designation?.accessRole || '').trim().toLowerCase()
  if (accessRole === 'team_leader') return true
  const title = normalizeTitle(employee)
  if (title === 'technical lead') return false
  return title.includes('team lead') || title === 'team leader'
}

export const isManagerEmployee = (employee) => {
  const accessRole = String(employee?.designation?.accessRole || '').trim().toLowerCase()
  const title = normalizeTitle(employee)
  if (title === 'hr manager' || accessRole === 'hr') return false
  if (['admin', 'technical_lead'].includes(accessRole)) return false
  if (accessRole === 'manager') return true
  if (title.includes('manager')) return true
  if (title.includes('operations')) return true
  return false
}

/** Map managerId -> direct report employee ids */
export const buildReportsByManager = (employees = []) => {
  const map = new Map()
  employees.forEach((employee) => {
    const managerId = refEmployeeId(employee.reportingManager)
    if (!managerId) return
    if (!map.has(managerId)) map.set(managerId, [])
    map.get(managerId).push(refEmployeeId(employee))
  })
  return map
}

/**
 * All reportee ids under rootManagerId (recursive via reportingManager).
 * Team leaders and managers expand to include everyone reporting to them.
 */
export const getAllReporteeIds = (employees = [], rootManagerId) => {
  const rootId = refEmployeeId(rootManagerId)
  if (!rootId) return new Set()

  const byManager = buildReportsByManager(employees)
  const result = new Set()
  const queue = [...(byManager.get(rootId) || [])]

  while (queue.length) {
    const id = queue.shift()
    if (!id || result.has(id)) continue
    result.add(id)
    const children = byManager.get(id) || []
    queue.push(...children)
  }

  return result
}

/**
 * Reportees with depth (1 = direct report) and metadata for UI grouping.
 */
export const getReporteesWithMeta = (employees = [], rootManagerId) => {
  const rootId = refEmployeeId(rootManagerId)
  if (!rootId) return []

  const byId = new Map(employees.map((e) => [refEmployeeId(e), e]))
  const byManager = buildReportsByManager(employees)
  const result = []
  const seen = new Set()

  const walk = (managerId, depth) => {
    const childIds = byManager.get(managerId) || []
    childIds.forEach((id) => {
      if (seen.has(id)) return
      seen.add(id)
      const employee = byId.get(id)
      if (!employee) return

      const childCount = (byManager.get(id) || []).length
      const isLeader = isTeamLeaderEmployee(employee)
      const isManager = isManagerEmployee(employee)

      result.push({
        id,
        depth,
        employee,
        childCount,
        isTeamLeader: isLeader,
        isManager,
        leadsTeam: (isLeader || isManager) && childCount > 0,
        reportsTo: byId.get(managerId)?.name || '—',
        reportsToId: managerId,
      })

      walk(id, depth + 1)
    })
  }

  walk(rootId, 1)
  return result
}

export const filterEmployeesToReportees = (employees = [], rootManagerId) => {
  const ids = getAllReporteeIds(employees, rootManagerId)
  return employees.filter((e) => ids.has(refEmployeeId(e)))
}

export const isInReporteeTree = (ref, reporteeIds) => {
  const id = refEmployeeId(ref)
  return id && reporteeIds.has(id)
}
