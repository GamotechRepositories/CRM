import mongoose from 'mongoose';

const followUpSchema = new mongoose.Schema({
  date: { type: Date, default: Date.now },
  comments: { type: String, default: '' },
  /** @deprecated prefer comments — kept for older records */
  text: { type: String },
});

const leadSchema = new mongoose.Schema({
  name: { type: String, required: true },
  businessName: { type: String, required: true },
  contactNumber: { type: String, required: true },
  address: { type: String },
  city: { type: String },
  state: { type: String },
  businessType: { type: String },
  leadSource: { type: String },
  description: { type: String },
  status: {
    type: String,
    enum: [
      'Call not Received',
      'Call You After Sometime',
      'Interested',
      'Not Interested',
      'Meeting Schedule',
    ],
    default: 'Call not Received',
  },
  meetingType: {
    type: String,
    enum: ['Online', 'Offline'],
  },
  meetingPersonName: { type: String },
  meetingTime: { type: Date },
  meetingInfoSent: { type: Boolean, default: false },
  followUps: [followUpSchema],
  generatedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'mahaProperties_Employee',
    required: true,
  },
}, { timestamps: true });

const Lead = mongoose.model('mahaProperties_Lead', leadSchema);
export default Lead;
