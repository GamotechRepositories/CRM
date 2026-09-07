import React, { useEffect, useMemo, useState } from 'react'
import { useParams } from 'react-router-dom'
import api from '../api/axios'
import AdminCompanyShell, { getInitials } from '../components/AdminCompanyShell'
import { TENANT_NAMES } from '../config/tenants'

const AVATAR_COLORS = [
  'bg-violet-500',
  'bg-blue-500',
  'bg-emerald-500',
  'bg-amber-500',
  'bg-rose-500',
  'bg-cyan-500',
  'bg-indigo-500',
  'bg-pink-500',
]

const currentMonthValue = () => {
  const now = new Date()
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`
}

const formatDate = (value) => {
  if (!value) return '—'
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleDateString('en-GB', { weekday: 'short', day: '2-digit', month: 'short', year: 'numeric' })
}

const toDateKey = (value) => {
  if (!value) return ''
  if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)) return value
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return ''
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

const eachDateKeyInRange = (startValue, endValue) => {
  const start = new Date(startValue)
  const end = new Date(endValue)
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) return []
  start.setHours(12, 0, 0, 0)
  end.setHours(12, 0, 0, 0)
  const keys = []
  for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
    keys.push(toDateKey(d))
  }
  return keys
}

const findLeaveForEmployeeOnDay = (leaves, employeeId, dateKey) => {
  const day = new Date(`${dateKey}T12:00:00`)
  if (Number.isNaN(day.getTime())) return null
  return (
    leaves.find((leave) => {
      if (String(leave.employee?._id || leave.employee) !== String(employeeId)) return false
      const start = new Date(leave.startDate)
      const end = new Date(leave.endDate)
      if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) return false
      start.setHours(0, 0, 0, 0)
      end.setHours(23, 59, 59, 999)
      return day >= start && day <= end
    }) || null
  )
}

const formatAttendanceTime = (value) => {
  if (!value) return '—'
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
}

const getMapsUrl = (latitude, longitude) => {
  const lat = Number(latitude)
  const lon = Number(longitude)
  if (Number.isNaN(lat) || Number.isNaN(lon)) return null
  return `https://www.google.com/maps?q=${lat},${lon}`
}

const trackedMinutesFromRow = (row, startedAtKey, totalMinutesKey, nowMs = Date.now()) => {
  const savedMinutes = Number(row?.[totalMinutesKey]) || 0
  const startedAt = row?.[startedAtKey]
  if (!startedAt) return savedMinutes
  const startMs = new Date(startedAt).getTime()
  if (Number.isNaN(startMs)) return savedMinutes
  return savedMinutes + Math.max(0, (nowMs - startMs) / (1000 * 60))
}

const durationMsFromRow = (row, nowMs = Date.now()) => {
  if (!row?.checkIn) return null
  const start = new Date(row.checkIn).getTime()
  if (Number.isNaN(start)) return null
  const end = row.checkOut ? new Date(row.checkOut).getTime() : nowMs
  if (row.checkOut && Number.isNaN(end)) return null
  const breakMinutes = trackedMinutesFromRow(row, 'breakStartedAt', 'breakDurationMinutes', nowMs)
  return Math.max(0, end - start - breakMinutes * 60 * 1000)
}

