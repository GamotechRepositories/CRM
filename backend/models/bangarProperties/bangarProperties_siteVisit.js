import mongoose from 'mongoose';
import { getSiteVisitSchemaFields } from '../../utils/siteVisitFields.js';

const siteVisitSchema = new mongoose.Schema(
  getSiteVisitSchemaFields({
    employeeRef: 'bangarProperties_Employee',
    propertyRef: 'bangarProperties_Property',
    leadRef: 'bangarProperties_Lead',
  }),
  { timestamps: true }
);

const SiteVisit = mongoose.model('bangarProperties_SiteVisit', siteVisitSchema);
export default SiteVisit;
