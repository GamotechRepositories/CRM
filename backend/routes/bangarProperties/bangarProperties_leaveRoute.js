import { Router } from 'express';
import {
  createLeave,
  getLeaves,
  getLeaveById,
  updateLeaveStatus,
} from '../../controllers/bangarProperties/bangarProperties_leaveController.js';

const router = Router();

router.get('/leave', getLeaves);
router.post('/leave', createLeave);
router.get('/leave/:id', getLeaveById);
router.patch('/leave/:id/status', updateLeaveStatus);

export default router;
