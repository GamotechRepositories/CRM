import mongoose from 'mongoose';

const clientProfileSchema = new mongoose.Schema({
  client: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'mahaProperties_Client',
    required: true,
    unique: true,
    index: true,
  },
  project: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'mahaProperties_Project',
    default: null,
  },
  // Task metrics
  totalCreatedTasks: {
    type: Number,
    default: 0,
    min: 0,
  },
  totalCompletedTasks: {
    type: Number,
    default: 0,
    min: 0,
  },
  totalPendingTasks: {
    type: Number,
    default: 0,
    min: 0,
  },
  delayedTasks: {
    type: Number,
    default: 0,
    min: 0,
  },
  // Social media calendars linked to this client
  socialMediaCalendars: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'mahaProperties_SocialMediaCalendar',
  }],
  // Billing/invoice metrics
  totalInvoicesGenerated: {
    type: Number,
    default: 0,
    min: 0,
  },
  totalAmountPaid: {
    type: Number,
    default: 0,
    min: 0,
  },
  totalAmountPending: {
    type: Number,
    default: 0,
    min: 0,
  },
  // Project deadline insights
  projectDeadline: {
    type: Date,
    default: null,
  },
  nextProjectDeadline: {
    type: Date,
    default: null,
  },
  lastSyncedAt: {
    type: Date,
    default: null,
  },
}, { timestamps: true });

const ClientProfile = mongoose.model('mahaProperties_ClientProfile', clientProfileSchema);
export default ClientProfile;

