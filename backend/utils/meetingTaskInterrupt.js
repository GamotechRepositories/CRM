import { buildResumeFromPausedPayload } from './urgentTaskInterrupt.js';
import { emitTaskChanged } from '../services/realtimeNotification.service.js';
import { invalidateTenantCache } from './cache.js';

/**
 * Checks if the employee is currently in an active meeting.
 */
export const isEmployeeInMeeting = async ({ Attendance, employeeId }) => {
  if (!Attendance || !employeeId) return false;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const tomorrow = new Date(today.getTime() + 24 * 60 * 60 * 1000);
  const att = await Attendance.findOne({
    employee: employeeId,
    date: { $gte: today, $lt: tomorrow },
    meetingStartedAt: { $ne: null },
    checkOut: null,
  });
  return Boolean(att);
};

/**
 * Freeze in-progress tasks for an employee when a meeting starts.
 */
export const pauseInProgressTasksForMeeting = async ({
  Task,
  employeeId,
  companyKey = null,
}) => {
  if (!employeeId || !Task) return [];

  const openTasks = await Task.find({
    assignedTo: employeeId,
    status: 'In Progress',
    isRecurringTemplate: { $ne: true },
  });

  if (!openTasks.length) return [];

  const now = new Date();
  const paused = [];
  for (const task of openTasks) {
    task.status = 'Paused';
    task.pausedAt = now;
    task.pausedByMeeting = true;
    await task.save();
    paused.push(task);

    emitTaskChanged(employeeId, {
      reason: 'meeting_started_pause',
      taskId: task._id,
      status: 'Paused',
      previousStatus: 'In Progress',
      title: task.title,
    });
  }

  if (companyKey) {
    invalidateTenantCache(companyKey);
  }

  return paused;
};

/**
 * Auto-resume tasks that were paused by an ongoing meeting when that meeting ends.
 */
export const resumeTasksPausedByMeeting = async ({
  Task,
  employeeId,
  companyKey = null,
}) => {
  if (!employeeId || !Task) return [];

  const pausedTasks = await Task.find({
    assignedTo: employeeId,
    status: 'Paused',
    pausedByMeeting: true,
    isRecurringTemplate: { $ne: true },
  }).sort({ pausedAt: -1, updatedAt: -1 });

  if (!pausedTasks.length) return [];

  const now = new Date();
  const resumed = [];
  for (const task of pausedTasks) {
    const resumePayload = buildResumeFromPausedPayload(task, now);
    Object.assign(task, resumePayload);
    task.pausedByMeeting = false;
    await task.save();
    resumed.push(task);

    emitTaskChanged(employeeId, {
      reason: 'meeting_ended_resume',
      taskId: task._id,
      status: 'In Progress',
      previousStatus: 'Paused',
      title: task.title,
    });
  }

  if (companyKey) {
    invalidateTenantCache(companyKey);
  }

  return resumed;
};
