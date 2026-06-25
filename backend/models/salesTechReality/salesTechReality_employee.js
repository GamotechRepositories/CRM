import mongoose from "mongoose";
import { getEmployeeProfileFields } from "../../utils/employeeProfileFields.js";

const employeeSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
  },
  email: {
    type: String,
    required: true,
    unique: true,
  },
  password: {
    type: String,
    required: false,
    select: false,
  },
  designation: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'salesTechReality_Designation',
    required: true,
  },
  department: {
    type: String,
    required: true,
  },
  dateOfJoining: {
    type: Date,
    required: true,
  },
  salary: {
    type: Number,
    required: true,
  },
  workingHours: {
    type: String,
    required: true,
  },
  status: {
    type: String,
    enum: ['Active', 'Inactive'],
    default: 'Active',
  },
  ...getEmployeeProfileFields('salesTechReality_Employee'),
}, { timestamps: true });

const Employee = mongoose.model('salesTechReality_Employee', employeeSchema);
export default Employee;
