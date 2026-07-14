import Announcement from '../../models/adsResearchGlobal/adsResearchGlobal_announcement.js';
import Employee from '../../models/adsResearchGlobal/adsResearchGlobal_employee.js';
import Notification from '../../models/adsResearchGlobal/adsResearchGlobal_notification.js';
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
