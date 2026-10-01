import mongoose from 'mongoose';
import { getHolidayFields } from '../../utils/holidayFields.js';

const holidaySchema = new mongoose.Schema(
  getHolidayFields('mahaProperties'),
  { timestamps: true }
);

const Holiday = mongoose.model('mahaProperties_Holiday', holidaySchema);
export default Holiday;
