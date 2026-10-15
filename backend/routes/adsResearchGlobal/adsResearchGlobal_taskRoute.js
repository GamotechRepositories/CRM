import { Router } from 'express';
import {
  createTask,
  getTasks,
  getTaskById,
  updateTask,
  deleteTask,
  approveTask,
  rejectTask,
} from '../../controllers/adsResearchGlobal/adsResearchGlobal_taskController.js';

const router = Router();

router.get('/tasks', getTasks);
router.post('/tasks', createTask);
router.get('/tasks/:id', getTaskById);
router.put('/tasks/:id', updateTask);
router.put('/tasks/:id/approve', approveTask);
router.put('/tasks/:id/reject', rejectTask);
router.delete('/tasks/:id', deleteTask);

export default router;
