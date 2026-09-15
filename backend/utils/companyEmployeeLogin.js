import bcrypt from 'bcryptjs';
import { CENTRAL_TENANTS } from '../models/centralAdmin/centralAdmin_user.js';
import { enrichLoginUser, isAdminEmployee } from './adminAccess.js';

const employeeModelCache = new Map();

async function getEmployeeModel(companyId) {
  if (employeeModelCache.has(companyId)) {
    return employeeModelCache.get(companyId);
  }
  // Register designation schema so `.populate('designation')` works.
  await import(`../models/${companyId}/${companyId}_designation.js`);
  const module = await import(`../models/${companyId}/${companyId}_employee.js`);
  const model = module.default;
  employeeModelCache.set(companyId, model);
  return model;
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function designationTitleOf(employee) {
  return String(employee?.designation?.title || employee?.designation?.name || '').trim();
}

/** Chief Operating Officer in Operations (or Leadership seed department). */
export function isChiefOperatingOfficer(employee) {
  const title = designationTitleOf(employee).toLowerCase();
  const isCoo = title === 'chief operating officer' || title === 'coo';
  if (!isCoo) return false;

  const department = String(
    employee?.department || employee?.designation?.department || ''
  )
    .trim()
    .toLowerCase();

  // Seeded C-suite uses Leadership; org charts may use Operations / Operation.
  if (!department) return true;
  return (
    department.includes('operation') ||
    department === 'leadership' ||
    department === 'operations'
  );
}

function toCompanyLoginUser(employee, companyId) {
  const enriched = enrichLoginUser({ ...employee });
  delete enriched.password;
  const designationTitle =
    designationTitleOf(enriched) || enriched.department || 'Employee';

  return {
    ...enriched,
    _id: enriched._id,
    role: designationTitle,
    isRoot: false,
    isCentralAdmin: false,
    isCompanyEmployee: true,
    companyTenant: companyId,
    tenants: [companyId],
    phone: enriched.phone || enriched.mobileNumber || '',
  };
}

/** Find an active CRM employee by email across all company tenants. */
export async function findCompanyEmployeeByEmail(email) {
  const all = await findAllCompanyEmployeesByEmail(email);
  return all[0] || null;
}

/** Find matching employees in every company tenant (same email). */
export async function findAllCompanyEmployeesByEmail(email) {
  const normalized = String(email || '').trim().toLowerCase();
  if (!normalized) return [];

  const results = [];
  for (const companyId of CENTRAL_TENANTS) {
    const Employee = await getEmployeeModel(companyId);
    const employee = await Employee.findOne({
      email: { $regex: new RegExp(`^${escapeRegex(normalized)}$`, 'i') },
    })
      .select('+password')
      .populate('designation')
      .lean();

    if (employee) {
      results.push({ companyId, employee });
    }
  }

  return results;
}

export async function authenticateCompanyEmployee(email, password) {
  const found = await findCompanyEmployeeByEmail(email);
  if (!found) return null;

  const { companyId, employee } = found;

  if (String(employee.status || 'Active') !== 'Active') {
    return {
      error: 'Account is inactive. Contact your admin.',
      status: 401,
    };
  }

  if (!employee.password) {
    return {
      error: 'Account not set up for login. Ask admin to set a password in CRM.',
      status: 401,
    };
  }

  const valid = await bcrypt.compare(String(password || ''), employee.password);
  if (!valid) {
    return { error: 'Invalid email or password', status: 401 };
  }

  return {
    user: toCompanyLoginUser(employee, companyId),
    companyId,
  };
}

/**
 * Authenticate COO against every company CRM login (same email/password).
 * Returns CEO-equivalent central admin session scoped to companies that succeeded.
 */
export async function authenticateOperationCoo(email, password) {
  const matches = await findAllCompanyEmployeesByEmail(email);
  if (!matches.length) {
    return { error: 'Invalid email or password', status: 401 };
  }

  const companySessions = {};
  const tenants = [];
  let sawCooAccount = false;
  let sawPasswordMatch = false;
  let primaryUser = null;

  for (const { companyId, employee } of matches) {
    if (!isChiefOperatingOfficer(employee)) continue;
    sawCooAccount = true;

    if (String(employee.status || 'Active') !== 'Active') continue;
    if (!employee.password) continue;

    const valid = await bcrypt.compare(String(password || ''), employee.password);
    if (!valid) continue;
    sawPasswordMatch = true;

    const user = toCompanyLoginUser(employee, companyId);
    companySessions[companyId] = user;
    tenants.push(companyId);
    if (!primaryUser) primaryUser = user;
  }

  if (!sawCooAccount) {
    return {
      error: 'Operations login is only for Chief Operating Officer accounts.',
      status: 403,
    };
  }

  if (!sawPasswordMatch || !primaryUser || !tenants.length) {
    return { error: 'Invalid email or password', status: 401 };
  }

  return {
    user: {
      ...primaryUser,
      role: 'COO',
      isRoot: false,
      isCentralAdmin: true,
      isCompanyEmployee: true,
      isOperationLogin: true,
      loginVia: 'operation',
      companyTenant: tenants[0],
      tenants,
      companySessions,
      canManageEmployees: true,
      canManageAll: true,
      // Same privilege surface as platform CEO in the admin panel
      accessEquivalentToCeo: true,
    },
    tenants,
    companySessions,
  };
}

export { isAdminEmployee };
