import mongoose from 'mongoose';

/**
 * Per-employee travel journey (multiple allowed per business day).
 * Distance is calculated after the coordinator starts each journey.
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
  /** What route is used (e.g. "Via Western Express Hwy, SV Road"). */
  routeUsed: { type: String, default: '' },
  routeSummary: { type: String, default: '' },
  roadNames: [{ type: String }],
  totalDistanceKm: { type: Number, default: 0 },
  /** Driving route geometry points along actual streets. */
  routeCoordinates: [
    {
      latitude: { type: Number },
      longitude: { type: Number },
    },
  ],
  /** GPS breadcrumbs recorded while journey is active (actual path travelled). */
  trackPoints: [
    {
      latitude: { type: Number, required: true },
      longitude: { type: Number, required: true },
      recordedAt: { type: Date, default: Date.now },
      source: {
        type: String,
        enum: ['track', 'journey_start', 'check_in', 'check_out', 'journey_end'],
        default: 'track',
      },
      siteVisitId: { type: mongoose.Schema.Types.ObjectId, default: null },
      address: { type: String, default: '' },
    },
  ],
  /**
   * Main stops / timeline milestones for the journey (Google Maps Timeline style).
   * Includes journey_start, visits/stops with arrival, stay duration, departure, and journey_end.
   */
  stops: [
    {
      stopNumber: { type: Number, default: 1 },
      type: {
        type: String,
        enum: ['journey_start', 'site_visit', 'check_in', 'check_out', 'stop', 'journey_end'],
        default: 'stop',
      },
      name: { type: String, default: '' },
      siteVisitId: { type: mongoose.Schema.Types.ObjectId, default: null },
      propertyId: { type: mongoose.Schema.Types.ObjectId, default: null },
      propertyTitle: { type: String, default: '' },
      visitorName: { type: String, default: '' },
      address: { type: String, default: '' },
      city: { type: String, default: '' },
      latitude: { type: Number, default: null },
      longitude: { type: Number, default: null },
      arrivalTime: { type: Date, default: null },
      departureTime: { type: Date, default: null },
      durationMinutes: { type: Number, default: 0 },
      distanceFromPrevKm: { type: Number, default: 0 },
      routeUsed: { type: String, default: '' },
      roadNames: [{ type: String }],
      status: { type: String, default: 'scheduled' },
      notes: { type: String, default: '' },
      recordedAt: { type: Date, default: Date.now },
    },
  ],
});
