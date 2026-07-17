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
  },
  { timestamps: true }
);

const CentralMeeting = mongoose.model('CentralAdmin_Meeting', meetingSchema);
export default CentralMeeting;
