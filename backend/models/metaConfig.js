import mongoose from 'mongoose';

const metaConfigSchema = new mongoose.Schema(
  {
    tenantKey: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    appId: {
      type: String,
      default: '',
      trim: true,
    },
    adAccountId: {
      type: String,
      default: '',
      trim: true,
    },
    systemUserToken: {
      type: String,
      default: '',
      trim: true,
    },
    apiVersion: {
      type: String,
      default: 'v26.0',
      trim: true,
    },
    pageId: {
      type: String,
      default: '',
      trim: true,
    },
    lastSyncedAt: {
      type: Date,
    },
    lastSyncStatus: {
      type: String,
      enum: ['', 'success', 'failed', 'running'],
      default: '',
    },
    lastSyncMessage: {
      type: String,
      default: '',
    },
    lastSyncStats: {
      campaignsCount: { type: Number, default: 0 },
      leadsFetchedCount: { type: Number, default: 0 },
      newLeadsCount: { type: Number, default: 0 },
      existingLeadsCount: { type: Number, default: 0 },
    },
  },
  { timestamps: true }
);

const MetaConfig = mongoose.model('MetaConfig', metaConfigSchema);
export default MetaConfig;
