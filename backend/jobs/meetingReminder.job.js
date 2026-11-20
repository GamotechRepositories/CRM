import cron from 'node-cron';
import CentralMeeting from '../models/centralAdmin/centralAdmin_meeting.js';
import TenantMeeting from '../models/bangarProperties/bangarProperties_meeting.js';
import PushNotification from '../models/Notification.js';
import notificationService from '../services/notification.service.js';
import {
  enqueueNotificationJob,
  JOB_TYPES,
  isQueueEnabled,
} from '../queue/notification.queue.js';
import {
  pauseInProgressTasksForMeetingParticipants,
  resumeTasksPausedByMeetingParticipants,
} from '../utils/meetingTaskInterrupt.js';
import logger from '../utils/logger.js';

const REMINDER_MINUTES = Number(process.env.MEETING_REMINDER_MINUTES || 15);
const REMINDER_WINDOW_MS = 60 * 1000; // 1-minute cron window

/**
 * Find meetings starting in ~15 minutes and enqueue reminder notifications.
 * Skips meetings that already received a reminder (dedup via PushNotification).
 */
async function processMeetingReminders() {
  const now = Date.now();
  const windowStart = new Date(now + (REMINDER_MINUTES * 60 * 1000) - REMINDER_WINDOW_MS / 2);
  const windowEnd = new Date(now + (REMINDER_MINUTES * 60 * 1000) + REMINDER_WINDOW_MS / 2);

  const meetings = await CentralMeeting.find({
    status: { $in: ['scheduled', 'rescheduled'] },
    startAt: { $gte: windowStart, $lte: windowEnd },
    // Only remind for meetings already on the Boss schedule
    $or: [
      { coordinatorApproval: 'approved' },
      { coordinatorApproval: null },
      { coordinatorApproval: { $exists: false } },
    ],
  }).lean();

  if (!meetings.length) return;

  await Promise.all(
    meetings.map(async (meeting) => {
      const meetingId = String(meeting._id);
      const userIds = [meeting.bossId, meeting.organizerId].filter(Boolean);

      const existing = await PushNotification.findOne({
        meetingId,
        type: 'meeting_reminder',
        receiver: { $in: userIds },
        createdAt: { $gte: new Date(now - 24 * 60 * 60 * 1000) },
      }).lean();

      if (existing) return;

      const jobData = { meetingId };

      if (isQueueEnabled()) {
        await enqueueNotificationJob(JOB_TYPES.MEETING_REMINDER, jobData);
      } else {
        await notificationService.sendMeetingReminder(meeting);
      }

      logger.reminderSent({ meetingId, title: meeting.title });
    }),
  );
}

/**
 * Auto-pause ongoing employee tasks when a scheduled meeting starts (startAt <= now < endAt),
 * and auto-resume those meeting-paused tasks when the meeting ends (endAt <= now).
 */
export async function processScheduledMeetingTaskSync() {
  const now = new Date();
  const approvedFilter = {
    $or: [
      { coordinatorApproval: 'approved' },
      { coordinatorApproval: null },
      { coordinatorApproval: { $exists: false } },
    ],
  };

  // 1. Active meetings (startAt <= now < endAt) -> pause participants' in-progress tasks
  const [activeTenantMeetings, activeCentralMeetings] = await Promise.all([
    TenantMeeting.find({
      status: { $in: ['scheduled', 'rescheduled', 'ongoing'] },
      startAt: { $lte: now },
      endAt: { $gt: now },
    }),
    CentralMeeting.find({
      status: { $in: ['scheduled', 'rescheduled', 'ongoing'] },
      startAt: { $lte: now },
      endAt: { $gt: now },
      ...approvedFilter,
    }),
  ]);

  const activeParticipantIds = new Set();

  for (const m of activeTenantMeetings) {
    const ids = [m.organizerId, ...(m.participants || []).map((p) => p.userId)].filter(Boolean);
    ids.forEach((id) => activeParticipantIds.add(String(id)));
    if (m.status !== 'ongoing') {
      m.status = 'ongoing';
      await m.save();
    }
    await pauseInProgressTasksForMeetingParticipants({
      participantIds: ids,
      companyId: m.companyId,
    });
  }

  for (const m of activeCentralMeetings) {
    const ids = [m.organizerId, m.bossId].filter(Boolean);
    ids.forEach((id) => activeParticipantIds.add(String(id)));
    if (m.status !== 'ongoing') {
      m.status = 'ongoing';
      await m.save();
    }
    await pauseInProgressTasksForMeetingParticipants({
      participantIds: ids,
      companyId: m.companyId,
    });
  }

  // 2. Ended meetings (endAt <= now, still marked ongoing/scheduled/rescheduled) -> mark completed & resume tasks
  const [endedTenantMeetings, endedCentralMeetings] = await Promise.all([
    TenantMeeting.find({
      status: { $in: ['ongoing', 'scheduled', 'rescheduled'] },
      endAt: { $lte: now },
    }),
    CentralMeeting.find({
      status: { $in: ['ongoing', 'scheduled', 'rescheduled'] },
      endAt: { $lte: now },
      ...approvedFilter,
    }),
  ]);

  for (const m of endedTenantMeetings) {
    m.status = 'completed';
    await m.save();
    const ids = [m.organizerId, ...(m.participants || []).map((p) => p.userId)]
      .filter(Boolean)
      .filter((id) => !activeParticipantIds.has(String(id)));
    if (ids.length) {
      await resumeTasksPausedByMeetingParticipants({
        participantIds: ids,
        companyId: m.companyId,
      });
    }
  }

  for (const m of endedCentralMeetings) {
    m.status = 'completed';
    await m.save();
    const ids = [m.organizerId, m.bossId]
      .filter(Boolean)
      .filter((id) => !activeParticipantIds.has(String(id)));
    if (ids.length) {
      await resumeTasksPausedByMeetingParticipants({
        participantIds: ids,
        companyId: m.companyId,
      });
    }
  }
}

/**
 * Schedule meeting reminder & task pause/resume cron — runs every minute.
 * @returns {cron.ScheduledTask | null}
 */
export function startMeetingReminderJob() {
  if (process.env.DISABLE_MEETING_REMINDER_CRON === 'true') {
    logger.warn('ReminderCron', 'Meeting reminder cron disabled via env');
    return null;
  }

  const task = cron.schedule('* * * * *', async () => {
    try {
      await processMeetingReminders();
    } catch (error) {
      logger.error('ReminderCron', 'Meeting reminder job failed', { error: error?.message });
    }
    try {
      await processScheduledMeetingTaskSync();
    } catch (error) {
      logger.error('ReminderCron', 'Scheduled meeting task sync failed', { error: error?.message });
    }
  });

  logger.info('ReminderCron', 'Meeting reminder cron started (every minute)');
  return task;
}

export default startMeetingReminderJob;
