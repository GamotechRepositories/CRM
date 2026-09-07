import bcrypt from 'bcryptjs';
import mongoose from 'mongoose';
import CentralAdminUser, {
  CENTRAL_TENANTS,
  CENTRAL_TEAM_ROLES,
  CENTRAL_ROOT_ROLE,
} from '../models/centralAdmin/centralAdmin_user.js';
import { signAuthToken } from '../utils/jwtAuth.js';
import { authenticateCompanyEmployee } from '../utils/companyEmployeeLogin.js';
import { normalizeEmployeePayload } from '../utils/normalizeEmployeePayload.js';
import { getEmployeeApiError, validateEmployeePayload } from '../utils/employeeApiErrors.js';
import { assignEmployeeCodeOnCreate, validateEmployeeCodeOnUpdate } from '../utils/employeeCode.js';
import { isAdminEmployee } from '../utils/adminAccess.js';
import {
  createTenantClientRecord,
  updateTenantClientRecord,
  createTenantProjectRecord,
  updateTenantProjectRecord,
  createTenantLeadRecord,
  updateTenantLeadRecord,
} from '../utils/centralAdminTenantCrud.js';
import { cacheKey, cacheGet, cacheSet, CACHE_TTL } from '../utils/cache.js';

const COMPANIES = [
  {
    id: 'adsResearchGlobal',
    label: 'Ads Research Global',
  },
  {
    id: 'bangarProperties',
    label: 'Bangar Properties',
  },
  {
    id: 'mahaProperties',
    label: 'Maha Properties',
  },
  {
    id: 'salesTechReality',
    label: 'Sales Tech Reality',
  },
];

const toPublicUser = (doc) => {
  const user = typeof doc.toObject === 'function' ? doc.toObject() : { ...doc };
  delete user.password;
  return {
    ...user,
    isCentralAdmin: true,
  };
};

export const login = async (req, res) => {
  try {
    const email = String(req.body?.email || '').trim().toLowerCase();
    const password = String(req.body?.password || '');

    if (!email || !password) {
      return res.status(400).json({ message: 'Email and password are required' });
    }

    const admin = await CentralAdminUser.findOne({ email }).select('+password');
    if (admin) {
      if (admin.status !== 'Active') {
        return res.status(401).json({ message: 'Account is inactive. Contact platform owner.' });
      }
      if (!admin.password) {
        return res.status(401).json({ message: 'Account not set up for login.' });
      }

      const valid = await bcrypt.compare(password, admin.password);
      if (!valid) {
        return res.status(401).json({ message: 'Invalid email or password' });
      }

      const user = toPublicUser(admin);
      const token = signAuthToken({
        sub: String(user._id),
        email: user.email,
        role: user.role,
        isRoot: Boolean(user.isRoot),
        company: 'admin',
      });

      return res.status(200).json({
        message: 'Login successful',
        token,
        expiresIn: process.env.JWT_EXPIRES_IN || '30d',
        user: {
          ...user,
          canManageEmployees: true,
          canManageAll: true,
        },
      });
    }

    // Fallback: company CRM employee (same email/password as company login)
    const employeeAuth = await authenticateCompanyEmployee(email, password);
    if (employeeAuth?.error) {
      return res.status(employeeAuth.status || 401).json({ message: employeeAuth.error });
    }
    if (!employeeAuth?.user) {
      return res.status(401).json({ message: 'Invalid email or password' });
    }

    const user = employeeAuth.user;
    const token = signAuthToken({
      sub: String(user._id),
      email: user.email,
      role: user.role,
      isRoot: false,
      company: employeeAuth.companyId,
    });

    return res.status(200).json({
      message: 'Login successful',
      token,
      expiresIn: process.env.JWT_EXPIRES_IN || '30d',
      user: {
        ...user,
        canManageEmployees: canCentralAdminManageEmployees(user),
        canManageAll: canCentralAdminManageEmployees(user),
      },
    });
  } catch (error) {
    return res.status(500).json({ message: 'Login failed', error: error?.message || error });
  }
};

/** List central admin team members (no passwords) */
export const listCentralAdmins = async (_req, res) => {
  try {
    const users = await CentralAdminUser.find({})
      .select('-password')
      .sort({ isRoot: -1, createdAt: -1 })
      .lean();
    return res.status(200).json({
      users,
      roles: CENTRAL_TEAM_ROLES,
    });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to load team', error: error?.message || error });
  }
};

/** Create a team member with an assignable role (not CEO) across selected companies */
export const createCentralAdmin = async (req, res) => {
  try {
    const name = String(req.body?.name || '').trim();
    const email = String(req.body?.email || '').trim().toLowerCase();
    const password = String(req.body?.password || '');
    const phone = String(req.body?.phone || '').trim();
    const role = String(req.body?.role || 'Executive Assistant').trim();
    let tenants = Array.isArray(req.body?.tenants) ? req.body.tenants : [...CENTRAL_TENANTS];

    if (!name || !email || !password) {
      return res.status(400).json({ message: 'Name, email and password are required' });
    }

    if (!CENTRAL_TEAM_ROLES.includes(role)) {
      return res.status(400).json({
        message: `Invalid role. Choose one of: ${CENTRAL_TEAM_ROLES.join(', ')}`,
      });
    }

    if (role === CENTRAL_ROOT_ROLE) {
      return res.status(400).json({ message: 'CEO role cannot be assigned to team members' });
    }

    tenants = tenants.filter((id) => CENTRAL_TENANTS.includes(id));
    if (!tenants.length) tenants = [...CENTRAL_TENANTS];

    const exists = await CentralAdminUser.findOne({ email }).lean();
    if (exists) {
      return res.status(409).json({ message: 'A team member with this email already exists' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const admin = await CentralAdminUser.create({
      name,
      email,
      password: hashedPassword,
      role,
      isRoot: false,
      status: 'Active',
      tenants,
      phone,
    });

    return res.status(201).json({
      message: 'Team member created and saved to MongoDB',
      user: toPublicUser(admin),
    });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to create team member', error: error?.message || error });
  }
};

/** Update a team member (not root/CEO) */
export const updateCentralAdmin = async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: 'Invalid team member id' });
    }

    const existing = await CentralAdminUser.findById(id);
    if (!existing) {
      return res.status(404).json({ message: 'Team member not found' });
    }
    if (existing.isRoot || existing.role === CENTRAL_ROOT_ROLE) {
      return res.status(403).json({ message: 'Root CEO account cannot be edited here' });
    }

    const name = String(req.body?.name ?? existing.name).trim();
    const email = String(req.body?.email ?? existing.email).trim().toLowerCase();
    const phone = String(req.body?.phone ?? existing.phone ?? '').trim();
    const role = String(req.body?.role ?? existing.role).trim();
    const status = String(req.body?.status ?? existing.status).trim();
    const password = req.body?.password != null ? String(req.body.password) : '';
    let tenants = Array.isArray(req.body?.tenants) ? req.body.tenants : existing.tenants;

    if (!name || !email) {
      return res.status(400).json({ message: 'Name and email are required' });
    }
    if (!CENTRAL_TEAM_ROLES.includes(role)) {
      return res.status(400).json({
        message: `Invalid role. Choose one of: ${CENTRAL_TEAM_ROLES.join(', ')}`,
      });
    }
    if (role === CENTRAL_ROOT_ROLE) {
      return res.status(400).json({ message: 'CEO role cannot be assigned to team members' });
    }
    if (!['Active', 'Inactive'].includes(status)) {
      return res.status(400).json({ message: 'Status must be Active or Inactive' });
    }

    tenants = (tenants || []).filter((tid) => CENTRAL_TENANTS.includes(tid));
    if (!tenants.length) {
      return res.status(400).json({ message: 'Select at least one company' });
    }

    if (email !== existing.email) {
      const emailTaken = await CentralAdminUser.findOne({ email, _id: { $ne: id } }).lean();
      if (emailTaken) {
        return res.status(409).json({ message: 'A team member with this email already exists' });
      }
    }

    if (password) {
      if (password.length < 6) {
        return res.status(400).json({ message: 'Password must be at least 6 characters' });
      }
      existing.password = await bcrypt.hash(password, 10);
    }

    existing.name = name;
    existing.email = email;
    existing.phone = phone;
    existing.role = role;
    existing.status = status;
    existing.tenants = tenants;
    await existing.save();

    return res.status(200).json({
      message: 'Team member updated',
      user: toPublicUser(existing),
    });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to update team member', error: error?.message || error });
  }
};

