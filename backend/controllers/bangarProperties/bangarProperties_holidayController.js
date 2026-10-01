import Holiday from '../../models/bangarProperties/bangarProperties_holiday.js';
import Employee from '../../models/bangarProperties/bangarProperties_employee.js';
import Notification from '../../models/bangarProperties/bangarProperties_notification.js';
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
} = createHolidayHandlers({ Holiday, Employee, notificationService, tenantId: 'bangarProperties' });
