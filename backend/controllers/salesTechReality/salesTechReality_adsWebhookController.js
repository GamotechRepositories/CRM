import Lead from '../../models/salesTechReality/salesTechReality_lead.js';
import Employee from '../../models/salesTechReality/salesTechReality_employee.js';
import { createAdsWebhookHandlers } from '../../utils/createAdsWebhookHandlers.js';

export const adsWebhookHandlers = createAdsWebhookHandlers({
  Lead,
  Employee,
  tenantKey: 'salesTechReality',
});