/** Delete a team member (not root/CEO) */
export const deleteCentralAdmin = async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: 'Invalid team member id' });
    }

    const existing = await CentralAdminUser.findById(id);
    if (!existing) {
      return res.status(404).json({ message: 'Team member not found' });
    }
    if (existing.isRoot || existing.role === CENTRAL_ROOT_ROLE) {
      return res.status(403).json({ message: 'Root CEO account cannot be deleted' });
    }

    await CentralAdminUser.findByIdAndDelete(id);
    return res.status(200).json({ message: 'Team member deleted' });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to delete team member', error: error?.message || error });
  }
};

export const getCompanyTenants = async (_req, res) => {
  try {
    return res.status(200).json(COMPANIES);
  } catch (error) {
    return res.status(500).json({ message: 'Failed to load tenants', error: error?.message || error });
  }
};

export const getAllCompanies = async (_req, res) => {
  try {
    const rows = [];

    for (const tenant of COMPANIES) {
      try {
        const Company = (await import(`../models/${tenant.id}/${tenant.id}_company.js`)).default;
        const companies = await Company.find({}).sort({ createdAt: -1 }).lean();

        if (!companies.length) {
          rows.push({
            tenantId: tenant.id,
            tenantLabel: tenant.label,
            companyId: null,
            companyName: '— Not configured —',
            email: '',
            phone: '',
            website: '',
            address: '',
            pan: '',
            gstin: '',
            gstCode: '',
            state: '',
            bankName: '',
            bankAccountNumber: '',
            companyLogo: '',
            personalAccounts: [],
            createdAt: null,
            updatedAt: null,
            isEmpty: true,
          });
          continue;
        }

        for (const company of companies) {
          rows.push({
            tenantId: tenant.id,
            tenantLabel: tenant.label,
            companyId: company._id,
            companyName: company.companyName || '—',
            email: company.email || '',
            phone: company.phone || '',
            website: company.website || '',
            address: company.address || '',
            pan: company.pan || '',
            gstin: company.gstin || '',
            gstCode: company.gstCode || '',
            state: company.state || '',
            bankName: company.bankName || '',
            bankAccountNumber: company.bankAccountNumber || '',
            companyLogo: company.companyLogo || '',
            personalAccounts: Array.isArray(company.personalAccounts) ? company.personalAccounts : [],
            createdAt: company.createdAt || null,
            updatedAt: company.updatedAt || null,
            isEmpty: false,
          });
        }
      } catch (tenantError) {
        rows.push({
          tenantId: tenant.id,
          tenantLabel: tenant.label,
          companyId: null,
          companyName: '— Error loading —',
          email: '',
          phone: '',
          website: '',
          address: '',
          pan: '',
          gstin: '',
          gstCode: '',
          state: '',
          bankName: '',
          bankAccountNumber: '',
          companyLogo: '',
          personalAccounts: [],
          createdAt: null,
          updatedAt: null,
          isEmpty: true,
          error: tenantError?.message || 'Failed to load company data',
        });
      }
    }

    return res.status(200).json(rows);
  } catch (error) {
    return res.status(500).json({ message: 'Failed to load companies', error: error?.message || error });
  }
};

const safeCount = async (Model, filter = {}) => {
  try {
    return await Model.countDocuments(filter);
  } catch {
    return 0;
  }
};

const safeFind = async (Model, filter = {}, options = {}) => {
  try {
    let query = Model.find(filter);
    if (options.sort) query = query.sort(options.sort);
    if (options.limit) query = query.limit(options.limit);
    if (options.select) query = query.select(options.select);
    return await query.lean();
  } catch {
    return [];
  }
};

export const getTenantDashboard = async (req, res) => {
  try {
    const tenantId = String(req.params.tenantId || '').trim();
    const tenant = COMPANIES.find((c) => c.id === tenantId);
    if (!tenant) {
      return res.status(404).json({ message: 'Company tenant not found' });
    }

    const nowForMonth = new Date();
    const monthValue = `${nowForMonth.getFullYear()}-${String(nowForMonth.getMonth() + 1).padStart(2, '0')}`;
    const dashKey = cacheKey(tenantId, 'dashboard', { month: monthValue });
    const cached = await cacheGet(dashKey);
    if (cached) {
      return res.status(200).json(cached);
    }

    const [
      Company,
      Employee,
      Client,
      Project,
      Lead,
      Task,
      Billing,
      Leave,
      Expense,
    ] = await Promise.all([
      import(`../models/${tenantId}/${tenantId}_company.js`).then((m) => m.default),
      import(`../models/${tenantId}/${tenantId}_employee.js`).then((m) => m.default),
      import(`../models/${tenantId}/${tenantId}_client.js`).then((m) => m.default),
      import(`../models/${tenantId}/${tenantId}_project.js`).then((m) => m.default),
      import(`../models/${tenantId}/${tenantId}_lead.js`).then((m) => m.default).catch(() => null),
      import(`../models/${tenantId}/${tenantId}_task.js`).then((m) => m.default).catch(() => null),
      import(`../models/${tenantId}/${tenantId}_billing.js`).then((m) => m.default).catch(() => null),
      import(`../models/${tenantId}/${tenantId}_leave.js`).then((m) => m.default).catch(() => null),
      import(`../models/${tenantId}/${tenantId}_expense.js`).then((m) => m.default).catch(() => null),
    ]);

    const company = await Company.findOne().sort({ createdAt: 1 }).lean();

    // Month-scoped KPIs (tasks, leaves, revenue, expenses)
    const monthStart = new Date(nowForMonth.getFullYear(), nowForMonth.getMonth(), 1, 0, 0, 0, 0);
    const monthEnd = new Date(nowForMonth.getFullYear(), nowForMonth.getMonth() + 1, 0, 23, 59, 59, 999);
    const taskMonthFilter = {
      isRecurringTemplate: { $ne: true },
      createdAt: { $gte: monthStart, $lte: monthEnd },
    };
    const pendingLeaveMonthFilter = {
      status: 'Pending',
      $and: [
        { startDate: { $lte: monthEnd } },
        {
          $or: [
            { endDate: { $gte: monthStart } },
            { endDate: null },
            { endDate: { $exists: false } },
          ],
        },
      ],
    };
    const isInCurrentMonth = (value) => {
      if (!value) return false;
      const d = value instanceof Date ? value : new Date(value);
      if (Number.isNaN(d.getTime())) return false;
      return d >= monthStart && d <= monthEnd;
    };

    const [
      employees,
      clients,
      projects,
      activeProjects,
      leads,
      tasks,
      pendingTasks,
      inProgressTasks,
      completedTasks,
      pendingLeaves,
      billings,
      expenses,
      recentEmployees,
      recentProjects,
      recentLeads,
    ] = await Promise.all([
      safeCount(Employee),
      safeCount(Client),
      safeCount(Project),
      safeCount(Project, { status: { $in: ['In Progress', 'Not Started', 'Active'] } }),
      Lead ? safeCount(Lead) : 0,
      Task ? safeCount(Task, taskMonthFilter) : 0,
      Task ? safeCount(Task, { ...taskMonthFilter, status: 'Pending' }) : 0,
      Task ? safeCount(Task, { ...taskMonthFilter, status: 'In Progress' }) : 0,
      Task ? safeCount(Task, { ...taskMonthFilter, status: 'Completed' }) : 0,
      Leave ? safeCount(Leave, pendingLeaveMonthFilter) : 0,
      Billing
        ? safeFind(Billing, {}, {
            select: 'totalAmount amountPaid status createdAt paymentDate invoiceDate paymentDetails',
          })
        : [],
      Expense
        ? safeFind(Expense, {}, { select: 'amount totalAmount date createdAt' })
        : [],
      safeFind(Employee, {}, { sort: { createdAt: -1 }, limit: 5, select: 'name email designation createdAt' }),
      safeFind(Project, {}, { sort: { createdAt: -1 }, limit: 5, select: 'projectName status startDate deadline createdAt' }),
      Lead ? safeFind(Lead, {}, { sort: { createdAt: -1 }, limit: 5, select: 'businessName name status createdAt' }) : [],
    ]);

    const billingPaidAt = (b) =>
      b?.paymentDetails?.paymentDate || b?.paymentDate || b?.invoiceDate || b?.createdAt;

    const monthBillings = billings.filter((b) => isInCurrentMonth(billingPaidAt(b)));
    const totalRevenue = monthBillings.reduce(
      (sum, b) => sum + (Number(b.amountPaid) || Number(b.paymentDetails?.amount) || Number(b.totalAmount) || 0),
      0
    );
    const pendingInvoices = monthBillings.filter((b) => {
      const status = String(b.status || '').toLowerCase();
      return status !== 'paid' && status !== 'completed';
    }).length;
    const totalExpenses = expenses.reduce((sum, e) => {
      if (!isInCurrentMonth(e.date || e.createdAt)) return sum;
      return sum + (Number(e.amount) || Number(e.totalAmount) || 0);
    }, 0);

    const revenueByDay = [];
    const daysInMonth = monthEnd.getDate();
    for (let dayNum = 1; dayNum <= daysInMonth; dayNum += 1) {
      const day = new Date(monthStart.getFullYear(), monthStart.getMonth(), dayNum, 0, 0, 0, 0);
      const next = new Date(day);
      next.setDate(next.getDate() + 1);
      const dayRevenue = monthBillings.reduce((sum, b) => {
        const paidAt = new Date(billingPaidAt(b));
        if (Number.isNaN(paidAt.getTime())) return sum;
        if (paidAt >= day && paidAt < next) {
          return sum + (Number(b.amountPaid) || Number(b.paymentDetails?.amount) || Number(b.totalAmount) || 0);
        }
        return sum;
      }, 0);
      revenueByDay.push({
        date: day.toISOString(),
        label: day.toLocaleDateString('en-GB', { day: '2-digit', month: 'short' }),
        revenue: dayRevenue,
      });
    }

    const projectsWithProgress = recentProjects.map((project) => {
      const start = project.startDate ? new Date(project.startDate).getTime() : null;
      const end = project.deadline ? new Date(project.deadline).getTime() : null;
      let progress = 0;
      if (String(project.status || '').toLowerCase() === 'completed') {
        progress = 100;
      } else if (start && end && end > start) {
        progress = Math.min(95, Math.max(5, Math.round(((Date.now() - start) / (end - start)) * 100)));
      } else if (String(project.status || '') === 'In Progress') {
        progress = 40;
      }
      return { ...project, progress };
    });

    const payload = {
      tenantId: tenant.id,
      tenantLabel: tenant.label,
      company: company
        ? {
            companyName: company.companyName || tenant.label,
            email: company.email || '',
            phone: company.phone || '',
            website: company.website || '',
            address: company.address || '',
            pan: company.pan || '',
            gstin: company.gstin || '',
            state: company.state || '',
            bankName: company.bankName || '',
            bankAccountNumber: company.bankAccountNumber || '',
          }
        : null,
      stats: {
        employees,
        clients,
        projects,
        activeProjects,
        leads,
        tasks,
        pendingTasks,
        inProgressTasks,
        completedTasks,
        pendingLeaves,
        pendingInvoices,
        totalRevenue,
        totalExpenses,
      },
      revenueByDay,
      dateRange: {
        from: revenueByDay[0]?.date || null,
        to: revenueByDay[revenueByDay.length - 1]?.date || null,
      },
      recentEmployees,
      recentProjects: projectsWithProgress,
      recentLeads,
    };
    await cacheSet(dashKey, payload, CACHE_TTL.dashboard);
    return res.status(200).json(payload);
  } catch (error) {
    return res.status(500).json({ message: 'Failed to load company dashboard', error: error?.message || error });
  }
};


