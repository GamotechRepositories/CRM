import React, { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../api/axios'

const toLocalYmd = (d = new Date()) => {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

const formatDuration = (totalMinutes) => {
  const mins = Math.max(0, Math.round(Number(totalMinutes) || 0))
  if (mins === 0) return '0m'
  const h = Math.floor(mins / 60)
  const m = mins % 60
  if (h === 0) return `${m}m`
  if (m === 0) return `${h}h`
  return `${h}h ${m}m`
}

const formatClock = (value) => {
  if (!value) return '—'
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleTimeString('en-IN', { hour: 'numeric', minute: '2-digit', hour12: true })
}

const matchesDateYmd = (value, targetYmd) => {
  if (!value || !targetYmd) return false
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return false
  return toLocalYmd(d) === targetYmd || d.toISOString().slice(0, 10) === targetYmd
}

const STATUS_BADGE = {
  'In Meeting': 'bg-purple-50 text-purple-700 border-purple-200',
  'On Break': 'bg-amber-50 text-amber-700 border-amber-200',
  Working: 'bg-emerald-50 text-emerald-700 border-emerald-200',
  'Checked Out': 'bg-slate-100 text-slate-700 border-slate-200',
  'Not Checked In': 'bg-gray-50 text-gray-500 border-gray-200',
}

const STATUS_DOT = {
  'In Meeting': 'bg-purple-500',
  'On Break': 'bg-amber-500',
  Working: 'bg-emerald-500',
  'Checked Out': 'bg-slate-400',
  'Not Checked In': 'bg-gray-300',
}

const STATUS_SORT_ORDER = {
  Working: 1,
  'In Meeting': 2,
  'On Break': 3,
  'Checked Out': 4,
  'Not Checked In': 5,
}

/**
 * Displays employee-wise daily working hours, break time, and meeting time
 * for Admins, Managers, and Team Leaders.
 */
const EmployeeTimeUtilizationCard = ({
  employees = [],
  title = 'Employee Daily Activity & Time Utilization',
  subtitle = 'Working hours, break time, and meeting time per employee',
}) => {
  const navigate = useNavigate()
  const todayYmd = useMemo(() => toLocalYmd(new Date()), [])
  const [selectedDate, setSelectedDate] = useState(todayYmd)
  const [attendanceRecords, setAttendanceRecords] = useState([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('All')
  const [nowTick, setNowTick] = useState(() => Date.now())

  useEffect(() => {
    if (selectedDate !== todayYmd) return
    const timer = setInterval(() => setNowTick(Date.now()), 30000)
    return () => clearInterval(timer)
  }, [selectedDate, todayYmd])

  useEffect(() => {
    let active = true
    const load = async () => {
      try {
        setLoading(true)
        const endpoint = selectedDate === todayYmd ? '/attendance/today' : '/attendance'
        const res = await api.get(endpoint).catch(() => ({ data: [] }))
        if (!active) return
        const raw = Array.isArray(res.data) ? res.data : res.data?.data || []
        const filtered =
          selectedDate === todayYmd
            ? raw
            : raw.filter((a) => matchesDateYmd(a.date || a.checkIn || a.createdAt, selectedDate))
        setAttendanceRecords(filtered)
      } finally {
        if (active) setLoading(false)
      }
    }
    load()
    return () => {
      active = false
    }
  }, [selectedDate, todayYmd])

  const activeEmployees = useMemo(
    () => (Array.isArray(employees) ? employees.filter((e) => e && e.status !== 'Inactive') : []),
    [employees]
  )

  const rows = useMemo(() => {
    const isViewingToday = selectedDate === todayYmd
    const byEmpId = new Map()
    attendanceRecords.forEach((a) => {
      const eid = String(a.employee?._id || a.employee || '')
      if (!eid) return
      const existing = byEmpId.get(eid)
      if (!existing || new Date(a.updatedAt || a.checkIn || 0) > new Date(existing.updatedAt || existing.checkIn || 0)) {
        byEmpId.set(eid, a)
      }
    })

    return activeEmployees
      .map((emp) => {
        const eid = String(emp._id || emp.id || '')
        const att = byEmpId.get(eid)

        let breakMins = Number(att?.breakDurationMinutes) || 0
        if (att?.breakStartedAt && !att?.checkOut && isViewingToday) {
          breakMins += Math.max(0, Math.floor((nowTick - new Date(att.breakStartedAt).getTime()) / 60000))
        }

        let meetingMins = Number(att?.meetingDurationMinutes) || 0
        if (att?.meetingStartedAt && !att?.checkOut && isViewingToday) {
          meetingMins += Math.max(0, Math.floor((nowTick - new Date(att.meetingStartedAt).getTime()) / 60000))
        }

        let totalSpanMins = 0
        if (att?.checkIn) {
          const startMs = new Date(att.checkIn).getTime()
          const endMs = att.checkOut
            ? new Date(att.checkOut).getTime()
            : isViewingToday
              ? nowTick
              : startMs
          if (!Number.isNaN(startMs) && !Number.isNaN(endMs) && endMs > startMs) {
            totalSpanMins = Math.floor((endMs - startMs) / 60000)
          } else if (Number(att.durationHours) > 0) {
            totalSpanMins = Math.round(Number(att.durationHours) * 60)
          }
        } else if (Number(att?.durationHours) > 0) {
          totalSpanMins = Math.round(Number(att.durationHours) * 60)
        }

        const workingMins = Math.max(0, totalSpanMins - breakMins)

        let activityStatus = 'Not Checked In'
        if (att?.checkOut) activityStatus = 'Checked Out'
        else if (att?.meetingStartedAt) activityStatus = 'In Meeting'
        else if (att?.breakStartedAt) activityStatus = 'On Break'
        else if (att?.checkIn) activityStatus = 'Working'

        const totalTracked = workingMins + breakMins
        const meetingShare = totalTracked > 0 ? Math.min(100, Math.round((meetingMins / totalTracked) * 100)) : 0
        const breakShare = totalTracked > 0 ? Math.min(100 - meetingShare, Math.round((breakMins / totalTracked) * 100)) : 0
        const focusedWorkMins = Math.max(0, workingMins - meetingMins)
        const workShare = totalTracked > 0 ? Math.max(0, 100 - meetingShare - breakShare) : 0

        return {
          id: eid,
          name: emp.name || '—',
          role: emp.designation?.title || emp.designation?.name || '—',
          department: emp.department || emp.designation?.department || '—',
          checkIn: att?.checkIn || null,
          checkOut: att?.checkOut || null,
          workingMins,
          focusedWorkMins,
          breakMins,
          meetingMins,
          activityStatus,
          workShare,
          meetingShare,
          breakShare,
          isBreakActive: Boolean(att?.breakStartedAt && !att?.checkOut),
          isMeetingActive: Boolean(att?.meetingStartedAt && !att?.checkOut),
        }
      })
      .sort((a, b) => {
        const ordDiff = (STATUS_SORT_ORDER[a.activityStatus] || 9) - (STATUS_SORT_ORDER[b.activityStatus] || 9)
        if (ordDiff !== 0) return ordDiff
        return b.workingMins - a.workingMins || a.name.localeCompare(b.name)
      })
  }, [activeEmployees, attendanceRecords, selectedDate, todayYmd, nowTick])

  const summary = useMemo(() => {
    let checkedIn = 0
    let working = 0
    let onBreak = 0
    let inMeeting = 0
    let totalWorkMins = 0
    let totalBreakMins = 0
    let totalMeetingMins = 0

    rows.forEach((r) => {
      if (r.checkIn) checkedIn++
      if (r.activityStatus === 'Working') working++
      if (r.activityStatus === 'On Break') onBreak++
      if (r.activityStatus === 'In Meeting') inMeeting++
      totalWorkMins += r.workingMins
      totalBreakMins += r.breakMins
      totalMeetingMins += r.meetingMins
    })

    return { checkedIn, working, onBreak, inMeeting, totalWorkMins, totalBreakMins, totalMeetingMins }
  }, [rows])

  const filteredRows = useMemo(() => {
    const q = search.trim().toLowerCase()
    return rows.filter((r) => {
      if (statusFilter !== 'All' && r.activityStatus !== statusFilter) return false
      if (!q) return true
      return (
        r.name.toLowerCase().includes(q) ||
        r.role.toLowerCase().includes(q) ||
        r.department.toLowerCase().includes(q)
      )
    })
  }, [rows, search, statusFilter])

  return (
    <div className='bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden'>
      <div className='px-5 py-4 border-b border-gray-100 flex flex-wrap items-center justify-between gap-3'>
        <div>
          <h3 className='text-sm font-bold text-gray-900'>{title}</h3>
          <p className='text-xs text-gray-500 mt-0.5'>{subtitle}</p>
        </div>
        <div className='flex flex-wrap items-center gap-2'>
          <input
            type='date'
            value={selectedDate}
            onChange={(e) => e.target.value && setSelectedDate(e.target.value)}
            className='border border-gray-200 rounded-lg px-2.5 py-1.5 text-xs text-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-500'
          />
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className='border border-gray-200 rounded-lg px-2.5 py-1.5 text-xs text-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-500'
          >
            <option value='All'>All Status ({rows.length})</option>
            <option value='Working'>Working ({summary.working})</option>
            <option value='In Meeting'>In Meeting ({summary.inMeeting})</option>
            <option value='On Break'>On Break ({summary.onBreak})</option>
            <option value='Checked Out'>Checked Out</option>
            <option value='Not Checked In'>Not Checked In</option>
          </select>
          <input
            type='text'
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder='Search employee...'
            className='border border-gray-200 rounded-lg px-2.5 py-1.5 text-xs text-gray-700 w-40 focus:outline-none focus:ring-2 focus:ring-blue-500'
          />
        </div>
      </div>

      {/* Team Summary Strip */}
      <div className='grid grid-cols-2 sm:grid-cols-4 gap-3 px-5 py-3 bg-slate-50/70 border-b border-gray-100'>
        <div className='rounded-xl bg-white border border-gray-100 px-3 py-2'>
          <p className='text-[11px] text-gray-500 font-medium'>Checked In</p>
          <p className='text-base font-bold text-gray-900 mt-0.5'>
            {summary.checkedIn} <span className='text-xs font-normal text-gray-400'>/ {rows.length}</span>
          </p>
        </div>
        <div className='rounded-xl bg-white border border-emerald-100 px-3 py-2'>
          <p className='text-[11px] text-emerald-700 font-medium'>Total Working Hours</p>
          <p className='text-base font-bold text-emerald-800 mt-0.5'>{formatDuration(summary.totalWorkMins)}</p>
        </div>
        <div className='rounded-xl bg-white border border-amber-100 px-3 py-2'>
          <p className='text-[11px] text-amber-700 font-medium'>Total Break Time</p>
          <p className='text-base font-bold text-amber-800 mt-0.5'>
            {formatDuration(summary.totalBreakMins)}
            {summary.onBreak > 0 && <span className='text-[10px] font-semibold ml-1.5 text-amber-600'>({summary.onBreak} active)</span>}
          </p>
        </div>
        <div className='rounded-xl bg-white border border-purple-100 px-3 py-2'>
          <p className='text-[11px] text-purple-700 font-medium'>Total Meeting Time</p>
          <p className='text-base font-bold text-purple-800 mt-0.5'>
            {formatDuration(summary.totalMeetingMins)}
            {summary.inMeeting > 0 && <span className='text-[10px] font-semibold ml-1.5 text-purple-600'>({summary.inMeeting} active)</span>}
          </p>
        </div>
      </div>

      {loading ? (
        <div className='p-8 text-center text-xs text-gray-500'>Loading employee activity...</div>
      ) : filteredRows.length === 0 ? (
        <div className='p-8 text-center text-xs text-gray-500'>No employees match the selected filters.</div>
      ) : (
        <div className='overflow-x-auto max-h-[420px] overflow-y-auto'>
          <table className='w-full text-xs'>
            <thead className='bg-gray-50 text-gray-500 uppercase text-[10px] tracking-wider sticky top-0 z-10 border-b border-gray-100'>
              <tr>
                <th className='py-2.5 px-4 text-left font-semibold'>Employee</th>
                <th className='py-2.5 px-3 text-left font-semibold'>Status</th>
                <th className='py-2.5 px-3 text-left font-semibold'>Check In / Out</th>
                <th className='py-2.5 px-3 text-right font-semibold'>Working Hours</th>
                <th className='py-2.5 px-3 text-right font-semibold'>Break Time</th>
                <th className='py-2.5 px-3 text-right font-semibold'>Meeting Time</th>
                <th className='py-2.5 px-4 text-left font-semibold min-w-[130px]'>Utilization</th>
                <th className='py-2.5 px-3 text-right font-semibold'>Report</th>
              </tr>
            </thead>
            <tbody className='divide-y divide-gray-100'>
              {filteredRows.map((row) => (
                <tr key={row.id} className='hover:bg-slate-50/80 transition-colors'>
                  <td className='py-2.5 px-4'>
                    <div className='font-semibold text-gray-900'>{row.name}</div>
                    <div className='text-[11px] text-gray-500'>{row.role}</div>
                  </td>
                  <td className='py-2.5 px-3 whitespace-nowrap'>
                    <span
                      className={`inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full border text-[11px] font-semibold ${
                        STATUS_BADGE[row.activityStatus] || STATUS_BADGE['Not Checked In']
                      }`}
                    >
                      <span className={`w-1.5 h-1.5 rounded-full ${STATUS_DOT[row.activityStatus] || 'bg-gray-300'}`} />
                      {row.activityStatus}
                    </span>
                  </td>
                  <td className='py-2.5 px-3 whitespace-nowrap text-gray-600'>
                    <div>In: <span className='font-medium text-gray-800'>{formatClock(row.checkIn)}</span></div>
                    <div>Out: <span className='font-medium text-gray-800'>{formatClock(row.checkOut)}</span></div>
                  </td>
                  <td className='py-2.5 px-3 text-right whitespace-nowrap'>
                    <span className='font-bold text-emerald-700'>{formatDuration(row.workingMins)}</span>
                  </td>
                  <td className='py-2.5 px-3 text-right whitespace-nowrap'>
                    <span className={`font-semibold ${row.isBreakActive ? 'text-amber-700' : 'text-gray-700'}`}>
                      {formatDuration(row.breakMins)}
                    </span>
                  </td>
                  <td className='py-2.5 px-3 text-right whitespace-nowrap'>
                    <span className={`font-semibold ${row.isMeetingActive ? 'text-purple-700' : 'text-gray-700'}`}>
                      {formatDuration(row.meetingMins)}
                    </span>
                  </td>
                  <td className='py-2.5 px-4'>
                    {row.workingMins + row.breakMins > 0 ? (
                      <div>
                        <div className='h-2 w-full rounded-full bg-gray-100 overflow-hidden flex'>
                          {row.workShare > 0 && (
                            <div
                              className='bg-emerald-500 h-full'
                              style={{ width: `${row.workShare}%` }}
                              title={`Work: ${formatDuration(row.focusedWorkMins)}`}
                            />
                          )}
                          {row.meetingShare > 0 && (
                            <div
                              className='bg-purple-500 h-full'
                              style={{ width: `${row.meetingShare}%` }}
                              title={`Meeting: ${formatDuration(row.meetingMins)}`}
                            />
                          )}
                          {row.breakShare > 0 && (
                            <div
                              className='bg-amber-400 h-full'
                              style={{ width: `${row.breakShare}%` }}
                              title={`Break: ${formatDuration(row.breakMins)}`}
                            />
                          )}
                        </div>
                        <div className='flex items-center gap-2 mt-1 text-[10px] text-gray-500'>
                          <span className='inline-flex items-center gap-1'>
                            <span className='w-1.5 h-1.5 rounded-full bg-emerald-500' />Work
                          </span>
                          <span className='inline-flex items-center gap-1'>
                            <span className='w-1.5 h-1.5 rounded-full bg-purple-500' />Meet
                          </span>
                          <span className='inline-flex items-center gap-1'>
                            <span className='w-1.5 h-1.5 rounded-full bg-amber-400' />Break
                          </span>
                        </div>
                      </div>
                    ) : (
                      <span className='text-gray-400'>—</span>
                    )}
                  </td>
                  <td className='py-2.5 px-3 text-right whitespace-nowrap'>
                    <button
                      type='button'
                      onClick={() => navigate(`/daily-task-report?employeeId=${encodeURIComponent(row.id)}&date=${encodeURIComponent(selectedDate)}`)}
                      className='text-blue-600 hover:text-blue-700 font-semibold hover:underline'
                    >
                      Tasks
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

export default EmployeeTimeUtilizationCard
