import { SITE_VISIT_STATUSES, SITE_VISIT_TYPES } from './siteVisitFields.js';
import {
  buildGoogleMapsDirectionsUrl,
  getTravelRatePerKm,
  haversineKm,
  roundKm,
} from './travelDistance.js';
import { endOfBusinessDay, startOfBusinessDay } from './businessTime.js';
import { isCoordOnlyAddress, resolveAddressOrCoords } from './reverseGeocode.js';

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
    .populate('property', 'title propertyCode locality city address status listingType latitude longitude googleMapLink')
    .populate('lead', 'name businessName contactNumber')
    .populate('assignedTo', 'name email phone')
    .populate('createdBy', 'name email');

const parseCoords = (body = {}) => {
  const latitude = toNumberOrNull(body.latitude ?? body.lat);
  const longitude = toNumberOrNull(body.longitude ?? body.lng ?? body.lon);
  if (latitude == null || longitude == null) return null;
  if (Math.abs(latitude) > 90 || Math.abs(longitude) > 180) return null;
  return {
    latitude,
    longitude,
    address: String(body.address || '').trim(),
  };
};

/** Same as parseCoords, but fills place name via shared reverse-geocode API. */
const parseAndResolveCoords = async (body = {}) => {
  const coords = parseCoords(body);
  if (!coords) return null;
  coords.address = await resolveAddressOrCoords(coords.latitude, coords.longitude, coords.address);
  return coords;
};

const enrichPointAddress = async (point) => {
  if (!point) return point;
  const lat = toNumberOrNull(point.latitude);
  const lon = toNumberOrNull(point.longitude);
  if (lat == null || lon == null) return point;
  const address = await resolveAddressOrCoords(lat, lon, point.address);
  return { ...point, address };
};

const serializeJourney = (journey) => {
  if (!journey) return null;
  return {
    id: journey._id,
    date: journey.date,
    status: journey.status,
    startedAt: journey.startedAt,
    startLatitude: journey.startLatitude,
    startLongitude: journey.startLongitude,
    startAddress: journey.startAddress || '',
    endedAt: journey.endedAt,
    endLatitude: journey.endLatitude,
    endLongitude: journey.endLongitude,
    endAddress: journey.endAddress || '',
    mapsUrl:
      journey.startLatitude != null && journey.startLongitude != null
        ? `https://www.google.com/maps?q=${journey.startLatitude},${journey.startLongitude}`
        : null,
  };
};

const findJourneyForDay = async (TravelJourney, employeeId, dayStart) => {
  if (!TravelJourney || !employeeId) return null;
  return TravelJourney.findOne({ employee: employeeId, date: dayStart });
};

