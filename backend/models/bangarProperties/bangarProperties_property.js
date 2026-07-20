import mongoose from 'mongoose';
import { getPropertySchemaFields } from '../../utils/propertyFields.js';

const propertySchema = new mongoose.Schema(
  getPropertySchemaFields('bangarProperties_Employee'),
  { timestamps: true }
);

propertySchema.index({ title: 'text', locality: 'text', city: 'text', description: 'text' });

const Property = mongoose.model('bangarProperties_Property', propertySchema);
export default Property;
