import mongoose from 'mongoose';
import { getSiteVisitSchemaFields } from '../../utils/siteVisitFields.js';

const siteVisitSchema = new mongoose.Schema(
  getSiteVisitSchemaFields({
    employeeRef: 'mahaProperties_Employee',
    propertyRef: 'mahaProperties_Property',
    leadRef: 'mahaProperties_Lead',
  }),
  { timestamps: true }
);

const SiteVisit = mongoose.model('mahaProperties_SiteVisit', siteVisitSchema);
export default SiteVisit;
