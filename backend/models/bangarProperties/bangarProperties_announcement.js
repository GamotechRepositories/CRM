import mongoose from 'mongoose';
import { getAnnouncementFields } from '../../utils/announcementFields.js';

const announcementSchema = new mongoose.Schema(
  getAnnouncementFields('bangarProperties'),
  { timestamps: true }
);

const Announcement = mongoose.model('bangarProperties_Announcement', announcementSchema);
export default Announcement;
