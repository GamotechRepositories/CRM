import { Router } from 'express';
import {
  login,
  listCentralAdmins,
  createCentralAdmin,
  getAllCompanies,
  getCompanyTenants,
  getTenantDashboard,
  getTenantEmployees,
  getTenantEmployeeProfile,
  getTenantModuleList,
  getTenantClientDashboard,
  getTenantProjectDashboard,
  getTenantTaskOverview,
  getTenantInvoiceOverview,
} from '../controllers/centralAdminController.js';

const router = Router();

router.post('/auth/login', login);
router.get('/ceo-team', listCentralAdmins);
router.post('/ceo-team', createCentralAdmin);
router.get('/companies', getAllCompanies);
router.get('/tenants', getCompanyTenants);
router.get('/companies/:tenantId/dashboard', getTenantDashboard);
router.get('/companies/:tenantId/employees', getTenantEmployees);
router.get('/companies/:tenantId/employees/:employeeId', getTenantEmployeeProfile);
router.get('/companies/:tenantId/modules/:module', getTenantModuleList);
router.get('/companies/:tenantId/clients/:clientId/dashboard', getTenantClientDashboard);
router.get('/companies/:tenantId/projects/:projectId/dashboard', getTenantProjectDashboard);
router.get('/companies/:tenantId/tasks/:taskId', getTenantTaskOverview);
router.get('/companies/:tenantId/invoices/:invoiceId', getTenantInvoiceOverview);

export default router;
