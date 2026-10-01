import mongoose from 'mongoose';
import { getHolidayFields } from '../../utils/holidayFields.js';

const holidaySchema = new mongoose.Schema(
  getHolidayFields('salesTechReality'),
  { timestamps: true }
);

const Holiday = mongoose.model('salesTechReality_Holiday', holidaySchema);
export default Holiday;
