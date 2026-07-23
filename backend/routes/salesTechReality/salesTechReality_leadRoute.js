import { Router } from 'express';
import {
  createLead,
  getLeads,
  getLeadById,
  updateLead,
  deleteLead,
  addFollowUp,
  previewDistribution,
  distributeLeads,
} from '../../controllers/salesTechReality/salesTechReality_leadController.js';

const router = Router();

router.get('/leads', getLeads);
router.get('/leads/distribution-preview', previewDistribution);
router.post('/leads/distribute', distributeLeads);
router.post('/leads', createLead);
router.get('/leads/:id', getLeadById);
router.put('/leads/:id', updateLead);
router.delete('/leads/:id', deleteLead);
router.post('/leads/:id/follow-up', addFollowUp);

export default router;
