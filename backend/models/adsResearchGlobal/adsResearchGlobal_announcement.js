import mongoose from 'mongoose';
import { getAnnouncementFields } from '../../utils/announcementFields.js';

const announcementSchema = new mongoose.Schema(
  getAnnouncementFields('adsResearchGlobal'),
  { timestamps: true }
);

const Announcement = mongoose.model('adsResearchGlobal_Announcement', announcementSchema);
export default Announcement;
