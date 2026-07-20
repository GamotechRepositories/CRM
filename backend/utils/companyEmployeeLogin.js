import bcrypt from 'bcryptjs';
import { CENTRAL_TENANTS } from '../models/centralAdmin/centralAdmin_user.js';
import { enrichLoginUser } from './adminAccess.js';

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

/** Find an active CRM employee by email across all company tenants. */
export async function findCompanyEmployeeByEmail(email) {
  const normalized = String(email || '').trim().toLowerCase();
  if (!normalized) return null;

  for (const companyId of CENTRAL_TENANTS) {
    const Employee = await getEmployeeModel(companyId);
    const employee = await Employee.findOne({
      email: { $regex: new RegExp(`^${escapeRegex(normalized)}$`, 'i') },
    })
      .select('+password')
      .populate('designation')
      .lean();

    if (employee) {
      return { companyId, employee };
    }
  }

  return null;
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

  const enriched = enrichLoginUser({ ...employee });
  delete enriched.password;

  const designationTitle =
    enriched.designation?.title ||
    enriched.designation?.name ||
    enriched.department ||
    'Employee';

  return {
    user: {
      ...enriched,
      _id: enriched._id,
      role: designationTitle,
      isRoot: false,
      isCentralAdmin: false,
      isCompanyEmployee: true,
      companyTenant: companyId,
      tenants: [companyId],
      phone: enriched.phone || enriched.mobileNumber || '',
    },
    companyId,
  };
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