const loadTenantModels = async (tenantId) => {
  const [
    Employee,
    Project,
    Task,
    Attendance,
    Leave,
    Salary,
    Client,
  ] = await Promise.all([
    import(`../models/${tenantId}/${tenantId}_employee.js`).then((m) => m.default),
    import(`../models/${tenantId}/${tenantId}_project.js`).then((m) => m.default),
    import(`../models/${tenantId}/${tenantId}_task.js`).then((m) => m.default).catch(() => null),
    import(`../models/${tenantId}/${tenantId}_attendance.js`).then((m) => m.default).catch(() => null),
    import(`../models/${tenantId}/${tenantId}_leave.js`).then((m) => m.default).catch(() => null),
    import(`../models/${tenantId}/${tenantId}_salary.js`).then((m) => m.default).catch(() => null),
    import(`../models/${tenantId}/${tenantId}_client.js`).then((m) => m.default).catch(() => null),
  ]);
  return { Employee, Project, Task, Attendance, Leave, Salary, Client };
};

export const getTenantEmployees = async (req, res) => {
  try {
    const tenantId = String(req.params.tenantId || '').trim();
    const tenant = COMPANIES.find((c) => c.id === tenantId);
    if (!tenant) return res.status(404).json({ message: 'Company tenant not found' });

    const { Employee, Task } = await loadTenantModels(tenantId);
    const employees = await Employee.find({})
      .populate('designation', 'title accessRole department')
      .populate('reportingManager', 'name email')
      .select('-password')
      .sort({ createdAt: -1 })
      .lean();

    const ratingByEmployee = new Map();
    if (Task && employees.length) {
      const ratedTasks = await Task.find({
        assignedTo: { $in: employees.map((e) => e._id) },
        isRecurringTemplate: { $ne: true },
        'rating.score': { $ne: null },
      })
        .select('assignedTo rating.score')
        .lean();

      for (const task of ratedTasks) {
        const score = Number(task.rating?.score);
        if (!Number.isFinite(score) || score <= 0) continue;
        const key = String(task.assignedTo);
        if (!ratingByEmployee.has(key)) {
          ratingByEmployee.set(key, { sum: 0, count: 0 });
        }
        const entry = ratingByEmployee.get(key);
        entry.sum += score;
        entry.count += 1;
      }
    }

    const withPerformance = employees.map((emp) => {
      const entry = ratingByEmployee.get(String(emp._id));
      const averageRating =
        entry?.count > 0 ? Math.round((entry.sum / entry.count) * 10) / 10 : null;
      return {
        ...emp,
        performance: {
          averageRating,
          ratedTaskCount: entry?.count || 0,
        },
      };
    });

    return res.status(200).json({
      tenantId: tenant.id,
      tenantLabel: tenant.label,
      employees: withPerformance,
    });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to load employees', error: error?.message || error });
  }
};

export const getTenantEmployeeProfile = async (req, res) => {
  try {
    const tenantId = String(req.params.tenantId || '').trim();
    const employeeId = String(req.params.employeeId || '').trim();
    const tenant = COMPANIES.find((c) => c.id === tenantId);
    if (!tenant) return res.status(404).json({ message: 'Company tenant not found' });
    if (!employeeId) return res.status(400).json({ message: 'Employee id is required' });

    const { Employee, Project, Task, Attendance, Leave, Salary, Client } = await loadTenantModels(tenantId);
    if (!Task || !Attendance || !Leave || !Salary) {
      return res.status(500).json({ message: 'Employee related models are unavailable for this company' });
    }

    const monthParam = String(req.query.month || '').trim();
    const { buildEmployeeProfile } = await import('../utils/buildEmployeeProfile.js');
    const profile = await buildEmployeeProfile({
      employeeId,
      models: { Employee, Project, Task, Attendance, Leave, Salary },
      month: monthParam || null,
    });
    if (!profile) return res.status(404).json({ message: 'Employee not found' });

    const clientMap = new Map();
    for (const project of profile.assignedProjects || []) {
      const client = project.client;
      if (!client) continue;
      const key = String(client._id || client.clientName || client.name || client.companyName || Math.random());
      if (!clientMap.has(key)) {
        clientMap.set(key, {
          _id: client._id || null,
          name: client.clientName || client.companyName || client.name || '—',
          email: client.mailId || client.email || '',
          phone: client.clientNumber || client.phone || '',
          projects: [],
        });
      }
      clientMap.get(key).projects.push({
        _id: project._id,
        projectName: project.projectName,
        status: project.status,
        role: project.role,
      });
    }

    // Enrich clients if Client model fields differ / missing
    if (Client && clientMap.size) {
      const ids = [...clientMap.values()].map((c) => c._id).filter(Boolean);
      if (ids.length) {
        const clients = await Client.find({ _id: { $in: ids } })
          .select('clientName mailId clientNumber businessType city')
          .lean();
        for (const client of clients) {
          const existing = clientMap.get(String(client._id));
          if (!existing) continue;
          existing.name = client.clientName || existing.name;
          existing.email = client.mailId || existing.email;
          existing.phone = client.clientNumber || existing.phone;
          existing.businessType = client.businessType || '';
          existing.city = client.city || '';
        }
      }
    }

    return res.status(200).json({
      tenantId: tenant.id,
      tenantLabel: tenant.label,
      ...profile,
      clients: [...clientMap.values()],
    });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to load employee profile', error: error?.message || error });
  }
};

const resolveTenant = (tenantId) => COMPANIES.find((company) => company.id === tenantId) || null;

const loadTenantEmployeeModel = async (tenantId) => {
  await import(`../models/${tenantId}/${tenantId}_designation.js`).catch(() => null);
  return importTenantModel(tenantId, 'employee');
};

/** Central admin + company Admin designation may create/update employees in any tenant. */
export const canCentralAdminManageEmployees = (user) => {
  if (!user) return false;
  if (user.isCentralAdmin || user.isRoot) return true;
  if (user.role === CENTRAL_ROOT_ROLE) return true;
  if (user.isCompanyEmployee && isAdminEmployee(user)) return true;
  return false;
};

