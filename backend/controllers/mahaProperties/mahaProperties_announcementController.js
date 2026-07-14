import Announcement from '../../models/mahaProperties/mahaProperties_announcement.js';
import Employee from '../../models/mahaProperties/mahaProperties_employee.js';
import Notification from '../../models/mahaProperties/mahaProperties_notification.js';
import { createNotificationService } from '../../utils/notificationService.js';
import { createAnnouncementHandlers } from '../../utils/createAnnouncementHandlers.js';

const notificationService = createNotificationService({ Notification });

export const {
  getAnnouncements,
  createAnnouncement,
  getAnnouncementById,
  updateAnnouncement,
  deleteAnnouncement,
} = createAnnouncementHandlers({ Announcement, Employee, notificationService });
