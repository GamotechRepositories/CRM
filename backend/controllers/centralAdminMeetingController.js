import CentralMeeting from '../models/centralAdmin/centralAdmin_meeting.js';
import CentralAdminUser, { CENTRAL_ROOT_ROLE } from '../models/centralAdmin/centralAdmin_user.js';
import {
  notifyMeetingAssigned,
  notifyMeetingPendingApproval,
  notifyMeetingUpdated,
  notifyMeetingCancelled,
  notifyMeetingBossResponse,
} from './notification.controller.js';
import { emitMeetingChange } from '../services/realtimeNotification.service.js';

const isBossAuth = (auth) =>
  Boolean(auth?.isRoot) || String(auth?.role || '').toUpperCase() === 'CEO';

const isCoordinatorAuth = (auth) =>
  String(auth?.role || '').trim() === 'Meeting Coordinator';

const toApi = (doc) => {
  const obj = doc.toObject ? doc.toObject() : doc;
  const bossResponse = obj.bossResponse || 'pending';
  // Legacy meetings (no field) stay visible to Boss.
  const approval =
    obj.coordinatorApproval == null ? 'approved' : obj.coordinatorApproval;

  return {
    id: String(obj._id),
    title: obj.title,
    organizerId: obj.organizerId,
    organizerName: obj.organizerName,
    organizerRole: obj.organizerRole || '',
    bossId: obj.bossId,
    bossName: obj.bossName,
    companyId: obj.companyId || '',
    companyName: obj.companyName || '',
    agenda: obj.agenda || '',
    description: obj.description || '',
    priority: obj.priority || 'medium',
    status: obj.status || 'scheduled',
    type: obj.type || 'internal',
    participants: [
      {
        userId: obj.bossId,
        name: obj.bossName,
        response: bossResponse,
      },
    ],
    startAt: obj.startAt,
    endAt: obj.endAt,
    meetLink: obj.meetLink || null,
    location: obj.location || null,
    reminderMinutes: 15,
    attachments: [],
    notes: obj.notes || '',
    actionItems: [],
    teamLeadId: null,
    isTeamMeeting: false,
    bossResponse,
    bossResponseNote: obj.bossResponseNote || '',
    bossResponseAt: obj.bossResponseAt || null,
    rescheduleRequested: Boolean(obj.rescheduleRequested),
    reschedulePreferredStartAt: obj.reschedulePreferredStartAt || null,
    reschedulePreferredEndAt: obj.reschedulePreferredEndAt || null,
    rescheduleReason: obj.rescheduleReason || '',
    rescheduleRequestedAt: obj.rescheduleRequestedAt || null,
    bossMarkedImportant: Boolean(obj.bossMarkedImportant),
    bossPersonalNote: obj.bossPersonalNote || '',
    coordinatorApproval: approval,
    approvedById: obj.approvedById || '',
    approvedByName: obj.approvedByName || '',
    approvedAt: obj.approvedAt || null,
    rejectionReason: obj.rejectionReason || '',
    createdAt: obj.createdAt,
    updatedAt: obj.updatedAt,
  };
};

function emitRealtimeMeetingChange(action, meeting) {
  try {
    emitMeetingChange([], {
      action,
      meetingId: meeting?._id
        ? String(meeting._id)
        : meeting?.id
          ? String(meeting.id)
          : undefined,
    });
  } catch (_error) {
    // Real-time sync is best-effort; API response should not fail because of socket issues.
  }
}

/** Resolve the single Boss (CEO / isRoot) for meeting targeting */
export const getBoss = async (_req, res) => {
  try {
    const boss =
      (await CentralAdminUser.findOne({ isRoot: true, status: 'Active' }).lean()) ||
      (await CentralAdminUser.findOne({ role: CENTRAL_ROOT_ROLE, status: 'Active' }).lean());

    if (!boss) {
      return res.status(404).json({ message: 'Boss (CEO) account not found. Seed central admin first.' });
    }

    return res.status(200).json({
      id: String(boss._id),
      name: boss.name,
      email: boss.email,
      role: boss.role,
    });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to load boss', error: error?.message || error });
  }
};

export const listMeetings = async (req, res) => {
  try {
    const { forBoss, organizerId } = req.query;
    const filter = {};
    if (forBoss === 'true' || forBoss === '1') {
      const boss =
        (await CentralAdminUser.findOne({ isRoot: true, status: 'Active' }).lean()) ||
        (await CentralAdminUser.findOne({ role: CENTRAL_ROOT_ROLE, status: 'Active' }).lean());
      if (boss) filter.bossId = String(boss._id);
    }
    if (organizerId) filter.organizerId = String(organizerId);

    // Boss only sees meetings approved by Meeting Coordinator.
    if (isBossAuth(req.auth) && !isCoordinatorAuth(req.auth)) {
      filter.$or = [
        { coordinatorApproval: 'approved' },
        { coordinatorApproval: { $exists: false } },
        { coordinatorApproval: null },
      ];
    }

    const meetings = await CentralMeeting.find(filter).sort({ startAt: 1 });
    return res.status(200).json(meetings.map(toApi));
  } catch (error) {
    return res.status(500).json({ message: 'Failed to load meetings', error: error?.message || error });
  }
};