export const getTenantDesignations = async (req, res) => {
  try {
    const tenantId = String(req.params.tenantId || '').trim();
    const tenant = resolveTenant(tenantId);
    if (!tenant) return res.status(404).json({ message: 'Company tenant not found' });

    await import(`../models/${tenantId}/${tenantId}_designation.js`).catch(() => null);
    const Designation = await importTenantModel(tenantId, 'designation');
    if (!Designation) {
      return res.status(500).json({ message: 'Designations are unavailable for this company' });
    }

    const designations = await Designation.find({ isActive: { $ne: false } })
      .sort({ sortOrder: 1, title: 1 })
      .select('title accessRole department level')
      .lean();

    return res.status(200).json({ tenantId: tenant.id, designations });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to load designations', error: error?.message || error });
  }
};

export const createTenantEmployee = async (req, res) => {
  try {
    const tenantId = String(req.params.tenantId || '').trim();
    const tenant = resolveTenant(tenantId);
    if (!tenant) return res.status(404).json({ message: 'Company tenant not found' });

    const Employee = await loadTenantEmployeeModel(tenantId);
    if (!Employee) return res.status(500).json({ message: 'Employee model unavailable for this company' });

    const { payload, password } = normalizeEmployeePayload(req.body);
    if (!password || password.length < 6) {
      return res.status(400).json({ message: 'Password is required and must be at least 6 characters' });
    }
    const missing = validateEmployeePayload(payload);
    if (missing.length) {
      return res.status(400).json({ message: `Missing required fields: ${missing.join(', ')}` });
    }

    await assignEmployeeCodeOnCreate(Employee, tenantId, payload);
    const hashedPassword = await bcrypt.hash(password, 10);
    const newEmployee = new Employee({ ...payload, password: hashedPassword });
    await newEmployee.save();

    const employee = await Employee.findById(newEmployee._id)
      .populate('designation', 'title accessRole department')
      .populate('reportingManager', 'name email')
      .select('-password')
      .lean();

    return res.status(201).json({ message: 'Employee created successfully', employee });
  } catch (error) {
    const { status, message } = getEmployeeApiError(error, 'Error creating employee');
    return res.status(error.status || status).json({ message: error.message || message });
  }
};

export const updateTenantEmployee = async (req, res) => {
  try {
    const tenantId = String(req.params.tenantId || '').trim();
    const employeeId = String(req.params.employeeId || '').trim();
    const tenant = resolveTenant(tenantId);
    if (!tenant) return res.status(404).json({ message: 'Company tenant not found' });
    if (!employeeId) return res.status(400).json({ message: 'Employee id is required' });

    const Employee = await loadTenantEmployeeModel(tenantId);
    if (!Employee) return res.status(500).json({ message: 'Employee model unavailable for this company' });

    const { payload, password } = normalizeEmployeePayload(req.body);
    await validateEmployeeCodeOnUpdate(Employee, tenantId, employeeId, payload);
    const updates = { ...payload };
    if (password && password.length >= 6) {
      updates.password = await bcrypt.hash(password, 10);
    }

    const updated = await Employee.findByIdAndUpdate(employeeId, updates, { new: true, runValidators: true })
      .populate('designation', 'title accessRole department')
      .populate('reportingManager', 'name email')
      .select('-password')
      .lean();

    if (!updated) return res.status(404).json({ message: 'Employee not found' });

    return res.status(200).json({ message: 'Employee updated successfully', employee: updated });
  } catch (error) {
    const { status, message } = getEmployeeApiError(error, 'Error updating employee');
    return res.status(error.status || status).json({ message: error.message || message });
  }
};

export const createTenantClient = async (req, res) => {
  try {
    const tenantId = String(req.params.tenantId || '').trim();
    if (!resolveTenant(tenantId)) return res.status(404).json({ message: 'Company tenant not found' });
    const client = await createTenantClientRecord(tenantId, req.body);
    return res.status(201).json({ message: 'Client created successfully', client });
  } catch (error) {
    return res.status(error.status || 500).json({ message: error.message || 'Error creating client' });
  }
};

export const updateTenantClient = async (req, res) => {
  try {
    const tenantId = String(req.params.tenantId || '').trim();
    const clientId = String(req.params.clientId || '').trim();
    if (!resolveTenant(tenantId)) return res.status(404).json({ message: 'Company tenant not found' });
    const client = await updateTenantClientRecord(tenantId, clientId, req.body);
    return res.status(200).json({ message: 'Client updated successfully', client });
  } catch (error) {
    return res.status(error.status || 500).json({ message: error.message || 'Error updating client' });
  }
};

export const createTenantProject = async (req, res) => {
  try {
    const tenantId = String(req.params.tenantId || '').trim();
    if (!resolveTenant(tenantId)) return res.status(404).json({ message: 'Company tenant not found' });
    const project = await createTenantProjectRecord(tenantId, req.body);
    return res.status(201).json({ message: 'Project created successfully', project });
  } catch (error) {
    return res.status(error.status || 500).json({ message: error.message || 'Error creating project' });
  }
};

export const updateTenantProject = async (req, res) => {
  try {
    const tenantId = String(req.params.tenantId || '').trim();
    const projectId = String(req.params.projectId || '').trim();
    if (!resolveTenant(tenantId)) return res.status(404).json({ message: 'Company tenant not found' });
    const project = await updateTenantProjectRecord(tenantId, projectId, req.body);
    return res.status(200).json({ message: 'Project updated successfully', project });
  } catch (error) {
    return res.status(error.status || 500).json({ message: error.message || 'Error updating project' });
  }
};

export const createTenantLead = async (req, res) => {
  try {
    const tenantId = String(req.params.tenantId || '').trim();
    if (!resolveTenant(tenantId)) return res.status(404).json({ message: 'Company tenant not found' });
    const lead = await createTenantLeadRecord(tenantId, req.body);
    return res.status(201).json({ message: 'Lead created successfully', lead });
  } catch (error) {
    return res.status(error.status || 500).json({ message: error.message || 'Error creating lead' });
  }
};

export const updateTenantLead = async (req, res) => {
  try {
    const tenantId = String(req.params.tenantId || '').trim();
    const leadId = String(req.params.leadId || '').trim();
    if (!resolveTenant(tenantId)) return res.status(404).json({ message: 'Company tenant not found' });
    const lead = await updateTenantLeadRecord(tenantId, leadId, req.body);
    return res.status(200).json({ message: 'Lead updated successfully', lead });
  } catch (error) {
    return res.status(error.status || 500).json({ message: error.message || 'Error updating lead' });
  }
};


const importTenantModel = async (tenantId, suffix) => {
  try {
    return (await import(`../models/${tenantId}/${tenantId}_${suffix}.js`)).default;
  } catch {
    return null;
  }
};

