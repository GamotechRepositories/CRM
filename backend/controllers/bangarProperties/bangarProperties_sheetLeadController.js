import SheetLead from '../../models/bangarProperties/bangarProperties_sheetLead.js';
import Lead from '../../models/bangarProperties/bangarProperties_lead.js';
import Employee from '../../models/bangarProperties/bangarProperties_employee.js';
import { createSheetLeadImportHandlers } from '../../utils/createSheetLeadImportHandlers.js';

export const sheetLeadHandlers = createSheetLeadImportHandlers({
  SheetLead,
  Lead,
  Employee,
  tenantKey: 'bangarProperties',
});
