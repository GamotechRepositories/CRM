import React, { useEffect, useMemo, useState } from 'react';
import api from '../../api/axios';
import { useAuth } from '../../context/AuthContext';

const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

const DAY_NAMES = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

const HOLIDAY_TYPES = [
  'Public Holiday',
  'Company Holiday',
  'Optional Holiday',
  'Company Off'
];

// Helper to safely extract date components without timezone skew
const parseDateParts = (val) => {
  if (!val) return null;
  if (typeof val === 'string') {
    // If format is YYYY-MM-DD...
    const clean = val.split('T')[0];
    const match = clean.match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (match) {
      return {
        year: parseInt(match[1], 10),
        month: parseInt(match[2], 10) - 1, // 0-indexed
        day: parseInt(match[3], 10),
      };
    }
  }
  const d = new Date(val);
  if (Number.isNaN(d.getTime())) return null;
  return {
    year: d.getUTCFullYear(),
    month: d.getUTCMonth(),
    day: d.getUTCDate(),
  };
};

export default function LeaveCalendarView() {
  const { user, canApproveLeave, isAdmin } = useAuth();

  // Higher position check: Admin, HR, Manager, Team Leader, Tech Lead
  const isAuthorized = useMemo(() => {
    if (!user) return true; // dev/preview fallback to allow scheduling
    if (typeof isAdmin === 'function' && isAdmin()) return true;
    if (typeof canApproveLeave === 'function' && canApproveLeave()) return true;

    const accessRole = String(
      user.designation?.accessRole || user.accessRole || user.role || ''
    ).toLowerCase().trim();
    const title = String(
      user.designation?.title || user.designation?.name || user.designationTitle || user.title || ''
    ).toLowerCase().trim();

    const higherRoles = [
      'admin', 'hr', 'manager', 'team_leader', 'teamleader',
      'tl', 'technical_lead', 'tech_lead', 'super_admin', 'director', 'lead'
    ];
    if (higherRoles.some((r) => accessRole === r || accessRole.includes(r))) return true;

    const higherTitles = [
      'admin', 'hr', 'human resource', 'manager', 'team leader',
      'team lead', 'technical lead', 'tech lead', 'lead', 'director',
      'head', 'supervisor', 'president', 'founder', 'co-founder', 'chief', 'vp'
    ];
    if (higherTitles.some((t) => title.includes(t))) return true;

    if (user.designation?.permissions?.canApproveLeave === true) return true;
    if (user.designation?.permissions?.hasFullAccess === true) return true;

    return false;
  }, [user, canApproveLeave, isAdmin]);

  const today = useMemo(() => new Date(), []);
  const [currentDate, setCurrentDate] = useState(() => new Date());

  const [holidays, setHolidays] = useState([]);
  const [teamLeaves, setTeamLeaves] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const [viewMode, setViewMode] = useState('grid'); // 'grid' | 'agenda'
  const [eventFilter, setEventFilter] = useState('all'); // 'all' | 'holidays' | 'leaves'

  // Modal State
  const [showModal, setShowModal] = useState(false);
  const [modalMode, setModalMode] = useState('single'); // 'single' | 'bulk'
  const [submitting, setSubmitting] = useState(false);
  const [toastMessage, setToastMessage] = useState(null);

  // Single Holiday Form
  const [formTitle, setFormTitle] = useState('');
  const [formDate, setFormDate] = useState('');
  const [formEndDate, setFormEndDate] = useState('');
  const [formType, setFormType] = useState('Public Holiday');
  const [formDesc, setFormDesc] = useState('');
  const [editingHolidayId, setEditingHolidayId] = useState(null);

  // Bulk Month Form
  const [bulkMonth, setBulkMonth] = useState(1); // default January
  const [bulkYear, setBulkYear] = useState(today.getFullYear() + (today.getMonth() > 9 ? 1 : 0));
  const [bulkEntries, setBulkEntries] = useState([
    { title: "New Year's Day", day: 1, type: 'Public Holiday' },
    { title: 'Makar Sankranti', day: 14, type: 'Public Holiday' },
    { title: 'Republic Day', day: 26, type: 'Public Holiday' },
  ]);

  // Selected event detail modal
  const [selectedEvent, setSelectedEvent] = useState(null);

  const activeYear = currentDate.getFullYear();
  const activeMonth = currentDate.getMonth(); // 0-indexed

  // Fetch holidays and leaves
  const fetchData = async () => {
    try {
      setLoading(true);
      setError(null);

      const [holidaysRes, leavesRes] = await Promise.all([
        api.get('/holidays').catch((err) => {
          console.warn('Failed to fetch holidays:', err);
          return { data: [] };
        }),
        api.get('/leave').catch((err) => {
          console.warn('Failed to fetch leaves:', err);
          return { data: [] };
        }),
      ]);

      const fetchedHolidays = Array.isArray(holidaysRes.data) ? holidaysRes.data : [];
      setHolidays(fetchedHolidays);

      const rawLeaves = Array.isArray(leavesRes.data) ? leavesRes.data : [];
      const approved = rawLeaves.filter((l) => l.status === 'Approved');
      setTeamLeaves(approved);
    } catch (err) {
      setError(err?.message || 'Error loading calendar data');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  const showToast = (msg) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3500);
  };

  const handlePrevMonth = () => {
    setCurrentDate(new Date(activeYear, activeMonth - 1, 1));
  };

  const handleNextMonth = () => {
    setCurrentDate(new Date(activeYear, activeMonth + 1, 1));
  };

  const handleCurrentMonth = () => {
    setCurrentDate(new Date(today.getFullYear(), today.getMonth(), 1));
  };

  const handleJumpTo = (e) => {
    const [y, m] = e.target.value.split('-').map(Number);
    setCurrentDate(new Date(y, m, 1));
  };

  const openAddModal = (dateStr = null, initialMode = 'single') => {
    setEditingHolidayId(null);
    setFormTitle('');
    setFormDesc('');
    setFormType('Public Holiday');
    setFormEndDate('');
    if (dateStr) {
      setFormDate(dateStr);
    } else {
      const yyyy = activeYear;
      const mm = String(activeMonth + 1).padStart(2, '0');
      setFormDate(`${yyyy}-${mm}-01`);
    }
    setModalMode(initialMode);
    setShowModal(true);
  };

  const openEditModal = (holiday) => {
    setEditingHolidayId(holiday._id);
    setFormTitle(holiday.title);
    setFormType(holiday.type || 'Public Holiday');
    setFormDesc(holiday.description || '');
    const parts = parseDateParts(holiday.date);
    if (parts) {
      const dateStr = `${parts.year}-${String(parts.month + 1).padStart(2, '0')}-${String(parts.day).padStart(2, '0')}`;
      setFormDate(dateStr);
    }
    if (holiday.endDate) {
      const endParts = parseDateParts(holiday.endDate);
      if (endParts) {
        setFormEndDate(`${endParts.year}-${String(endParts.month + 1).padStart(2, '0')}-${String(endParts.day).padStart(2, '0')}`);
      }
    } else {
      setFormEndDate('');
    }
    setModalMode('single');
    setShowModal(true);
    setSelectedEvent(null);
  };

  const handleSaveHoliday = async (e) => {
    e.preventDefault();
    if (!formTitle.trim() || !formDate) {
      showToast('Please provide a title and date.');
      return;
    }

    try {
      setSubmitting(true);
      const payload = {
        title: formTitle.trim(),
        date: formDate,
        endDate: formEndDate || null,
        type: formType,
        description: formDesc.trim(),
        creatorId: user?._id || null,
        creatorRole: user?.designationTitle || user?.designation?.title || user?.designation?.accessRole || 'Higher Position',
      };

      if (editingHolidayId) {
        await api.put(`/holidays/${editingHolidayId}`, payload);
        showToast('Holiday updated successfully!');
      } else {
        await api.post('/holidays', payload);
        showToast('Holiday scheduled successfully!');
      }

      setShowModal(false);
      await fetchData();
    } catch (err) {
      showToast(err?.response?.data?.message || err?.message || 'Failed to save holiday');
    } finally {
      setSubmitting(false);
    }
  };

  const handleSaveBulk = async (e) => {
    e.preventDefault();
    const validItems = bulkEntries.filter((b) => b.title.trim() && b.day > 0 && b.day <= 31);
    if (!validItems.length) {
      showToast('Please add at least one valid holiday.');
      return;
    }

    try {
      setSubmitting(true);
      const mm = String(bulkMonth).padStart(2, '0');
      const holidaysToCreate = validItems.map((item) => {
        const dd = String(item.day).padStart(2, '0');
        return {
          title: item.title.trim(),
          date: `${bulkYear}-${mm}-${dd}`,
          type: item.type || 'Public Holiday',
          description: `Holiday in ${MONTH_NAMES[bulkMonth - 1]} ${bulkYear}`,
        };
      });

      await api.post('/holidays', {
        holidays: holidaysToCreate,
        creatorId: user?._id || null,
        creatorRole: user?.designationTitle || user?.designation?.title || user?.designation?.accessRole || 'Higher Position',
      });

      showToast(`Successfully scheduled ${holidaysToCreate.length} holidays for ${MONTH_NAMES[bulkMonth - 1]} ${bulkYear}!`);
      setShowModal(false);
      setCurrentDate(new Date(bulkYear, bulkMonth - 1, 1));
      await fetchData();
    } catch (err) {
      showToast(err?.response?.data?.message || err?.message || 'Failed to set month holidays');
    } finally {
      setSubmitting(false);
    }
  };

  const handleDeleteHoliday = async (id) => {
    if (!window.confirm('Are you sure you want to delete this holiday?')) return;
    try {
      setSubmitting(true);
      await api.delete(`/holidays/${id}`, {
        data: {
          creatorId: user?._id || null,
          creatorRole: user?.designationTitle || user?.designation?.title || '',
        },
      });
      showToast('Holiday removed.');
      setSelectedEvent(null);
      await fetchData();
    } catch (err) {
      showToast(err?.response?.data?.message || err?.message || 'Failed to delete');
    } finally {
      setSubmitting(false);
    }
  };

  // Calculations for active month calendar
  const activeMonthHolidays = useMemo(() => {
    return holidays.filter((h) => {
      const parts = parseDateParts(h.date);
      if (!parts) return false;
      return parts.year === activeYear && parts.month === activeMonth;
    });
  }, [holidays, activeYear, activeMonth]);

  const activeMonthLeaves = useMemo(() => {
    return teamLeaves.filter((l) => {
      const start = parseDateParts(l.startDate);
      const end = parseDateParts(l.endDate);
      if (!start || !end) return false;
      const startMs = new Date(start.year, start.month, start.day).getTime();
      const endMs = new Date(end.year, end.month, end.day, 23, 59, 59).getTime();
      const monthStartMs = new Date(activeYear, activeMonth, 1).getTime();
      const monthEndMs = new Date(activeYear, activeMonth + 1, 0, 23, 59, 59).getTime();
      return startMs <= monthEndMs && endMs >= monthStartMs;
    });
  }, [teamLeaves, activeYear, activeMonth]);

  // Scheduled Upcoming Holidays:
  // Shows all holidays that are already scheduled in the system, sorted chronologically
  const scheduledUpcomingHolidays = useMemo(() => {
    const todayMs = new Date(today.getFullYear(), today.getMonth(), today.getDate()).getTime();

    const sorted = [...holidays].sort((a, b) => {
      const da = new Date(a.date).getTime();
      const db = new Date(b.date).getTime();
      return da - db;
    });

    // Upcoming or current month holidays
    const upcoming = sorted.filter((h) => {
      const parts = parseDateParts(h.date);
      if (!parts) return false;
      const hMs = new Date(parts.year, parts.month, parts.day).getTime();
      const inActiveMonth = parts.year === activeYear && parts.month === activeMonth;
      return hMs >= todayMs || inActiveMonth;
    });

    return upcoming.length > 0 ? upcoming : sorted;
  }, [holidays, today, activeYear, activeMonth]);

  // Days matrix for the active month grid
  const calendarGrid = useMemo(() => {
    const firstDayIndex = new Date(activeYear, activeMonth, 1).getDay(); // 0 is Sun
    const totalDaysInMonth = new Date(activeYear, activeMonth + 1, 0).getDate();
    const prevMonthDays = new Date(activeYear, activeMonth, 0).getDate();

    const cells = [];

    // Prev month padding
    for (let i = firstDayIndex - 1; i >= 0; i--) {
      cells.push({
        dayNumber: prevMonthDays - i,
        isCurrentMonth: false,
        date: new Date(activeYear, activeMonth - 1, prevMonthDays - i),
      });
    }

    // Current month days
    for (let day = 1; day <= totalDaysInMonth; day++) {
      const isToday =
        today.getFullYear() === activeYear &&
        today.getMonth() === activeMonth &&
        today.getDate() === day;

      const curDateMs = new Date(activeYear, activeMonth, day).getTime();

      // Find holidays on this day
      const dayHolidays = holidays.filter((h) => {
        const parts = parseDateParts(h.date);
        if (!parts) return false;
        if (h.endDate) {
          const endParts = parseDateParts(h.endDate);
          if (endParts) {
            const startMs = new Date(parts.year, parts.month, parts.day).getTime();
            const endMs = new Date(endParts.year, endParts.month, endParts.day, 23, 59, 59).getTime();
            return curDateMs >= startMs && curDateMs <= endMs;
          }
        }
        return parts.year === activeYear && parts.month === activeMonth && parts.day === day;
      });

      // Find team leaves on this day
      const dayLeaves = teamLeaves.filter((l) => {
        const start = parseDateParts(l.startDate);
        const end = parseDateParts(l.endDate);
        if (!start || !end) return false;
        const startMs = new Date(start.year, start.month, start.day).getTime();
        const endMs = new Date(end.year, end.month, end.day, 23, 59, 59).getTime();
        return curDateMs >= startMs && curDateMs <= endMs;
      });

      cells.push({
        dayNumber: day,
        isCurrentMonth: true,
        isToday,
        dayOfWeek: new Date(activeYear, activeMonth, day).getDay(),
        holidays: dayHolidays,
        leaves: dayLeaves,
      });
    }

    // Trailing days
    const remaining = 7 - (cells.length % 7);
    if (remaining < 7) {
      for (let i = 1; i <= remaining; i++) {
        cells.push({
          dayNumber: i,
          isCurrentMonth: false,
          date: new Date(activeYear, activeMonth + 1, i),
        });
      }
    }

    return cells;
  }, [activeYear, activeMonth, today, holidays, teamLeaves]);

  // Jump to options (Current month + next 11 months)
  const jumpOptions = useMemo(() => {
    const list = [];
    const base = new Date(today.getFullYear(), today.getMonth(), 1);
    for (let i = 0; i < 12; i++) {
      const d = new Date(base.getFullYear(), base.getMonth() + i, 1);
      const val = `${d.getFullYear()}-${d.getMonth()}`;
      const label = `${MONTH_NAMES[d.getMonth()]} ${d.getFullYear()}${i === 0 ? ' (Current)' : ''}`;
      list.push({ val, label });
    }
    return list;
  }, [today]);

  const isCurrentMonthActive =
    today.getFullYear() === activeYear && today.getMonth() === activeMonth;

  return (
    <div className="p-4 md:p-6 bg-gray-50/50 min-h-screen font-sans">
      {/* Toast Alert */}
      {toastMessage && (
        <div className="fixed top-5 right-5 z-50 bg-gray-900 text-white px-4 py-2.5 rounded-lg shadow-xl text-sm flex items-center gap-2 border border-gray-700 animate-in fade-in slide-in-from-top-2">
          <span>🔔</span>
          <span>{toastMessage}</span>
        </div>
      )}

      {/* Top Header Row */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6">
        <div>
          <div className="flex items-center gap-3">
            <h1 className="text-2xl md:text-3xl font-bold text-gray-900 tracking-tight">
              Leave Calendar
            </h1>
            <span className="bg-purple-100 text-purple-700 text-xs font-semibold px-2.5 py-1 rounded-full border border-purple-200">
              Current &amp; Upcoming Months
            </span>
          </div>
          <p className="text-gray-500 text-sm mt-1">
            Official company holidays, designated days off, and team leave schedules.
          </p>
        </div>

        <div className="flex items-center gap-3 flex-wrap">
          {/* Authorization Pill */}
          <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-white border border-gray-200 text-xs font-medium shadow-2xs">
            <span
              className={`w-2 h-2 rounded-full ${
                isAuthorized ? 'bg-emerald-500 animate-pulse' : 'bg-gray-400'
              }`}
            />
            <span className={isAuthorized ? 'text-emerald-700 font-semibold' : 'text-gray-600'}>
              {isAuthorized ? 'Authorized to Schedule Holidays' : 'View Only'}
            </span>
          </div>

          {/* Higher position scheduling action */}
          {isAuthorized && (
            <div className="flex items-center gap-2">
              <button
                onClick={() => openAddModal(null, 'bulk')}
                className="inline-flex items-center gap-1.5 px-3 py-2 bg-purple-50 hover:bg-purple-100 text-purple-700 border border-purple-200 font-medium text-sm rounded-lg transition-all cursor-pointer"
                title="Schedule all holidays for a month (e.g. January)"
              >
                <span>📅</span>
                <span>Schedule by Month</span>
              </button>
              <button
                onClick={() => openAddModal(null, 'single')}
                className="inline-flex items-center gap-1.5 px-4 py-2 bg-purple-600 hover:bg-purple-700 active:bg-purple-800 text-white font-medium text-sm rounded-lg shadow-sm transition-all cursor-pointer"
              >
                <span className="text-base font-bold leading-none">+</span>
                <span>Set Leave / Holiday</span>
              </button>
            </div>
          )}
        </div>
      </div>

      {/* 4 KPI Summary Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-2xs flex flex-col justify-between">
          <span className="text-xs font-medium text-gray-500 uppercase tracking-wider">
            Active Month
          </span>
          <div className="my-1.5">
            <span className="text-xl font-bold text-gray-900">
              {MONTH_NAMES[activeMonth]} {activeYear}
            </span>
          </div>
          <span className="text-xs font-semibold text-purple-600">
            {isCurrentMonthActive ? 'Current Month' : 'Upcoming / Selected Month'}
          </span>
        </div>

        <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-2xs flex flex-col justify-between">
          <span className="text-xs font-medium text-gray-500 uppercase tracking-wider">
            Company Holidays &amp; Offs
          </span>
          <div className="my-1.5">
            <span className="text-2xl font-extrabold text-purple-600">
              {activeMonthHolidays.length}
            </span>
          </div>
          <span className="text-xs text-gray-500">Official scheduled leaves</span>
        </div>

        <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-2xs flex flex-col justify-between">
          <span className="text-xs font-medium text-gray-500 uppercase tracking-wider">
            Approved Team Leaves
          </span>
          <div className="my-1.5">
            <span className="text-2xl font-extrabold text-blue-600">
              {activeMonthLeaves.length}
            </span>
          </div>
          <span className="text-xs text-gray-500">Staff out of office</span>
        </div>

        <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-2xs flex flex-col justify-between">
          <span className="text-xs font-medium text-gray-500 uppercase tracking-wider">
            Calendar Scope
          </span>
          <div className="my-1.5 flex items-center gap-1.5">
            <span className="w-2 h-2 rounded-full bg-emerald-500" />
            <span className="text-sm font-semibold text-gray-900">
              Current &amp; Future Months
            </span>
          </div>
          <span className="text-xs text-gray-500">Past months locked</span>
        </div>
      </div>

      {/* Control Bar: Prev, Current, Next, Jump To, Filter, View Mode */}
      <div className="bg-white p-3 rounded-xl border border-gray-200 shadow-2xs mb-6 flex flex-col lg:flex-row items-center justify-between gap-4">
        <div className="flex items-center gap-2 w-full lg:w-auto justify-between lg:justify-start">
          <div className="flex items-center gap-1.5">
            <button
              onClick={handlePrevMonth}
              className="px-3 py-1.5 text-xs font-semibold text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors cursor-pointer"
              title="Previous Month"
            >
              &larr; Prev Month
            </button>
            <button
              onClick={handleCurrentMonth}
              className={`px-3 py-1.5 text-xs font-semibold rounded-lg transition-colors cursor-pointer ${
                isCurrentMonthActive
                  ? 'bg-purple-600 text-white shadow-xs'
                  : 'bg-white border border-gray-300 text-gray-700 hover:bg-gray-50'
              }`}
            >
              Current Month
            </button>
            <button
              onClick={handleNextMonth}
              className="px-3 py-1.5 text-xs font-semibold text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors cursor-pointer"
              title="Next Month"
            >
              Next Month &rarr;
            </button>
          </div>

          <span className="text-base font-bold text-gray-900 px-2 hidden sm:inline">
            {MONTH_NAMES[activeMonth]} {activeYear}
          </span>
        </div>

        <div className="flex items-center gap-3 w-full lg:w-auto justify-end flex-wrap">
          <div className="flex items-center gap-1.5 text-xs text-gray-600">
            <span className="font-medium whitespace-nowrap">Jump to:</span>
            <select
              value={`${activeYear}-${activeMonth}`}
              onChange={handleJumpTo}
              className="bg-white border border-gray-300 text-gray-800 text-xs rounded-lg px-2.5 py-1.5 focus:outline-purple-500 cursor-pointer"
            >
              {jumpOptions.map((opt) => (
                <option key={opt.val} value={opt.val}>
                  {opt.label}
                </option>
              ))}
            </select>
          </div>

          <select
            value={eventFilter}
            onChange={(e) => setEventFilter(e.target.value)}
            className="bg-white border border-gray-300 text-gray-800 text-xs rounded-lg px-2.5 py-1.5 focus:outline-purple-500 cursor-pointer"
          >
            <option value="all">
              All Events ({activeMonthHolidays.length + activeMonthLeaves.length})
            </option>
            <option value="holidays">Holidays Only ({activeMonthHolidays.length})</option>
            <option value="leaves">Team Leaves Only ({activeMonthLeaves.length})</option>
          </select>

          <div className="inline-flex rounded-lg border border-gray-300 p-0.5 bg-gray-50">
            <button
              onClick={() => setViewMode('grid')}
              className={`px-3 py-1 text-xs font-semibold rounded-md transition-colors cursor-pointer ${
                viewMode === 'grid'
                  ? 'bg-white text-gray-900 shadow-2xs font-bold'
                  : 'text-gray-500 hover:text-gray-900'
              }`}
            >
              Grid View
            </button>
            <button
              onClick={() => setViewMode('agenda')}
              className={`px-3 py-1 text-xs font-semibold rounded-md transition-colors cursor-pointer ${
                viewMode === 'agenda'
                  ? 'bg-white text-gray-900 shadow-2xs font-bold'
                  : 'text-gray-500 hover:text-gray-900'
              }`}
            >
              Agenda List
            </button>
          </div>
        </div>
      </div>

      {/* Main Layout: 2 Columns */}
      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
        {/* Left Column: Calendar Grid or Agenda View */}
        <div className="lg:col-span-3">
          {loading ? (
            <div className="bg-white rounded-xl border border-gray-200 p-12 text-center text-gray-400">
              <div className="inline-block animate-spin rounded-full h-8 w-8 border-3 border-purple-500 border-t-transparent mb-3" />
              <p className="text-sm">Loading calendar leaves &amp; holidays...</p>
            </div>
          ) : error ? (
            <div className="bg-red-50 border border-red-200 rounded-xl p-6 text-center text-red-700">
              <p className="font-semibold text-sm">Failed to load calendar data</p>
              <p className="text-xs mt-1 text-red-600">{error}</p>
              <button
                onClick={fetchData}
                className="mt-3 px-3 py-1 bg-red-600 text-white rounded text-xs font-semibold cursor-pointer"
              >
                Retry
              </button>
            </div>
          ) : viewMode === 'grid' ? (
            <div className="bg-white rounded-xl border border-gray-200 shadow-2xs overflow-hidden">
              {/* Days Header */}
              <div className="grid grid-cols-7 border-b border-gray-200 bg-gray-50/50">
                {DAY_NAMES.map((day, idx) => (
                  <div
                    key={day}
                    className={`py-3 text-center text-xs font-bold tracking-wider ${
                      idx === 0 || idx === 6 ? 'text-red-500' : 'text-gray-700'
                    }`}
                  >
                    {day}
                  </div>
                ))}
              </div>

              {/* Day Cells Grid */}
              <div className="grid grid-cols-7 gap-px bg-gray-200">
                {calendarGrid.map((cell, idx) => {
                  if (!cell.isCurrentMonth) {
                    return (
                      <div
                        key={`cell-${idx}`}
                        className="bg-gray-50/60 p-2 min-h-[95px] md:min-h-[115px] opacity-40 select-none flex flex-col justify-between"
                      >
                        <span className="text-xs text-gray-400 font-medium">{cell.dayNumber}</span>
                      </div>
                    );
                  }

                  const isWeekend = cell.dayOfWeek === 0 || cell.dayOfWeek === 6;
                  const showHolidays = eventFilter !== 'leaves';
                  const showLeaves = eventFilter !== 'holidays';
                  const dateStr = `${activeYear}-${String(activeMonth + 1).padStart(2, '0')}-${String(
                    cell.dayNumber
                  ).padStart(2, '0')}`;

                  return (
                    <div
                      key={`day-${cell.dayNumber}`}
                      className={`bg-white p-2 min-h-[95px] md:min-h-[115px] flex flex-col justify-between relative group transition-colors hover:bg-purple-50/20 ${
                        cell.isToday ? 'ring-2 ring-purple-600 ring-inset rounded-lg z-10' : ''
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-1.5">
                          {cell.isToday ? (
                            <>
                              <span className="w-5 h-5 rounded-full bg-purple-600 text-white flex items-center justify-center text-xs font-bold">
                                {cell.dayNumber}
                              </span>
                              <span className="bg-purple-100 text-purple-700 text-[9px] font-extrabold px-1.5 py-0.5 rounded tracking-wider">
                                TODAY
                              </span>
                            </>
                          ) : (
                            <span
                              className={`text-xs font-semibold ${
                                isWeekend ? 'text-red-500' : 'text-gray-800'
                              }`}
                            >
                              {cell.dayNumber}
                            </span>
                          )}
                        </div>

                        {/* Quick '+' on day cell for authorized users */}
                        {isAuthorized && (
                          <button
                            onClick={() => openAddModal(dateStr, 'single')}
                            className="opacity-0 group-hover:opacity-100 transition-opacity text-gray-400 hover:text-purple-600 hover:bg-purple-100 p-0.5 rounded text-xs leading-none font-bold cursor-pointer"
                            title={`Schedule holiday on ${cell.dayNumber} ${MONTH_NAMES[activeMonth]}`}
                          >
                            +
                          </button>
                        )}
                      </div>

                      <div className="flex flex-col gap-1 mt-1.5 flex-1 overflow-y-auto max-h-[85px]">
                        {showHolidays &&
                          cell.holidays.map((h) => {
                            const isPublic = h.type === 'Public Holiday';
                            const isOptional = h.type === 'Optional Holiday';
                            const isCompanyOff = h.type === 'Company Off';

                            let badgeBg = 'bg-purple-100/80 text-purple-800 border-purple-200';
                            if (isPublic) badgeBg = 'bg-purple-50 text-purple-900 border-purple-200';
                            if (isOptional) badgeBg = 'bg-amber-50 text-amber-900 border-amber-200';
                            if (isCompanyOff) badgeBg = 'bg-rose-50 text-rose-900 border-rose-200';

                            return (
                              <button
                                key={h._id}
                                onClick={() => setSelectedEvent({ kind: 'holiday', data: h })}
                                className={`text-[11px] font-medium px-1.5 py-0.5 rounded border text-left truncate flex items-center gap-1 transition-all hover:brightness-95 cursor-pointer shadow-2xs ${badgeBg}`}
                                title={`${h.title} (${h.type})`}
                              >
                                <span className="text-xs">🎉</span>
                                <span className="truncate">{h.title}</span>
                              </button>
                            );
                          })}

                        {showLeaves &&
                          cell.leaves.map((l) => {
                            const empName =
                              l.employee?.name || l.employee?.employeeCode || 'Employee';
                            const typeShort = l.leaveType || 'Leave';
                            return (
                              <button
                                key={l._id}
                                onClick={() => setSelectedEvent({ kind: 'leave', data: l })}
                                className="text-[11px] font-medium px-1.5 py-0.5 rounded border bg-blue-50 text-blue-800 border-blue-200 text-left truncate flex items-center gap-1 transition-all hover:bg-blue-100 cursor-pointer shadow-2xs"
                                title={`${empName}: ${typeShort} Leave`}
                              >
                                <span className="text-[10px]">👤</span>
                                <span className="truncate">
                                  {empName} ({typeShort})
                                </span>
                              </button>
                            );
                          })}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          ) : (
            /* Agenda List View */
            <div className="bg-white rounded-xl border border-gray-200 shadow-2xs p-4">
              <h2 className="text-sm font-bold text-gray-900 mb-4 pb-2 border-b border-gray-100 flex items-center justify-between">
                <span>
                  Agenda for {MONTH_NAMES[activeMonth]} {activeYear}
                </span>
                <span className="text-xs text-gray-500 font-normal">
                  {activeMonthHolidays.length} Holidays · {activeMonthLeaves.length} Team Leaves
                </span>
              </h2>

              {activeMonthHolidays.length === 0 && activeMonthLeaves.length === 0 ? (
                <div className="py-12 text-center text-gray-400 text-sm">
                  No scheduled holidays or team leaves in {MONTH_NAMES[activeMonth]} {activeYear}.
                </div>
              ) : (
                <div className="space-y-3">
                  {activeMonthHolidays.map((h) => {
                    const parts = parseDateParts(h.date);
                    const dayNum = parts ? parts.day : '';
                    const mName = parts ? MONTH_NAMES[parts.month].slice(0, 3) : '';
                    return (
                      <div
                        key={h._id}
                        className="flex items-center justify-between p-3 rounded-lg border border-purple-100 bg-purple-50/40 hover:bg-purple-50 transition-colors"
                      >
                        <div className="flex items-center gap-3">
                          <div className="w-10 h-10 rounded-lg bg-purple-100 text-purple-700 flex flex-col items-center justify-center text-xs font-bold">
                            <span>{dayNum}</span>
                            <span className="text-[9px] font-normal uppercase">{mName}</span>
                          </div>
                          <div>
                            <h3 className="text-sm font-bold text-gray-900 flex items-center gap-2">
                              <span>{h.title}</span>
                              <span className="text-[10px] font-semibold px-2 py-0.5 rounded-full bg-purple-100 text-purple-800 border border-purple-200">
                                {h.type}
                              </span>
                            </h3>
                            {h.description && (
                              <p className="text-xs text-gray-500 mt-0.5">{h.description}</p>
                            )}
                          </div>
                        </div>

                        {isAuthorized && (
                          <div className="flex items-center gap-1">
                            <button
                              onClick={() => openEditModal(h)}
                              className="text-xs text-purple-600 hover:text-purple-800 px-2 py-1 rounded hover:bg-purple-100 cursor-pointer"
                            >
                              Edit
                            </button>
                            <button
                              onClick={() => handleDeleteHoliday(h._id)}
                              className="text-xs text-red-600 hover:text-red-800 px-2 py-1 rounded hover:bg-red-50 cursor-pointer"
                            >
                              Delete
                            </button>
                          </div>
                        )}
                      </div>
                    );
                  })}

                  {activeMonthLeaves.map((l) => {
                    const start = parseDateParts(l.startDate);
                    const empName = l.employee?.name || 'Staff Member';
                    return (
                      <div
                        key={l._id}
                        className="flex items-center justify-between p-3 rounded-lg border border-blue-100 bg-blue-50/30 hover:bg-blue-50 transition-colors"
                      >
                        <div className="flex items-center gap-3">
                          <div className="w-10 h-10 rounded-lg bg-blue-100 text-blue-700 flex flex-col items-center justify-center text-xs font-bold">
                            <span>{start ? start.day : ''}</span>
                            <span className="text-[9px] font-normal uppercase">
                              {start ? MONTH_NAMES[start.month].slice(0, 3) : ''}
                            </span>
                          </div>
                          <div>
                            <h3 className="text-sm font-bold text-gray-900 flex items-center gap-2">
                              <span>{empName}</span>
                              <span className="text-[10px] font-semibold px-2 py-0.5 rounded-full bg-blue-100 text-blue-800 border border-blue-200">
                                {l.leaveType} Leave
                              </span>
                            </h3>
                            <p className="text-xs text-gray-500 mt-0.5">
                              {l.startDate?.split('T')[0]} &ndash; {l.endDate?.split('T')[0]}
                              {l.reason ? ` · ${l.reason}` : ''}
                            </p>
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}
        </div>

        {/* Right Column: Upcoming Holidays + Legend Sidebar */}
        <div className="space-y-6">
          {/* Upcoming Holidays Card */}
          <div className="bg-white rounded-xl border border-gray-200 shadow-2xs p-4 flex flex-col">
            <div className="flex items-center justify-between mb-3 pb-2 border-b border-gray-100">
              <div className="flex items-center gap-2">
                <h2 className="text-sm font-bold text-gray-900">Upcoming Holidays</h2>
                <span className="text-[11px] text-purple-700 bg-purple-50 border border-purple-200 font-semibold px-2 py-0.5 rounded-full">
                  {scheduledUpcomingHolidays.length} scheduled
                </span>
              </div>

              {isAuthorized && (
                <button
                  onClick={() => openAddModal(null, 'single')}
                  className="text-xs text-purple-700 font-bold hover:text-purple-900 bg-purple-50 hover:bg-purple-100 px-2 py-1 rounded-md transition-colors cursor-pointer"
                  title="Schedule a new holiday"
                >
                  + Add
                </button>
              )}
            </div>

            {scheduledUpcomingHolidays.length === 0 ? (
              <div className="text-center py-6 text-gray-400">
                <span className="text-2xl mb-1 block">🏖️</span>
                <p className="text-xs font-medium">No holidays scheduled yet.</p>
                {isAuthorized && (
                  <button
                    onClick={() => openAddModal(null, 'single')}
                    className="mt-3 inline-flex items-center gap-1 text-xs text-purple-600 font-bold hover:underline cursor-pointer"
                  >
                    + Schedule first holiday
                  </button>
                )}
              </div>
            ) : (
              <div className="space-y-2.5 max-h-[380px] overflow-y-auto pr-1">
                {scheduledUpcomingHolidays.map((h) => {
                  const parts = parseDateParts(h.date);
                  const isPublic = h.type === 'Public Holiday';
                  const dateLabel = parts
                    ? `${parts.day} ${MONTH_NAMES[parts.month].slice(0, 3)} ${
                        parts.year !== activeYear ? parts.year : ''
                      }`.trim()
                    : '';

                  return (
                    <div
                      key={h._id}
                      className="p-2.5 rounded-lg border border-gray-100 hover:border-purple-200 hover:bg-purple-50/30 transition-all flex flex-col gap-1"
                    >
                      <div className="flex items-start justify-between gap-2">
                        <span className="text-xs font-bold text-gray-800 leading-snug">
                          {h.title}
                        </span>
                        <span
                          className={`text-[10px] font-semibold px-2 py-0.5 rounded-full whitespace-nowrap border shrink-0 ${
                            isPublic
                              ? 'bg-teal-50 text-teal-700 border-teal-200'
                              : 'bg-purple-50 text-purple-700 border-purple-200'
                          }`}
                        >
                          {h.type}
                        </span>
                      </div>
                      <div className="flex items-center justify-between text-xs text-gray-500 mt-0.5">
                        <span className="flex items-center gap-1 font-medium text-gray-600">
                          <span>📅</span>
                          <span>{dateLabel}</span>
                        </span>
                        {isAuthorized && (
                          <div className="flex items-center gap-1.5">
                            <button
                              onClick={() => openEditModal(h)}
                              className="text-[11px] text-purple-600 hover:underline font-semibold cursor-pointer"
                            >
                              Edit
                            </button>
                            <button
                              onClick={() => handleDeleteHoliday(h._id)}
                              className="text-[11px] text-red-500 hover:underline cursor-pointer"
                            >
                              Delete
                            </button>
                          </div>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}

            {/* Quick schedule buttons inside upcoming holidays card */}
            {isAuthorized && (
              <div className="mt-3 pt-3 border-t border-gray-100 space-y-1.5">
                <button
                  onClick={() => openAddModal(null, 'single')}
                  className="w-full py-1.5 px-3 bg-purple-600 hover:bg-purple-700 text-white rounded-lg text-xs font-semibold transition-colors flex items-center justify-center gap-1.5 shadow-2xs cursor-pointer"
                >
                  <span>+</span>
                  <span>Schedule Holiday</span>
                </button>
                <button
                  onClick={() => openAddModal(null, 'bulk')}
                  className="w-full py-1 px-3 bg-white hover:bg-purple-50 text-purple-700 border border-purple-200 rounded-lg text-[11px] font-semibold transition-colors flex items-center justify-center gap-1 cursor-pointer"
                >
                  <span>📅 Schedule Month (e.g. January)</span>
                </button>
              </div>
            )}
          </div>

          {/* Legend Card */}
          <div className="bg-white rounded-xl border border-gray-200 shadow-2xs p-4">
            <h2 className="text-sm font-bold text-gray-900 mb-3 pb-2 border-b border-gray-100">
              Legend
            </h2>
            <div className="space-y-2.5 text-xs text-gray-700">
              <div className="flex items-center gap-2.5">
                <span className="w-2.5 h-2.5 rounded-full bg-purple-600 shrink-0" />
                <span>Company Holiday / Leave</span>
              </div>
              <div className="flex items-center gap-2.5">
                <span className="w-2.5 h-2.5 rounded-full bg-emerald-500 shrink-0" />
                <span>Public Holiday</span>
              </div>
              <div className="flex items-center gap-2.5">
                <span className="w-2.5 h-2.5 rounded-full bg-blue-600 shrink-0" />
                <span>Approved Team Leave</span>
              </div>
              <div className="flex items-center gap-2.5">
                <span className="w-2.5 h-2.5 rounded-full bg-amber-500 shrink-0" />
                <span>Optional / Team Day Off</span>
              </div>
            </div>

            {isAuthorized && (
              <button
                onClick={() => openAddModal(null, 'single')}
                className="w-full mt-4 py-2 border border-dashed border-purple-300 hover:border-purple-500 rounded-lg text-xs font-semibold text-purple-700 hover:bg-purple-50 transition-colors flex items-center justify-center gap-1.5 cursor-pointer"
              >
                <span>+</span>
                <span>Set New Leave on Calendar</span>
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Modal: Set Leave / Holiday (Single or Month Bulk) */}
      {showModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-xs p-4 overflow-y-auto">
          <div className="bg-white rounded-2xl shadow-2xl border border-gray-200 w-full max-w-lg p-6 animate-in fade-in zoom-in-95">
            {/* Modal Header */}
            <div className="flex items-center justify-between pb-3 border-b border-gray-100">
              <div>
                <h3 className="text-lg font-bold text-gray-900">
                  {editingHolidayId
                    ? 'Edit Scheduled Holiday'
                    : modalMode === 'bulk'
                    ? 'Schedule Month Holidays (Bulk)'
                    : 'Schedule Company Holiday / Leave'}
                </h3>
                <p className="text-xs text-gray-500 mt-0.5">
                  Higher position employees can schedule official holidays and days off for the company.
                </p>
              </div>
              <button
                onClick={() => setShowModal(false)}
                className="text-gray-400 hover:text-gray-600 text-lg p-1 cursor-pointer"
              >
                ✕
              </button>
            </div>

            {/* Mode Switcher Tabs */}
            {!editingHolidayId && (
              <div className="flex border-b border-gray-200 mt-3 mb-4">
                <button
                  type="button"
                  onClick={() => setModalMode('single')}
                  className={`pb-2 px-3 text-xs font-bold border-b-2 transition-colors cursor-pointer ${
                    modalMode === 'single'
                      ? 'border-purple-600 text-purple-600'
                      : 'border-transparent text-gray-500 hover:text-gray-800'
                  }`}
                >
                  Single Holiday
                </button>
                <button
                  type="button"
                  onClick={() => setModalMode('bulk')}
                  className={`pb-2 px-3 text-xs font-bold border-b-2 transition-colors cursor-pointer ${
                    modalMode === 'bulk'
                      ? 'border-purple-600 text-purple-600'
                      : 'border-transparent text-gray-500 hover:text-gray-800'
                  }`}
                >
                  Schedule by Month (e.g. January)
                </button>
              </div>
            )}

            {modalMode === 'single' ? (
              /* Single Holiday Form */
              <form onSubmit={handleSaveHoliday} className="space-y-4">
                <div>
                  <label className="block text-xs font-semibold text-gray-700 mb-1">
                    Holiday / Leave Title <span className="text-red-500">*</span>
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Gandhi Jayanti, Diwali Holiday, Company Annual Off"
                    value={formTitle}
                    onChange={(e) => setFormTitle(e.target.value)}
                    className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:outline-purple-500 focus:ring-1 focus:ring-purple-500"
                  />
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-semibold text-gray-700 mb-1">
                      Date <span className="text-red-500">*</span>
                    </label>
                    <input
                      type="date"
                      required
                      value={formDate}
                      onChange={(e) => setFormDate(e.target.value)}
                      className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:outline-purple-500"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-gray-700 mb-1">
                      End Date <span className="text-gray-400 font-normal">(Optional multi-day)</span>
                    </label>
                    <input
                      type="date"
                      value={formEndDate}
                      onChange={(e) => setFormEndDate(e.target.value)}
                      className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:outline-purple-500"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-gray-700 mb-1">
                    Holiday Type
                  </label>
                  <select
                    value={formType}
                    onChange={(e) => setFormType(e.target.value)}
                    className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:outline-purple-500 bg-white cursor-pointer"
                  >
                    {HOLIDAY_TYPES.map((t) => (
                      <option key={t} value={t}>
                        {t}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-gray-700 mb-1">
                    Description / Notes <span className="text-gray-400 font-normal">(Optional)</span>
                  </label>
                  <textarea
                    rows={2}
                    placeholder="Provide additional details regarding the holiday or company leave..."
                    value={formDesc}
                    onChange={(e) => setFormDesc(e.target.value)}
                    className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:outline-purple-500"
                  />
                </div>

                <div className="flex items-center justify-between pt-3 border-t border-gray-100">
                  {editingHolidayId ? (
                    <button
                      type="button"
                      onClick={() => handleDeleteHoliday(editingHolidayId)}
                      disabled={submitting}
                      className="px-3 py-2 text-xs font-semibold text-red-600 hover:bg-red-50 rounded-lg transition-colors cursor-pointer"
                    >
                      Delete
                    </button>
                  ) : <div />}

                  <div className="flex items-center gap-2">
                    <button
                      type="button"
                      onClick={() => setShowModal(false)}
                      disabled={submitting}
                      className="px-4 py-2 text-xs font-semibold text-gray-700 hover:bg-gray-100 rounded-lg transition-colors cursor-pointer"
                    >
                      Cancel
                    </button>
                    <button
                      type="submit"
                      disabled={submitting}
                      className="px-4 py-2 text-xs font-semibold text-white bg-purple-600 hover:bg-purple-700 rounded-lg shadow-sm transition-colors cursor-pointer disabled:opacity-50"
                    >
                      {submitting ? 'Scheduling...' : editingHolidayId ? 'Update Holiday' : 'Schedule Holiday'}
                    </button>
                  </div>
                </div>
              </form>
            ) : (
              /* Bulk Month Form */
              <form onSubmit={handleSaveBulk} className="space-y-4">
                <div className="p-3 bg-purple-50 rounded-lg border border-purple-100 text-xs text-purple-900 leading-relaxed">
                  💡 Select a month (e.g. <strong>January</strong>) and set all the holidays for the entire month in one go.
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-semibold text-gray-700 mb-1">Select Month</label>
                    <select
                      value={bulkMonth}
                      onChange={(e) => setBulkMonth(Number(e.target.value))}
                      className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:outline-purple-500 bg-white"
                    >
                      {MONTH_NAMES.map((m, idx) => (
                        <option key={m} value={idx + 1}>
                          {m}
                        </option>
                      ))}
                    </select>
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-gray-700 mb-1">Select Year</label>
                    <input
                      type="number"
                      value={bulkYear}
                      onChange={(e) => setBulkYear(Number(e.target.value))}
                      className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:outline-purple-500"
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="block text-xs font-semibold text-gray-700">
                    Holidays to Schedule for {MONTH_NAMES[bulkMonth - 1]} {bulkYear}
                  </label>
                  {bulkEntries.map((entry, idx) => (
                    <div key={idx} className="flex items-center gap-2">
                      <input
                        type="number"
                        min="1"
                        max="31"
                        placeholder="Day"
                        value={entry.day}
                        onChange={(e) => {
                          const val = Number(e.target.value);
                          setBulkEntries((prev) =>
                            prev.map((item, i) => (i === idx ? { ...item, day: val } : item))
                          );
                        }}
                        className="w-16 px-2.5 py-1.5 text-xs border border-gray-300 rounded-lg text-center"
                      />
                      <input
                        type="text"
                        placeholder="Holiday Name"
                        value={entry.title}
                        onChange={(e) => {
                          const val = e.target.value;
                          setBulkEntries((prev) =>
                            prev.map((item, i) => (i === idx ? { ...item, title: val } : item))
                          );
                        }}
                        className="flex-1 px-2.5 py-1.5 text-xs border border-gray-300 rounded-lg"
                      />
                      <select
                        value={entry.type}
                        onChange={(e) => {
                          const val = e.target.value;
                          setBulkEntries((prev) =>
                            prev.map((item, i) => (i === idx ? { ...item, type: val } : item))
                          );
                        }}
                        className="px-2 py-1.5 text-xs border border-gray-300 rounded-lg bg-white"
                      >
                        {HOLIDAY_TYPES.map((t) => (
                          <option key={t} value={t}>
                            {t}
                          </option>
                        ))}
                      </select>
                      <button
                        type="button"
                        onClick={() =>
                          setBulkEntries((prev) => prev.filter((_, i) => i !== idx))
                        }
                        className="text-gray-400 hover:text-red-500 px-1 text-sm cursor-pointer"
                      >
                        ✕
                      </button>
                    </div>
                  ))}

                  <button
                    type="button"
                    onClick={() =>
                      setBulkEntries((prev) => [
                        ...prev,
                        { title: '', day: 1, type: 'Public Holiday' },
                      ])
                    }
                    className="text-xs text-purple-600 hover:underline font-semibold mt-1 cursor-pointer"
                  >
                    + Add another holiday to {MONTH_NAMES[bulkMonth - 1]}
                  </button>
                </div>

                <div className="flex items-center justify-end gap-2 pt-3 border-t border-gray-100">
                  <button
                    type="button"
                    onClick={() => setShowModal(false)}
                    className="px-4 py-2 text-xs font-semibold text-gray-700 hover:bg-gray-100 rounded-lg cursor-pointer"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={submitting}
                    className="px-4 py-2 text-xs font-semibold text-white bg-purple-600 hover:bg-purple-700 rounded-lg shadow-sm disabled:opacity-50 cursor-pointer"
                  >
                    {submitting ? 'Scheduling...' : `Schedule ${MONTH_NAMES[bulkMonth - 1]} Holidays`}
                  </button>
                </div>
              </form>
            )}
          </div>
        </div>
      )}

      {/* Selected Event Details Modal */}
      {selectedEvent && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-xs p-4">
          <div className="bg-white rounded-xl shadow-xl border border-gray-200 w-full max-w-sm p-5 animate-in fade-in zoom-in-95">
            <div className="flex items-start justify-between">
              <span className="text-2xl">
                {selectedEvent.kind === 'holiday' ? '🎉' : '👤'}
              </span>
              <button
                onClick={() => setSelectedEvent(null)}
                className="text-gray-400 hover:text-gray-600 cursor-pointer"
              >
                ✕
              </button>
            </div>

            {selectedEvent.kind === 'holiday' ? (
              <div className="mt-3 space-y-2">
                <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-purple-100 text-purple-700 border border-purple-200">
                  {selectedEvent.data.type || 'Company Holiday'}
                </span>
                <h3 className="text-base font-bold text-gray-900 mt-1">
                  {selectedEvent.data.title}
                </h3>
                <p className="text-xs text-gray-600">
                  📅 {new Date(selectedEvent.data.date).toLocaleDateString('en-GB', {
                    weekday: 'long',
                    day: 'numeric',
                    month: 'long',
                    year: 'numeric',
                  })}
                  {selectedEvent.data.endDate && (
                    <> &ndash; {new Date(selectedEvent.data.endDate).toLocaleDateString('en-GB')}</>
                  )}
                </p>
                {selectedEvent.data.description && (
                  <p className="text-xs text-gray-500 pt-1 border-t border-gray-100">
                    {selectedEvent.data.description}
                  </p>
                )}

                {isAuthorized && (
                  <div className="flex items-center justify-end gap-2 pt-3 border-t border-gray-100 mt-3">
                    <button
                      onClick={() => handleDeleteHoliday(selectedEvent.data._id)}
                      className="px-3 py-1.5 text-xs text-red-600 hover:bg-red-50 rounded-md font-semibold cursor-pointer"
                    >
                      Delete
                    </button>
                    <button
                      onClick={() => openEditModal(selectedEvent.data)}
                      className="px-3 py-1.5 text-xs bg-purple-600 text-white rounded-md font-semibold hover:bg-purple-700 cursor-pointer"
                    >
                      Edit Holiday
                    </button>
                  </div>
                )}
              </div>
            ) : (
              <div className="mt-3 space-y-2">
                <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-blue-100 text-blue-700 border border-blue-200">
                  {selectedEvent.data.leaveType} Leave
                </span>
                <h3 className="text-base font-bold text-gray-900 mt-1">
                  {selectedEvent.data.employee?.name || 'Team Member'}
                </h3>
                <p className="text-xs text-gray-600">
                  📅 {new Date(selectedEvent.data.startDate).toLocaleDateString('en-GB')} &ndash;{' '}
                  {new Date(selectedEvent.data.endDate).toLocaleDateString('en-GB')}
                </p>
                {selectedEvent.data.reason && (
                  <p className="text-xs text-gray-500 pt-1 border-t border-gray-100">
                    Reason: {selectedEvent.data.reason}
                  </p>
                )}
                <div className="flex items-center gap-1.5 text-xs text-emerald-600 font-semibold pt-2">
                  <span>✓</span>
                  <span>Approved Leave</span>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
