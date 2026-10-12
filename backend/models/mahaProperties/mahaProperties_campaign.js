import mongoose from 'mongoose';
import { campaignSchemaDefinition } from '../../utils/campaignSchemaDefinition.js';

const campaignSchema = new mongoose.Schema(campaignSchemaDefinition, { timestamps: true });
campaignSchema.index({ campaignId: 1 }, { unique: true });

const Campaign = mongoose.model('mahaProperties_Campaign', campaignSchema);
export default Campaign;