export const updateTenantLeaveFinalDecision = async (req, res) => {
  try {
    const tenantId = String(req.params.tenantId || '').trim();
    const tenant = COMPANIES.find((company) => company.id === tenantId);
    if (!tenant) return res.status(404).json({ message: 'Company tenant not found' });

    const action = String(req.body?.action || '').trim();
    const centralAdminId = String(req.body?.centralAdminId || '').trim();
    const comment = String(req.body?.comment || '').trim();
    if (!['Approve', 'Reject'].includes(action)) {
      return res.status(400).json({ message: 'Action must be Approve or Reject' });
    }
    if (!centralAdminId) {
      return res.status(400).json({ message: 'Centralized Admin identity is required' });
    }

    // Stored sessions may predate the DB-backed user model (legacy ids like "central-admin-root"),
    // so resolve by ObjectId when possible and fall back to email otherwise.
    const centralAdminEmail = String(req.body?.centralAdminEmail || '').trim().toLowerCase();
    let centralAdmin = null;
    if (mongoose.isValidObjectId(centralAdminId)) {
      centralAdmin = await CentralAdminUser.findById(centralAdminId).lean();
    }
    if (!centralAdmin && centralAdminEmail) {
      centralAdmin = await CentralAdminUser.findOne({ email: centralAdminEmail }).lean();
    }
    if (!centralAdmin) {
      return res.status(401).json({ message: 'Your admin session is outdated. Please log out and log in again.' });
    }
    if (centralAdmin.status !== 'Active') {
      return res.status(403).json({ message: 'Centralized Admin account is not active' });
    }
    if (!centralAdmin.isRoot && !centralAdmin.tenants?.includes(tenantId)) {
      return res.status(403).json({ message: 'You do not have access to this company' });
    }

    const [Leave, Notification] = await Promise.all([
      importTenantModel(tenantId, 'leave'),
      importTenantModel(tenantId, 'notification'),
    ]);
    if (!Leave) return res.status(404).json({ message: 'Leaves not available' });

    const leave = await Leave.findById(req.params.leaveId);
    if (!leave) return res.status(404).json({ message: 'Leave not found' });
    if (leave.status !== 'Pending' || leave.approvalStage !== 'central_admin') {
      return res.status(400).json({ message: 'This leave is not awaiting the Centralized Admin decision' });
    }

    const approved = action === 'Approve';
    const actedAt = new Date();
    leave.status = approved ? 'Approved' : 'Rejected';
    leave.approvalStage = 'completed';
    leave.approvedAt = actedAt;
    leave.rejectionReason = approved ? '' : comment;
    leave.finalDecisionBy = {
      id: String(centralAdmin._id),
      name: centralAdmin.name || '',
      role: centralAdmin.role || 'Centralized Admin',
    };
    leave.approvalHistory.push({
      stage: 'central_admin',
      action: approved ? 'Approved' : 'Rejected',
      actor: null,
      actorName: centralAdmin.name || '',
      actorRole: centralAdmin.role || 'Centralized Admin',
      comment,
      actedAt,
    });
    await leave.save();

    if (Notification) {
      try {
        await Notification.create({
          recipient: leave.employee,
          type: 'leave_status',
          title: approved ? 'Leave request approved' : 'Leave request rejected',
          message: approved
            ? 'Your leave request received final approval.'
            : (comment ? `Your leave request was rejected: ${comment}` : 'Your leave request was rejected.'),
          link: '/leave',
          priority: 'high',
          metadata: {
            entityType: 'leave',
            entityId: leave._id,
            extra: { stage: 'central_admin', finalDecision: true },
          },
        });
      } catch {
        // The final decision remains valid if notification delivery fails.
      }
    }

    const populated = await Leave.findById(leave._id)
      .populate({ path: 'employee', populate: { path: 'designation' } })
      .populate('approvalHistory.actor');
    return res.status(200).json({
      message: approved ? 'Leave approved (final decision)' : 'Leave rejected (final decision)',
      leave: populated,
    });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to update leave', error: error?.message || error });
  }
};

