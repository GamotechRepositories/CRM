import mongoose from 'mongoose';

const travelConfigSchema = new mongoose.Schema(
  {
    tenantKey: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      index: true,
    },
    ratePerKm: {
      type: Number,
      required: true,
      min: 0.1,
    },
  },
  { timestamps: true }
);

const TravelConfig =
  mongoose.models.TravelConfig || mongoose.model('TravelConfig', travelConfigSchema);

export default TravelConfig;
