import mongoose from 'mongoose';
import { getNotificationSchemaFields } from '../../utils/notificationFields.js';

const notificationSchema = new mongoose.Schema(
  getNotificationSchemaFields('mahaProperties_Employee'),
  { timestamps: true }
);

notificationSchema.index({ recipient: 1, read: 1, createdAt: -1 });

const Notification = mongoose.model('mahaProperties_Notification', notificationSchema);
export default Notification;
