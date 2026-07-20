import { Router } from 'express';
import { adsWebhookHandlers } from '../../controllers/mahaProperties/mahaProperties_adsWebhookController.js';

const router = Router();
const {
  verifyMetaWebhook,
  receiveMetaWebhook,
  receiveGoogleAdsWebhook,
  receiveGenericAdsWebhook,
} = adsWebhookHandlers;

router.get('/webhooks/meta', verifyMetaWebhook);
router.post('/webhooks/meta', receiveMetaWebhook);
router.post('/webhooks/google-ads', receiveGoogleAdsWebhook);
router.post('/webhooks/ads', receiveGenericAdsWebhook);

export default router;
