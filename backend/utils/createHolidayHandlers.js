import { HOLIDAY_TYPES, HOLIDAY_SCOPES } from './holidayFields.js';
import { cacheKey, withCache, invalidateTenantCache, CACHE_TTL } from './cache.js';

const parseDateOnly = (val) => {
  if (!val) return null;
  const d = new Date(val);
  return Number.isNaN(d.getTime()) ? null : d;
};

const getDefaultHolidaysForYear = (year) => [
  {
    title: "New Year's Day",
    date: new Date(`${year}-01-01T00:00:00.000Z`),
    type: 'Public Holiday',
    description: 'Celebration of the New Year',
    year,
    month: 1,
    scope: 'all_company',
  },
  {
    title: 'Makar Sankranti / Pongal',
    date: new Date(`${year}-01-14T00:00:00.000Z`),
    type: 'Public Holiday',
    description: 'Harvest festival celebrated across India',
    year,
    month: 1,
    scope: 'all_company',
  },
  {
    title: 'Republic Day',
    date: new Date(`${year}-01-26T00:00:00.000Z`),
    type: 'Public Holiday',
    description: 'National holiday commemorating the Constitution of India',
    year,
    month: 1,
    scope: 'all_company',
  },
  {
    title: 'Holi',
    date: new Date(`${year}-03-25T00:00:00.000Z`),
    type: 'Public Holiday',
    description: 'Festival of Colors',
    year,
    month: 3,
    scope: 'all_company',
  },
  {
    title: 'Independence Day',
    date: new Date(`${year}-08-15T00:00:00.000Z`),
    type: 'Public Holiday',
    description: 'National Independence Day celebration',
    year,
    month: 8,
    scope: 'all_company',
  },
  {
    title: 'Gandhi Jayanti',
    date: new Date(`${year}-10-02T00:00:00.000Z`),
    type: 'Public Holiday',
    description: 'Birth anniversary of Mahatma Gandhi',
    year,
    month: 10,
    scope: 'all_company',
  },
  {
    title: 'Dussehra / Vijayadashami',
    date: new Date(`${year}-10-20T00:00:00.000Z`),
    type: 'Public Holiday',
    description: 'Victory of good over evil festival',
    year,
    month: 10,
    scope: 'all_company',
  },
  {
    title: 'Diwali (Deepavali)',
    date: new Date(`${year}-11-08T00:00:00.000Z`),
    type: 'Public Holiday',
    description: 'Festival of Lights',
    year,
    month: 11,
    scope: 'all_company',
  },
  {
    title: 'Christmas Day',
    date: new Date(`${year}-12-25T00:00:00.000Z`),
    type: 'Public Holiday',
    description: 'Christmas celebration',
    year,
    month: 12,
    scope: 'all_company',
  },
];

