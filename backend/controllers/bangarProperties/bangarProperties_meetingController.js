import Meeting from '../../models/bangarProperties/bangarProperties_meeting.js';

const toApiMeeting = (doc) => {
  const obj = doc.toObject ? doc.toObject() : doc;
  return {
    id: String(obj._id),
    companyId: obj.companyId || 'bangarProperties',
    title: obj.title,
    organizerId: obj.organizerId,
    organizerName: obj.organizerName,
    agenda: obj.agenda || '',
    description: obj.description || '',
    priority: obj.priority || 'medium',
    status: obj.status || 'scheduled',
    type: obj.type || 'internal',
    participants: obj.participants || [],
    startAt: obj.startAt,
    endAt: obj.endAt,
    meetLink: obj.meetLink || null,
    location: obj.location || null,
    reminderMinutes: obj.reminderMinutes ?? 15,
    attachments: obj.attachments || [],
    notes: obj.notes || '',
    actionItems: obj.actionItems || [],
    teamLeadId: obj.teamLeadId || null,
    isTeamMeeting: Boolean(obj.isTeamMeeting),
    createdAt: obj.createdAt,
    updatedAt: obj.updatedAt,
  };
};

const fromBody = (body = {}) => ({
  companyId: body.companyId || 'bangarProperties',
  title: body.title,
  organizerId: body.organizerId,
  organizerName: body.organizerName,
  agenda: body.agenda || '',
  description: body.description || '',
  priority: body.priority || 'medium',
  status: body.status || 'scheduled',
  type: body.type || 'internal',
  participants: Array.isArray(body.participants) ? body.participants : [],
  startAt: body.startAt,
  endAt: body.endAt,
  meetLink: body.meetLink || '',
  location: body.location || '',
  reminderMinutes: body.reminderMinutes ?? 15,
  attachments: Array.isArray(body.attachments) ? body.attachments : [],
  notes: body.notes || '',
  actionItems: Array.isArray(body.actionItems) ? body.actionItems : [],
  teamLeadId: body.teamLeadId || null,
  isTeamMeeting: Boolean(body.isTeamMeeting),
});

export const getMeetings = async (req, res) => {
  try {
    const companyId = req.query.companyId || 'bangarProperties';
    const meetings = await Meeting.find({ companyId }).sort({ startAt: 1 });
    res.status(200).json(meetings.map(toApiMeeting));
  } catch (error) {
    res.status(500).json({ message: 'Error fetching meetings', error: error.message });
  }
};

export const getAllMeetings = async (_req, res) => {
  try {
    const meetings = await Meeting.find().sort({ startAt: 1 });
    res.status(200).json(meetings.map(toApiMeeting));
  } catch (error) {
    res.status(500).json({ message: 'Error fetching meetings', error: error.message });
  }
};

export const getMeetingById = async (req, res) => {
  try {
    const meeting = await Meeting.findById(req.params.id);
    if (!meeting) return res.status(404).json({ message: 'Meeting not found' });
    res.status(200).json(toApiMeeting(meeting));
  } catch (error) {
    res.status(500).json({ message: 'Error fetching meeting', error: error.message });
  }
};

export const createMeeting = async (req, res) => {
  try {
    const payload = fromBody(req.body);
    if (!payload.title || !payload.organizerId || !payload.startAt || !payload.endAt) {
      return res.status(400).json({
        message: 'title, organizerId, startAt and endAt are required',
      });
    }
    if (!payload.organizerName) {
      payload.organizerName = 'Organizer';
    }
    const meeting = await Meeting.create(payload);
    res.status(201).json({ message: 'Meeting created', meeting: toApiMeeting(meeting) });
  } catch (error) {
    res.status(500).json({ message: 'Error creating meeting', error: error.message });
  }
};

export const updateMeeting = async (req, res) => {
  try {
    const payload = fromBody({ ...req.body, companyId: req.body.companyId });
    delete payload.companyId;
    if (req.body.companyId) payload.companyId = req.body.companyId;

    const meeting = await Meeting.findByIdAndUpdate(req.params.id, payload, {
      new: true,
      runValidators: true,
    });
    if (!meeting) return res.status(404).json({ message: 'Meeting not found' });
    res.status(200).json({ message: 'Meeting updated', meeting: toApiMeeting(meeting) });
  } catch (error) {
    res.status(500).json({ message: 'Error updating meeting', error: error.message });
  }
};

export const deleteMeeting = async (req, res) => {
  try {
    const meeting = await Meeting.findByIdAndDelete(req.params.id);
    if (!meeting) return res.status(404).json({ message: 'Meeting not found' });
    res.status(200).json({ message: 'Meeting deleted' });
  } catch (error) {
    res.status(500).json({ message: 'Error deleting meeting', error: error.message });
  }
};
