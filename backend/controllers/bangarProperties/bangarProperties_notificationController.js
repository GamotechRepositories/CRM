import Notification from '../../models/bangarProperties/bangarProperties_notification.js';
import Employee from '../../models/bangarProperties/bangarProperties_employee.js';
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
