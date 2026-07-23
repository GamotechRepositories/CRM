const isSalesDepartment = (value = '') =>
  /sales/i.test(String(value || '').trim());

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
  if (String(assignedId || '') !== String(access.employeeId)) {
    const err = new Error('You can only access leads assigned to you');
    err.statusCode = 403;
    throw err;
  }
};
