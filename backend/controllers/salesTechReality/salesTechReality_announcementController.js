import Announcement from '../../models/salesTechReality/salesTechReality_announcement.js';
import Employee from '../../models/salesTechReality/salesTechReality_employee.js';
import Notification from '../../models/salesTechReality/salesTechReality_notification.js';
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
