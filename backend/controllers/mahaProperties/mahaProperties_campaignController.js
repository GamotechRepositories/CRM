import Lead from '../../models/mahaProperties/mahaProperties_lead.js';
import Employee from '../../models/mahaProperties/mahaProperties_employee.js';
import Campaign from '../../models/mahaProperties/mahaProperties_campaign.js';
import { createCampaignHandlers } from '../../utils/createCampaignHandlers.js';

export const campaignHandlers = createCampaignHandlers({
  Lead,
  Employee,
  Campaign,
  tenantKey: 'mahaProperties',
});
