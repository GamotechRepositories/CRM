import mongoose from 'mongoose';

const salarySchema = new mongoose.Schema({
  employee: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'adsResearchGlobal_Employee',
    required: true,
  },
  amount: {
    type: Number,
    required: true,
  },
  month: {
    type: Number,
    required: true,
    min: 1,
    max: 12,
  },
  year: {
    type: Number,
    required: true,
  },
  status: {
    type: String,
    enum: ['Paid', 'Unpaid'],
    default: 'Unpaid',
  },
}, { timestamps: true });

const Salary = mongoose.model('adsResearchGlobal_Salary', salarySchema);
export default Salary;
