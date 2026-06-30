import mongoose from 'mongoose';
import { getAssetSchemaFields } from '../../utils/assetFields.js';

const assetSchema = new mongoose.Schema(
  getAssetSchemaFields('adsResearchGlobal_Employee'),
  { timestamps: true }
);

const Asset = mongoose.model('adsResearchGlobal_Asset', assetSchema);
export default Asset;