export const getTenantModuleList = async (req, res) => {
  try {
    const tenantId = String(req.params.tenantId || '').trim();
    const module = String(req.params.module || '').trim().toLowerCase();
    const tenant = COMPANIES.find((c) => c.id === tenantId);
    if (!tenant) return res.status(404).json({ message: 'Company tenant not found' });

    const statusFilter = String(req.query.status || '').trim();

    if (module === 'clients') {
      const Client = await importTenantModel(tenantId, 'client');
      if (!Client) return res.status(404).json({ message: 'Clients not available' });
      const items = await Client.find({}).sort({ createdAt: -1 }).lean();
      return res.status(200).json({ tenantId, tenantLabel: tenant.label, module, items });
    }

    if (module === 'projects') {
      const Project = await importTenantModel(tenantId, 'project');
      if (!Project) return res.status(404).json({ message: 'Projects not available' });
      const filter = {};
      if (statusFilter === 'active') {
        filter.status = { $in: ['In Progress', 'Not Started', 'Active'] };
      } else if (statusFilter) {
        filter.status = new RegExp(`^${statusFilter}$`, 'i');
      }
      const items = await Project.find(filter)
        .populate('client', 'clientName mailId clientNumber')
        .populate('projectManager', 'name email')
        .sort({ createdAt: -1 })
        .lean();
      return res.status(200).json({ tenantId, tenantLabel: tenant.label, module, items });
    }

    if (module === 'leads') {
      const Lead = await importTenantModel(tenantId, 'lead');
      if (!Lead) return res.status(404).json({ message: 'Leads not available' });

      const sourceFilter = String(req.query.leadSource || req.query.source || '').trim();
      const sortBy = String(req.query.sortBy || '').trim().toLowerCase();
      const sortDir = String(req.query.sortDir || 'asc').trim().toLowerCase() === 'desc' ? -1 : 1;
      const dateFrom = String(req.query.dateFrom || req.query.createdFrom || '').trim();
      const dateTo = String(req.query.dateTo || req.query.createdTo || '').trim();
      const createdDate = String(req.query.createdAt || req.query.date || '').trim();

      const filter = {};
      if (statusFilter) filter.status = statusFilter;
      if (sourceFilter) filter.leadSource = new RegExp(sourceFilter.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');

      if (createdDate || dateFrom || dateTo) {
        filter.createdAt = {};
        if (createdDate && /^\d{4}-\d{2}-\d{2}$/.test(createdDate)) {
          const start = new Date(`${createdDate}T00:00:00.000`);
          const end = new Date(`${createdDate}T23:59:59.999`);
          filter.createdAt.$gte = start;
          filter.createdAt.$lte = end;
        } else {
          if (dateFrom && /^\d{4}-\d{2}-\d{2}$/.test(dateFrom)) {
            filter.createdAt.$gte = new Date(`${dateFrom}T00:00:00.000`);
          }
          if (dateTo && /^\d{4}-\d{2}-\d{2}$/.test(dateTo)) {
            filter.createdAt.$lte = new Date(`${dateTo}T23:59:59.999`);
          }
        }
        if (!Object.keys(filter.createdAt).length) delete filter.createdAt;
      }

      let sort = { createdAt: -1 };
      if (sortBy === 'status') sort = { status: sortDir, createdAt: -1 };
      else if (sortBy === 'source' || sortBy === 'leadsource') sort = { leadSource: sortDir, createdAt: -1 };
      else if (sortBy === 'createdat' || sortBy === 'date') sort = { createdAt: sortDir };

      const hasSalesAssignment = ['bangarProperties', 'mahaProperties', 'salesTechReality'].includes(tenantId);
      let leadQuery = Lead.find(filter).populate('generatedBy', 'name email');
      if (hasSalesAssignment) {
        leadQuery = leadQuery
          .populate('assignedTo', 'name email')
          .populate('siteCoordinator', 'name email');
      }
      const items = await leadQuery.sort(sort).lean();

      const statuses = await Lead.distinct('status');
      const sources = (await Lead.distinct('leadSource')).filter((s) => String(s || '').trim());

      return res.status(200).json({
        tenantId,
        tenantLabel: tenant.label,
        module,
        items,
        filters: {
          statuses: statuses.filter(Boolean).sort(),
          sources: sources.sort((a, b) => String(a).localeCompare(String(b))),
        },
      });
    }

    if (module === 'tasks') {
      const Task = await importTenantModel(tenantId, 'task');
      if (!Task) return res.status(404).json({ message: 'Tasks not available' });
      const filter = { isRecurringTemplate: { $ne: true } };
      if (statusFilter === 'pending') filter.status = 'Pending';
      else if (statusFilter === 'completed') filter.status = 'Completed';
      else if (statusFilter === 'in-progress') filter.status = 'In Progress';
      else if (statusFilter) filter.status = new RegExp(`^${statusFilter}$`, 'i');

      const now = new Date();
      const monthParam = String(req.query.month || '').trim();
      const dateParam = String(req.query.date || req.query.day || '').trim();
      const rangeMode = String(req.query.range || '').trim().toLowerCase() === 'month' || (/^\d{4}-\d{2}$/.test(monthParam) && !/^\d{4}-\d{2}-\d{2}$/.test(dateParam))
        ? 'month'
        : 'day';

      let rangeStart;
      let rangeEnd;
      let dateValue = null;
      let dateLabel = null;
      let monthValue = null;
      let monthLabel = null;

      if (rangeMode === 'month') {
        let year = now.getFullYear();
        let monthIndex = now.getMonth();
        if (/^\d{4}-\d{2}$/.test(monthParam)) {
          const [yStr, mStr] = monthParam.split('-');
          const parsedYear = Number(yStr);
          const parsedMonth = Number(mStr) - 1;
          if (parsedYear >= 2000 && parsedYear <= 2100 && parsedMonth >= 0 && parsedMonth <= 11) {
            year = parsedYear;
            monthIndex = parsedMonth;
          }
        }
        rangeStart = new Date(year, monthIndex, 1, 0, 0, 0, 0);
        rangeEnd = new Date(year, monthIndex + 1, 0, 23, 59, 59, 999);
        monthValue = `${year}-${String(monthIndex + 1).padStart(2, '0')}`;
        monthLabel = rangeStart.toLocaleDateString('en-IN', { month: 'long', year: 'numeric' });
      } else {
        let dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
        if (/^\d{4}-\d{2}-\d{2}$/.test(dateParam)) {
          const [yStr, mStr, dStr] = dateParam.split('-');
          const year = Number(yStr);
          const monthIndex = Number(mStr) - 1;
          const day = Number(dStr);
          const candidate = new Date(year, monthIndex, day, 0, 0, 0, 0);
          if (
            year >= 2000 &&
            year <= 2100 &&
            monthIndex >= 0 &&
            monthIndex <= 11 &&
            day >= 1 &&
            day <= 31 &&
            !Number.isNaN(candidate.getTime()) &&
            candidate.getFullYear() === year &&
            candidate.getMonth() === monthIndex &&
            candidate.getDate() === day
          ) {
            dayStart = candidate;
          }
        }
        rangeStart = dayStart;
        rangeEnd = new Date(dayStart.getTime() + 24 * 60 * 60 * 1000 - 1);
        dateValue = `${dayStart.getFullYear()}-${String(dayStart.getMonth() + 1).padStart(2, '0')}-${String(dayStart.getDate()).padStart(2, '0')}`;
        dateLabel = dayStart.toLocaleDateString('en-IN', {
          weekday: 'short',
          day: '2-digit',
          month: 'short',
          year: 'numeric',
        });
      }

      // Tasks created in the selected day or month
      filter.createdAt = { $gte: rangeStart, $lte: rangeEnd };

      const items = await Task.find(filter)
        .populate('project', 'projectName')
        .populate('assignedTo', 'name email')
        .populate('assignedBy', 'name email')
        .populate('rating.ratedBy', 'name email')
        .sort({ createdAt: -1 })
        .lean();
      return res.status(200).json({
        tenantId,
        tenantLabel: tenant.label,
        module,
        range: rangeMode,
        date: dateValue,
        dateLabel,
        month: monthValue,
        monthLabel,
        items,
      });
    }

    if (module === 'invoices') {
      const Billing = await importTenantModel(tenantId, 'billing');
      if (!Billing) return res.status(404).json({ message: 'Invoices not available' });

      const monthParam = String(req.query.month || '').trim();
      let monthLabel = null;
      let monthValue = null;
      let rangeStart = null;
      let rangeEnd = null;
      if (/^\d{4}-\d{2}$/.test(monthParam)) {
        const [yStr, mStr] = monthParam.split('-');
        const year = Number(yStr);
        const monthIndex = Number(mStr) - 1;
        if (year >= 2000 && year <= 2100 && monthIndex >= 0 && monthIndex <= 11) {
          rangeStart = new Date(year, monthIndex, 1, 0, 0, 0, 0);
          rangeEnd = new Date(year, monthIndex + 1, 0, 23, 59, 59, 999);
          monthLabel = rangeStart.toLocaleDateString('en-IN', { month: 'long', year: 'numeric' });
          monthValue = `${year}-${String(monthIndex + 1).padStart(2, '0')}`;
        }
      }

      let items = await Billing.find({})
        .populate('client', 'clientName mailId clientNumber')
        .sort({ createdAt: -1 })
        .lean();

      if (rangeStart && rangeEnd) {
        items = items.filter((b) => {
          const raw = b.paymentDetails?.paymentDate || b.createdAt;
          if (!raw) return false;
          const d = new Date(raw);
          if (Number.isNaN(d.getTime())) return false;
          return d >= rangeStart && d <= rangeEnd;
        });
      }

      if (statusFilter === 'pending') {
        items = items.filter((b) => {
          const paid = Number(b.paymentDetails?.amount) || Number(b.amountPaid) || 0;
          const total = Number(b.totalAmount) || Number(b.paymentDetails?.amount) || 0;
          const st = String(b.status || '').toLowerCase();
          if (st === 'paid' || st === 'completed') return false;
          if (total > 0 && paid >= total) return false;
          return true;
        });
      }
      return res.status(200).json({
        tenantId,
        tenantLabel: tenant.label,
        module,
        month: monthValue,
        monthLabel,
        items,
      });
    }

    if (module === 'leaves') {
      const Leave = await importTenantModel(tenantId, 'leave');
      if (!Leave) return res.status(404).json({ message: 'Leaves not available' });
      const filter = {};
      if (statusFilter === 'pending') filter.status = 'Pending';
      else if (statusFilter) filter.status = new RegExp(`^${statusFilter}$`, 'i');

      const monthParam = String(req.query.month || '').trim();
      let monthLabel = null;
      let monthValue = null;
      if (/^\d{4}-\d{2}$/.test(monthParam)) {
        const [yStr, mStr] = monthParam.split('-');
        const year = Number(yStr);
        const monthIndex = Number(mStr) - 1;
        if (year >= 2000 && year <= 2100 && monthIndex >= 0 && monthIndex <= 11) {
          const rangeStart = new Date(year, monthIndex, 1, 0, 0, 0, 0);
          const rangeEnd = new Date(year, monthIndex + 1, 0, 23, 59, 59, 999);
          monthLabel = rangeStart.toLocaleDateString('en-IN', { month: 'long', year: 'numeric' });
          monthValue = `${year}-${String(monthIndex + 1).padStart(2, '0')}`;
          // Leaves that overlap the selected month
          filter.$and = [
            ...(filter.$and || []),
            { startDate: { $lte: rangeEnd } },
            {
              $or: [
                { endDate: { $gte: rangeStart } },
                { endDate: null },
                { endDate: { $exists: false } },
              ],
            },
          ];
        }
      }

      const items = await Leave.find(filter)
        .populate('employee', 'name email department profilePhoto')
        .populate('approvedBy', 'name email')
        .sort({ startDate: -1, createdAt: -1 })
        .lean();
      return res.status(200).json({
        tenantId,
        tenantLabel: tenant.label,
        module,
        month: monthValue,
        monthLabel,
        items,
      });
    }

    if (module === 'reports') {
      const monthParam = String(req.query.month || '').trim(); // YYYY-MM
      let rangeStart = null;
      let rangeEnd = null;
      let monthLabel = 'All time';

      if (/^\d{4}-\d{2}$/.test(monthParam)) {
        const [yStr, mStr] = monthParam.split('-');
        const year = Number(yStr);
        const monthIndex = Number(mStr) - 1;
        if (year >= 2000 && year <= 2100 && monthIndex >= 0 && monthIndex <= 11) {
          rangeStart = new Date(year, monthIndex, 1, 0, 0, 0, 0);
          rangeEnd = new Date(year, monthIndex + 1, 0, 23, 59, 59, 999);
          monthLabel = rangeStart.toLocaleDateString('en-IN', { month: 'long', year: 'numeric' });
        }
      }

      const inRange = (value) => {
        if (!rangeStart || !rangeEnd) return true;
        if (!value) return false;
        const d = new Date(value);
        if (Number.isNaN(d.getTime())) return false;
        return d >= rangeStart && d <= rangeEnd;
      };

      const createdInRange = rangeStart
        ? { createdAt: { $gte: rangeStart, $lte: rangeEnd } }
        : {};

      const [Billing, Expense, Project, Task, Lead, Client, Employee, Salary] = await Promise.all([
        importTenantModel(tenantId, 'billing'),
        importTenantModel(tenantId, 'expense'),
        importTenantModel(tenantId, 'project'),
        importTenantModel(tenantId, 'task'),
        importTenantModel(tenantId, 'lead'),
        importTenantModel(tenantId, 'client'),
        importTenantModel(tenantId, 'employee'),
        importTenantModel(tenantId, 'salary'),
      ]);

      const salaryMonthFilter = {};
      if (rangeStart) {
        salaryMonthFilter.year = rangeStart.getFullYear();
        salaryMonthFilter.month = rangeStart.getMonth() + 1;
      }

      const [allBillings, allExpenses, salaries, projectCount, taskCount, leadCount, clientCount, employeeCount] =
        await Promise.all([
          Billing
            ? Billing.find({})
                .select('paymentDetails totalAmount amountPaid status invoiceNumber createdAt')
                .populate('client', 'clientName')
                .lean()
            : [],
          Expense ? Expense.find({}).sort({ date: -1 }).lean() : [],
          Salary
            ? Salary.find(salaryMonthFilter)
                .populate('employee', 'name email department designation')
                .sort({ amount: -1 })
                .lean()
            : [],
          Project ? Project.countDocuments(createdInRange) : 0,
          Task
            ? Task.countDocuments({
                isRecurringTemplate: { $ne: true },
                ...createdInRange,
              })
            : 0,
          Lead ? Lead.countDocuments(createdInRange) : 0,
          Client ? Client.countDocuments(createdInRange) : 0,
          Employee
            ? Employee.countDocuments(
                rangeStart
                  ? {
                      $or: [
                        { dateOfJoining: { $gte: rangeStart, $lte: rangeEnd } },
                        { createdAt: { $gte: rangeStart, $lte: rangeEnd } },
                      ],
                    }
                  : {}
              )
            : 0,
        ]);

      const billings = allBillings.filter((b) =>
        inRange(b.paymentDetails?.paymentDate || b.createdAt)
      );
      const expenses = allExpenses.filter((e) => inRange(e.date || e.createdAt));

      const totalRevenue = billings.reduce(
        (sum, b) => sum + (Number(b.paymentDetails?.amount) || Number(b.amountPaid) || Number(b.totalAmount) || 0),
        0
      );
      const totalExpenses = expenses.reduce(
        (sum, e) => sum + (Number(e.amount) || Number(e.totalAmount) || 0),
        0
      );
      const totalPayroll = salaries.reduce((sum, s) => sum + (Number(s.amount) || 0), 0);
      const payrollPaid = salaries
        .filter((s) => String(s.status || '').toLowerCase() === 'paid')
        .reduce((sum, s) => sum + (Number(s.amount) || 0), 0);
      const payrollUnpaid = totalPayroll - payrollPaid;

      return res.status(200).json({
        tenantId,
        tenantLabel: tenant.label,
        module,
        month: monthParam || null,
        monthLabel,
        summary: {
          employees: employeeCount,
          clients: clientCount,
          projects: projectCount,
          tasks: taskCount,
          leads: leadCount,
          totalRevenue,
          totalExpenses,
          totalPayroll,
          payrollPaid,
          payrollUnpaid,
          payrollCount: salaries.length,
          net: totalRevenue - totalExpenses - totalPayroll,
          invoiceCount: billings.length,
        },
        expenses,
        billings,
        salaries,
      });
    }

    if (module === 'settings') {
      const Company = await importTenantModel(tenantId, 'company');
      if (!Company) return res.status(404).json({ message: 'Company settings not available' });
      const company = await Company.findOne().sort({ createdAt: 1 }).lean();
      return res.status(200).json({
        tenantId,
        tenantLabel: tenant.label,
        module,
        company: company || null,
      });
    }

    if (module === 'expenses') {
      const Expense = await importTenantModel(tenantId, 'expense');
      if (!Expense) return res.status(404).json({ message: 'Expenses not available' });

      const monthParam = String(req.query.month || '').trim();
      let monthLabel = null;
      let monthValue = null;
      const filter = {};
      if (/^\d{4}-\d{2}$/.test(monthParam)) {
        const [yStr, mStr] = monthParam.split('-');
        const year = Number(yStr);
        const monthIndex = Number(mStr) - 1;
        if (year >= 2000 && year <= 2100 && monthIndex >= 0 && monthIndex <= 11) {
          const rangeStart = new Date(year, monthIndex, 1, 0, 0, 0, 0);
          const rangeEnd = new Date(year, monthIndex + 1, 0, 23, 59, 59, 999);
          monthLabel = rangeStart.toLocaleDateString('en-IN', { month: 'long', year: 'numeric' });
          monthValue = `${year}-${String(monthIndex + 1).padStart(2, '0')}`;
          filter.date = { $gte: rangeStart, $lte: rangeEnd };
        }
      }

      const items = await Expense.find(filter).sort({ date: -1, createdAt: -1 }).lean();
      return res.status(200).json({
        tenantId,
        tenantLabel: tenant.label,
        module,
        month: monthValue,
        monthLabel,
        items,
      });
    }

    if (module === 'salaries') {
      const Salary = await importTenantModel(tenantId, 'salary');
      if (!Salary) return res.status(404).json({ message: 'Payroll not available' });

      const monthParam = String(req.query.month || '').trim();
      let monthLabel = null;
      let monthValue = null;
      const filter = {};
      if (/^\d{4}-\d{2}$/.test(monthParam)) {
        const [yStr, mStr] = monthParam.split('-');
        const year = Number(yStr);
        const monthIndex = Number(mStr) - 1;
        if (year >= 2000 && year <= 2100 && monthIndex >= 0 && monthIndex <= 11) {
          filter.year = year;
          filter.month = monthIndex + 1;
          const rangeStart = new Date(year, monthIndex, 1, 0, 0, 0, 0);
          monthLabel = rangeStart.toLocaleDateString('en-IN', { month: 'long', year: 'numeric' });
          monthValue = `${year}-${String(monthIndex + 1).padStart(2, '0')}`;
        }
      }

      const items = await Salary.find(filter)
        .populate('employee', 'name email department designation profilePhoto')
        .sort({ year: -1, month: -1, amount: -1 })
        .lean();
      return res.status(200).json({
        tenantId,
        tenantLabel: tenant.label,
        module,
        month: monthValue,
        monthLabel,
        items,
      });
    }

    if (module === 'attendance') {
      const Attendance = await importTenantModel(tenantId, 'attendance');
      if (!Attendance) return res.status(404).json({ message: 'Attendance not available' });

      const Employee = await importTenantModel(tenantId, 'employee');
      const monthParam = String(req.query.month || '').trim();
      const employeeId = String(req.query.employeeId || '').trim();
      const employeeSearch = String(req.query.employee || req.query.search || '').trim();

      const now = new Date();
      let year = now.getFullYear();
      let monthIndex = now.getMonth();
      if (/^\d{4}-\d{2}$/.test(monthParam)) {
        const [yStr, mStr] = monthParam.split('-');
        const parsedYear = Number(yStr);
        const parsedMonth = Number(mStr) - 1;
        if (parsedYear >= 2000 && parsedYear <= 2100 && parsedMonth >= 0 && parsedMonth <= 11) {
          year = parsedYear;
          monthIndex = parsedMonth;
        }
      }

      const rangeStart = new Date(year, monthIndex, 1, 0, 0, 0, 0);
      const rangeEnd = new Date(year, monthIndex + 1, 0, 23, 59, 59, 999);
      const monthLabel = rangeStart.toLocaleDateString('en-IN', { month: 'long', year: 'numeric' });
      const monthValue = `${year}-${String(monthIndex + 1).padStart(2, '0')}`;

      const Leave = await importTenantModel(tenantId, 'leave');

      const employees = Employee
        ? await Employee.find({ status: { $ne: 'Inactive' } })
            .select('name email department designation profilePhoto employeeCode')
            .sort({ name: 1 })
            .lean()
        : [];

      const filter = { date: { $gte: rangeStart, $lte: rangeEnd } };

      if (employeeId && mongoose.isValidObjectId(employeeId)) {
        filter.employee = employeeId;
      } else if (employeeSearch && Employee) {
        const escaped = employeeSearch.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        const matchingEmployees = await Employee.find({
          name: new RegExp(escaped, 'i'),
        })
          .select('_id')
          .lean();
        const ids = matchingEmployees.map((row) => row._id);
        filter.employee = ids.length ? { $in: ids } : null;
        if (!ids.length) {
          return res.status(200).json({
            tenantId,
            tenantLabel: tenant.label,
            module,
            month: monthValue,
            monthLabel,
            items: [],
            leaves: [],
            summary: {
              totalRecords: 0,
              fullDay: 0,
              halfDay: 0,
              absent: 0,
              inProgress: 0,
              uniqueEmployees: 0,
            },
            employees,
          });
        }
      }

      const leaveFilter = {
        status: 'Approved',
        startDate: { $lte: rangeEnd },
        endDate: { $gte: rangeStart },
      };
      if (filter.employee) leaveFilter.employee = filter.employee;

      const [items, leaves] = await Promise.all([
        Attendance.find(filter)
          .populate('employee', 'name email department designation profilePhoto employeeCode')
          .sort({ date: -1 })
          .lean(),
        Leave
          ? Leave.find(leaveFilter)
              .select('employee leaveType startDate endDate numberOfDays reason')
              .lean()
          : Promise.resolve([]),
      ]);

      const uniqueEmployeeIds = new Set(
        items.map((row) => String(row.employee?._id || row.employee || '')).filter(Boolean)
      );

      const summary = {
        totalRecords: items.length,
        fullDay: items.filter((row) => row.status === 'Full Day').length,
        halfDay: items.filter((row) => row.status === 'Half Day').length,
        absent: items.filter((row) => row.status === 'Absent').length,
        inProgress: items.filter((row) => row.status === 'In Progress').length,
        uniqueEmployees: uniqueEmployeeIds.size,
      };

      return res.status(200).json({
        tenantId,
        tenantLabel: tenant.label,
        module,
        month: monthValue,
        monthLabel,
        items,
        leaves,
        summary,
        employees,
      });
    }

    if (module === 'properties') {
      const Property = await importTenantModel(tenantId, 'property');
      if (!Property) return res.status(404).json({ message: 'Properties not available' });
      const items = await Property.find({})
        .populate('assignedTo', 'name email')
        .sort({ updatedAt: -1 })
        .lean();
      return res.status(200).json({ tenantId, tenantLabel: tenant.label, module, items });
    }

    if (module === 'quotations') {
      const Quotation = await importTenantModel(tenantId, 'quotation');
      if (!Quotation) return res.status(404).json({ message: 'Quotations not available' });

      const monthParam = String(req.query.month || '').trim();
      let monthLabel = null;
      let monthValue = null;
      const filter = {};
      if (/^\d{4}-\d{2}$/.test(monthParam)) {
        const [yStr, mStr] = monthParam.split('-');
        const year = Number(yStr);
        const monthIndex = Number(mStr) - 1;
        if (year >= 2000 && year <= 2100 && monthIndex >= 0 && monthIndex <= 11) {
          const rangeStart = new Date(year, monthIndex, 1, 0, 0, 0, 0);
          const rangeEnd = new Date(year, monthIndex + 1, 0, 23, 59, 59, 999);
          monthLabel = rangeStart.toLocaleDateString('en-IN', { month: 'long', year: 'numeric' });
          monthValue = `${year}-${String(monthIndex + 1).padStart(2, '0')}`;
          filter.createdAt = { $gte: rangeStart, $lte: rangeEnd };
        }
      }

      const items = await Quotation.find(filter)
        .populate('client', 'clientName mailId')
        .sort({ createdAt: -1 })
        .lean();
      return res.status(200).json({
        tenantId,
        tenantLabel: tenant.label,
        module,
        month: monthValue,
        monthLabel,
        items,
      });
    }

    return res.status(404).json({ message: `Unknown module: ${module}` });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to load module data', error: error?.message || error });
  }
};


export const getTenantClientDashboard = async (req, res) => {
  try {
    const tenantId = String(req.params.tenantId || '').trim();
    const clientId = String(req.params.clientId || '').trim();
    const tenant = COMPANIES.find((c) => c.id === tenantId);
    if (!tenant) return res.status(404).json({ message: 'Company tenant not found' });
    if (!clientId) return res.status(400).json({ message: 'Client id is required' });

    const [Client, Project, Billing, Task, SocialMediaCalendar] = await Promise.all([
      importTenantModel(tenantId, 'client'),
      importTenantModel(tenantId, 'project'),
      importTenantModel(tenantId, 'billing'),
      importTenantModel(tenantId, 'task'),
      importTenantModel(tenantId, 'socialMediaCalendar'),
    ]);

    if (!Client || !Project) {
      return res.status(500).json({ message: 'Client models unavailable for this company' });
    }

    const { buildClientDashboard } = await import('../utils/buildClientDashboard.js');
    const data = await buildClientDashboard({
      clientId,
      models: { Client, Project, Billing, Task, SocialMediaCalendar },
    });
    if (!data) return res.status(404).json({ message: 'Client not found' });

    return res.status(200).json({
      tenantId: tenant.id,
      tenantLabel: tenant.label,
      ...data,
    });
  } catch (error) {
    return res.status(500).json({
      message: 'Failed to load client overview',
      error: error?.message || error,
    });
  }
};


export const getTenantProjectDashboard = async (req, res) => {
  try {
    const tenantId = String(req.params.tenantId || '').trim();
    const projectId = String(req.params.projectId || '').trim();
    const tenant = COMPANIES.find((c) => c.id === tenantId);
    if (!tenant) return res.status(404).json({ message: 'Company tenant not found' });
    if (!projectId) return res.status(400).json({ message: 'Project id is required' });

    const [Project, Billing, Task] = await Promise.all([
      importTenantModel(tenantId, 'project'),
      importTenantModel(tenantId, 'billing'),
      importTenantModel(tenantId, 'task'),
    ]);

    if (!Project) {
      return res.status(500).json({ message: 'Project model unavailable for this company' });
    }

    const { buildProjectDashboard } = await import('../utils/buildProjectDashboard.js');
    const data = await buildProjectDashboard({
      projectId,
      models: { Project, Billing, Task },
    });
    if (!data) return res.status(404).json({ message: 'Project not found' });

    return res.status(200).json({
      tenantId: tenant.id,
      tenantLabel: tenant.label,
      ...data,
    });
  } catch (error) {
    return res.status(500).json({
      message: 'Failed to load project overview',
      error: error?.message || error,
    });
  }
};


export const getTenantTaskOverview = async (req, res) => {
  try {
    const tenantId = String(req.params.tenantId || '').trim();
    const taskId = String(req.params.taskId || '').trim();
    const tenant = COMPANIES.find((c) => c.id === tenantId);
    if (!tenant) return res.status(404).json({ message: 'Company tenant not found' });
    if (!taskId) return res.status(400).json({ message: 'Task id is required' });

    if (taskId.startsWith('social-media-')) {
      return res.status(404).json({ message: 'Social media calendar tasks are not available in overview' });
    }

    const Task = await importTenantModel(tenantId, 'task');
    if (!Task) return res.status(404).json({ message: 'Tasks not available for this company' });

    const task = await Task.findById(taskId)
      .populate({
        path: 'project',
        select: 'projectName status department budget startDate endDate deadline progress client',
        populate: { path: 'client', select: 'clientName clientNumber mailId businessType' },
      })
      .populate('assignedTo', 'name email department')
      .populate('assignedBy', 'name email department')
      .populate('rating.ratedBy', 'name email')
      .lean();

    if (!task) return res.status(404).json({ message: 'Task not found' });

    return res.status(200).json({
      tenantId: tenant.id,
      tenantLabel: tenant.label,
      task,
    });
  } catch (error) {
    return res.status(500).json({
      message: 'Failed to load task overview',
      error: error?.message || error,
    });
  }
};

/** Distribute payment across projects for display (same logic as tenant billing controllers) */
const withDynamicRemainingCost = (billing) => {
  const doc = billing?.toObject ? billing.toObject() : { ...billing };
  const paymentAmount = Number(doc.paymentDetails?.amount) || 0;
  const projects = Array.isArray(doc.projects) ? doc.projects : [];
  if (paymentAmount <= 0) {
    doc.projects = projects.map((p) => ({
      ...p,
      remainingCost: Math.max(0, Number(p.projectCost) || 0),
    }));
    return doc;
  }
  let remainingToDistribute = paymentAmount;
  doc.projects = projects.map((p) => {
    const cost = Number(p.projectCost) || 0;
    const amountPaid = Math.min(cost, Math.max(0, remainingToDistribute));
    remainingToDistribute -= amountPaid;
    return { ...p, remainingCost: Math.max(0, cost - amountPaid) };
  });
  return doc;
};

const computeBillingTracking = (billings) => {
  const byProject = new Map();
  for (const b of billings) {
    const doc = b?.toObject ? b.toObject() : b;
    const paymentAmount = Number(doc.paymentDetails?.amount) || 0;
    const projects = Array.isArray(doc.projects) ? doc.projects : [];
    let remainingToDistribute = paymentAmount;
    for (const p of projects) {
      const projectId = (p.project?._id || p.project)?.toString?.() || p.project;
      if (!projectId) continue;
      const cost = Number(p.projectCost) || 0;
      const amountPaid = paymentAmount <= 0 ? 0 : Math.min(cost, Math.max(0, remainingToDistribute));
      if (paymentAmount > 0) remainingToDistribute -= amountPaid;
      if (!byProject.has(projectId)) {
        byProject.set(projectId, { project: p.project, projectCost: cost, totalPaid: 0 });
      }
      const entry = byProject.get(projectId);
      entry.projectCost = Math.max(entry.projectCost, cost);
      entry.totalPaid += amountPaid;
    }
  }
  return Array.from(byProject.values()).map((entry) => ({
    ...entry,
    remaining: Math.max(0, entry.projectCost - entry.totalPaid),
  }));
};

export const getTenantInvoiceOverview = async (req, res) => {
  try {
    const tenantId = String(req.params.tenantId || '').trim();
    const invoiceId = String(req.params.invoiceId || '').trim();
    const tenant = COMPANIES.find((c) => c.id === tenantId);
    if (!tenant) return res.status(404).json({ message: 'Company tenant not found' });
    if (!invoiceId) return res.status(400).json({ message: 'Invoice id is required' });

    const Billing = await importTenantModel(tenantId, 'billing');
    if (!Billing) return res.status(404).json({ message: 'Invoices not available for this company' });

    const billing = await Billing.findById(invoiceId)
      .populate('client')
      .populate('projects.project');
    if (!billing) return res.status(404).json({ message: 'Invoice not found' });

    const result = withDynamicRemainingCost(billing);
    const clientId = (billing.client?._id || billing.client)?.toString?.();
    if (clientId) {
      const allForClient = await Billing.find({ client: clientId })
        .populate('projects.project')
        .sort({ createdAt: 1 });
      result.tracking = computeBillingTracking(allForClient);
    }

    return res.status(200).json({
      tenantId: tenant.id,
      tenantLabel: tenant.label,
      invoice: result,
    });
  } catch (error) {
    return res.status(500).json({
      message: 'Failed to load invoice',
      error: error?.message || error,
    });
  }
};
