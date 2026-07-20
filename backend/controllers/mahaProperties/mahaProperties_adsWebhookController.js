import Lead from '../../models/mahaProperties/mahaProperties_lead.js';
import Employee from '../../models/mahaProperties/mahaProperties_employee.js';
import { createAdsWebhookHandlers } from '../../utils/createAdsWebhookHandlers.js';

export const adsWebhookHandlers = createAdsWebhookHandlers({
  Lead,
  Employee,
  tenantKey: 'mahaProperties',
});
