import { Router } from 'express';
import { campaignHandlers } from '../../controllers/salesTechReality/salesTechReality_campaignController.js';

const router = Router();

router.get('/campaigns', campaignHandlers.getCampaigns);
router.get('/campaigns/meta/config', campaignHandlers.getMetaConfig);
router.post('/campaigns/meta/config', campaignHandlers.saveMetaConfig);
router.post('/campaigns/meta/test', campaignHandlers.testMetaConnection);
router.post('/campaigns/meta/sync', campaignHandlers.syncMetaCampaignsAndLeads);
router.get('/campaigns/:campaignId', campaignHandlers.getCampaignById);
router.get('/campaigns/:campaignId/leads', campaignHandlers.getCampaignLeads);

export default router;
