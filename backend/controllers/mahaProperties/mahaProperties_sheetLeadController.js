import SheetLead from '../../models/mahaProperties/mahaProperties_sheetLead.js';
import Lead from '../../models/mahaProperties/mahaProperties_lead.js';
import Employee from '../../models/mahaProperties/mahaProperties_employee.js';
import { createSheetLeadImportHandlers } from '../../utils/createSheetLeadImportHandlers.js';

export const sheetLeadHandlers = createSheetLeadImportHandlers({
  SheetLead,
  Lead,
  Employee,
  tenantKey: 'mahaProperties',
});
