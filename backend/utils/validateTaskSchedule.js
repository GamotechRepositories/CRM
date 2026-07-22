import { getBusinessMinutesFromMidnight } from './businessTime.js';
import { parseWorkingHours } from './workingHoursTimeline.js';

export const assertValidTaskSchedule = async ({
  Task,
  Employee,
  Company,
  assigneeId,
  scheduledStartAt,
  scheduledEndAt,
  estimatedDurationMinutes,
  excludeTaskId,
  now = new Date(),
}) => {
  if (!scheduledStartAt) {
    const error = new Error('A scheduled start time is required');
    error.statusCode = 400;
    throw error;
  }

  const start = new Date(scheduledStartAt);
  if (Number.isNaN(start.getTime())) {
    const error = new Error('Invalid scheduled start time');
    error.statusCode = 400;
    throw error;
  }

  if (start.getTime() < now.getTime()) {
    const error = new Error('Cannot schedule a task in the past');
    error.statusCode = 400;
    throw error;
  }

  let end = scheduledEndAt ? new Date(scheduledEndAt) : null;
  if (!end || Number.isNaN(end.getTime())) {
    const duration = Number(estimatedDurationMinutes);
    if (!Number.isFinite(duration) || duration <= 0) {
      const error = new Error('Task duration is required when scheduling a start time');
      error.statusCode = 400;
      throw error;
    }
    end = new Date(start.getTime() + duration * 60000);
  }

  if (end <= start) {
    const error = new Error('Scheduled end time must be after the start time');
    error.statusCode = 400;
    throw error;
  }

  // Company working hours are the canonical timeline; employee workingHours is a legacy fallback.
  const company = Company
    ? await Company.findOne().sort({ createdAt: 1 }).select('workingHours').lean()
    : null;
  let workingHours = String(company?.workingHours || '').trim();
  if (!workingHours) {
    const employee = await Employee.findById(assigneeId).select('workingHours').lean();
    workingHours = employee?.workingHours;
  }
  const { startMinutes: workStart, endMinutes: workEnd } = parseWorkingHours(workingHours);
  const startMinutesOnDay = getBusinessMinutesFromMidnight(start);
  const endMinutesOnDay = getBusinessMinutesFromMidnight(end);

  if (startMinutesOnDay < workStart || endMinutesOnDay > workEnd) {
    const error = new Error('Task must fit within the employee working hours');
    error.statusCode = 400;
    throw error;
  }

  // Overlapping schedules are allowed: an employee can have multiple tasks at the same time.

  return { scheduledStartAt: start, scheduledEndAt: end };
};
