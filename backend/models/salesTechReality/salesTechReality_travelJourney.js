import mongoose from 'mongoose';
import { getTravelJourneySchemaFields } from '../../utils/travelJourneyFields.js';

const travelJourneySchema = new mongoose.Schema(
  getTravelJourneySchemaFields({ employeeRef: 'salesTechReality_Employee' }),
  { timestamps: true }
);

travelJourneySchema.index({ employee: 1, date: 1 }, { unique: true });

const TravelJourney = mongoose.model('salesTechReality_TravelJourney', travelJourneySchema);
export default TravelJourney;
