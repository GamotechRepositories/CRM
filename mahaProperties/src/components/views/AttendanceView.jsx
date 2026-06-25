import React, { useEffect, useState, useRef } from 'react'
import api from '../../api/axios'
import { useAuth } from '../../context/AuthContext'

const formatTime = (ms) => {
  const totalSeconds = Math.floor(ms / 1000)
  const hours = Math.floor(totalSeconds / 3600)
  const minutes = Math.floor((totalSeconds % 3600) / 60)
  const seconds = totalSeconds % 60
  return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
}

/** Elapsed from check-in to check-out, or from check-in to now (live) when still open */
const durationMsFromRow = (row, nowMs = Date.now()) => {
  if (!row?.checkIn) return null
  const start = new Date(row.checkIn).getTime()
  if (Number.isNaN(start)) return null
  const end = row.checkOut ? new Date(row.checkOut).getTime() : nowMs
  if (row.checkOut && Number.isNaN(end)) return null
  return Math.max(0, end - start)
}

const hoursFromAttendanceRow = (row, nowMs = Date.now()) => {
  const ms = durationMsFromRow(row, nowMs)
  return ms == null ? 0 : ms / (1000 * 60 * 60)
}

function DurationCell({ row }) {
  const [now, setNow] = useState(() => Date.now())
  const isOpen = Boolean(row?.checkIn && !row.checkOut)

  useEffect(() => {
    if (!isOpen) return
    const id = setInterval(() => setNow(Date.now()), 1000)
    return () => clearInterval(id)
  }, [isOpen])

  if (!row?.checkIn) return <span>—</span>

  const ms = durationMsFromRow(row, now)
  if (ms == null) return <span>—</span>
  return (
    <span className='font-mono tabular-nums' title={row.checkOut ? 'Time from check-in to check-out' : 'Live time since check-in'}>
      {formatTime(ms)}
    </span>
  )
}

