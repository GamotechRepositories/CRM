import mongoose from 'mongoose';

export const campaignSchemaDefinition = {
  campaignId: { type: String, required: true, index: true },
  name: { type: String, required: true },
  status: { type: String, default: 'ACTIVE' },
  objective: { type: String, default: '' },
  adAccountId: { type: String, default: '' },
  dailyBudget: { type: Number, default: 0 },
  lifetimeBudget: { type: Number, default: 0 },
  budgetRemaining: { type: Number, default: 0 },
  spend: { type: Number, default: 0 },
  impressions: { type: Number, default: 0 },
  clicks: { type: Number, default: 0 },
  reach: { type: Number, default: 0 },
  leadsCount: { type: Number, default: 0 },
  startTime: { type: Date },
  stopTime: { type: Date },
  lastSyncedAt: { type: Date, default: Date.now },
  metaRaw: { type: mongoose.Schema.Types.Mixed },
};
