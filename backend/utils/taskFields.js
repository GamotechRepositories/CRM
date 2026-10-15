import mongoose from 'mongoose';

/** Duration and performance rating fields shared across company task models. */
export const getTaskDurationAndRatingFields = (employeeRef) => ({
  estimatedDurationMinutes: {
    type: Number,
    min: 1,
    default: null,
  },
  startedAt: {
    type: Date,
    default: null,
  },
  /** When status is Paused, freezes the active timer at this instant. */
  pausedAt: {
    type: Date,
    default: null,
  },
  /** Urgent task that caused this pause (auto-resume when that task completes). */
  pausedByUrgentTask: {
    type: mongoose.Schema.Types.ObjectId,
    default: null,
  },
  /** True when task is temporarily paused due to an ongoing meeting. Auto-resumes on meeting end. */
  pausedByMeeting: {
    type: Boolean,
    default: false,
  },
  /** True when task is temporarily paused due to an active break. Auto-resumes on break end. */
  pausedByBreak: {
    type: Boolean,
    default: false,
  },
  scheduledStartAt: {
    type: Date,
    default: null,
  },
  scheduledEndAt: {
    type: Date,
    default: null,
  },
  approvalStatus: {
    type: String,
    enum: ['None', 'Pending', 'Approved', 'Rejected'],
    default: 'None',
  },
  approvedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: employeeRef,
    default: null,
  },
  approvedAt: {
    type: Date,
    default: null,
  },
  rejectionReason: {
    type: String,
    default: '',
  },
  rating: {
    score: { type: Number, min: 1, max: 5, default: null },
    title: { type: String, default: '' },
    encouragement: { type: String, default: '' },
    comments: { type: String, default: '' },
    ratedBy: { type: mongoose.Schema.Types.ObjectId, ref: employeeRef, default: null },
    ratedAt: { type: Date, default: null },
    /** true when score was set by completion-time automation */
    auto: { type: Boolean, default: false },
  },
});
