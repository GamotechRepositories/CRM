import mongoose from 'mongoose';

const meetingSchema = new mongoose.Schema(
  {
    title: { type: String, required: true, trim: true },
    /** Team member who created the meeting */
    organizerId: { type: String, required: true, index: true },
    organizerName: { type: String, required: true },
    organizerRole: { type: String, default: '' },
    /** Always the CEO / Boss */
    bossId: { type: String, required: true, index: true },
    bossName: { type: String, required: true },
    /** Which CRM company this meeting belongs to */
    companyId: { type: String, default: '', index: true },
    companyName: { type: String, default: '' },
    agenda: { type: String, default: '' },
    description: { type: String, default: '' },
    priority: {
      type: String,
      enum: ['low', 'medium', 'high', 'critical'],
      default: 'medium',
    },
    status: {
      type: String,
      enum: ['scheduled', 'ongoing', 'completed', 'cancelled', 'rescheduled', 'missed'],
      default: 'scheduled',
    },
    type: {
      type: String,
      enum: [
        'client',
        'internal',
        'sales',
        'interview',
        'training',
        'boardMeeting',
        'reviewMeeting',
        'investorMeeting',
        'hrDiscussion',
        'projectDiscussion',
      ],
      default: 'internal',
    },
    startAt: { type: Date, required: true },
    endAt: { type: Date, required: true },
    meetLink: { type: String, default: '' },
    location: { type: String, default: '' },
    notes: { type: String, default: '' },

    /** Boss RSVP — will attend / not attend */
    bossResponse: {
      type: String,
      enum: ['pending', 'accepted', 'declined'],
      default: 'pending',
    },
    bossResponseNote: { type: String, default: '' },
    bossResponseAt: { type: Date, default: null },

    /** Boss asks team to move the meeting */
    rescheduleRequested: { type: Boolean, default: false },
    reschedulePreferredStartAt: { type: Date, default: null },
    reschedulePreferredEndAt: { type: Date, default: null },
    rescheduleReason: { type: String, default: '' },
    rescheduleRequestedAt: { type: Date, default: null },

    /** Boss flags / message for the scheduling team */
    bossMarkedImportant: { type: Boolean, default: false },
    bossPersonalNote: { type: String, default: '' },

    /**
     * Meeting Coordinator gate — Boss only sees approved meetings.
     * Legacy rows without this field are treated as approved in toApi.
     */
    coordinatorApproval: {
      type: String,
      enum: ['pending', 'approved', 'rejected'],
      default: 'pending',
      index: true,
    },
    approvedById: { type: String, default: '' },
    approvedByName: { type: String, default: '' },
    approvedAt: { type: Date, default: null },
    rejectionReason: { type: String, default: '' },
  },
  { timestamps: true }
);

const CentralMeeting = mongoose.model('CentralAdmin_Meeting', meetingSchema);
export default CentralMeeting;
