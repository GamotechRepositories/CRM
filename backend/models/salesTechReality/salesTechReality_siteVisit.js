import mongoose from 'mongoose';
import { getSiteVisitSchemaFields } from '../../utils/siteVisitFields.js';

const siteVisitSchema = new mongoose.Schema(
  getSiteVisitSchemaFields({
    employeeRef: 'salesTechReality_Employee',
    propertyRef: 'salesTechReality_Property',
    leadRef: 'salesTechReality_Lead',
  }),
  { timestamps: true }
);

const SiteVisit = mongoose.model('salesTechReality_SiteVisit', siteVisitSchema);
export default SiteVisit;
