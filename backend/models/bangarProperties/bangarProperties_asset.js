import mongoose from 'mongoose';
import { getAssetSchemaFields } from '../../utils/assetFields.js';

const assetSchema = new mongoose.Schema(
  getAssetSchemaFields('bangarProperties_Employee'),
  { timestamps: true }
);

const Asset = mongoose.model('bangarProperties_Asset', assetSchema);
export default Asset;
