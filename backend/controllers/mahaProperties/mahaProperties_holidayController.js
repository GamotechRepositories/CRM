import Holiday from '../../models/mahaProperties/mahaProperties_holiday.js';
import Employee from '../../models/mahaProperties/mahaProperties_employee.js';
import Notification from '../../models/mahaProperties/mahaProperties_notification.js';
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
} = createHolidayHandlers({ Holiday, Employee, notificationService, tenantId: 'mahaProperties' });
