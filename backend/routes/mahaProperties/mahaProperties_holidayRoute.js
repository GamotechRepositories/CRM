import { Router } from 'express';
import {
  getHolidays,
  createHoliday,
  getHolidayById,
  updateHoliday,
  deleteHoliday,
  seedDefaultHolidays,
} from '../../controllers/mahaProperties/mahaProperties_holidayController.js';

const router = Router();

router.get('/holidays', getHolidays);
router.post('/holidays', createHoliday);
router.post('/holidays/seed-default', seedDefaultHolidays);
router.get('/holidays/:id', getHolidayById);
router.put('/holidays/:id', updateHoliday);
router.delete('/holidays/:id', deleteHoliday);

export default router;
