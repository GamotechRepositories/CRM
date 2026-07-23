import SheetLead from '../../models/adsResearchGlobal/adsResearchGlobal_sheetLead.js';
import Lead from '../../models/adsResearchGlobal/adsResearchGlobal_lead.js';
import Employee from '../../models/adsResearchGlobal/adsResearchGlobal_employee.js';
import { createSheetLeadImportHandlers } from '../../utils/createSheetLeadImportHandlers.js';

export const sheetLeadHandlers = createSheetLeadImportHandlers({
  SheetLead,
  Lead,
  Employee,
  tenantKey: 'adsResearchGlobal',
});
