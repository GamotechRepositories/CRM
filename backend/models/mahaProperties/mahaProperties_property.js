import mongoose from 'mongoose';
import { getPropertySchemaFields } from '../../utils/propertyFields.js';

const propertySchema = new mongoose.Schema(
  getPropertySchemaFields('mahaProperties_Employee'),
  { timestamps: true }
);

propertySchema.index({ title: 'text', locality: 'text', city: 'text', description: 'text' });

const Property = mongoose.model('mahaProperties_Property', propertySchema);
export default Property;
