import mongoose from 'mongoose';
import { getNotificationSchemaFields } from '../../utils/notificationFields.js';

const notificationSchema = new mongoose.Schema(
  getNotificationSchemaFields('salesTechReality_Employee'),
  { timestamps: true }
);

notificationSchema.index({ recipient: 1, read: 1, createdAt: -1 });

const Notification = mongoose.model('salesTechReality_Notification', notificationSchema);
export default Notification;
