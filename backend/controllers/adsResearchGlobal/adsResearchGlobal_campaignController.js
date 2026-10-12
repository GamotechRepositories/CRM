import Lead from '../../models/adsResearchGlobal/adsResearchGlobal_lead.js';
import Employee from '../../models/adsResearchGlobal/adsResearchGlobal_employee.js';
import Campaign from '../../models/adsResearchGlobal/adsResearchGlobal_campaign.js';
import { createCampaignHandlers } from '../../utils/createCampaignHandlers.js';

export const campaignHandlers = createCampaignHandlers({
  Lead,
  Employee,
  Campaign,
  tenantKey: 'adsResearchGlobal',
});
