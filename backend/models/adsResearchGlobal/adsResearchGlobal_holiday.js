import mongoose from 'mongoose';
import { getHolidayFields } from '../../utils/holidayFields.js';

const holidaySchema = new mongoose.Schema(
  getHolidayFields('adsResearchGlobal'),
  { timestamps: true }
);

const Holiday = mongoose.model('adsResearchGlobal_Holiday', holidaySchema);
export default Holiday;