const AttendanceView = () => {
  const { user, hasFullAccess } = useAuth()
  const isHR = hasFullAccess()
  const [activeTab, setActiveTab] = useState(() => (isHR ? 'employees' : 'my'))
  const [employeesViewMode, setEmployeesViewMode] = useState('day') // 'day' | 'month'
  const [selectedDate, setSelectedDate] = useState(() => {
    const d = new Date()
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
  })
  const [employees, setEmployees] = useState([])
  const [attendances, setAttendances] = useState([]) // table data (day or month depending on view)
  const [monthAttendances, setMonthAttendances] = useState([]) // always month data for employee summary
  const [selectedEmployee, setSelectedEmployee] = useState('')
  const [selectedMonth, setSelectedMonth] = useState(() => {
    const d = new Date()
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
  })
  const [filterEmployeeId, setFilterEmployeeId] = useState('')
  const [checkInTime, setCheckInTime] = useState(null)
  const [elapsedMs, setElapsedMs] = useState(0)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const timerRef = useRef(null)

  const fetchEmployees = async () => {
    try {
      const res = await api.get('/employees')
      const payload = res.data
      setEmployees(Array.isArray(payload) ? payload : payload?.data || [])
    } catch (err) {
      console.error('Failed to fetch employees:', err)
    }
  }

  const fetchAttendanceByMonth = async () => {
    try {
      const params = { month: selectedMonth }
      if (!isHR && user?._id) params.employeeId = user._id
      const res = await api.get('/attendance/by-month', { params })
      const payload = res.data
      const rows = Array.isArray(payload) ? payload : []
      setAttendances(rows)
      if (isHR) setMonthAttendances(rows)
    } catch (err) {
      console.error('Failed to fetch attendance:', err)
    }
  }

  const fetchMonthAttendancesForSummary = async () => {
    if (!isHR) return
    try {
      const params = { month: selectedMonth }
      const res = await api.get('/attendance/by-month', { params })
      const payload = res.data
      setMonthAttendances(Array.isArray(payload) ? payload : [])
    } catch (err) {
      console.error('Failed to fetch month attendance summary:', err)
    }
  }

  const fetchAttendanceByDay = async () => {
    try {
      const params = { date: selectedDate }
      if (!isHR && user?._id) params.employeeId = user._id
      if (isHR && filterEmployeeId) params.employeeId = filterEmployeeId
      const res = await api.get('/attendance/today', { params })
      const payload = res.data
      setAttendances(Array.isArray(payload) ? payload : [])
    } catch (err) {
      console.error('Failed to fetch attendance:', err)
    }
  }

  const syncActiveSessionFromServer = async () => {
    if (!user?._id) return
    try {
      const res = await api.get('/attendance/today', { params: { employeeId: user._id } })
      const rows = Array.isArray(res.data) ? res.data : []
      const active = rows.find((r) => r.checkIn && !r.checkOut)
      if (active?.checkIn) {
        const ci = new Date(active.checkIn)
        setCheckInTime(ci)
        setElapsedMs(Math.max(0, Date.now() - ci.getTime()))
      } else {
        setCheckInTime(null)
        setElapsedMs(0)
      }
    } catch {
      // ignore, UI keeps current state
    }
  }

  useEffect(() => {
    if (isHR) fetchEmployees()
  }, [isHR])

  useEffect(() => {
    setActiveTab(isHR ? 'employees' : 'my')
  }, [isHR])

  useEffect(() => {
    if (!(isHR || user?._id)) return
    if (isHR && activeTab === 'employees' && employeesViewMode === 'day') {
      fetchAttendanceByDay()
    } else {
      fetchAttendanceByMonth()
    }
  }, [isHR, user?._id, selectedMonth, selectedDate, activeTab, employeesViewMode, filterEmployeeId])

  useEffect(() => {
    // Keep employee summary correct even when table is in Day view
    if (isHR && activeTab === 'employees') fetchMonthAttendancesForSummary()
  }, [isHR, activeTab, selectedMonth])

  useEffect(() => {
    if (user?._id) {
      setSelectedEmployee(user._id)
    }
  }, [user?._id, user?.name])

  useEffect(() => {
    syncActiveSessionFromServer()
  }, [user?._id])

  useEffect(() => {
    if (!checkInTime) return
    const tick = () => {
      setElapsedMs(Math.max(0, Date.now() - checkInTime.getTime()))
    }
    tick()
    timerRef.current = setInterval(tick, 1000)
    return () => {
      if (timerRef.current) clearInterval(timerRef.current)
    }
  }, [checkInTime])

  // Auto checkout when the day ends (midnight passed) and user still has an active session
  useEffect(() => {
    if (!checkInTime || !selectedEmployee) return
    const checkDayEnd = () => {
      const now = new Date()
      const checkInDate = new Date(checkInTime)
      const todayStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
      const checkInStr = `${checkInDate.getFullYear()}-${String(checkInDate.getMonth() + 1).padStart(2, '0')}-${String(checkInDate.getDate()).padStart(2, '0')}`
      if (todayStr > checkInStr) {
        api.post('/attendance/check-out', { employee: selectedEmployee })
          .then(() => {
            setCheckInTime(null)
            setElapsedMs(0)
            if (timerRef.current) clearInterval(timerRef.current)
            fetchAttendanceByMonth()
          })
          .catch(() => {})
      }
    }
    const dayEndInterval = setInterval(checkDayEnd, 60 * 1000)
    checkDayEnd()
    return () => clearInterval(dayEndInterval)
  }, [checkInTime, selectedEmployee])

  const getLocation = () => {
    return new Promise((resolve) => {
      if (!navigator.geolocation) {
        resolve({ failed: true, reason: 'unsupported' })
        return
      }
      const onPosition = async (pos, done) => {
        const lat = Number(pos.coords.latitude)
        const lon = Number(pos.coords.longitude)
        if (Number.isNaN(lat) || Number.isNaN(lon)) {
          done({ failed: true, reason: 'unavailable' })
          return
        }
        let address = ''
        try {
          const res = await fetch(
            `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lon}&format=json&addressdetails=1`,
            { headers: { Accept: 'application/json', 'User-Agent': 'CRM-Attendance/1.0' } }
          )
          const data = await res.json()
          const addr = data.address || {}
          address = [
            addr.house_number,
            addr.road,
            addr.neighbourhood || addr.suburb,
            addr.village || addr.city_district,
            addr.city || addr.town,
            addr.state,
          ]
            .filter(Boolean)
            .join(', ') || data.display_name || ''
        } catch {
          // keep address empty; we'll show coords
        }
        done({ latitude: lat, longitude: lon, address })
      }
      const onError = (err, tryFallback) => {
        const reason = err?.code === 1 ? 'permission_denied' : err?.code === 3 ? 'timeout' : 'unavailable'
        if (tryFallback && reason !== 'permission_denied') {
          navigator.geolocation.getCurrentPosition(
            (pos) => onPosition(pos, resolve),
            () => resolve({ failed: true, reason }),
            { enableHighAccuracy: false, timeout: 10000, maximumAge: 60000 }
          )
        } else {
          resolve({ failed: true, reason })
        }
      }
      navigator.geolocation.getCurrentPosition(
        (pos) => onPosition(pos, resolve),
        (err) => onError(err, true),
        { enableHighAccuracy: true, timeout: 20000, maximumAge: 0 }
      )
    })
  }

  const handleCheckIn = async () => {
    if (!selectedEmployee) {
      setError('User is not ready yet. Please try again.')
      return
    }
    setLoading(true)
    setError(null)
    try {
      const location = await getLocation()
      const hasValidLocation = !location.failed && location.latitude != null && location.longitude != null &&
        !Number.isNaN(Number(location.latitude)) && !Number.isNaN(Number(location.longitude))
      if (!hasValidLocation) {
        const msg = location.reason === 'permission_denied'
          ? 'Location is required to check in. Allow location for this site (click the lock icon in the address bar → Site settings → Location → Allow), then try again.'
          : location.reason === 'timeout'
          ? 'Location is required to check in. Request timed out—ensure device location is on and try again.'
          : location.reason === 'unsupported'
          ? 'Location is required to check in. Your browser does not support geolocation.'
          : 'Location is required to check in. Enable device location and allow this site to use it, then try again.'
        setError(msg)
        setLoading(false)
        return
      }
      const payload = {
        employee: selectedEmployee,
        latitude: Number(location.latitude),
        longitude: Number(location.longitude),
        ...(location.address && location.address.trim() && { address: String(location.address).trim() }),
      }
      const res = await api.post('/attendance/check-in', payload)
      const checkIn = new Date(res.data.attendance?.checkIn || Date.now())
      setCheckInTime(checkIn)
      setElapsedMs(Math.max(0, Date.now() - checkIn.getTime()))
      await syncActiveSessionFromServer()
      fetchAttendanceByMonth()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Error checking in')
    } finally {
      setLoading(false)
    }
  }

  const handleCheckOut = async () => {
    if (!selectedEmployee) {
      setError('User is not ready yet. Please try again.')
      return
    }
    setLoading(true)
    setError(null)
    try {
      const location = await getLocation()
      const hasValidLocation = !location.failed && location.latitude != null && location.longitude != null &&
        !Number.isNaN(Number(location.latitude)) && !Number.isNaN(Number(location.longitude))
      const checkoutPayload = {
        employee: selectedEmployee,
      }
      if (hasValidLocation) {
        checkoutPayload.latitude = Number(location.latitude)
        checkoutPayload.longitude = Number(location.longitude)
        if (location.address && location.address.trim()) {
          checkoutPayload.address = String(location.address).trim()
        }
      }
      await api.post('/attendance/check-out', checkoutPayload)
      setCheckInTime(null)
      setElapsedMs(0)
      if (timerRef.current) clearInterval(timerRef.current)
      await syncActiveSessionFromServer()
      fetchAttendanceByMonth()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Error checking out')
    } finally {
      setLoading(false)
    }
  }

  const monthLabel = selectedMonth
    ? new Date(selectedMonth + '-01').toLocaleDateString('en-IN', { month: 'long', year: 'numeric' })
    : ''

  const dateLabel = selectedDate
    ? new Date(selectedDate + 'T00:00:00').toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })
    : ''

  const filteredAttendances = filterEmployeeId && !(isHR && employeesViewMode === 'day')
    ? attendances.filter((a) => (a.employee?._id || a.employee) === filterEmployeeId)
    : attendances

  const employeeMonthSummary = isHR
    ? employees.map((emp) => {
        const rows = monthAttendances.filter((a) => (a.employee?._id || a.employee) === emp._id)
        const fullDays = rows.filter((r) => r.status === 'Full Day').length
        const halfDays = rows.filter((r) => r.status === 'Half Day').length
        const inProgress = rows.filter((r) => r.status === 'In Progress').length
        const totalHours = rows.reduce((s, r) => s + hoursFromAttendanceRow(r), 0)
        return { emp, fullDays, halfDays, inProgress, totalHours }
      })
    : []

  const getStatusBadge = (status) => {
    const label = status != null && String(status).trim() !== '' ? String(status).trim() : '—'
    const classes = {
      'Full Day': 'bg-green-100 text-green-800 border border-green-200',
      'Half Day': 'bg-amber-100 text-amber-800 border border-amber-200',
      'In Progress': 'bg-blue-100 text-blue-800 border border-blue-200',
      Absent: 'bg-gray-100 text-gray-800 border border-gray-200',
    }
    const pillClass = classes[label] || 'bg-slate-100 text-slate-800 border border-slate-200'
    return (
      <span
        className={`inline-flex items-center justify-center min-w-[5.5rem] px-3 py-1 rounded-full text-xs font-semibold whitespace-nowrap ${pillClass}`}
      >
        {label}
      </span>
    )
  }

  return (
    <div className='p-8'>
      <div className='mb-8'>
        <h1 className='text-2xl font-bold text-gray-900'>Attendance</h1>
        <p className='text-gray-600 mt-1 text-sm'>
          {isHR ? 'View and manage all employees\' attendance.' : 'Check in and check out to track your working hours.'}
        </p>
      </div>

      {isHR && (
        <div className='mb-6 flex flex-wrap gap-2'>
          <button
            onClick={() => setActiveTab('employees')}
            className={`px-4 py-2 rounded-lg text-sm font-medium border ${activeTab === 'employees' ? 'bg-blue-600 text-white border-blue-600' : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'}`}
          >
            Employees Attendance
          </button>
          <button
            onClick={() => setActiveTab('my')}
            className={`px-4 py-2 rounded-lg text-sm font-medium border ${activeTab === 'my' ? 'bg-blue-600 text-white border-blue-600' : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'}`}
          >
            Check In / Check Out
          </button>
        </div>
      )}

      {(activeTab === 'my' || !isHR) && (
        <div className='bg-white rounded-xl shadow-lg border border-gray-100 p-6 w-full mb-8'>
          <div className='mb-4'>
            <label className='block text-sm font-medium text-gray-700 mb-2'>Employee</label>
            <div className='w-full border border-gray-200 rounded-xl px-3 py-2 text-sm bg-gray-50 text-gray-700'>
              {user?.name || '—'}
            </div>
          </div>

          <p className='text-xs text-gray-500 mb-2'>
            Location is required to check in. When you click Check In, allow location access when your browser asks.
          </p>
          <div className='flex items-center gap-4 mb-4'>
            <button
              onClick={handleCheckIn}
              disabled={loading || checkInTime}
              className='px-6 py-3 bg-green-600 text-white rounded-xl font-medium text-sm hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors'
            >
              Check In
            </button>
            <button
              onClick={handleCheckOut}
              disabled={loading || !checkInTime}
              className='px-6 py-3 bg-red-600 text-white rounded-xl font-medium text-sm hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors'
            >
              Check Out
            </button>
          </div>

          {checkInTime && (
            <div className='mt-4 p-4 bg-blue-50 rounded-xl'>
              <p className='text-sm text-gray-600'>Time elapsed</p>
              <p className='text-2xl font-bold text-blue-700 font-mono'>{formatTime(elapsedMs)}</p>
            </div>
          )}

          {error && <p className='text-red-600 text-sm mt-4'>{error}</p>}
        </div>
      )}

      {(activeTab === 'employees' || !isHR) && (
        <>
          {isHR && (
            <div className='bg-white rounded-lg shadow border border-gray-100 p-4 mb-4 overflow-x-auto'>
              <div className='flex items-center justify-between gap-4 flex-wrap'>
                <h2 className='text-lg font-bold text-gray-900'>Employee summary</h2>
                <div className='flex items-center gap-2'>
                  <label className='text-sm font-medium text-gray-700'>Month</label>
                  <input
                    type='month'
                    value={selectedMonth}
                    onChange={(e) => setSelectedMonth(e.target.value)}
                    className='border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
                  />
                </div>
              </div>
              <div className='mt-3 overflow-x-auto'>
                <table className='w-full table-auto text-sm'>
                  <thead className='text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>
                    <tr className='text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>
                      <th className='text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Employee</th>
                      <th className='text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Full days</th>
                      <th className='text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Half days</th>
                      <th className='text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>In progress</th>
                      <th className='text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Total hours</th>
                    </tr>
                  </thead>
                  <tbody>
                    {employeeMonthSummary.length === 0 ? (
                      <tr><td colSpan={5} className='py-6 text-center text-gray-500'>No employees</td></tr>
                    ) : (
                      employeeMonthSummary.map(({ emp, fullDays, halfDays, inProgress, totalHours }) => (
                        <tr key={emp._id} className='border-b last:border-b-0'>
                          <td className='py-2 pr-4 font-medium text-gray-900'>{emp.name}</td>
                          <td className='py-2 pr-4'>{fullDays}</td>
                          <td className='py-2 pr-4'>{halfDays}</td>
                          <td className='py-2 pr-4'>{inProgress}</td>
                          <td className='py-2 pr-4'>{totalHours.toFixed(2)}</td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          <div className='bg-white rounded-lg shadow overflow-x-auto'>
            <div className='px-4 py-3 border-b flex flex-wrap items-center justify-between gap-4'>
              <h2 className='text-lg font-bold text-gray-900'>
                {isHR ? "Employees Attendance" : "Your Attendance"}{' '}
                <span className='text-sm font-medium text-gray-500'>
                  {isHR && employeesViewMode === 'day' ? `(${dateLabel})` : `(${monthLabel})`}
                </span>
              </h2>
              <div className='flex flex-wrap items-center gap-4'>
                {isHR && (
                  <div className='flex items-center gap-2'>
                    <label className='text-sm font-medium text-gray-700'>View</label>
                    <select
                      value={employeesViewMode}
                      onChange={(e) => setEmployeesViewMode(e.target.value)}
                      className='border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
                    >
                      <option value='day'>Day</option>
                      <option value='month'>Month</option>
                    </select>
                  </div>
                )}
                {isHR && employeesViewMode === 'day' && (
                  <div className='flex items-center gap-2'>
                    <label className='text-sm font-medium text-gray-700'>Date</label>
                    <input
                      type='date'
                      value={selectedDate}
                      onChange={(e) => setSelectedDate(e.target.value)}
                      className='border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
                    />
                  </div>
                )}
                {isHR && employeesViewMode === 'month' && (
                  <div className='flex items-center gap-2'>
                    <label className='text-sm font-medium text-gray-700'>Month</label>
                    <input
                      type='month'
                      value={selectedMonth}
                      onChange={(e) => setSelectedMonth(e.target.value)}
                      className='border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
                    />
                  </div>
                )}
                {isHR && (
                  <div className='flex items-center gap-2'>
                    <label className='text-sm font-medium text-gray-700'>Employee</label>
                    <select
                      value={filterEmployeeId}
                      onChange={(e) => setFilterEmployeeId(e.target.value)}
                      className='border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 min-w-[180px]'
                    >
                      <option value=''>All Employees</option>
                      {employees.map((emp) => (
                        <option key={emp._id} value={emp._id}>{emp.name}</option>
                      ))}
                    </select>
                  </div>
                )}
                {!isHR && (
                  <div className='flex items-center gap-2'>
                    <label className='text-sm font-medium text-gray-700'>Month</label>
                    <input
                      type='month'
                      value={selectedMonth}
                      onChange={(e) => setSelectedMonth(e.target.value)}
                      className='border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
                    />
                  </div>
                )}
              </div>
            </div>
            <table className='w-full table-auto text-sm'>
              <thead className='bg-blue-600 text-white'>
                <tr className='text-sm font-bold'>
                  <th className='px-4 py-3 text-left border-b border-blue-500/30'>Date</th>
                  <th className='px-4 py-3 text-left border-b border-blue-500/30'>Employee</th>
                  <th className='px-4 py-3 text-left border-b border-blue-500/30'>Check In</th>
                  <th className='px-4 py-3 text-left border-b border-blue-500/30'>Check Out</th>
                  <th className='px-4 py-3 text-left border-b border-blue-500/30'>Check-in location</th>
                  <th className='px-4 py-3 text-left border-b border-blue-500/30'>Check-out location</th>
                  <th className='px-4 py-3 text-left border-b border-blue-500/30'>Duration</th>
                  <th className='px-4 py-3 text-center border-b border-blue-500/30'>Status</th>
                </tr>
              </thead>
              <tbody>
                {filteredAttendances.length === 0 ? (
                  <tr>
                    <td colSpan={8} className='px-4 py-12 text-center text-gray-500'>
                      {attendances.length === 0
                        ? `No attendance records for ${isHR && employeesViewMode === 'day' ? dateLabel : monthLabel}`
                        : `No attendance records for selected employee in ${isHR && employeesViewMode === 'day' ? dateLabel : monthLabel}`}
                    </td>
                  </tr>
                ) : (
                  filteredAttendances.map((a) => (
                    <tr key={a._id} className='border-b hover:bg-gray-50'>
                      <td className='px-4 py-3'>{a.date ? new Date(a.date).toLocaleDateString() : '—'}</td>
                      <td className='px-4 py-3 font-medium'>{a.employee?.name || '—'}</td>
                      <td className='px-4 py-3'>{a.checkIn ? new Date(a.checkIn).toLocaleTimeString() : '—'}</td>
                      <td className='px-4 py-3'>{a.checkOut ? new Date(a.checkOut).toLocaleTimeString() : '—'}</td>
                      <td className='px-4 py-3 text-gray-600 max-w-[280px] align-top' title={a.checkInLatitude != null && a.checkInLongitude != null ? `${Number(a.checkInLatitude).toFixed(6)}, ${Number(a.checkInLongitude).toFixed(6)}` : null}>
                        {a.checkInAddress || a.checkInLatitude != null && a.checkInLongitude != null ? (
                          <span className='block'>
                            {a.checkInAddress && <span className='block'>{a.checkInAddress}</span>}
                            {(a.checkInLatitude != null && a.checkInLongitude != null) && (
                              <span className='text-xs text-gray-500 mt-0.5 block font-mono'>
                                {Number(a.checkInLatitude).toFixed(6)}, {Number(a.checkInLongitude).toFixed(6)}
                              </span>
                            )}
                          </span>
                        ) : (
                          <span className='text-gray-400 italic'>Location unavailable</span>
                        )}
                      </td>
                      <td className='px-4 py-3 text-gray-600 max-w-[280px] align-top' title={a.checkOutLatitude != null && a.checkOutLongitude != null ? `${Number(a.checkOutLatitude).toFixed(6)}, ${Number(a.checkOutLongitude).toFixed(6)}` : null}>
                        {a.checkOutAddress || a.checkOutLatitude != null && a.checkOutLongitude != null ? (
                          <span className='block'>
                            {a.checkOutAddress && <span className='block'>{a.checkOutAddress}</span>}
                            {(a.checkOutLatitude != null && a.checkOutLongitude != null) && (
                              <span className='text-xs text-gray-500 mt-0.5 block font-mono'>
                                {Number(a.checkOutLatitude).toFixed(6)}, {Number(a.checkOutLongitude).toFixed(6)}
                              </span>
                            )}
                          </span>
                        ) : (
                          <span className='text-gray-400 italic'>—</span>
                        )}
                      </td>
                      <td className='px-4 py-3'>
                        <DurationCell row={a} />
                      </td>
                      <td className='px-4 py-3 align-middle text-center'>{getStatusBadge(a.status)}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </>
      )}
    </div>
  )
}

export default AttendanceView
