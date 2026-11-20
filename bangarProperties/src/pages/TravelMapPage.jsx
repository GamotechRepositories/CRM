import React, { useCallback, useEffect, useMemo, useState } from 'react'
import api from '../api/axios'
import { useAuth } from '../context/AuthContext'
import TravelRouteMap from '../components/TravelRouteMap'

const toLocalYmd = (d = new Date()) => {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

const formatINR = (amount) =>
  `₹${Math.round(Number(amount) || 0).toLocaleString('en-IN')}`

const formatTime = (value) => {
  if (!value) return '—'
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleTimeString('en-IN', { hour: 'numeric', minute: '2-digit', hour12: true })
}

const stopBadge = (type) => {
  if (type === 'journey_start') return { label: 'Start', cls: 'bg-emerald-100 text-emerald-700' }
  if (type === 'journey_end') return { label: 'End', cls: 'bg-rose-100 text-rose-700' }
  return { label: 'Site Visit', cls: 'bg-blue-100 text-blue-700' }
}

const TravelMapPage = () => {
  const { hasFullAccess } = useAuth()
  const isAdminView = typeof hasFullAccess === 'function' ? hasFullAccess() : true

  const todayYmd = useMemo(() => toLocalYmd(new Date()), [])
  const yesterdayYmd = useMemo(() => {
    const d = new Date()
    d.setDate(d.getDate() - 1)
    return toLocalYmd(d)
  }, [])

  const [selectedDate, setSelectedDate] = useState(todayYmd)
  const [selectedEmployeeId, setSelectedEmployeeId] = useState('')
  const [employees, setEmployees] = useState([])
  const [loadingEmployees, setLoadingEmployees] = useState(true)

  const [ratePerKm, setRatePerKm] = useState(12)
  const [rateInput, setRateInput] = useState('12')
  const [savingRate, setSavingRate] = useState(false)
  const [rateMessage, setRateMessage] = useState('')
  const [rateError, setRateError] = useState('')

  const [loadingTravel, setLoadingTravel] = useState(true)
  const [travelRows, setTravelRows] = useState([])
  const [search, setSearch] = useState('')
  const [onlyWithTravel, setOnlyWithTravel] = useState(false)
  const [allocatingId, setAllocatingId] = useState('')
  const [actionMessage, setActionMessage] = useState('')
  const [actionError, setActionError] = useState('')

  const activeEmployees = useMemo(
    () =>
      (Array.isArray(employees) ? employees : [])
        .filter((e) => e && e.status !== 'Inactive')
        .slice()
        .sort((a, b) => String(a.name || '').localeCompare(String(b.name || ''))),
    [employees]
  )

  useEffect(() => {
    let active = true
    const loadInitial = async () => {
      try {
        const [empRes, rateRes] = await Promise.all([
          api.get('/employees').catch(() => ({ data: [] })),
          api.get('/site-visits/travel-rate').catch(() => ({ data: { ratePerKm: 12 } })),
        ])
        if (!active) return
        const empList = Array.isArray(empRes.data) ? empRes.data : empRes.data?.data || []
        setEmployees(empList)
        const fetchedRate = Number(rateRes.data?.ratePerKm)
        if (Number.isFinite(fetchedRate) && fetchedRate > 0) {
          setRatePerKm(fetchedRate)
          setRateInput(String(fetchedRate))
        }
      } finally {
        if (active) setLoadingEmployees(false)
      }
    }
    loadInitial()
    return () => {
      active = false
    }
  }, [])

  const fetchTravelData = useCallback(async () => {
    if (loadingEmployees) return
    const targetEmployees = selectedEmployeeId
      ? activeEmployees.filter((e) => String(e._id || e.id) === selectedEmployeeId)
      : activeEmployees

    if (!targetEmployees.length) {
      setTravelRows([])
      setLoadingTravel(false)
      return
    }

    setLoadingTravel(true)
    setActionMessage('')
    setActionError('')
    try {
      const results = await Promise.all(
        targetEmployees.map(async (emp) => {
          const empId = String(emp._id || emp.id || '')
          try {
            const res = await api.get('/site-visits/travel-timeline', {
              params: { employeeId: empId, date: selectedDate },
            })
            const data = res.data || {}
            const distKm = Number(data.totalDistanceKm) || 0
            return {
              employeeId: empId,
              name: emp.name || '—',
              role: emp.designation?.title || emp.designation?.name || '—',
              department: emp.department || emp.designation?.department || '—',
              totalDistanceKm: distKm,
              journeyCount: Number(data.journeyCount) || (Array.isArray(data.journeys) ? data.journeys.length : 0),
              hasActiveJourney: Boolean(data.activeJourneyId),
              journeyStarted: Boolean(data.journeyStarted),
              visitsCount: Array.isArray(data.visits) ? data.visits.length : 0,
              journeys: Array.isArray(data.journeys) ? data.journeys : [],
              timeline: Array.isArray(data.timeline) ? data.timeline : [],
              trackPoints: Array.isArray(data.trackPoints) ? data.trackPoints : [],
              routeUrl: data.routeUrl || null,
              routeUsed: data.routeUsed || '',
              routeSummary: data.routeSummary || '',
              roadNames: Array.isArray(data.roadNames) ? data.roadNames : [],
            }
          } catch {
            return {
              employeeId: empId,
              name: emp.name || '—',
              role: emp.designation?.title || emp.designation?.name || '—',
              department: emp.department || emp.designation?.department || '—',
              totalDistanceKm: 0,
              journeyCount: 0,
              hasActiveJourney: false,
              journeyStarted: false,
              visitsCount: 0,
              journeys: [],
              timeline: [],
              trackPoints: [],
              routeUrl: null,
              routeUsed: '',
              routeSummary: '',
              roadNames: [],
            }
          }
        })
      )
      const sorted = results.sort((a, b) => {
        if (a.hasActiveJourney !== b.hasActiveJourney) return a.hasActiveJourney ? -1 : 1
        if (b.totalDistanceKm !== a.totalDistanceKm) return b.totalDistanceKm - a.totalDistanceKm
        if (b.journeyCount !== a.journeyCount) return b.journeyCount - a.journeyCount
        return a.name.localeCompare(b.name)
      })
      setTravelRows(sorted)
    } finally {
      setLoadingTravel(false)
    }
  }, [activeEmployees, loadingEmployees, selectedDate, selectedEmployeeId])

  useEffect(() => {
    ;(async () => {
      await fetchTravelData()
    })()
  }, [fetchTravelData])

  const handleSaveRate = async (e) => {
    e.preventDefault()
    setRateMessage('')
    setRateError('')
    const parsed = Number(rateInput)
    if (!Number.isFinite(parsed) || parsed <= 0 || parsed > 10000) {
      setRateError('Enter a valid rate per km (e.g. 10, 12, 15).')
      return
    }
    setSavingRate(true)
    try {
      const res = await api.put('/site-visits/travel-rate', { ratePerKm: parsed })
      const updated = Number(res.data?.ratePerKm) || parsed
      setRatePerKm(updated)
      setRateInput(String(updated))
      setRateMessage(`Saved! Travel allowance rate is now ₹${updated}/km.`)
    } catch (err) {
      setRateError(err.response?.data?.message || err.message || 'Failed to update travel rate.')
    } finally {
      setSavingRate(false)
    }
  }

  const rowsWithAllowance = useMemo(
    () =>
      travelRows.map((r) => ({
        ...r,
        ratePerKm,
        estimatedExpense: Math.round(r.totalDistanceKm * ratePerKm),
      })),
    [travelRows, ratePerKm]
  )

  const summary = useMemo(() => {
    let travellingCount = 0
    let activeJourneys = 0
    let totalJourneys = 0
    let totalDistanceKm = 0
    let totalAllowance = 0
    rowsWithAllowance.forEach((r) => {
      if (r.journeyStarted || r.totalDistanceKm > 0 || r.journeyCount > 0) travellingCount++
      if (r.hasActiveJourney) activeJourneys++
      totalJourneys += r.journeyCount
      totalDistanceKm += r.totalDistanceKm
      totalAllowance += r.estimatedExpense
    })
    return {
      travellingCount,
      activeJourneys,
      totalJourneys,
      totalDistanceKm: Math.round(totalDistanceKm * 10) / 10,
      totalAllowance: Math.round(totalAllowance),
    }
  }, [rowsWithAllowance])

  const filteredRows = useMemo(() => {
    const q = search.trim().toLowerCase()
    return rowsWithAllowance.filter((r) => {
      if (onlyWithTravel && !r.journeyStarted && r.totalDistanceKm <= 0 && r.journeyCount <= 0) return false
      if (!q) return true
      return (
        r.name.toLowerCase().includes(q) ||
        r.role.toLowerCase().includes(q) ||
        r.department.toLowerCase().includes(q)
      )
    })
  }, [rowsWithAllowance, search, onlyWithTravel])

  const selectedRow = useMemo(() => {
    if (selectedEmployeeId) {
      return rowsWithAllowance.find((r) => r.employeeId === selectedEmployeeId) || null
    }
    return null
  }, [rowsWithAllowance, selectedEmployeeId])

  const handleAllocateExpense = async (row) => {
    if (!row || row.totalDistanceKm <= 0) return
    const ok = window.confirm(
      `Allocate travel allowance for ${row.name} (${selectedDate})?\n\nDistance: ${row.totalDistanceKm} km\nRate: ₹${ratePerKm}/km\nAmount: ${formatINR(row.estimatedExpense)}`
    )
    if (!ok) return
    setAllocatingId(row.employeeId)
    setActionMessage('')
    setActionError('')
    try {
      const res = await api.post('/site-visits/allocate-travel-expense', {
        employeeId: row.employeeId,
        date: selectedDate,
        ratePerKm,
      })
      setActionMessage(
        `Allocated ${formatINR(res.data?.amount ?? row.estimatedExpense)} for ${row.name} (${res.data?.totalDistanceKm ?? row.totalDistanceKm} km @ ₹${res.data?.ratePerKm ?? ratePerKm}/km).`
      )
    } catch (err) {
      setActionError(err.response?.data?.message || err.message || 'Failed to allocate travel expense.')
    } finally {
      setAllocatingId('')
    }
  }

  if (!isAdminView) {
    return (
      <div className='p-6 md:p-8 max-w-4xl mx-auto'>
        <div className='bg-white rounded-2xl border border-gray-200 p-8 text-center'>
          <h1 className='text-lg font-bold text-gray-900'>Admin Access Required</h1>
          <p className='text-sm text-gray-500 mt-2'>
            Only administrators can view employee travel maps and configure per-km travel rates.
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className='p-6 md:p-8 w-full bg-gray-50 min-h-full space-y-6'>
      {/* Page Header */}
      <div className='flex flex-wrap items-start justify-between gap-4'>
        <div>
          <h1 className='text-2xl font-bold text-gray-900 tracking-tight'>Travel Map &amp; Allowance</h1>
          <p className='text-sm text-gray-500 mt-1'>
            Inspect employee-wise GPS routes, journeys, site visits, and manage the per-km travel reimbursement rate.
          </p>
        </div>

        {/* Per-KM Rate Configurator */}
        <form
          onSubmit={handleSaveRate}
          className='bg-white rounded-xl border border-gray-200 shadow-sm px-4 py-3 flex flex-wrap items-center gap-3'
        >
          <div>
            <label htmlFor='travel-rate-input' className='block text-[11px] font-semibold uppercase tracking-wide text-gray-500'>
              Per KM Price (₹)
            </label>
            <div className='flex items-center gap-2 mt-1'>
              <div className='relative'>
                <span className='absolute left-2.5 top-1/2 -translate-y-1/2 text-xs font-bold text-gray-500'>₹</span>
                <input
                  id='travel-rate-input'
                  type='number'
                  step='0.5'
                  min='0.5'
                  max='10000'
                  value={rateInput}
                  onChange={(e) => setRateInput(e.target.value)}
                  className='w-24 pl-6 pr-2 py-1.5 border border-gray-300 rounded-lg text-sm font-bold text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500'
                />
              </div>
              <span className='text-xs text-gray-500'>/ km</span>
              <button
                type='submit'
                disabled={savingRate}
                className='px-3 py-1.5 rounded-lg bg-blue-600 text-white text-xs font-semibold hover:bg-blue-700 disabled:opacity-50 transition-colors'
              >
                {savingRate ? 'Saving...' : 'Update Rate'}
              </button>
            </div>
          </div>
        </form>
      </div>

      {rateMessage && (
        <div className='rounded-xl bg-emerald-50 border border-emerald-200 px-4 py-2.5 text-xs font-medium text-emerald-800'>
          {rateMessage}
        </div>
      )}
      {rateError && (
        <div className='rounded-xl bg-red-50 border border-red-200 px-4 py-2.5 text-xs font-medium text-red-700'>
          {rateError}
        </div>
      )}

      {/* Filter Bar: Date + Employee Selector */}
      <div className='bg-white rounded-2xl border border-gray-200 shadow-sm p-4 flex flex-wrap items-end gap-4'>
        <div>
          <label htmlFor='travel-date-picker' className='block text-xs font-semibold text-gray-600 mb-1'>
            Select Date
          </label>
          <div className='flex items-center gap-2'>
            <input
              id='travel-date-picker'
              type='date'
              value={selectedDate}
              onChange={(e) => e.target.value && setSelectedDate(e.target.value)}
              className='border border-gray-300 rounded-lg px-3 py-2 text-sm text-gray-800 focus:outline-none focus:ring-2 focus:ring-blue-500'
            />
            <button
              type='button'
              onClick={() => setSelectedDate(todayYmd)}
              className={`px-2.5 py-2 rounded-lg text-xs font-semibold border transition-colors ${
                selectedDate === todayYmd
                  ? 'bg-blue-600 text-white border-blue-600'
                  : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
              }`}
            >
              Today
            </button>
            <button
              type='button'
              onClick={() => setSelectedDate(yesterdayYmd)}
              className={`px-2.5 py-2 rounded-lg text-xs font-semibold border transition-colors ${
                selectedDate === yesterdayYmd
                  ? 'bg-blue-600 text-white border-blue-600'
                  : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
              }`}
            >
              Yesterday
            </button>
          </div>
        </div>

        <div className='min-w-[240px] flex-1 max-w-sm'>
          <label htmlFor='travel-employee-select' className='block text-xs font-semibold text-gray-600 mb-1'>
            Select Employee
          </label>
          <select
            id='travel-employee-select'
            value={selectedEmployeeId}
            onChange={(e) => setSelectedEmployeeId(e.target.value)}
            className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm text-gray-800 bg-white focus:outline-none focus:ring-2 focus:ring-blue-500'
          >
            <option value=''>All Employees ({activeEmployees.length})</option>
            {activeEmployees.map((emp) => {
              const id = String(emp._id || emp.id)
              const role = emp.designation?.title || emp.designation?.name || ''
              return (
                <option key={id} value={id}>
                  {emp.name}{role ? ` — ${role}` : ''}
                </option>
              )
            })}
          </select>
        </div>

        {!selectedEmployeeId && (
          <>
            <div>
              <label htmlFor='travel-search-input' className='block text-xs font-semibold text-gray-600 mb-1'>
                Search
              </label>
              <input
                id='travel-search-input'
                type='text'
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder='Name, role, dept...'
                className='border border-gray-300 rounded-lg px-3 py-2 text-sm text-gray-800 w-44 focus:outline-none focus:ring-2 focus:ring-blue-500'
              />
            </div>
            <button
              type='button'
              onClick={() => setOnlyWithTravel((v) => !v)}
              className={`px-3 py-2 rounded-lg text-xs font-semibold border transition-colors ${
                onlyWithTravel
                  ? 'bg-blue-600 text-white border-blue-600'
                  : 'bg-white text-gray-700 border-gray-300 hover:bg-gray-50'
              }`}
            >
              {onlyWithTravel ? 'Showing Travel Only' : 'With Travel Only'}
            </button>
          </>
        )}

        <button
          type='button'
          onClick={fetchTravelData}
          disabled={loadingTravel}
          className='px-3.5 py-2 rounded-lg border border-gray-300 bg-white text-xs font-semibold text-gray-700 hover:bg-gray-50 disabled:opacity-50'
        >
          {loadingTravel ? 'Refreshing...' : 'Refresh'}
        </button>
      </div>

      {/* KPI Summary Strip */}
      <div className='grid grid-cols-2 lg:grid-cols-4 gap-4'>
        <div className='rounded-2xl bg-white border border-gray-200 shadow-sm p-4'>
          <p className='text-xs text-gray-500 font-medium'>
            {selectedEmployeeId ? 'Employee Status' : 'Employees Travelled'}
          </p>
          <p className='text-2xl font-bold text-gray-900 mt-1'>
            {selectedEmployeeId
              ? summary.activeJourneys > 0
                ? 'Live'
                : summary.travellingCount > 0
                  ? 'Travelled'
                  : 'No Travel'
              : summary.travellingCount}
            {!selectedEmployeeId && summary.activeJourneys > 0 && (
              <span className='text-xs font-semibold ml-2 text-emerald-600'>({summary.activeJourneys} live)</span>
            )}
          </p>
        </div>
        <div className='rounded-2xl bg-white border border-blue-100 shadow-sm p-4'>
          <p className='text-xs text-blue-700 font-medium'>Total Journeys</p>
          <p className='text-2xl font-bold text-blue-800 mt-1'>{summary.totalJourneys}</p>
        </div>
        <div className='rounded-2xl bg-white border border-indigo-100 shadow-sm p-4'>
          <p className='text-xs text-indigo-700 font-medium'>Total Distance</p>
          <p className='text-2xl font-bold text-indigo-800 mt-1'>{summary.totalDistanceKm} km</p>
        </div>
        <div className='rounded-2xl bg-white border border-emerald-100 shadow-sm p-4'>
          <p className='text-xs text-emerald-700 font-medium'>
            Total Travel Allowance <span className='text-[11px] font-normal text-gray-400'>(₹{ratePerKm}/km)</span>
          </p>
          <p className='text-2xl font-bold text-emerald-800 mt-1'>{formatINR(summary.totalAllowance)}</p>
        </div>
      </div>

      {actionMessage && (
        <div className='rounded-xl bg-emerald-50 border border-emerald-200 px-4 py-2.5 text-xs font-medium text-emerald-800'>
          {actionMessage}
        </div>
      )}
      {actionError && (
        <div className='rounded-xl bg-red-50 border border-red-200 px-4 py-2.5 text-xs font-medium text-red-700'>
          {actionError}
        </div>
      )}

      {/* Selected Employee Route Map & Breakdown */}
      {selectedRow && (
        <div className='bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden'>
          <div className='px-5 py-4 border-b border-gray-100 flex flex-wrap items-center justify-between gap-3 bg-slate-50/70'>
            <div>
              <div className='flex items-center gap-2'>
                <h2 className='text-base font-bold text-gray-900'>
                  {selectedRow.name} — Route Map ({selectedDate})
                </h2>
                {selectedRow.hasActiveJourney && (
                  <span className='px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-700'>
                    LIVE
                  </span>
                )}
              </div>
              <p className='text-xs text-gray-500 mt-0.5'>
                {selectedRow.role} · {selectedRow.totalDistanceKm} km · Est. Allowance:{' '}
                <strong className='text-emerald-700'>{formatINR(selectedRow.estimatedExpense)}</strong> (₹{ratePerKm}/km) ·{' '}
                {selectedRow.journeyCount} journey(s) · {selectedRow.visitsCount} site visit(s)
              </p>
            </div>
            <div className='flex flex-wrap items-center gap-2'>
              {selectedRow.routeUrl && (
                <a
                  href={selectedRow.routeUrl}
                  target='_blank'
                  rel='noopener noreferrer'
                  className='px-3 py-1.5 rounded-lg border border-blue-200 bg-white text-blue-700 text-xs font-semibold hover:bg-blue-50'
                >
                  Open in Google Maps ↗
                </a>
              )}
              {selectedRow.totalDistanceKm > 0 && (
                <button
                  type='button'
                  disabled={allocatingId === selectedRow.employeeId}
                  onClick={() => handleAllocateExpense(selectedRow)}
                  className='px-3 py-1.5 rounded-lg bg-emerald-600 text-white text-xs font-semibold hover:bg-emerald-700 disabled:opacity-50'
                >
                  {allocatingId === selectedRow.employeeId ? 'Allocating...' : 'Allocate Expense'}
                </button>
              )}
              <button
                type='button'
                onClick={() => setSelectedEmployeeId('')}
                className='px-3 py-1.5 rounded-lg border border-gray-200 bg-white text-gray-600 text-xs font-semibold hover:bg-gray-50'
              >
                All Employees
              </button>
            </div>
          </div>

          <div className='p-5 space-y-5'>
            <TravelRouteMap
              points={selectedRow.timeline}
              trackPoints={selectedRow.trackPoints}
              routeUsed={selectedRow.routeUsed}
              routeSummary={selectedRow.routeSummary}
              roadNames={selectedRow.roadNames}
              routeUrl={selectedRow.routeUrl}
              height={440}
              emptyMessage={`No GPS route recorded for ${selectedRow.name} on ${selectedDate}.`}
            />

            {/* Journey Breakdown */}
            {selectedRow.journeys.length > 0 && (
              <div>
                <h3 className='text-xs font-bold uppercase tracking-wider text-gray-500 mb-3'>
                  Journeys ({selectedRow.journeys.length})
                </h3>
                <div className='grid grid-cols-1 md:grid-cols-2 gap-3'>
                  {selectedRow.journeys.map((j, idx) => {
                    const jKm = Number(j.distanceKm ?? j.totalDistanceKm ?? 0)
                    return (
                      <div key={j.id || j._id || idx} className='rounded-xl bg-slate-50 border border-gray-200 p-3.5 text-xs space-y-1.5'>
                        <div className='flex items-center justify-between'>
                          <span className='font-bold text-gray-900'>
                            Journey #{j.journeyNumber || idx + 1}
                            {j.status === 'active' && (
                              <span className='ml-1.5 px-1.5 py-0.5 rounded-full text-[9px] font-bold bg-emerald-100 text-emerald-700'>
                                LIVE
                              </span>
                            )}
                          </span>
                          <span className='font-bold text-indigo-700'>
                            {jKm} km · <span className='text-emerald-700'>{formatINR(jKm * ratePerKm)}</span>
                          </span>
                        </div>
                        <p className='text-gray-600'>
                          <span className='font-semibold text-gray-800'>Start:</span> {formatTime(j.startedAt)} · {j.startAddress || '—'}
                        </p>
                        <p className='text-gray-600'>
                          <span className='font-semibold text-gray-800'>End:</span>{' '}
                          {j.endedAt ? `${formatTime(j.endedAt)} · ${j.endAddress || '—'}` : 'In Progress'}
                        </p>
                        {j.routeUsed && (
                          <p className='text-[11px] text-blue-700 font-medium'>{j.routeUsed}</p>
                        )}
                      </div>
                    )
                  })}
                </div>
              </div>
            )}

            {/* Stops / Timeline */}
            {selectedRow.timeline.length > 0 && (
              <div>
                <h3 className='text-xs font-bold uppercase tracking-wider text-gray-500 mb-3'>
                  Stops Timeline ({selectedRow.timeline.length})
                </h3>
                <div className='divide-y divide-gray-100 rounded-xl border border-gray-200 overflow-hidden bg-white'>
                  {selectedRow.timeline.map((stop, idx) => {
                    const badge = stopBadge(stop.type)
                    return (
                      <div key={`${stop.journeyId || 'j'}-${idx}`} className='px-4 py-3 flex flex-wrap items-center justify-between gap-2 text-xs'>
                        <div className='min-w-0 flex-1'>
                          <div className='flex items-center gap-2 flex-wrap'>
                            <span className='w-5 h-5 rounded-full bg-gray-100 text-gray-700 font-bold text-[10px] inline-flex items-center justify-center'>
                              {stop.stopNumber || idx + 1}
                            </span>
                            <span className={`px-2 py-0.5 rounded-full text-[10px] font-semibold ${badge.cls}`}>
                              {badge.label}
                            </span>
                            <span className='font-semibold text-gray-900'>
                              {stop.property?.title || stop.visitorName || 'Stop'}
                            </span>
                            <span className='text-gray-400'>· {formatTime(stop.checkInAt)}</span>
                            {stop.durationMinutes > 0 && (
                              <span className='text-gray-500'>({stop.durationMinutes} min)</span>
                            )}
                          </div>
                          {stop.address && <p className='text-gray-500 mt-1 pl-7'>{stop.address}</p>}
                        </div>
                        <div className='flex items-center gap-3 shrink-0'>
                          {Number(stop.segmentKm) > 0 && (
                            <span className='font-semibold text-indigo-700'>+{stop.segmentKm} km</span>
                          )}
                          {stop.mapsUrl && (
                            <a
                              href={stop.mapsUrl}
                              target='_blank'
                              rel='noopener noreferrer'
                              className='text-blue-600 hover:underline font-medium'
                            >
                              Map ↗
                            </a>
                          )}
                        </div>
                      </div>
                    )
                  })}
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Employee-wise Table (when All Employees selected) */}
      {!selectedEmployeeId && (
        <div className='bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden'>
          <div className='px-5 py-3.5 border-b border-gray-100 flex items-center justify-between'>
            <h2 className='text-sm font-bold text-gray-900'>
              Employee-wise Travel Summary ({selectedDate})
            </h2>
            <span className='text-xs text-gray-500'>
              Showing {filteredRows.length} employee{filteredRows.length === 1 ? '' : 's'} · Rate ₹{ratePerKm}/km
            </span>
          </div>

          {loadingTravel || loadingEmployees ? (
            <div className='p-10 text-center text-sm text-gray-500'>Loading employee travel &amp; route details...</div>
          ) : filteredRows.length === 0 ? (
            <div className='p-10 text-center text-sm text-gray-500'>No employees found for this filter.</div>
          ) : (
            <div className='overflow-x-auto'>
              <table className='w-full text-xs'>
                <thead className='bg-gray-50 text-gray-500 uppercase text-[10px] tracking-wider border-b border-gray-100'>
                  <tr>
                    <th className='py-3 px-4 text-left font-semibold'>Employee</th>
                    <th className='py-3 px-3 text-center font-semibold'>Journeys</th>
                    <th className='py-3 px-3 text-center font-semibold'>Site Visits</th>
                    <th className='py-3 px-3 text-right font-semibold'>Distance</th>
                    <th className='py-3 px-3 text-right font-semibold'>Allowance</th>
                    <th className='py-3 px-3 text-left font-semibold'>Route Summary</th>
                    <th className='py-3 px-4 text-right font-semibold'>Actions</th>
                  </tr>
                </thead>
                <tbody className='divide-y divide-gray-100'>
                  {filteredRows.map((row) => (
                    <tr key={row.employeeId} className='hover:bg-slate-50/80 transition-colors'>
                      <td className='py-3 px-4'>
                        <div className='font-semibold text-gray-900 flex items-center gap-1.5'>
                          <span>{row.name}</span>
                          {row.hasActiveJourney && (
                            <span className='px-1.5 py-0.5 rounded-full text-[9px] font-bold bg-emerald-100 text-emerald-700'>
                              LIVE
                            </span>
                          )}
                        </div>
                        <div className='text-[11px] text-gray-500'>{row.role}</div>
                      </td>
                      <td className='py-3 px-3 text-center font-semibold text-gray-800'>{row.journeyCount}</td>
                      <td className='py-3 px-3 text-center font-semibold text-gray-800'>{row.visitsCount}</td>
                      <td className='py-3 px-3 text-right font-bold text-indigo-700 whitespace-nowrap'>
                        {row.totalDistanceKm > 0 ? `${row.totalDistanceKm} km` : '0 km'}
                      </td>
                      <td className='py-3 px-3 text-right font-bold text-emerald-700 whitespace-nowrap'>
                        {formatINR(row.estimatedExpense)}
                        <span className='block text-[10px] font-normal text-gray-400'>₹{ratePerKm}/km</span>
                      </td>
                      <td className='py-3 px-3 text-gray-600 max-w-[260px] truncate'>
                        {row.routeUsed || row.routeSummary || (row.journeys[0]?.startAddress ? `${row.journeys[0].startAddress}` : '—')}
                      </td>
                      <td className='py-3 px-4 text-right whitespace-nowrap'>
                        <div className='inline-flex items-center gap-1.5'>
                          <button
                            type='button'
                            onClick={() => setSelectedEmployeeId(row.employeeId)}
                            className='px-2.5 py-1 rounded-lg text-[11px] font-semibold border bg-blue-50 text-blue-700 border-blue-200 hover:bg-blue-100 transition-colors'
                          >
                            View Map
                          </button>
                          {row.totalDistanceKm > 0 && (
                            <button
                              type='button'
                              disabled={allocatingId === row.employeeId}
                              onClick={() => handleAllocateExpense(row)}
                              className='px-2.5 py-1 rounded-lg text-[11px] font-semibold bg-emerald-600 text-white hover:bg-emerald-700 disabled:opacity-50'
                            >
                              {allocatingId === row.employeeId ? '...' : 'Allocate'}
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}
    </div>
  )
}

export default TravelMapPage
