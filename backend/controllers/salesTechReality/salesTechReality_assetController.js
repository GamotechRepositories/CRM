import Asset from '../../models/salesTechReality/salesTechReality_asset.js';
import Employee from '../../models/salesTechReality/salesTechReality_employee.js';
import { createAssetHandlers } from '../../utils/createAssetHandlers.js';

export const {
  getAssets,
  createAsset,
  getAssetById,
  updateAsset,
  deleteAsset,
  assignAsset,
} = createAssetHandlers({ Asset, Employee });
