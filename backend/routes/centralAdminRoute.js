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
  updateTenantLeaveFinalDecision,
} from '../controllers/centralAdminController.js';
import {
  createMeeting,
  deleteMeeting,
  getBoss,
  getMeetingById,
  listMeetings,
  updateMeeting,
} from '../controllers/centralAdminMeetingController.js';
import { registerDevice } from '../controllers/notification.controller.js';
import { optionalAuth, requireAuth } from '../utils/jwtAuth.js';

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
router.patch('/companies/:tenantId/leaves/:leaveId/status', updateTenantLeaveFinalDecision);

// Meeting app (CEO + create-team members)
router.use(optionalAuth);
router.post('/device/register', requireAuth, registerDevice);
router.get('/boss', getBoss);
router.get('/meetings', listMeetings);
router.get('/meetings/:id', getMeetingById);
router.post('/meetings', createMeeting);
router.put('/meetings/:id', updateMeeting);
router.delete('/meetings/:id', deleteMeeting);

export default router;
