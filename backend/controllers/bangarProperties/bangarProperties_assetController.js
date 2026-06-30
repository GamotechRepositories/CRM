import Asset from '../../models/bangarProperties/bangarProperties_asset.js';
import Employee from '../../models/bangarProperties/bangarProperties_employee.js';
import { createAssetHandlers } from '../../utils/createAssetHandlers.js';

export const {
  getAssets,
  createAsset,
  getAssetById,
  updateAsset,
  deleteAsset,
  assignAsset,
} = createAssetHandlers({ Asset, Employee });
