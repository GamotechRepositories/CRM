import { Router } from 'express';
import {
  checkIn,
  checkOut,
  getTodayAttendance,
  getAttendanceByMonth,
  getAttendanceByEmployee,
  startBreak,
  endBreak,
  startMeeting,
  endMeeting,
  updateLocationTimeline,
} from '../../controllers/mahaProperties/mahaProperties_attendanceController.js';

const router = Router();

router.post('/attendance/check-in', checkIn);
router.post('/attendance/check-out', checkOut);
router.post('/attendance/break/start', startBreak);
router.post('/attendance/break/end', endBreak);
router.post('/attendance/meeting/start', startMeeting);
router.post('/attendance/meeting/end', endMeeting);
router.post('/attendance/location-update', updateLocationTimeline);
router.get('/attendance/today', getTodayAttendance);
router.get('/attendance/by-month', getAttendanceByMonth);
router.get('/attendance/employee/:employeeId', getAttendanceByEmployee);

export default router;
