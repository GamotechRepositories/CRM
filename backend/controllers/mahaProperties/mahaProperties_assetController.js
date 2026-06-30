import Asset from '../../models/mahaProperties/mahaProperties_asset.js';
import Employee from '../../models/mahaProperties/mahaProperties_employee.js';
import { createAssetHandlers } from '../../utils/createAssetHandlers.js';

export const {
  getAssets,
  createAsset,
  getAssetById,
  updateAsset,
  deleteAsset,
  assignAsset,
} = createAssetHandlers({ Asset, Employee });