const formatDurationClock = (ms) => {
  if (ms == null) return '—'
  const totalSeconds = Math.floor(ms / 1000)
  const hours = Math.floor(totalSeconds / 3600)
  const minutes = Math.floor((totalSeconds % 3600) / 60)
  const seconds = totalSeconds % 60
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`
}

const getTodayDateKey = () => {
  const now = new Date()
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
}

const getDaysInMonth = (monthKey) => {
  if (!/^\d{4}-\d{2}$/.test(monthKey || '')) return []
  const [y, m] = monthKey.split('-').map(Number)
  const count = new Date(y, m, 0).getDate()
  return Array.from({ length: count }, (_, i) => {
    const day = i + 1
    return `${y}-${String(m).padStart(2, '0')}-${String(day).padStart(2, '0')}`
  })
}

const isLateCheckIn = (checkIn) => {
  if (!checkIn) return false
  const checkInDate = new Date(checkIn)
  if (Number.isNaN(checkInDate.getTime())) return false
  // Office start 10:00 + 15 min grace => late after 10:15
  const checkMinutes = checkInDate.getHours() * 60 + checkInDate.getMinutes()
  return checkMinutes > 10 * 60 + 15
}

const deriveDayStatus = (attendance, onLeave, isFuture) => {
  if (isFuture) return '—'
  if (onLeave) return 'On Leave'
  if (!attendance?.checkIn) return 'Absent'
  if (isLateCheckIn(attendance.checkIn)) return 'Late'
  if (attendance.status === 'In Progress') return 'Present'
  if (attendance.status === 'Full Day' || attendance.status === 'Half Day') return 'Present'
  return attendance.status || 'Present'
}

const formatDuration = (row, nowMs = Date.now()) => {
  if (!row?.checkIn) return '—'
  if (row.durationHours != null && row.checkOut) {
    const hours = Number(row.durationHours)
    if (!Number.isNaN(hours)) return `${hours.toFixed(2)} h`
  }
  const ms = durationMsFromRow(row, nowMs)
  if (ms == null) return '—'
  const totalMinutes = Math.floor(ms / (1000 * 60))
  const hours = Math.floor(totalMinutes / 60)
  const minutes = totalMinutes % 60
  if (hours && minutes) return `${hours}h ${minutes}m`
  if (hours) return `${hours}h`
  return `${minutes}m`
}

const LocationDisplay = ({ address, latitude, longitude, compact = false }) => {
  const label = String(address || '').trim()
  if (!label) return <span className='text-gray-400 text-xs'>—</span>

  const mapsUrl = getMapsUrl(latitude, longitude)
  const content = (
    <span className={`block text-xs text-gray-600 leading-snug break-words ${compact ? 'max-w-[220px]' : 'max-w-[240px]'}`}>
      {label}
    </span>
  )

  if (!mapsUrl) return <div className={compact ? '' : 'mt-1'}>{content}</div>

  return (
    <a
      href={mapsUrl}
      target='_blank'
      rel='noopener noreferrer'
      className={`inline-flex items-start gap-1 text-blue-600 hover:text-blue-800 hover:underline ${compact ? '' : 'mt-1'}`}
      title='Open in Google Maps'
      onClick={(e) => e.stopPropagation()}
    >
      <span className='shrink-0'>📍</span>
      {content}
    </a>
  )
}

const EmployeeCell = ({ employee, colorIndex = 0 }) => {
  const [imgError, setImgError] = useState(false)
  const name = employee?.name || '—'
  const email = employee?.email || '—'
  const photo = String(employee?.profilePhoto || '').trim()
  const showPhoto = Boolean(photo) && !imgError

  return (
    <div className='flex items-center gap-3 min-w-[200px]'>
      {showPhoto ? (
        <img
          src={photo}
          alt={name}
          className='w-10 h-10 rounded-full object-cover shrink-0 border border-gray-200'
          onError={() => setImgError(true)}
        />
      ) : (
        <div className={`w-10 h-10 rounded-full flex items-center justify-center text-xs font-bold text-white shrink-0 ${AVATAR_COLORS[colorIndex % AVATAR_COLORS.length]}`}>
          {getInitials(name)}
        </div>
      )}
      <div className='min-w-0'>
        <p className='font-medium text-gray-900 truncate'>{name}</p>
        <p className='text-xs text-gray-400 truncate'>{email}</p>
      </div>
    </div>
  )
}

const CheckCell = ({ time, address, latitude, longitude }) => (
  <div className='min-w-[180px]'>
    <p className='font-mono text-sm font-semibold text-gray-900 tabular-nums'>{formatAttendanceTime(time)}</p>
    <LocationDisplay address={address} latitude={latitude} longitude={longitude} />
  </div>
)

const HoursCell = ({ row, clock = false }) => {
  const [now, setNow] = useState(() => Date.now())
  const isOpen = Boolean(row?.checkIn && !row?.checkOut)

  useEffect(() => {
    if (!isOpen) return undefined
    const id = window.setInterval(() => setNow(Date.now()), 1000)
    return () => window.clearInterval(id)
  }, [isOpen])

  const breakMinutes = trackedMinutesFromRow(row, 'breakStartedAt', 'breakDurationMinutes', now)

  if (!row?.checkIn) return <span className='text-xs text-gray-400'>—</span>

  const ms = durationMsFromRow(row, now)

  return (
    <div className='min-w-[90px]'>
      <p className='font-mono text-sm font-semibold text-gray-900 tabular-nums'>
        {clock ? formatDurationClock(ms) : formatDuration(row, now)}
      </p>
      {!clock && breakMinutes > 0 && (
        <p className='text-[11px] text-gray-400 mt-0.5'>Break: {Math.round(breakMinutes)}m</p>
      )}
      {!clock && isOpen && <p className='text-[11px] text-blue-600 mt-0.5'>In progress</p>}
    </div>
  )
}

const statusClass = (status) => {
  const s = String(status || '').toLowerCase()
  if (s.includes('full day') || s.includes('present')) return 'bg-emerald-50 text-emerald-700'
  if (s.includes('late') || s.includes('half')) return 'bg-amber-50 text-amber-700'
  if (s.includes('progress')) return 'bg-blue-50 text-blue-700'
  if (s.includes('leave')) return 'bg-violet-50 text-violet-700'
  if (s.includes('absent')) return 'bg-rose-50 text-rose-700'
  return 'bg-slate-50 text-slate-600'
}

const StatCard = ({ label, value }) => (
  <div className='rounded-2xl border border-gray-100 bg-white shadow-sm px-4 py-3'>
    <p className='text-xs text-gray-500'>{label}</p>
    <p className='text-2xl font-bold text-gray-900 mt-0.5 tabular-nums'>{value}</p>
  </div>
)

const AttendancePage = () => {
  const { tenantId } = useParams()
  const [selectedMonth, setSelectedMonth] = useState(currentMonthValue())
  const [employeeSearch, setEmployeeSearch] = useState('')
  const [employeeId, setEmployeeId] = useState('')
  const [debouncedSearch, setDebouncedSearch] = useState('')
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    const timer = window.setTimeout(() => setDebouncedSearch(employeeSearch.trim()), 300)
    return () => window.clearTimeout(timer)
  }, [employeeSearch])

  useEffect(() => {
    let cancelled = false
    const load = async () => {
      if (!TENANT_NAMES[tenantId]) {
        setError('Unknown company')
        setLoading(false)
        return
      }
      try {
        setLoading(true)
        setError('')
        const params = { month: selectedMonth }
        if (employeeId) params.employeeId = employeeId
        else if (debouncedSearch) params.employee = debouncedSearch
        const res = await api.get(`/companies/${tenantId}/modules/attendance`, { params })
        if (!cancelled) setData(res.data)
      } catch (err) {
        if (!cancelled) {
          setError(err.response?.data?.message || err.message || 'Failed to load attendance')
          setData(null)
        }
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    load()
    return () => {
      cancelled = true
    }
  }, [tenantId, selectedMonth, employeeId, debouncedSearch])

  const items = data?.items || []
  const employees = data?.employees || []
  const leaves = data?.leaves || []
  const summary = data?.summary || {}
  const selectedEmployee = useMemo(
    () => employees.find((emp) => String(emp._id) === String(employeeId)) || null,
    [employees, employeeId],
  )
  const showMonthlyEmployeeView = Boolean(employeeId && selectedEmployee)

  const rosterEmployees = useMemo(() => {
    if (employeeId) {
      return employees.filter((emp) => String(emp._id) === String(employeeId))
    }
    if (debouncedSearch) {
      const q = debouncedSearch.toLowerCase()
      return employees.filter((emp) => String(emp.name || '').toLowerCase().includes(q))
    }
    return employees
  }, [employees, employeeId, debouncedSearch])

  const monthlyRows = useMemo(() => {
    if (!showMonthlyEmployeeView || !selectedMonth) return []
    const todayKey = getTodayDateKey()
    const attendanceByDay = new Map()
    for (const row of items) {
      const dateKey = toDateKey(row.date)
      if (!dateKey) continue
      attendanceByDay.set(dateKey, row)
    }

    return getDaysInMonth(selectedMonth).map((dateKey) => {
      const att = attendanceByDay.get(dateKey) || null
      const leave = findLeaveForEmployeeOnDay(leaves, selectedEmployee._id, dateKey)
      const isFuture = dateKey > todayKey
      const status = deriveDayStatus(att, Boolean(leave), isFuture)
      return {
        dateKey,
        att,
        leave,
        status,
        isFuture,
      }
    })
  }, [showMonthlyEmployeeView, selectedMonth, items, leaves, selectedEmployee])

  const groupedByDate = useMemo(() => {
    if (showMonthlyEmployeeView) return []

    const attendanceMap = new Map()
    const dateKeys = new Set()

    for (const row of items) {
      const dateKey = toDateKey(row.date)
      const empId = String(row.employee?._id || row.employee || '')
      if (!dateKey || !empId) continue
      dateKeys.add(dateKey)
      attendanceMap.set(`${dateKey}|${empId}`, row)
    }

    for (const leave of leaves) {
      const empId = String(leave.employee?._id || leave.employee || '')
      if (!empId) continue
      for (const dateKey of eachDateKeyInRange(leave.startDate, leave.endDate)) {
        if (selectedMonth && !dateKey.startsWith(selectedMonth)) continue
        dateKeys.add(dateKey)
      }
    }

    const sortedDateKeys = [...dateKeys].sort((a, b) => b.localeCompare(a))

    return sortedDateKeys.map((dateKey) => {
      const rows = rosterEmployees
        .map((emp) => {
          const existing = attendanceMap.get(`${dateKey}|${String(emp._id)}`)
          if (existing) {
            return {
              ...existing,
              employee: existing.employee?._id ? existing.employee : emp,
            }
          }
          const leave = findLeaveForEmployeeOnDay(leaves, emp._id, dateKey)
          if (leave) {
            return {
              _id: `leave-${dateKey}-${emp._id}`,
              synthetic: true,
              employee: emp,
              date: `${dateKey}T12:00:00`,
              status: 'On Leave',
              leaveType: leave.leaveType || 'Leave',
              checkIn: null,
              checkOut: null,
            }
          }
          return {
            _id: `absent-${dateKey}-${emp._id}`,
            synthetic: true,
            employee: emp,
            date: `${dateKey}T12:00:00`,
            status: 'Absent',
            checkIn: null,
            checkOut: null,
          }
        })
        .sort((a, b) => String(a.employee?.name || '').localeCompare(String(b.employee?.name || '')))

      return [formatDate(dateKey), rows]
    })
  }, [showMonthlyEmployeeView, items, leaves, rosterEmployees, selectedMonth])

  const displaySummary = useMemo(() => {
    if (showMonthlyEmployeeView) {
      const rows = monthlyRows.filter((r) => !r.isFuture)
      return {
        totalRecords: rows.length,
        fullDay: rows.filter((r) => r.status === 'Present').length,
        halfDay: rows.filter((r) => r.status === 'Late').length,
        absent: rows.filter((r) => r.status === 'Absent').length,
        inProgress: rows.filter((r) => r.att?.status === 'In Progress').length,
        onLeave: rows.filter((r) => r.status === 'On Leave').length,
        uniqueEmployees: 1,
        present: rows.filter((r) => r.status === 'Present').length,
        late: rows.filter((r) => r.status === 'Late').length,
      }
    }

    let fullDay = 0
    let halfDay = 0
    let absent = 0
    let inProgress = 0
    let onLeave = 0
    let totalRecords = 0
    for (const [, rows] of groupedByDate) {
      for (const row of rows) {
        totalRecords += 1
        const status = String(row.status || '')
        if (status === 'Full Day') fullDay += 1
        else if (status === 'Half Day') halfDay += 1
        else if (status === 'In Progress') inProgress += 1
        else if (status === 'On Leave') onLeave += 1
        else if (status === 'Absent') absent += 1
      }
    }
    return {
      totalRecords,
      fullDay,
      halfDay,
      absent,
      inProgress,
      onLeave,
      uniqueEmployees: rosterEmployees.length || summary.uniqueEmployees || 0,
    }
  }, [showMonthlyEmployeeView, monthlyRows, groupedByDate, rosterEmployees.length, summary.uniqueEmployees])

  const clearEmployeeFilter = () => {
    setEmployeeId('')
    setEmployeeSearch('')
  }

  const selectedEmployeeColorIndex = String(selectedEmployee?._id || '')
    .split('')
    .reduce((sum, ch) => sum + ch.charCodeAt(0), 0)

  return (
    <AdminCompanyShell activeNav='attendance'>
      <div className='flex flex-wrap items-start justify-between gap-4 mb-6'>
        <div>
          <h1 className='text-2xl font-bold text-gray-900'>Attendance</h1>
          <p className='text-sm text-gray-500 mt-1'>
            {TENANT_NAMES[tenantId]} · {data?.monthLabel || selectedMonth}
            {employeeId || debouncedSearch
              ? ` · filtered by ${employeeId ? selectedEmployee?.name || 'employee' : `"${debouncedSearch}"`}`
              : ''}
          </p>
        </div>
        <div className='flex flex-wrap items-center gap-2'>
          <label htmlFor='attendance-month' className='text-sm text-gray-600'>Month</label>
          <input
            id='attendance-month'
            type='month'
            value={selectedMonth}
            onChange={(e) => setSelectedMonth(e.target.value || currentMonthValue())}
            className='rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
          />
          <input
            type='search'
            value={employeeSearch}
            onChange={(e) => {
              setEmployeeSearch(e.target.value)
              setEmployeeId('')
            }}
            placeholder='Filter by employee name…'
            className='w-56 max-w-full rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
          />
          <select
            value={employeeId}
            onChange={(e) => {
              setEmployeeId(e.target.value)
              if (e.target.value) setEmployeeSearch('')
            }}
            className='rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 min-w-[180px]'
          >
            <option value=''>All employees</option>
            {employees.map((emp) => (
              <option key={emp._id} value={emp._id}>{emp.name}</option>
            ))}
          </select>
          {(employeeId || employeeSearch) && (
            <button
              type='button'
              onClick={clearEmployeeFilter}
              className='rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm text-gray-600 hover:bg-slate-50'
            >
              Clear filter
            </button>
          )}
        </div>
      </div>

      {error && (
        <div className='mb-4 rounded-xl bg-red-50 border border-red-100 px-3 py-2 text-sm text-red-600'>{error}</div>
      )}

      <div className='grid grid-cols-2 md:grid-cols-3 xl:grid-cols-6 gap-3 mb-5'>
        {showMonthlyEmployeeView ? (
          <>
            <StatCard label='Days' value={displaySummary.totalRecords ?? 0} />
            <StatCard label='Present' value={displaySummary.present ?? 0} />
            <StatCard label='Late' value={displaySummary.late ?? 0} />
            <StatCard label='Absent' value={displaySummary.absent ?? 0} />
            <StatCard label='On leave' value={displaySummary.onLeave ?? 0} />
            <StatCard label='In progress' value={displaySummary.inProgress ?? 0} />
          </>
        ) : (
          <>
            <StatCard label='Records' value={displaySummary.totalRecords ?? 0} />
            <StatCard label='Employees' value={displaySummary.uniqueEmployees ?? 0} />
            <StatCard label='Full day' value={displaySummary.fullDay ?? 0} />
            <StatCard label='Half day' value={displaySummary.halfDay ?? 0} />
            <StatCard label='In progress' value={displaySummary.inProgress ?? 0} />
            <StatCard label='Absent' value={displaySummary.absent ?? 0} />
          </>
        )}
      </div>

      {loading ? (
        <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-10 text-center text-sm text-gray-500'>
          Loading attendance…
        </div>
      ) : showMonthlyEmployeeView ? (
        <div className='bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden'>
          <div className='px-5 py-4 border-b border-gray-100 flex items-center gap-3'>
            {String(selectedEmployee.profilePhoto || '').trim() ? (
              <img
                src={selectedEmployee.profilePhoto}
                alt={selectedEmployee.name}
                className='w-11 h-11 rounded-full object-cover border border-gray-200 shrink-0'
              />
            ) : (
              <div className={`w-11 h-11 rounded-full flex items-center justify-center text-sm font-bold text-white shrink-0 ${AVATAR_COLORS[selectedEmployeeColorIndex % AVATAR_COLORS.length]}`}>
                {getInitials(selectedEmployee.name)}
              </div>
            )}
            <div className='min-w-0'>
              <h2 className='text-base font-semibold text-gray-900'>
                Monthly Attendance · {data?.monthLabel || selectedMonth}
              </h2>
              <p className='text-sm text-gray-500 mt-0.5'>
                {selectedEmployee.name}
                {selectedEmployee.employeeCode ? ` · ${selectedEmployee.employeeCode}` : ''}
              </p>
            </div>
          </div>
          <div className='overflow-x-auto'>
            <table className='min-w-full text-sm'>
              <thead className='text-left text-xs uppercase tracking-wide text-gray-500 border-b border-gray-100 bg-slate-50'>
                <tr>
                  <th className='px-4 py-3 font-semibold'>Date</th>
                  <th className='px-4 py-3 font-semibold'>Day</th>
                  <th className='px-4 py-3 font-semibold'>Check in time</th>
                  <th className='px-4 py-3 font-semibold'>Check out time</th>
                  <th className='px-4 py-3 font-semibold min-w-[180px]'>Check in location</th>
                  <th className='px-4 py-3 font-semibold min-w-[180px]'>Check out location</th>
                  <th className='px-4 py-3 font-semibold'>Duration</th>
                  <th className='px-4 py-3 font-semibold'>Status</th>
                </tr>
              </thead>
              <tbody className='divide-y divide-gray-50'>
                {monthlyRows.map(({ dateKey, att, status, isFuture }) => {
                  const dayDate = new Date(`${dateKey}T12:00:00`)
                  return (
                    <tr key={dateKey} className={`hover:bg-slate-50/70 ${isFuture ? 'opacity-50' : ''}`}>
                      <td className='px-4 py-3 whitespace-nowrap text-gray-900'>
                        {dayDate.toLocaleDateString('en-IN')}
                      </td>
                      <td className='px-4 py-3 text-gray-600'>
                        {dayDate.toLocaleDateString('en-IN', { weekday: 'short' })}
                      </td>
                      <td className='px-4 py-3 font-mono whitespace-nowrap tabular-nums'>
                        {formatAttendanceTime(att?.checkIn)}
                      </td>
                      <td className='px-4 py-3 font-mono whitespace-nowrap tabular-nums'>
                        {formatAttendanceTime(att?.checkOut)}
                      </td>
                      <td className='px-4 py-3 align-top'>
                        <LocationDisplay
                          address={att?.checkInAddress}
                          latitude={att?.checkInLatitude}
                          longitude={att?.checkInLongitude}
                          compact
                        />
                      </td>
                      <td className='px-4 py-3 align-top'>
                        <LocationDisplay
                          address={att?.checkOutAddress}
                          latitude={att?.checkOutLatitude}
                          longitude={att?.checkOutLongitude}
                          compact
                        />
                      </td>
                      <td className='px-4 py-3 align-top'>
                        <HoursCell row={att} clock />
                      </td>
                      <td className='px-4 py-3'>
                        {isFuture ? (
                          <span className='text-gray-400'>—</span>
                        ) : (
                          <span className={`inline-flex px-2 py-0.5 rounded-md text-xs font-medium ${statusClass(status)}`}>
                            {status}
                          </span>
                        )}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        </div>
      ) : groupedByDate.length === 0 ? (
        <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-10 text-center text-sm text-gray-500'>
          No attendance records for this month{employeeId || debouncedSearch ? ' matching your filter' : ''}.
        </div>
      ) : (
        <div className='space-y-4'>
          {groupedByDate.map(([dateLabel, rows]) => (
            <div key={dateLabel} className='bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden'>
              <div className='px-4 py-3 border-b border-gray-100 bg-slate-50'>
                <h2 className='text-sm font-semibold text-gray-900'>{dateLabel}</h2>
                <p className='text-xs text-gray-500 mt-0.5'>
                  {rows.length} employee{rows.length === 1 ? '' : 's'}
                  {' · '}
                  {rows.filter((r) => r.status === 'Absent').length} absent
                  {' · '}
                  {rows.filter((r) => r.status === 'On Leave').length} on leave
                </p>
              </div>
              <div className='overflow-x-auto'>
                <table className='min-w-full text-sm'>
                  <thead className='text-left text-xs uppercase tracking-wide text-gray-500 border-b border-gray-100'>
                    <tr>
                      <th className='px-4 py-3 font-semibold'>Employee</th>
                      <th className='px-4 py-3 font-semibold'>Department</th>
                      <th className='px-4 py-3 font-semibold'>Status</th>
                      <th className='px-4 py-3 font-semibold min-w-[190px]'>Check in</th>
                      <th className='px-4 py-3 font-semibold min-w-[190px]'>Check out</th>
                      <th className='px-4 py-3 font-semibold'>Hours worked</th>
                    </tr>
                  </thead>
                  <tbody className='divide-y divide-gray-50'>
                    {rows.map((row, rowIndex) => {
                      const employeeKey = String(row.employee?._id || row.employee || rowIndex)
                      const colorIndex = employeeKey.split('').reduce((sum, ch) => sum + ch.charCodeAt(0), 0)
                      return (
                      <tr key={row._id} className='hover:bg-slate-50/70'>
                        <td className='px-4 py-3'>
                          <EmployeeCell employee={row.employee} colorIndex={colorIndex} />
                        </td>
                        <td className='px-4 py-3 text-gray-600'>{row.employee?.department || '—'}</td>
                        <td className='px-4 py-3'>
                          <span className={`inline-flex px-2 py-0.5 rounded-md text-xs font-medium ${statusClass(row.status)}`}>
                            {row.status || '—'}
                          </span>
                          {row.status === 'On Leave' && row.leaveType ? (
                            <p className='text-[11px] text-gray-400 mt-1'>{row.leaveType}</p>
                          ) : null}
                        </td>
                        <td className='px-4 py-3 align-top'>
                          {row.synthetic && !row.checkIn ? (
                            <span className='text-xs text-gray-400'>—</span>
                          ) : (
                            <CheckCell
                              time={row.checkIn}
                              address={row.checkInAddress}
                              latitude={row.checkInLatitude}
                              longitude={row.checkInLongitude}
                            />
                          )}
                        </td>
                        <td className='px-4 py-3 align-top'>
                          {row.synthetic && !row.checkOut ? (
                            <span className='text-xs text-gray-400'>—</span>
                          ) : (
                            <CheckCell
                              time={row.checkOut}
                              address={row.checkOutAddress}
                              latitude={row.checkOutLatitude}
                              longitude={row.checkOutLongitude}
                            />
                          )}
                        </td>
                        <td className='px-4 py-3 align-top'>
                          {row.synthetic && !row.checkIn ? (
                            <span className='text-xs text-gray-400'>—</span>
                          ) : (
                            <HoursCell row={row} />
                          )}
                        </td>
                      </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
            </div>
          ))}
        </div>
      )}
    </AdminCompanyShell>
  )
}

export default AttendancePage
