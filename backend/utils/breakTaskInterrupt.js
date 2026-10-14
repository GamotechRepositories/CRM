import { buildResumeFromPausedPayload } from './urgentTaskInterrupt.js';
import { emitTaskChanged } from '../services/realtimeNotification.service.js';
import { invalidateTenantCache } from './cache.js';

/**
 * Checks if the employee is currently on an active break.
 */
export const isEmployeeOnBreak = async ({ Attendance, employeeId }) => {
  if (!Attendance || !employeeId) return false;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const tomorrow = new Date(today.getTime() + 24 * 60 * 60 * 1000);
  const att = await Attendance.findOne({
    employee: employeeId,
    date: { $gte: today, $lt: tomorrow },
    breakStartedAt: { $ne: null },
    checkOut: null,
  });
  return Boolean(att);
};

/**
 * Freeze in-progress tasks for an employee when a break starts.
 */
export const pauseInProgressTasksForBreak = async ({
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
    task.pausedByBreak = true;
    await task.save();
    paused.push(task);

    emitTaskChanged(employeeId, {
      reason: 'break_started_pause',
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
 * Auto-resume tasks that were paused by an ongoing break when that break ends.
 */
export const resumeTasksPausedByBreak = async ({
  Task,
  employeeId,
  companyKey = null,
}) => {
  if (!employeeId || !Task) return [];

  const pausedTasks = await Task.find({
    assignedTo: employeeId,
    status: 'Paused',
    pausedByBreak: true,
    isRecurringTemplate: { $ne: true },
  }).sort({ pausedAt: -1, updatedAt: -1 });

  if (!pausedTasks.length) return [];

  const now = new Date();
  const resumed = [];
  for (const task of pausedTasks) {
    const resumePayload = buildResumeFromPausedPayload(task, now);
    Object.assign(task, resumePayload);
    task.pausedByBreak = false;
    await task.save();
    resumed.push(task);

    emitTaskChanged(employeeId, {
      reason: 'break_ended_resume',
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
