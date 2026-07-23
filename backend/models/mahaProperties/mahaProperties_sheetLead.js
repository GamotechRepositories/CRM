import mongoose from 'mongoose';
import { getSheetLeadSchemaFields } from '../../utils/sheetLeadFields.js';

const sheetLeadSchema = new mongoose.Schema(
  getSheetLeadSchemaFields('mahaProperties_Employee', 'mahaProperties_Lead'),
  { timestamps: true }
);

sheetLeadSchema.index(
  { metaLeadId: 1 },
  {
    unique: true,
    partialFilterExpression: { metaLeadId: { $type: 'string', $gt: '' } },
  }
);

const SheetLead = mongoose.model('mahaProperties_SheetLead', sheetLeadSchema);
export default SheetLead;
