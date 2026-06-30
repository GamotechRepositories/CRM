import mongoose from 'mongoose';
import { getAssetSchemaFields } from '../../utils/assetFields.js';

const assetSchema = new mongoose.Schema(
  getAssetSchemaFields('salesTechReality_Employee'),
  { timestamps: true }
);

const Asset = mongoose.model('salesTechReality_Asset', assetSchema);
export default Asset;
