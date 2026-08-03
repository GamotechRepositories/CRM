import mongoose from 'mongoose';

/**
 * Per-employee daily travel journey.
 * Distance is only calculated after the coordinator starts a journey.
 */
export const getTravelJourneySchemaFields = ({ employeeRef }) => ({
  employee: {
    type: mongoose.Schema.Types.ObjectId,
    ref: employeeRef,
    required: true,
    index: true,
  },
  /** Business-day start used as the day key. */
  date: {
    type: Date,
    required: true,
    index: true,
  },
  status: {
    type: String,
    enum: ['active', 'ended'],
    default: 'active',
  },
  startedAt: { type: Date, default: null },
  startLatitude: { type: Number, default: null },
  startLongitude: { type: Number, default: null },
  startAddress: { type: String, default: '' },
  endedAt: { type: Date, default: null },
  endLatitude: { type: Number, default: null },
  endLongitude: { type: Number, default: null },
  endAddress: { type: String, default: '' },
});
