import Holiday from '../../models/adsResearchGlobal/adsResearchGlobal_holiday.js';
import Employee from '../../models/adsResearchGlobal/adsResearchGlobal_employee.js';
import Notification from '../../models/adsResearchGlobal/adsResearchGlobal_notification.js';
import { createNotificationService } from '../../utils/notificationService.js';
import { createHolidayHandlers } from '../../utils/createHolidayHandlers.js';

const notificationService = createNotificationService({ Notification });

export const {
  getHolidays,
  createHoliday,
  getHolidayById,
  updateHoliday,
  deleteHoliday,
  seedDefaultHolidays,
} = createHolidayHandlers({ Holiday, Employee, notificationService, tenantId: 'adsResearchGlobal' });