export const getMeetingById = async (req, res) => {
  try {
    const meeting = await CentralMeeting.findById(req.params.id);
    if (!meeting) return res.status(404).json({ message: 'Meeting not found' });

    // Boss cannot open unapproved meetings by deep link.
    if (isBossAuth(req.auth) && !isCoordinatorAuth(req.auth)) {
      const approval =
        meeting.coordinatorApproval == null ? 'approved' : meeting.coordinatorApproval;
      if (approval !== 'approved') {
        return res.status(404).json({ message: 'Meeting not found' });
      }
    }

    return res.status(200).json(toApi(meeting));
  } catch (error) {
    return res.status(500).json({ message: 'Failed to load meeting', error: error?.message || error });
  }
};

const ACTIVE_STATUSES = ['scheduled', 'ongoing', 'rescheduled'];

function parseDate(value) {
  const d = value ? new Date(value) : null;
  return d && !Number.isNaN(d.getTime()) ? d : null;
}

/** Reject past start times and overlapping Boss meetings. */
async function assertValidSchedule({ startAt, endAt, excludeId }) {
  const start = parseDate(startAt);
  const end = parseDate(endAt);
  if (!start || !end) {
    return { error: 'Invalid start or end time', status: 400 };
  }
  if (!(end > start)) {
    return { error: 'End time must be after start time', status: 400 };
  }

  const graceMs = 60 * 1000;
  if (start.getTime() < Date.now() - graceMs) {
    return {
      error: 'Cannot schedule a meeting in the past. Pick a future time.',
      status: 400,
    };
  }

  const filter = {
    status: { $in: ACTIVE_STATUSES },
    startAt: { $lt: end },
    endAt: { $gt: start },
  };
  if (excludeId) {
    filter._id = { $ne: excludeId };
  }

  const conflict = await CentralMeeting.findOne(filter).lean();
  if (conflict) {
    return {
      error: `Time slot conflicts with “${conflict.title}”. Choose a different time.`,
      status: 409,
    };
  }

  return { start, end };
}

export const createMeeting = async (req, res) => {
  try {
    const body = req.body || {};
    if (!body.title || !body.startAt || !body.endAt) {
      return res.status(400).json({ message: 'title, startAt and endAt are required' });
    }

    const schedule = await assertValidSchedule({
      startAt: body.startAt,
      endAt: body.endAt,
    });
    if (schedule.error) {
      return res.status(schedule.status).json({ message: schedule.error });
    }

    const boss =
      (await CentralAdminUser.findOne({ isRoot: true, status: 'Active' }).lean()) ||
      (await CentralAdminUser.findOne({ role: CENTRAL_ROOT_ROLE, status: 'Active' }).lean());

    if (!boss) {
      return res.status(400).json({ message: 'Boss account not found. Cannot create meeting.' });
    }

    const organizerId = String(body.organizerId || req.auth?.sub || '');
    if (!organizerId) {
      return res.status(400).json({ message: 'organizerId is required' });
    }

    const createdByCoordinator = isCoordinatorAuth(req.auth);
    const meeting = await CentralMeeting.create({
      title: body.title,
      organizerId,
      organizerName: body.organizerName || 'Team member',
      organizerRole: body.organizerRole || '',
      bossId: String(boss._id),
      bossName: boss.name,
      companyId: body.companyId || '',
      companyName: body.companyName || '',
      agenda: body.agenda || '',
      description: body.description || '',
      priority: body.priority || 'medium',
      status: body.status || 'scheduled',
      type: body.type || 'internal',
      startAt: schedule.start,
      endAt: schedule.end,
      meetLink: body.meetLink || '',
      location: body.location || '',
      notes: body.notes || '',
      // Coordinator-created meetings go straight to Boss.
      coordinatorApproval: createdByCoordinator ? 'approved' : 'pending',
      approvedById: createdByCoordinator ? organizerId : '',
      approvedByName: createdByCoordinator
        ? (body.organizerName || 'Meeting Coordinator')
        : '',
      approvedAt: createdByCoordinator ? new Date() : null,
    });

    if (meeting.coordinatorApproval === 'approved') {
      notifyMeetingAssigned(meeting);
    } else {
      notifyMeetingPendingApproval(meeting);
    }
    emitRealtimeMeetingChange('created', meeting);

    return res.status(201).json({
      message: createdByCoordinator
        ? 'Meeting created for Boss'
        : 'Meeting created — waiting for Meeting Coordinator approval',
      meeting: toApi(meeting),
    });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to create meeting', error: error?.message || error });
  }
};

