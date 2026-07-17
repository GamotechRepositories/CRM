import mongoose from 'mongoose';

const participantSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true },
    name: { type: String, required: true },
    response: {
      type: String,
      enum: ['pending', 'accepted', 'declined'],
      default: 'pending',
    },
  },
  { _id: false }
);

const meetingSchema = new mongoose.Schema(
  {
    companyId: { type: String, default: 'bangarProperties', index: true },
    title: { type: String, required: true, trim: true },
    organizerId: { type: String, required: true },
    organizerName: { type: String, required: true },
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
    participants: { type: [participantSchema], default: [] },
    startAt: { type: Date, required: true },
    endAt: { type: Date, required: true },
    meetLink: { type: String, default: '' },
    location: { type: String, default: '' },
    reminderMinutes: { type: Number, default: 15 },
    attachments: { type: [String], default: [] },
    notes: { type: String, default: '' },
    actionItems: { type: [String], default: [] },
    teamLeadId: { type: String, default: null },
    isTeamMeeting: { type: Boolean, default: false },
  },
  { timestamps: true }
);

const Meeting = mongoose.model('bangarProperties_Meeting', meetingSchema);
export default Meeting;
