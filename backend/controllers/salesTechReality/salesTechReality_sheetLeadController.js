import SheetLead from '../../models/salesTechReality/salesTechReality_sheetLead.js';
import Lead from '../../models/salesTechReality/salesTechReality_lead.js';
import Employee from '../../models/salesTechReality/salesTechReality_employee.js';
import { createSheetLeadImportHandlers } from '../../utils/createSheetLeadImportHandlers.js';

export const sheetLeadHandlers = createSheetLeadImportHandlers({
  SheetLead,
  Lead,
  Employee,
  tenantKey: 'salesTechReality',
});
