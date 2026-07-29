const isSalesDepartment = (value = '') =>
  /sales/i.test(String(value || '').trim());

/** Normalize titles so "Site Co-ordinator" and "Site Coordinator" match. */
const normalizeDesignationKey = (value = '') =>
  String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '');

/** Designation titles allowed as Site Visit assignees. */
export const isSiteCoordinatorDesignation = (designation) => {
  if (!designation) return false;
  const title = String(designation.title || designation.name || '').trim();
  const key = normalizeDesignationKey(title);
  // Site Co-ordinator / Site Coordinator, or Site Reliability Engineer
  return (
    key.includes('sitecoordinator') ||
    key.includes('sitereliabilityengineer') ||
    (key.includes('sitereliability') && key.includes('engineer'))
  );
};

export const isSiteCoordinatorEmployee = (employee) =>
  Boolean(employee && isSiteCoordinatorDesignation(employee.designation));

/**
 * Admin, Sales Manager, or Sales Team Lead may upload/distribute and view all leads.
 * Everyone else may only see leads assigned to them.
 */
export const canManageLeadsFromEmployee = (employee) => {
  if (!employee) return false;

  const designation = employee.designation || {};
  const accessRole = String(designation.accessRole || '').toLowerCase().trim();
  const title = String(designation.title || designation.name || '').toLowerCase().trim();
  const department = employee.department || designation.department || '';

  if (accessRole === 'admin' || title === 'admin') return true;

  const inSales = isSalesDepartment(department);

  // Title can identify sales roles even if department field is empty
  if (title.includes('sales manager')) return true;
  if (
    title.includes('sales team lead') ||
    (inSales && (title.includes('team leader') || title.includes('team lead')))
  ) {
    return true;
  }

  const isSalesManager = inSales && (accessRole === 'manager' || title.includes('manager'));

  const isSalesTeamLead = inSales && accessRole === 'team_leader';

  return Boolean(isSalesManager || isSalesTeamLead);
};

export const resolveLeadAccess = async (Employee, employeeId) => {
  if (!employeeId) {
    const err = new Error('viewerId is required');
    err.statusCode = 400;
    throw err;
  }

  const emp = await Employee.findById(employeeId)
    .populate('designation', 'title name accessRole department')
    .select('name email department designation status');

  if (!emp) {
    const err = new Error('Employee not found');
    err.statusCode = 404;
    throw err;
  }

  const canManageLeads = canManageLeadsFromEmployee(emp);
  return {
    employeeId: emp._id,
    canManageLeads,
    canViewAllLeads: canManageLeads,
  };
};

export const assertCanManageLeads = (access) => {
  if (!access?.canManageLeads) {
    const err = new Error(
      'Only Admin, Sales Manager, or Sales Team Lead can upload or distribute leads'
    );
    err.statusCode = 403;
    throw err;
  }
};

export const assertCanAccessLead = (access, lead) => {
  if (!access || access.canViewAllLeads) return;
  const assignedId = lead?.assignedTo?._id || lead?.assignedTo;
  const siteCoordinatorId = lead?.siteCoordinator?._id || lead?.siteCoordinator;
  const viewer = String(access.employeeId);
  const ok =
    String(assignedId || '') === viewer || String(siteCoordinatorId || '') === viewer;
  if (!ok) {
    const err = new Error('You can only access leads assigned to you');
    err.statusCode = 403;
    throw err;
  }
};

/** Validate / normalize Site Visit assignment (Site Co-ordinator or Site Reliability Engineer). */
export const applySiteVisitAssignment = async (Employee, body = {}) => {
  if (body.status !== 'Site Visit') return body;

  const coordinatorId = body.siteCoordinator || body.assignedTo;
  if (!coordinatorId) {
    const err = new Error(
      'Please select a Site Co-ordinator or Site Reliability Engineer when status is Site Visit'
    );
    err.statusCode = 400;
    throw err;
  }

  const emp = await Employee.findById(coordinatorId)
    .populate('designation', 'title name accessRole')
    .select('name designation status');

  if (!emp || emp.status === 'Inactive') {
    const err = new Error('Selected employee was not found or is inactive');
    err.statusCode = 400;
    throw err;
  }
  if (!isSiteCoordinatorEmployee(emp)) {
    const err = new Error(
      'Selected employee must be a Site Co-ordinator / Site Coordinator or Site Reliability Engineer'
    );
    err.statusCode = 400;
    throw err;
  }

  // Keep sales `assignedTo` intact; attach site coordinator separately.
  const next = { ...body, siteCoordinator: emp._id, siteCoordinatorAssignedAt: new Date() };
  // If client mistakenly sent coordinator as assignedTo, don't overwrite sales assignee.
  if (body.siteCoordinator) {
    // leave assignedTo as provided (sales)
  } else if (body.assignedTo && String(body.assignedTo) === String(emp._id)) {
    delete next.assignedTo;
  }
  return next;
};
