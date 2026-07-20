import mongoose from 'mongoose';

export const SITE_VISIT_STATUSES = [
  'Scheduled',
  'Confirmed',
  'Completed',
  'Cancelled',
  'No Show',
  'Rescheduled',
];

export const SITE_VISIT_TYPES = [
  'First Visit',
  'Follow-up',
  'Inspection',
  'Negotiation',
  'Handover',
  'Other',
];

export const getSiteVisitSchemaFields = ({ employeeRef, propertyRef, leadRef }) => ({
  property: {
    type: mongoose.Schema.Types.ObjectId,
    ref: propertyRef,
    default: null,
    index: true,
  },
  lead: {
    type: mongoose.Schema.Types.ObjectId,
    ref: leadRef,
    default: null,
  },
  visitorName: {
    type: String,
    required: true,
    trim: true,
  },
  visitorPhone: {
    type: String,
    default: '',
    trim: true,
  },
  visitorEmail: {
    type: String,
    default: '',
    trim: true,
  },
  visitType: {
    type: String,
    enum: SITE_VISIT_TYPES,
    default: 'First Visit',
  },
  status: {
    type: String,
    enum: SITE_VISIT_STATUSES,
    default: 'Scheduled',
    index: true,
  },
  scheduledAt: {
    type: Date,
    required: true,
    index: true,
  },
  durationMinutes: {
    type: Number,
    default: 60,
    min: 15,
  },
  assignedTo: {
    type: mongoose.Schema.Types.ObjectId,
    ref: employeeRef,
    default: null,
    index: true,
  },
  meetingPoint: {
    type: String,
    default: '',
    trim: true,
  },
  address: {
    type: String,
    default: '',
    trim: true,
  },
  city: {
    type: String,
    default: '',
    trim: true,
  },
  notes: {
    type: String,
    default: '',
  },
  outcome: {
    type: String,
    default: '',
  },
  interested: {
    type: Boolean,
    default: null,
  },
  feedback: {
    type: String,
    default: '',
  },
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: employeeRef,
    default: null,
  },
});
