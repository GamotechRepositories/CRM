import mongoose from 'mongoose';
import { getHolidayFields } from '../../utils/holidayFields.js';

const holidaySchema = new mongoose.Schema(
  getHolidayFields('bangarProperties'),
  { timestamps: true }
);

const Holiday = mongoose.model('bangarProperties_Holiday', holidaySchema);
export default Holiday;