export const updateMeeting = async (req, res) => {
  try {
    const body = req.body || {};
    const updates = {};
    for (const key of [
      'title',
      'agenda',
      'description',
      'priority',
      'status',
      'type',
      'startAt',
      'endAt',
      'meetLink',
      'location',
      'notes',
      'companyId',
      'companyName',
      'bossResponse',
      'bossResponseNote',
      'bossResponseAt',
      'rescheduleRequested',
      'reschedulePreferredStartAt',
      'reschedulePreferredEndAt',
      'rescheduleReason',
      'rescheduleRequestedAt',
      'bossMarkedImportant',
      'bossPersonalNote',
      'coordinatorApproval',
      'approvedById',
      'approvedByName',
      'approvedAt',
      'rejectionReason',
    ]) {
      if (body[key] !== undefined) updates[key] = body[key];
    }

    if (updates.coordinatorApproval === 'approved') {
      updates.approvedAt = updates.approvedAt || new Date();
      if (req.auth?.sub) {
        updates.approvedById = updates.approvedById || String(req.auth.sub);
      }
      if (!updates.approvedByName && req.auth?.email) {
        updates.approvedByName = String(req.auth.email);
      }
    }
    if (updates.coordinatorApproval === 'rejected') {
      updates.approvedAt = null;
    }

    // When team confirms a new time after a reschedule request, clear the flag.
    if (
      (updates.startAt !== undefined || updates.endAt !== undefined) &&
      body.clearRescheduleRequest === true
    ) {
      updates.rescheduleRequested = false;
      updates.rescheduleReason = '';
      updates.reschedulePreferredStartAt = null;
      updates.reschedulePreferredEndAt = null;
      updates.rescheduleRequestedAt = null;
    }

    if (updates.startAt !== undefined || updates.endAt !== undefined) {
      const current = await CentralMeeting.findById(req.params.id).lean();
      if (!current) return res.status(404).json({ message: 'Meeting not found' });

      const nextStart = parseDate(updates.startAt ?? current.startAt);
      const nextEnd = parseDate(updates.endAt ?? current.endAt);
      const prevStart = parseDate(current.startAt);
      const prevEnd = parseDate(current.endAt);
      const timesChanged =
        !nextStart ||
        !nextEnd ||
        !prevStart ||
        !prevEnd ||
        Math.abs(nextStart.getTime() - prevStart.getTime()) > 2000 ||
        Math.abs(nextEnd.getTime() - prevEnd.getTime()) > 2000;

      // Only enforce past/overlap rules when the schedule actually changes
      // (Boss RSVP updates also send start/end and must not be blocked).
      if (timesChanged) {
        const schedule = await assertValidSchedule({
          startAt: nextStart,
          endAt: nextEnd,
          excludeId: req.params.id,
        });
        if (schedule.error) {
          return res.status(schedule.status).json({ message: schedule.error });
        }
        updates.startAt = schedule.start;
        updates.endAt = schedule.end;
      }
    }

    const previous = await CentralMeeting.findById(req.params.id).lean();
    if (!previous) return res.status(404).json({ message: 'Meeting not found' });

    const meeting = await CentralMeeting.findByIdAndUpdate(req.params.id, updates, {
      new: true,
      runValidators: true,
    });
    if (!meeting) return res.status(404).json({ message: 'Meeting not found' });

    const wasApproved =
      previous.coordinatorApproval == null || previous.coordinatorApproval === 'approved';
    const isNowApproved =
      meeting.coordinatorApproval == null || meeting.coordinatorApproval === 'approved';
    if (!wasApproved && isNowApproved) {
      notifyMeetingAssigned(meeting, req.auth?.sub);
    }

    if (updates.status === 'cancelled' && previous.status !== 'cancelled') {
      notifyMeetingCancelled(meeting, req.auth?.sub);
    } else if (
      meeting.coordinatorApproval === 'approved' &&
      Object.keys(updates).some((k) =>
        ['title', 'startAt', 'endAt', 'location', 'meetLink', 'agenda', 'description'].includes(k),
      )
    ) {
      notifyMeetingUpdated(meeting, req.auth?.sub, previous);
    } else if (
      Object.keys(updates).some((k) =>
        [
          'bossResponse',
          'bossResponseNote',
          'bossResponseAt',
          'rescheduleRequested',
          'reschedulePreferredStartAt',
          'reschedulePreferredEndAt',
          'rescheduleReason',
          'rescheduleRequestedAt',
          'bossMarkedImportant',
          'bossPersonalNote',
        ].includes(k),
      )
    ) {
      // Boss "Confirm for your team" → notify scheduler + coordinators
      notifyMeetingBossResponse(meeting, req.auth?.sub, previous);
    }
    emitRealtimeMeetingChange('updated', meeting);

    return res.status(200).json({ message: 'Meeting updated', meeting: toApi(meeting) });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to update meeting', error: error?.message || error });
  }
};

export const deleteMeeting = async (req, res) => {
  try {
    const meeting = await CentralMeeting.findByIdAndDelete(req.params.id);
    if (!meeting) return res.status(404).json({ message: 'Meeting not found' });
    emitRealtimeMeetingChange('deleted', meeting);
    return res.status(200).json({ message: 'Meeting deleted' });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to delete meeting', error: error?.message || error });
  }
};
