import { Router } from 'express';
import { leaveHandlers } from '../../controllers/mahaProperties/mahaProperties_leaveController.js';

const router = Router();
const { createLeave, getLeaves, getLeaveById, updateLeaveStatus } = leaveHandlers;

router.get('/leave', getLeaves);
router.post('/leave', createLeave);
router.get('/leave/:id', getLeaveById);
router.patch('/leave/:id/status', updateLeaveStatus);

export default router;