export const createSiteVisitHandlers = ({ SiteVisit, Expense = null, TravelJourney = null }) => {
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
        .populate('property', 'title propertyCode locality city address status listingType latitude longitude googleMapLink')
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

  const startTravelJourney = async (req, res) => {
    try {
      if (!TravelJourney) {
        return res.status(500).json({ message: 'Travel journey model is not configured for this tenant' });
      }

      const employeeId = String(req.body.employeeId || '').trim();
      if (!employeeId) {
        return res.status(400).json({ message: 'employeeId is required' });
      }

      const coords = await parseAndResolveCoords(req.body);
      if (!coords) {
        return res.status(400).json({ message: 'Valid latitude and longitude are required to start journey' });
      }

      const now = new Date();
      const dayStart = startOfBusinessDay(now);
      const existing = await findJourneyForDay(TravelJourney, employeeId, dayStart);

      if (existing?.startedAt && existing.status === 'active') {
        return res.status(409).json({
          message: 'Journey already started for today. End it first to restart.',
          journey: serializeJourney(existing),
        });
      }

      const payload = {
        employee: employeeId,
        date: dayStart,
        status: 'active',
        startedAt: now,
        startLatitude: coords.latitude,
        startLongitude: coords.longitude,
        startAddress: coords.address,
        endedAt: null,
        endLatitude: null,
        endLongitude: null,
        endAddress: '',
      };

      let journey;
      if (existing) {
        Object.assign(existing, payload);
        journey = await existing.save();
      } else {
        journey = await TravelJourney.create(payload);
      }

      return res.status(200).json({
        message: 'Journey started — route distance will be calculated from this point',
        journey: serializeJourney(journey),
      });
    } catch (error) {
      return res.status(500).json({ message: 'Error starting journey', error: error?.message || error });
    }
  };

  const endTravelJourney = async (req, res) => {
    try {
      if (!TravelJourney) {
        return res.status(500).json({ message: 'Travel journey model is not configured for this tenant' });
      }

      const employeeId = String(req.body.employeeId || '').trim();
      if (!employeeId) {
        return res.status(400).json({ message: 'employeeId is required' });
      }

      const coords = await parseAndResolveCoords(req.body);
      const now = new Date();
      const dayStart = startOfBusinessDay(req.body.date ? new Date(req.body.date) : now);
      const journey = await findJourneyForDay(TravelJourney, employeeId, dayStart);

      if (!journey?.startedAt) {
        return res.status(400).json({ message: 'No journey started for this day' });
      }
      if (journey.status === 'ended') {
        return res.status(409).json({
          message: 'Journey already ended',
          journey: serializeJourney(journey),
        });
      }

      journey.status = 'ended';
      journey.endedAt = now;
      if (coords) {
        journey.endLatitude = coords.latitude;
        journey.endLongitude = coords.longitude;
        journey.endAddress = coords.address;
      }
      await journey.save();

      return res.status(200).json({
        message: 'Journey ended',
        journey: serializeJourney(journey),
      });
    } catch (error) {
      return res.status(500).json({ message: 'Error ending journey', error: error?.message || error });
    }
  };

  const checkInSiteVisit = async (req, res) => {
    try {
      const coords = await parseAndResolveCoords(req.body);
      if (!coords) {
        return res.status(400).json({ message: 'Valid latitude and longitude are required to check in' });
      }

      const visit = await SiteVisit.findById(req.params.id);
      if (!visit) return res.status(404).json({ message: 'Site visit not found' });

      const employeeId = req.body.employeeId || visit.assignedTo;
      const now = new Date();
      const dayStart = startOfBusinessDay(now);
      const dayEnd = endOfBusinessDay(now);

      // Distance only after the coordinator starts a journey for the day
      let travelFromPreviousKm = null;
      const journey = employeeId ? await findJourneyForDay(TravelJourney, employeeId, dayStart) : null;
      const journeyActive = Boolean(journey?.startedAt);

      if (journeyActive && employeeId) {
        const previous = await SiteVisit.findOne({
          _id: { $ne: visit._id },
          assignedTo: employeeId,
          checkInAt: { $gte: dayStart, $lte: dayEnd },
          checkInLatitude: { $ne: null },
          checkInLongitude: { $ne: null },
        })
          .sort({ checkInAt: -1 })
          .select('checkInLatitude checkInLongitude checkInAt');

        if (previous) {
          travelFromPreviousKm = roundKm(
            haversineKm(
              previous.checkInLatitude,
              previous.checkInLongitude,
              coords.latitude,
              coords.longitude
            )
          );
        } else if (journey.startLatitude != null && journey.startLongitude != null) {
          travelFromPreviousKm = roundKm(
            haversineKm(
              journey.startLatitude,
              journey.startLongitude,
              coords.latitude,
              coords.longitude
            )
          );
        }
      }

      visit.checkInAt = now;
      visit.checkInLatitude = coords.latitude;
      visit.checkInLongitude = coords.longitude;
      visit.checkInAddress = coords.address;
      visit.travelFromPreviousKm = travelFromPreviousKm;
      if (visit.status === 'Scheduled' || visit.status === 'Confirmed') {
        visit.status = 'Confirmed';
      }
      await visit.save();

      const populated = await populateVisit(SiteVisit, visit._id);
      return res.status(200).json({
        message: journeyActive
          ? 'Checked in at site'
          : 'Checked in at site (start journey to calculate travel distance)',
        siteVisit: populated,
        travelFromPreviousKm,
        journeyStarted: journeyActive,
      });
    } catch (error) {
      return res.status(500).json({ message: 'Error checking in', error: error?.message || error });
    }
  };

  const checkOutSiteVisit = async (req, res) => {
    try {
      const coords = await parseAndResolveCoords(req.body);
      if (!coords) {
        return res.status(400).json({ message: 'Valid latitude and longitude are required to check out' });
      }

      const visit = await SiteVisit.findById(req.params.id);
      if (!visit) return res.status(404).json({ message: 'Site visit not found' });
      if (!visit.checkInAt) {
        return res.status(400).json({ message: 'Check in before checking out' });
      }

      visit.checkOutAt = new Date();
      visit.checkOutLatitude = coords.latitude;
      visit.checkOutLongitude = coords.longitude;
      visit.checkOutAddress = coords.address;
      if (visit.status !== 'Cancelled' && visit.status !== 'No Show') {
        visit.status = 'Completed';
      }
      await visit.save();

      const populated = await populateVisit(SiteVisit, visit._id);
      return res.status(200).json({ message: 'Checked out from site', siteVisit: populated });
    } catch (error) {
      return res.status(500).json({ message: 'Error checking out', error: error?.message || error });
    }
  };

  const getTravelTimeline = async (req, res) => {
    try {
      const employeeId = String(req.query.employeeId || '').trim();
      if (!employeeId) {
        return res.status(400).json({ message: 'employeeId is required' });
      }

      const date = req.query.date ? new Date(req.query.date) : new Date();
      if (Number.isNaN(date.getTime())) {
        return res.status(400).json({ message: 'Invalid date' });
      }

      const dayStart = startOfBusinessDay(date);
      const dayEnd = endOfBusinessDay(date);
      const ratePerKm = getTravelRatePerKm();
      const journey = await findJourneyForDay(TravelJourney, employeeId, dayStart);
      const journeyStarted = Boolean(journey?.startedAt);

      const visits = await SiteVisit.find({
        assignedTo: employeeId,
        $or: [
          { scheduledAt: { $gte: dayStart, $lte: dayEnd } },
          { checkInAt: { $gte: dayStart, $lte: dayEnd } },
        ],
      })
        .populate('property', 'title propertyCode locality city address latitude longitude googleMapLink')
        .populate('lead', 'name businessName contactNumber')
        .populate('assignedTo', 'name email phone')
        .sort({ checkInAt: 1, scheduledAt: 1 });

      const checkedIn = visits
        .filter((v) => v.checkInLatitude != null && v.checkInLongitude != null)
        .sort((a, b) => new Date(a.checkInAt) - new Date(b.checkInAt));

      const timeline = [];

      if (journeyStarted && journey.startLatitude != null && journey.startLongitude != null) {
        timeline.push({
          type: 'journey_start',
          siteVisitId: null,
          visitorName: 'Journey start',
          property: null,
          address: journey.startAddress || '',
          city: '',
          status: journey.status,
          scheduledAt: null,
          checkInAt: journey.startedAt,
          checkOutAt: null,
          latitude: journey.startLatitude,
          longitude: journey.startLongitude,
          mapsUrl: `https://www.google.com/maps?q=${journey.startLatitude},${journey.startLongitude}`,
          segmentKm: 0,
          travelExpenseId: null,
        });
      }

      // Distance only when journey has been started
      checkedIn.forEach((v, idx) => {
        let segmentKm = 0;
        if (journeyStarted) {
          if (idx === 0 && journey.startLatitude != null && journey.startLongitude != null) {
            segmentKm = roundKm(
              haversineKm(
                journey.startLatitude,
                journey.startLongitude,
                v.checkInLatitude,
                v.checkInLongitude
              )
            );
          } else if (idx > 0) {
            const prev = checkedIn[idx - 1];
            segmentKm = roundKm(
              haversineKm(
                prev.checkInLatitude,
                prev.checkInLongitude,
                v.checkInLatitude,
                v.checkInLongitude
              )
            );
          }
        }

        timeline.push({
          type: 'check_in',
          siteVisitId: v._id,
          visitorName: v.visitorName,
          property: v.property,
          address: v.checkInAddress || v.address,
          city: v.city,
          status: v.status,
          scheduledAt: v.scheduledAt,
          checkInAt: v.checkInAt,
          checkOutAt: v.checkOutAt,
          latitude: v.checkInLatitude,
          longitude: v.checkInLongitude,
          mapsUrl: `https://www.google.com/maps?q=${v.checkInLatitude},${v.checkInLongitude}`,
          segmentKm,
          travelExpenseId: v.travelExpenseId || null,
        });
      });

      if (
        journeyStarted &&
        journey.status === 'ended' &&
        journey.endLatitude != null &&
        journey.endLongitude != null
      ) {
        const lastPoint = timeline[timeline.length - 1];
        const segmentKm =
          lastPoint?.latitude != null && lastPoint?.longitude != null
            ? roundKm(
                haversineKm(
                  lastPoint.latitude,
                  lastPoint.longitude,
                  journey.endLatitude,
                  journey.endLongitude
                )
              )
            : 0;
        timeline.push({
          type: 'journey_end',
          siteVisitId: null,
          visitorName: 'Journey end',
          property: null,
          address: journey.endAddress || '',
          city: '',
          status: 'ended',
          scheduledAt: null,
          checkInAt: journey.endedAt,
          checkOutAt: null,
          latitude: journey.endLatitude,
          longitude: journey.endLongitude,
          mapsUrl: `https://www.google.com/maps?q=${journey.endLatitude},${journey.endLongitude}`,
          segmentKm,
          travelExpenseId: null,
        });
      }

      const totalDistanceKm = journeyStarted
        ? roundKm(timeline.reduce((sum, p) => sum + (Number(p.segmentKm) || 0), 0))
        : 0;
      const estimatedExpense = roundKm(totalDistanceKm * ratePerKm, 0);
      const routeUrl = journeyStarted ? buildGoogleMapsDirectionsUrl(timeline) : null;

      // Enrich coord-only addresses with place names (same for web + Flutter clients).
      const enrichedTimeline = await Promise.all(timeline.map((p) => enrichPointAddress(p)));
      let journeyPayload = serializeJourney(journey);
      if (journeyPayload?.startLatitude != null && journeyPayload?.startLongitude != null) {
        const startAddress = await resolveAddressOrCoords(
          journeyPayload.startLatitude,
          journeyPayload.startLongitude,
          journeyPayload.startAddress
        );
        journeyPayload = { ...journeyPayload, startAddress };
        // Persist if previously stored as coordinates only
        if (
          journey &&
          startAddress &&
          isCoordOnlyAddress(journey.startAddress) &&
          !isCoordOnlyAddress(startAddress)
        ) {
          journey.startAddress = startAddress;
          await journey.save().catch(() => {});
        }
      }
      if (
        journeyPayload?.endLatitude != null &&
        journeyPayload?.endLongitude != null
      ) {
        const endAddress = await resolveAddressOrCoords(
          journeyPayload.endLatitude,
          journeyPayload.endLongitude,
          journeyPayload.endAddress
        );
        journeyPayload = { ...journeyPayload, endAddress };
        if (
          journey &&
          endAddress &&
          isCoordOnlyAddress(journey.endAddress) &&
          !isCoordOnlyAddress(endAddress)
        ) {
          journey.endAddress = endAddress;
          await journey.save().catch(() => {});
        }
      }

      return res.status(200).json({
        date: dayStart.toISOString(),
        employeeId,
        ratePerKm,
        totalDistanceKm,
        estimatedExpense,
        currency: 'INR',
        routeUrl,
        journey: journeyPayload,
        journeyStarted,
        visits,
        timeline: enrichedTimeline,
      });
    } catch (error) {
      return res.status(500).json({ message: 'Error building travel timeline', error: error?.message || error });
    }
  };

  const allocateTravelExpense = async (req, res) => {
    try {
      if (!Expense) {
        return res.status(500).json({ message: 'Expense model is not configured for this tenant' });
      }

      const employeeId = String(req.body.employeeId || '').trim();
      if (!employeeId) {
        return res.status(400).json({ message: 'employeeId is required' });
      }

      const date = req.body.date ? new Date(req.body.date) : new Date();
      if (Number.isNaN(date.getTime())) {
        return res.status(400).json({ message: 'Invalid date' });
      }

      const dayStart = startOfBusinessDay(date);
      const dayEnd = endOfBusinessDay(date);
      const ratePerKm = toNumberOrNull(req.body.ratePerKm) || getTravelRatePerKm();
      const journey = await findJourneyForDay(TravelJourney, employeeId, dayStart);

      if (!journey?.startedAt) {
        return res.status(400).json({
          message: 'Start your journey first before allocating travel expense',
        });
      }

      const visits = await SiteVisit.find({
        assignedTo: employeeId,
        checkInAt: { $gte: dayStart, $lte: dayEnd },
        checkInLatitude: { $ne: null },
        checkInLongitude: { $ne: null },
      }).sort({ checkInAt: 1 });

      if (!visits.length) {
        return res.status(400).json({
          message: 'Need at least one GPS check-in after starting the journey to allocate travel expense',
        });
      }

      let totalDistanceKm = 0;
      for (let i = 0; i < visits.length; i += 1) {
        const cur = visits[i];
        let km = 0;
        if (i === 0) {
          if (journey.startLatitude != null && journey.startLongitude != null) {
            km = roundKm(
              haversineKm(
                journey.startLatitude,
                journey.startLongitude,
                cur.checkInLatitude,
                cur.checkInLongitude
              )
            );
          }
        } else {
          const prev = visits[i - 1];
          km = roundKm(
            haversineKm(
              prev.checkInLatitude,
              prev.checkInLongitude,
              cur.checkInLatitude,
              cur.checkInLongitude
            )
          );
        }
        cur.travelFromPreviousKm = km;
        totalDistanceKm += km;
      }

      if (
        journey.status === 'ended' &&
        journey.endLatitude != null &&
        journey.endLongitude != null &&
        visits.length
      ) {
        const last = visits[visits.length - 1];
        totalDistanceKm += roundKm(
          haversineKm(
            last.checkInLatitude,
            last.checkInLongitude,
            journey.endLatitude,
            journey.endLongitude
          )
        );
      }

      totalDistanceKm = roundKm(totalDistanceKm);
      const amount = Math.round(totalDistanceKm * ratePerKm);

      if (amount <= 0) {
        return res.status(400).json({ message: 'Calculated travel distance is zero — nothing to allocate' });
      }

      const already = visits.find((v) => v.travelExpenseId);
      if (already?.travelExpenseId && !req.body.force) {
        return res.status(409).json({
          message: 'Travel expense already allocated for this day. Pass force=true to create another.',
          expenseId: already.travelExpenseId,
        });
      }

      const ymd = dayStart.toISOString().slice(0, 10);
      const expense = await Expense.create({
        description: `Site visit travel (${ymd}) · ${totalDistanceKm} km × ₹${ratePerKm}/km · ${visits.length} check-in(s)`,
        amount,
        date: dayStart,
        category: 'Travel',
      });

      const now = new Date();
      await Promise.all(
        visits.map((v) => {
          v.travelExpenseId = expense._id;
          v.travelExpenseAllocatedAt = now;
          return v.save();
        })
      );

      const routePoints = [
        { latitude: journey.startLatitude, longitude: journey.startLongitude },
        ...visits.map((v) => ({ latitude: v.checkInLatitude, longitude: v.checkInLongitude })),
      ];
      if (journey.endLatitude != null && journey.endLongitude != null) {
        routePoints.push({ latitude: journey.endLatitude, longitude: journey.endLongitude });
      }

      return res.status(201).json({
        message: 'Travel expense allocated',
        expense,
        totalDistanceKm,
        ratePerKm,
        amount,
        visitCount: visits.length,
        journey: serializeJourney(journey),
        routeUrl: buildGoogleMapsDirectionsUrl(routePoints),
      });
    } catch (error) {
      return res.status(500).json({ message: 'Error allocating travel expense', error: error?.message || error });
    }
  };

  return {
    createSiteVisit,
    getSiteVisits,
    getSiteVisitById,
    updateSiteVisit,
    deleteSiteVisit,
    checkInSiteVisit,
    checkOutSiteVisit,
    startTravelJourney,
    endTravelJourney,
    getTravelTimeline,
    allocateTravelExpense,
  };
};
