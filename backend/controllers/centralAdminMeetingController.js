import CentralMeeting from '../models/centralAdmin/centralAdmin_meeting.js';
import CentralAdminUser, { CENTRAL_ROOT_ROLE } from '../models/centralAdmin/centralAdmin_user.js';

const toApi = (doc) => {
  const obj = doc.toObject ? doc.toObject() : doc;
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
        response: 'accepted',
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
    createdAt: obj.createdAt,
    updatedAt: obj.updatedAt,
  };
};

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
    return res.status(200).json(toApi(meeting));
  } catch (error) {
    return res.status(500).json({ message: 'Failed to load meeting', error: error?.message || error });
  }
};

export const createMeeting = async (req, res) => {
  try {
    const body = req.body || {};
    if (!body.title || !body.startAt || !body.endAt) {
      return res.status(400).json({ message: 'title, startAt and endAt are required' });
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
      startAt: body.startAt,
      endAt: body.endAt,
      meetLink: body.meetLink || '',
      location: body.location || '',
      notes: body.notes || '',
    });

    return res.status(201).json({ message: 'Meeting created for Boss', meeting: toApi(meeting) });
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
    ]) {
      if (body[key] !== undefined) updates[key] = body[key];
    }

    const meeting = await CentralMeeting.findByIdAndUpdate(req.params.id, updates, {
      new: true,
      runValidators: true,
    });
    if (!meeting) return res.status(404).json({ message: 'Meeting not found' });
    return res.status(200).json({ message: 'Meeting updated', meeting: toApi(meeting) });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to update meeting', error: error?.message || error });
  }
};

export const deleteMeeting = async (req, res) => {
  try {
    const meeting = await CentralMeeting.findByIdAndDelete(req.params.id);
    if (!meeting) return res.status(404).json({ message: 'Meeting not found' });
    return res.status(200).json({ message: 'Meeting deleted' });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to delete meeting', error: error?.message || error });
  }
};
