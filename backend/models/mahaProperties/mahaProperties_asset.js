import mongoose from 'mongoose';
import { getAssetSchemaFields } from '../../utils/assetFields.js';

const assetSchema = new mongoose.Schema(
  getAssetSchemaFields('mahaProperties_Employee'),
  { timestamps: true }
);

const Asset = mongoose.model('mahaProperties_Asset', assetSchema);
export default Asset;
