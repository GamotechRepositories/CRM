import Lead from '../../models/salesTechReality/salesTechReality_lead.js';
import Employee from '../../models/salesTechReality/salesTechReality_employee.js';
import Campaign from '../../models/salesTechReality/salesTechReality_campaign.js';
import { createCampaignHandlers } from '../../utils/createCampaignHandlers.js';

export const campaignHandlers = createCampaignHandlers({
  Lead,
  Employee,
  Campaign,
  tenantKey: 'salesTechReality',
});
