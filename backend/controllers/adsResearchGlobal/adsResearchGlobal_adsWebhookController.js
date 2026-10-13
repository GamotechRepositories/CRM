import Lead from '../../models/adsResearchGlobal/adsResearchGlobal_lead.js';
import Employee from '../../models/adsResearchGlobal/adsResearchGlobal_employee.js';
import { createAdsWebhookHandlers } from '../../utils/createAdsWebhookHandlers.js';

export const adsWebhookHandlers = createAdsWebhookHandlers({
  Lead,
  Employee,
  tenantKey: 'adsResearchGlobal',
});
