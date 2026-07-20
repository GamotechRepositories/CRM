import Lead from '../../models/bangarProperties/bangarProperties_lead.js';
import Employee from '../../models/bangarProperties/bangarProperties_employee.js';
import { createAdsWebhookHandlers } from '../../utils/createAdsWebhookHandlers.js';

export const adsWebhookHandlers = createAdsWebhookHandlers({
  Lead,
  Employee,
  tenantKey: 'bangarProperties',
});
