import mongoose from 'mongoose';
import { buildResumeFromPausedPayload } from './urgentTaskInterrupt.js';
import { emitTaskChanged } from '../services/realtimeNotification.service.js';
import { invalidateTenantCache } from './cache.js';
import SalesTechTask from '../models/salesTechReality/salesTechReality_task.js';
import SalesTechAttendance from '../models/salesTechReality/salesTechReality_attendance.js';
import AdsResearchTask from '../models/adsResearchGlobal/adsResearchGlobal_task.js';
import AdsResearchAttendance from '../models/adsResearchGlobal/adsResearchGlobal_attendance.js';
import BangarTask from '../models/bangarProperties/bangarProperties_task.js';
import BangarAttendance from '../models/bangarProperties/bangarProperties_attendance.js';
import MahaTask from '../models/mahaProperties/mahaProperties_task.js';
import MahaAttendance from '../models/mahaProperties/mahaProperties_attendance.js';

const TENANT_MODELS = {
  salesTechReality: { Task: SalesTechTask, Attendance: SalesTechAttendance },
  adsResearchGlobal: { Task: AdsResearchTask, Attendance: AdsResearchAttendance },
  bangarProperties: { Task: BangarTask, Attendance: BangarAttendance },
  mahaProperties: { Task: MahaTask, Attendance: MahaAttendance },
};

const resolveTenantTargets = (companyId) => {
  const key = String(companyId || '').trim();
  if (key && TENANT_MODELS[key]) {
    return [[key, TENANT_MODELS[key]]];
  }
  return Object.entries(TENANT_MODELS);
};

const uniqueValidObjectIds = (ids = []) => {
  const seen = new Set();
  const out = [];
  for (const raw of ids) {
    const id = String(raw?._id || raw || '').trim();
    if (!id || seen.has(id) || !mongoose.Types.ObjectId.isValid(id)) continue;
    seen.add(id);
    out.push(id);
  }
  return out;
};

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

/**
 * Pause in-progress tasks for all meeting participants across the target tenant (or all tenants if companyId is omitted).
 */
export const pauseInProgressTasksForMeetingParticipants = async ({
  participantIds = [],
  companyId = null,
}) => {
  const validIds = uniqueValidObjectIds(participantIds);
  if (!validIds.length) return [];

  const targets = resolveTenantTargets(companyId);
  const pausedAll = [];
  for (const [companyKey, { Task }] of targets) {
    for (const empId of validIds) {
      const paused = await pauseInProgressTasksForMeeting({
        Task,
        employeeId: empId,
        companyKey,
      });
      if (paused.length) pausedAll.push(...paused);
    }
  }
  return pausedAll;
};

/**
 * Resume meeting-paused tasks for all participants who are not still in an active attendance meeting.
 */
export const resumeTasksPausedByMeetingParticipants = async ({
  participantIds = [],
  companyId = null,
}) => {
  const validIds = uniqueValidObjectIds(participantIds);
  if (!validIds.length) return [];

  const targets = resolveTenantTargets(companyId);
  const resumedAll = [];
  for (const [companyKey, { Task, Attendance }] of targets) {
    for (const empId of validIds) {
      const stillInAttendanceMeeting = await isEmployeeInMeeting({ Attendance, employeeId: empId });
      if (stillInAttendanceMeeting) continue;
      const resumed = await resumeTasksPausedByMeeting({
        Task,
        employeeId: empId,
        companyKey,
      });
      if (resumed.length) resumedAll.push(...resumed);
    }
  }
  return resumedAll;
};
