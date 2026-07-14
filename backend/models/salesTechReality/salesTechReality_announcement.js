import mongoose from 'mongoose';
import { getAnnouncementFields } from '../../utils/announcementFields.js';

const announcementSchema = new mongoose.Schema(
  getAnnouncementFields('salesTechReality'),
  { timestamps: true }
);

const Announcement = mongoose.model('salesTechReality_Announcement', announcementSchema);
export default Announcement;
