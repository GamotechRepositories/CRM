import { Router } from 'express';
import { siteVisitHandlers } from '../../controllers/mahaProperties/mahaProperties_siteVisitController.js';

const router = Router();
const {
  createSiteVisit,
  getSiteVisits,
  getSiteVisitById,
  updateSiteVisit,
  deleteSiteVisit,
} = siteVisitHandlers;

router.get('/site-visits', getSiteVisits);
router.post('/site-visits', createSiteVisit);
router.get('/site-visits/:id', getSiteVisitById);
router.put('/site-visits/:id', updateSiteVisit);
router.delete('/site-visits/:id', deleteSiteVisit);

export default router;
