import { Router } from 'express';
import {
  createMeeting,
  deleteMeeting,
  getAllMeetings,
  getMeetingById,
  getMeetings,
  updateMeeting,
} from '../../controllers/bangarProperties/bangarProperties_meetingController.js';
import { optionalAuth } from '../../utils/jwtAuth.js';

const router = Router();

router.use(optionalAuth);

router.get('/meetings', getMeetings);
router.get('/meetings/all', getAllMeetings);
router.get('/meetings/:id', getMeetingById);
router.post('/meetings', createMeeting);
router.put('/meetings/:id', updateMeeting);
router.delete('/meetings/:id', deleteMeeting);

export default router;
