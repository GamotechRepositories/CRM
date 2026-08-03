import { Router } from 'express';
import { siteVisitHandlers } from '../../controllers/salesTechReality/salesTechReality_siteVisitController.js';

const router = Router();
const {
  createSiteVisit,
  getSiteVisits,
  getSiteVisitById,
  updateSiteVisit,
  deleteSiteVisit,
  checkInSiteVisit,
  checkOutSiteVisit,
  startTravelJourney,
  endTravelJourney,
  getTravelTimeline,
  allocateTravelExpense,
} = siteVisitHandlers;

router.get('/site-visits', getSiteVisits);
router.post('/site-visits', createSiteVisit);
router.get('/site-visits/travel-timeline', getTravelTimeline);
router.post('/site-visits/start-journey', startTravelJourney);
router.post('/site-visits/end-journey', endTravelJourney);
router.post('/site-visits/allocate-travel-expense', allocateTravelExpense);
router.get('/site-visits/:id', getSiteVisitById);
router.put('/site-visits/:id', updateSiteVisit);
router.delete('/site-visits/:id', deleteSiteVisit);
router.post('/site-visits/:id/check-in', checkInSiteVisit);
router.post('/site-visits/:id/check-out', checkOutSiteVisit);

export default router;
