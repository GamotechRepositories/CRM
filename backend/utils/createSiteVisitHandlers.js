import { SITE_VISIT_STATUSES, SITE_VISIT_TYPES } from './siteVisitFields.js';

const toNumberOrNull = (value) => {
  if (value === undefined || value === null || value === '') return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
};

const toDateOrNull = (value) => {
  if (!value) return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d;
};

const toBoolOrNull = (value) => {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value === 'boolean') return value;
  if (value === 'true' || value === '1' || value === 1) return true;
  if (value === 'false' || value === '0' || value === 0) return false;
  return null;
};

const buildPayload = (body = {}) => ({
  property: body.property || null,
  lead: body.lead || null,
  visitorName: String(body.visitorName || '').trim(),
  visitorPhone: String(body.visitorPhone || '').trim(),
  visitorEmail: String(body.visitorEmail || '').trim(),
  visitType: SITE_VISIT_TYPES.includes(body.visitType) ? body.visitType : 'First Visit',
  status: SITE_VISIT_STATUSES.includes(body.status) ? body.status : 'Scheduled',
  scheduledAt: toDateOrNull(body.scheduledAt),
  durationMinutes: toNumberOrNull(body.durationMinutes) || 60,
  assignedTo: body.assignedTo || null,
  meetingPoint: String(body.meetingPoint || '').trim(),
  address: String(body.address || '').trim(),
  city: String(body.city || '').trim(),
  notes: String(body.notes || ''),
  outcome: String(body.outcome || ''),
  interested: toBoolOrNull(body.interested),
  feedback: String(body.feedback || ''),
  createdBy: body.createdBy || null,
});

const populateVisit = (SiteVisit, id) =>
  SiteVisit.findById(id)
    .populate('property', 'title propertyCode locality city address status listingType')
    .populate('lead', 'name businessName contactNumber')
    .populate('assignedTo', 'name email phone')
    .populate('createdBy', 'name email');

export const createSiteVisitHandlers = ({ SiteVisit }) => {
  const createSiteVisit = async (req, res) => {
    try {
      const payload = buildPayload(req.body);
      if (!payload.visitorName) {
        return res.status(400).json({ message: 'Visitor name is required' });
      }
      if (!payload.scheduledAt) {
        return res.status(400).json({ message: 'Scheduled date and time are required' });
      }
      const visit = await SiteVisit.create(payload);
      const populated = await populateVisit(SiteVisit, visit._id);
      return res.status(201).json({ message: 'Site visit scheduled', siteVisit: populated });
    } catch (error) {
      return res.status(500).json({ message: 'Error scheduling site visit', error: error?.message || error });
    }
  };

  const getSiteVisits = async (req, res) => {
    try {
      const { status, assignedTo, propertyId, from, to, search } = req.query;
      const filter = {};
      if (status?.trim()) filter.status = status.trim();
      if (assignedTo?.trim()) filter.assignedTo = assignedTo.trim();
      if (propertyId?.trim()) filter.property = propertyId.trim();
      if (from || to) {
        filter.scheduledAt = {};
        if (from) filter.scheduledAt.$gte = new Date(from);
        if (to) filter.scheduledAt.$lte = new Date(to);
      }
      if (search?.trim()) {
        const q = search.trim();
        filter.$or = [
          { visitorName: new RegExp(q, 'i') },
          { visitorPhone: new RegExp(q, 'i') },
          { visitorEmail: new RegExp(q, 'i') },
          { city: new RegExp(q, 'i') },
          { meetingPoint: new RegExp(q, 'i') },
          { address: new RegExp(q, 'i') },
        ];
      }
      const visits = await SiteVisit.find(filter)
        .populate('property', 'title propertyCode locality city address status listingType')
        .populate('lead', 'name businessName contactNumber')
        .populate('assignedTo', 'name email phone')
        .populate('createdBy', 'name email')
        .sort({ scheduledAt: 1 });
      return res.status(200).json(visits);
    } catch (error) {
      return res.status(500).json({ message: 'Error fetching site visits', error: error?.message || error });
    }
  };

  const getSiteVisitById = async (req, res) => {
    try {
      const visit = await populateVisit(SiteVisit, req.params.id);
      if (!visit) return res.status(404).json({ message: 'Site visit not found' });
      return res.status(200).json(visit);
    } catch (error) {
      return res.status(500).json({ message: 'Error fetching site visit', error: error?.message || error });
    }
  };

  const updateSiteVisit = async (req, res) => {
    try {
      const payload = buildPayload(req.body);
      if (!payload.visitorName) {
        return res.status(400).json({ message: 'Visitor name is required' });
      }
      if (!payload.scheduledAt) {
        return res.status(400).json({ message: 'Scheduled date and time are required' });
      }
      // Keep original creator unless explicitly replaced
      if (req.body.createdBy === undefined) delete payload.createdBy;

      const visit = await SiteVisit.findByIdAndUpdate(req.params.id, payload, {
        new: true,
        runValidators: true,
      });
      if (!visit) return res.status(404).json({ message: 'Site visit not found' });
      const populated = await populateVisit(SiteVisit, visit._id);
      return res.status(200).json({ message: 'Site visit updated', siteVisit: populated });
    } catch (error) {
      return res.status(500).json({ message: 'Error updating site visit', error: error?.message || error });
    }
  };

  const deleteSiteVisit = async (req, res) => {
    try {
      const visit = await SiteVisit.findByIdAndDelete(req.params.id);
      if (!visit) return res.status(404).json({ message: 'Site visit not found' });
      return res.status(200).json({ message: 'Site visit deleted' });
    } catch (error) {
      return res.status(500).json({ message: 'Error deleting site visit', error: error?.message || error });
    }
  };

  return {
    createSiteVisit,
    getSiteVisits,
    getSiteVisitById,
    updateSiteVisit,
    deleteSiteVisit,
  };
};
