import mongoose from 'mongoose';
import { getAnnouncementFields } from '../../utils/announcementFields.js';

const announcementSchema = new mongoose.Schema(
  getAnnouncementFields('mahaProperties'),
  { timestamps: true }
);

const Announcement = mongoose.model('mahaProperties_Announcement', announcementSchema);
export default Announcement;
