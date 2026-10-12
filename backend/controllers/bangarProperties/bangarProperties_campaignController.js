import Lead from '../../models/bangarProperties/bangarProperties_lead.js';
import Employee from '../../models/bangarProperties/bangarProperties_employee.js';
import Campaign from '../../models/bangarProperties/bangarProperties_campaign.js';
import { createCampaignHandlers } from '../../utils/createCampaignHandlers.js';

export const campaignHandlers = createCampaignHandlers({
  Lead,
  Employee,
  Campaign,
  tenantKey: 'bangarProperties',
});
