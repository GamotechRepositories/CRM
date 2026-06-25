import { Router } from 'express';
import {
  checkIn,
  checkOut,
  getTodayAttendance,
  getAttendanceByMonth,
  getAttendanceByEmployee,
} from '../../controllers/mahaProperties/mahaProperties_attendanceController.js';

const router = Router();

router.post('/attendance/check-in', checkIn);
router.post('/attendance/check-out', checkOut);
router.get('/attendance/today', getTodayAttendance);
router.get('/attendance/by-month', getAttendanceByMonth);
router.get('/attendance/employee/:employeeId', getAttendanceByEmployee);

export default router;
