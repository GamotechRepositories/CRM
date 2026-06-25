import mongoose from 'mongoose';

const leaveSchema = new mongoose.Schema({
  employee: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'mahaProperties_Employee',
    required: true,
  },
  leaveType: {
    type: String,
    enum: ['Sick', 'Casual', 'Annual', 'Unpaid', 'Other'],
    required: true,
  },
  startDate: {
    type: Date,
    required: true,
  },
  endDate: {
    type: Date,
    required: true,
  },
  reason: {
    type: String,
    default: '',
  },
  status: {
    type: String,
    enum: ['Pending', 'Approved', 'Rejected'],
    default: 'Pending',
  },
  approvedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'mahaProperties_Employee',
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
  numberOfDays: {
    type: Number,
    default: null,
  },
}, { timestamps: true });

const Leave = mongoose.model('mahaProperties_Leave', leaveSchema);
export default Leave;
