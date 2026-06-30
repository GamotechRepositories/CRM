import Asset from '../../models/adsResearchGlobal/adsResearchGlobal_asset.js';
import Employee from '../../models/adsResearchGlobal/adsResearchGlobal_employee.js';
import { createAssetHandlers } from '../../utils/createAssetHandlers.js';

export const {
  getAssets,
  createAsset,
  getAssetById,
  updateAsset,
  deleteAsset,
  assignAsset,
} = createAssetHandlers({ Asset, Employee });