export const createHolidayHandlers = ({ Holiday, Employee, notificationService, tenantId = 'shared' }) => {
  const bust = () => invalidateTenantCache(tenantId, 'holidays');

  /**
   * Check if caller is higher position (Admin, HR, Manager, Team Leader, Tech Lead).
   */
  const checkHigherPosition = async (actorId, roleHint) => {
    if (roleHint) {
      const r = String(roleHint).toLowerCase().trim();
      if (['admin', 'hr', 'manager', 'team_leader', 'technical_lead', 'tech_lead'].includes(r)) return true;
    }
    if (!actorId) return true; // fallback to allow if not authenticated in dev

    try {
      const emp = await Employee.findById(actorId).populate('designation').lean();
      if (!emp) return false;

      const accessRole = String(emp.designation?.accessRole || emp.role || '').toLowerCase().trim();
      const title = String(emp.designation?.title || emp.designation?.name || '').toLowerCase().trim();

      if (['admin', 'hr', 'manager', 'team_leader', 'technical_lead', 'super_admin'].includes(accessRole)) return true;
      if (title.includes('admin') || title.includes('hr') || title.includes('manager') || title.includes('team lead') || title.includes('lead')) return true;
      if (emp.designation?.permissions?.canApproveLeave === true || emp.designation?.permissions?.hasFullAccess === true) return true;

      return false;
    } catch {
      return false;
    }
  };

  /**
   * GET /holidays
   * Query params:
   *   year: number (e.g. 2026)
   *   month: number (1-12)
   *   upcoming: boolean (date >= start of current month)
   *   type: string
   */
  const getHolidays = async (req, res) => {
    try {
      const { year, month, upcoming, type, startDate, endDate } = req.query;

      const filter = {};
      if (type?.trim()) filter.type = type.trim();

      if (startDate && endDate) {
        const s = parseDateOnly(startDate);
        const e = parseDateOnly(endDate);
        if (s && e) {
          filter.date = { $gte: s, $lte: e };
        }
      } else if (year) {
        filter.year = parseInt(year, 10);
        if (month) filter.month = parseInt(month, 10);
      } else if (month) {
        filter.month = parseInt(month, 10);
      } else if (upcoming === 'true') {
        const now = new Date();
        const startOfMonth = new Date(Date.UTC(now.getFullYear(), now.getMonth(), 1));
        filter.date = { $gte: startOfMonth };
      }

      // Check if DB is completely empty for this tenant, seed default standard holidays
      const count = await Holiday.countDocuments({});
      if (count === 0) {
        const currentYear = new Date().getFullYear();
        const seeds = [
          ...getDefaultHolidaysForYear(currentYear),
          ...getDefaultHolidaysForYear(currentYear + 1),
        ];
        await Holiday.insertMany(seeds);
      }

      const holidays = await Holiday.find(filter)
        .populate('createdBy', 'name email profilePhoto designation')
        .sort({ date: 1 });

      return res.status(200).json(holidays);
    } catch (error) {
      console.error(`[${tenantId}] getHolidays error:`, error);
      return res.status(500).json({ message: 'Error fetching holidays', error: error?.message || error });
    }
  };

  /**
   * POST /holidays
   * Create single holiday or multiple holidays (array in body.holidays)
   */
  const createHoliday = async (req, res) => {
    try {
      const { creatorId, creatorRole, holidays } = req.body;

      // Higher position authorization check
      const authorized = await checkHigherPosition(creatorId, creatorRole);
      if (!authorized) {
        return res.status(403).json({
          message: 'Access denied: Only employees in higher positions (Admin, HR, Manager, Team Leader) can set holidays.',
        });
      }

      let creatorName = '';
      let creatorRoleResolved = creatorRole || '';
      let createdById = creatorId || null;

      if (creatorId) {
        const emp = await Employee.findById(creatorId).populate('designation').lean();
        if (emp) {
          creatorName = emp.name || '';
          creatorRoleResolved = creatorRoleResolved || emp.designation?.title || emp.designation?.accessRole || '';
        }
      }

      // Batch creation support (e.g. setting all holidays in January)
      if (Array.isArray(holidays) && holidays.length > 0) {
        const docs = [];
        for (const item of holidays) {
          if (!item.title || !item.date) continue;
          const d = parseDateOnly(item.date);
          if (!d) continue;

          const endD = item.endDate ? parseDateOnly(item.endDate) : null;
          docs.push({
            title: String(item.title).trim(),
            date: d,
            endDate: endD,
            type: HOLIDAY_TYPES.includes(item.type) ? item.type : 'Public Holiday',
            description: String(item.description || '').trim(),
            year: d.getUTCFullYear(),
            month: d.getUTCMonth() + 1,
            scope: HOLIDAY_SCOPES.includes(item.scope) ? item.scope : 'all_company',
            department: item.department || '',
            createdBy: createdById,
            createdByName: creatorName,
            createdByRole: creatorRoleResolved,
          });
        }

        if (!docs.length) {
          return res.status(400).json({ message: 'No valid holidays provided.' });
        }

        const created = await Holiday.insertMany(docs);
        await bust();

        return res.status(201).json({
          message: `Successfully created ${created.length} holiday(s)`,
          holidays: created,
        });
      }

      // Single holiday creation
      const { title, date, endDate, type, description, scope, department } = req.body;
      if (!title || !date) {
        return res.status(400).json({ message: 'Holiday title and date are required.' });
      }

      const d = parseDateOnly(date);
      if (!d) {
        return res.status(400).json({ message: 'Invalid date provided.' });
      }

      const endD = endDate ? parseDateOnly(endDate) : null;
      if (endD && endD < d) {
        return res.status(400).json({ message: 'End date cannot be earlier than start date.' });
      }

      const holiday = await Holiday.create({
        title: String(title).trim(),
        date: d,
        endDate: endD,
        type: HOLIDAY_TYPES.includes(type) ? type : 'Public Holiday',
        description: String(description || '').trim(),
        year: d.getUTCFullYear(),
        month: d.getUTCMonth() + 1,
        scope: HOLIDAY_SCOPES.includes(scope) ? scope : 'all_company',
        department: department || '',
        createdBy: createdById,
        createdByName: creatorName,
        createdByRole: creatorRoleResolved,
      });

      await bust();

      // Notify employees
      if (notificationService?.createMany && Employee) {
        try {
          const employees = await Employee.find({ status: 'Active' }).select('_id').lean();
          if (employees.length) {
            const dateStr = d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
            await notificationService.createMany(
              employees.map((e) => ({
                recipientId: e._id,
                type: 'general',
                title: `New Holiday: ${holiday.title}`,
                message: `${holiday.title} has been scheduled for ${dateStr}.`,
                link: '/leave-calendar',
                priority: 'normal',
                metadata: {
                  entityType: 'holiday',
                  entityId: holiday._id,
                },
              }))
            );
          }
        } catch (notifErr) {
          console.warn(`[${tenantId}] notification send failed:`, notifErr?.message || notifErr);
        }
      }

      return res.status(201).json({
        message: 'Holiday scheduled successfully',
        holiday,
      });
    } catch (error) {
      console.error(`[${tenantId}] createHoliday error:`, error);
      return res.status(500).json({ message: 'Error creating holiday', error: error?.message || error });
    }
  };

  /**
   * GET /holidays/:id
   */
  const getHolidayById = async (req, res) => {
    try {
      const holiday = await Holiday.findById(req.params.id)
        .populate('createdBy', 'name email profilePhoto designation');
      if (!holiday) return res.status(404).json({ message: 'Holiday not found' });
      return res.status(200).json(holiday);
    } catch (error) {
      return res.status(500).json({ message: 'Error fetching holiday', error: error?.message || error });
    }
  };

  /**
   * PUT /holidays/:id
   */
  const updateHoliday = async (req, res) => {
    try {
      const { creatorId, creatorRole, title, date, endDate, type, description, scope, department } = req.body;

      const authorized = await checkHigherPosition(creatorId, creatorRole);
      if (!authorized) {
        return res.status(403).json({
          message: 'Access denied: Only employees in higher positions can update holidays.',
        });
      }

      const holiday = await Holiday.findById(req.params.id);
      if (!holiday) return res.status(404).json({ message: 'Holiday not found' });

      if (title) holiday.title = String(title).trim();
      if (date) {
        const d = parseDateOnly(date);
        if (d) {
          holiday.date = d;
          holiday.year = d.getUTCFullYear();
          holiday.month = d.getUTCMonth() + 1;
        }
      }
      if (endDate !== undefined) {
        holiday.endDate = endDate ? parseDateOnly(endDate) : null;
      }
      if (type && HOLIDAY_TYPES.includes(type)) holiday.type = type;
      if (description !== undefined) holiday.description = String(description).trim();
      if (scope && HOLIDAY_SCOPES.includes(scope)) holiday.scope = scope;
      if (department !== undefined) holiday.department = department;

      await holiday.save();
      await bust();

      return res.status(200).json({ message: 'Holiday updated successfully', holiday });
    } catch (error) {
      return res.status(500).json({ message: 'Error updating holiday', error: error?.message || error });
    }
  };

  /**
   * DELETE /holidays/:id
   */
  const deleteHoliday = async (req, res) => {
    try {
      const { creatorId, creatorRole } = req.body || req.query;

      const authorized = await checkHigherPosition(creatorId, creatorRole);
      if (!authorized) {
        return res.status(403).json({
          message: 'Access denied: Only employees in higher positions can delete holidays.',
        });
      }

      const holiday = await Holiday.findByIdAndDelete(req.params.id);
      if (!holiday) return res.status(404).json({ message: 'Holiday not found' });

      await bust();
      return res.status(200).json({ message: 'Holiday deleted successfully' });
    } catch (error) {
      return res.status(500).json({ message: 'Error deleting holiday', error: error?.message || error });
    }
  };

  /**
   * POST /holidays/seed-default
   */
  const seedDefaultHolidays = async (req, res) => {
    try {
      const year = parseInt(req.body?.year || new Date().getFullYear(), 10);
      const defaults = getDefaultHolidaysForYear(year);

      // Check existing
      const existing = await Holiday.find({ year }).select('title date').lean();
      const existingTitles = new Set(existing.map((h) => h.title.toLowerCase()));

      const toInsert = defaults.filter((d) => !existingTitles.has(d.title.toLowerCase()));
      if (toInsert.length > 0) {
        await Holiday.insertMany(toInsert);
        await bust();
      }

      const all = await Holiday.find({ year }).sort({ date: 1 });
      return res.status(200).json({
        message: `Default holidays seeded for ${year}`,
        count: toInsert.length,
        holidays: all,
      });
    } catch (error) {
      return res.status(500).json({ message: 'Error seeding holidays', error: error?.message || error });
    }
  };

  return {
    getHolidays,
    createHoliday,
    getHolidayById,
    updateHoliday,
    deleteHoliday,
    seedDefaultHolidays,
  };
};
