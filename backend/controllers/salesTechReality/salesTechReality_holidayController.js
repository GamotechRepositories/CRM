import Holiday from '../../models/salesTechReality/salesTechReality_holiday.js';
import Employee from '../../models/salesTechReality/salesTechReality_employee.js';
import Notification from '../../models/salesTechReality/salesTechReality_notification.js';
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
} = createHolidayHandlers({ Holiday, Employee, notificationService, tenantId: 'salesTechReality' });
