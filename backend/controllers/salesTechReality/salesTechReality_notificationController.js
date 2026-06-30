import Notification from '../../models/salesTechReality/salesTechReality_notification.js';
import Employee from '../../models/salesTechReality/salesTechReality_employee.js';
import { createNotificationHandlers } from '../../utils/createNotificationHandlers.js';
import { createNotificationService } from '../../utils/notificationService.js';

const notificationService = createNotificationService({ Notification });

export const {
  getNotifications,
  getUnreadCount,
  createNotification,
  markNotificationRead,
  markAllRead,
  deleteNotification,
} = createNotificationHandlers({ Notification, Employee, notificationService });
