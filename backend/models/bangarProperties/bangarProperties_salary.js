import mongoose from 'mongoose';

const salarySchema = new mongoose.Schema({
  employee: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'bangarProperties_Employee',
    required: true,
  },
  amount: {
    type: Number,
    required: true,
  },
  basicSalary: {
    type: Number,
    default: 0,
  },
  hra: {
    type: Number,
    default: 0,
  },
  allowances: {
    type: Number,
    default: 0,
  },
  deductions: {
    type: Number,
    default: 0,
  },
  bonus: {
    type: Number,
    default: 0,
  },
  netSalary: {
    type: Number,
    default: 0,
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
  paymentDate: {
    type: Date,
  },
  paymentMode: {
    type: String,
    default: 'Bank Transfer',
  },
  status: {
    type: String,
    enum: ['Paid', 'Unpaid'],
    default: 'Unpaid',
  },
}, { timestamps: true });

const Salary = mongoose.model('bangarProperties_Salary', salarySchema);
export default Salary;
