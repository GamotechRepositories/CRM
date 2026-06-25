import mongoose from 'mongoose';

const attendanceSchema = new mongoose.Schema({
  employee: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'adsResearchGlobal_Employee',
    required: true,
  },
  date: {
    type: Date,
    required: true,
  },
  checkIn: {
    type: Date,
  },
  checkInLatitude: { type: Number },
  checkInLongitude: { type: Number },
  checkInAddress: { type: String },
  checkOut: {
    type: Date,
  },
  checkOutLatitude: { type: Number },
  checkOutLongitude: { type: Number },
  checkOutAddress: { type: String },
  durationHours: {
    type: Number,
  },
  status: {
    type: String,
    enum: ['Absent', 'Half Day', 'Full Day', 'In Progress'],
    default: 'Absent',
  },
}, { timestamps: true });

const Attendance = mongoose.model('adsResearchGlobal_Attendance', attendanceSchema);
export default Attendance;
