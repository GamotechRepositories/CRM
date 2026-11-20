import React, { useEffect, useMemo, useState } from 'react'
import api from '../api/axios'
import TravelRouteMap from './TravelRouteMap'

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

/**
 * Employee-wise Travel Allowance & Route Map overview for Admin Dashboard
 * (salesTechReality, bangarProperties, mahaProperties).
 */
const AdminTravelAllowanceCard = ({ employees = [] }) => {
  const todayYmd = useMemo(() => toLocalYmd(new Date()), [])
  const [selectedDate, setSelectedDate] = useState(todayYmd)
  const [search, setSearch] = useState('')
  const [onlyWithTravel, setOnlyWithTravel] = useState(false)
  const [loading, setLoading] = useState(true)
  const [travelRows, setTravelRows] = useState([])
  const [selectedEmployeeId, setSelectedEmployeeId] = useState('')
  const [allocatingId, setAllocatingId] = useState('')
  const [actionMessage, setActionMessage] = useState('')

  const activeEmployees = useMemo(
    () => (Array.isArray(employees) ? employees.filter((e) => e && e.status !== 'Inactive') : []),
    [employees]
  )

  useEffect(() => {
    let active = true
    const loadAllTravel = async () => {
      if (!activeEmployees.length) {
        setTravelRows([])
        setLoading(false)
        return
      }
      setLoading(true)
      setActionMessage('')
      try {
        const results = await Promise.all(
          activeEmployees.map(async (emp) => {
            const empId = String(emp._id || emp.id || '')
            try {
              const res = await api.get('/site-visits/travel-timeline', {
                params: { employeeId: empId, date: selectedDate },
              })
              const data = res.data || {}
              return {
                employeeId: empId,
                name: emp.name || '—',
                role: emp.designation?.title || emp.designation?.name || '—',
                department: emp.department || emp.designation?.department || '—',
                ratePerKm: Number(data.ratePerKm) || 12,
                totalDistanceKm: Number(data.totalDistanceKm) || 0,
                estimatedExpense: Number(data.estimatedExpense) || 0,
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
                ratePerKm: 12,
                totalDistanceKm: 0,
                estimatedExpense: 0,
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
        if (!active) return
        const sorted = results.sort((a, b) => {
          if (a.hasActiveJourney !== b.hasActiveJourney) return a.hasActiveJourney ? -1 : 1
          if (b.totalDistanceKm !== a.totalDistanceKm) return b.totalDistanceKm - a.totalDistanceKm
          if (b.journeyCount !== a.journeyCount) return b.journeyCount - a.journeyCount
          return a.name.localeCompare(b.name)
        })
        setTravelRows(sorted)
        setSelectedEmployeeId((prev) => {
          if (prev && sorted.some((r) => r.employeeId === prev)) return prev
          const firstWithTravel = sorted.find((r) => r.journeyStarted || r.totalDistanceKm > 0 || r.timeline.length > 0)
          return firstWithTravel ? firstWithTravel.employeeId : ''
        })
      } finally {
        if (active) setLoading(false)
      }
    }
    loadAllTravel()
    return () => {
      active = false
    }
  }, [activeEmployees, selectedDate])

  const summary = useMemo(() => {
    let travellingCount = 0
    let activeJourneys = 0
    let totalJourneys = 0
    let totalDistanceKm = 0
    let totalAllowance = 0
    travelRows.forEach((r) => {
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
  }, [travelRows])

  const filteredRows = useMemo(() => {
    const q = search.trim().toLowerCase()
    return travelRows.filter((r) => {
      if (onlyWithTravel && !r.journeyStarted && r.totalDistanceKm <= 0 && r.journeyCount <= 0) return false
      if (!q) return true
      return (
        r.name.toLowerCase().includes(q) ||
        r.role.toLowerCase().includes(q) ||
        r.department.toLowerCase().includes(q)
      )
    })
  }, [travelRows, search, onlyWithTravel])

  const selectedRow = useMemo(
    () => travelRows.find((r) => r.employeeId === selectedEmployeeId) || null,
    [travelRows, selectedEmployeeId]
  )

  const handleAllocateExpense = async (row) => {
    if (!row || row.totalDistanceKm <= 0) return
    const ok = window.confirm(
      `Allocate travel allowance for ${row.name} (${selectedDate})?\n\nDistance: ${row.totalDistanceKm} km\nAmount: ${formatINR(row.estimatedExpense)}`
    )
    if (!ok) return
    setAllocatingId(row.employeeId)
    setActionMessage('')
    try {
      const res = await api.post('/site-visits/allocate-travel-expense', {
        employeeId: row.employeeId,
        date: selectedDate,
      })
      setActionMessage(
        `Allocated ${formatINR(res.data?.amount ?? row.estimatedExpense)} for ${row.name} (${res.data?.totalDistanceKm ?? row.totalDistanceKm} km).`
      )
    } catch (err) {
      setActionMessage(err.response?.data?.message || err.message || 'Failed to allocate travel expense.')
    } finally {
      setAllocatingId('')
    }
  }

  return (
    <div className='bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden'>
      <div className='px-5 py-4 border-b border-gray-100 flex flex-wrap items-center justify-between gap-3'>
        <div>
          <h3 className='text-sm font-bold text-gray-900'>Travel Allowance &amp; Route Map (Employee-wise)</h3>
          <p className='text-xs text-gray-500 mt-0.5'>
            Daily travel distance, estimated allowance, journeys, and GPS route map per employee
          </p>
        </div>
        <div className='flex flex-wrap items-center gap-2'>
          <input
            type='date'
            value={selectedDate}
            onChange={(e) => e.target.value && setSelectedDate(e.target.value)}
            className='border border-gray-200 rounded-lg px-2.5 py-1.5 text-xs text-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-500'
          />
          <button
            type='button'
            onClick={() => setOnlyWithTravel((v) => !v)}
            className={`px-2.5 py-1.5 rounded-lg text-xs font-semibold border transition-colors ${
              onlyWithTravel
                ? 'bg-blue-600 text-white border-blue-600'
                : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
            }`}
          >
            {onlyWithTravel ? 'Showing Travel Only' : 'With Travel Only'}
          </button>
          <input
            type='text'
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder='Search employee...'
            className='border border-gray-200 rounded-lg px-2.5 py-1.5 text-xs text-gray-700 w-40 focus:outline-none focus:ring-2 focus:ring-blue-500'
          />
        </div>
      </div>

      {/* KPI Summary Strip */}
      <div className='grid grid-cols-2 sm:grid-cols-4 gap-3 px-5 py-3 bg-slate-50/70 border-b border-gray-100'>
        <div className='rounded-xl bg-white border border-gray-100 px-3 py-2'>
          <p className='text-[11px] text-gray-500 font-medium'>Employees Travelled</p>
          <p className='text-base font-bold text-gray-900 mt-0.5'>
            {summary.travellingCount}
            {summary.activeJourneys > 0 && (
              <span className='text-[10px] font-semibold ml-1.5 text-emerald-600'>({summary.activeJourneys} live)</span>
            )}
          </p>
        </div>
        <div className='rounded-xl bg-white border border-blue-100 px-3 py-2'>
          <p className='text-[11px] text-blue-700 font-medium'>Total Journeys</p>
          <p className='text-base font-bold text-blue-800 mt-0.5'>{summary.totalJourneys}</p>
        </div>
        <div className='rounded-xl bg-white border border-indigo-100 px-3 py-2'>
          <p className='text-[11px] text-indigo-700 font-medium'>Total Distance</p>
          <p className='text-base font-bold text-indigo-800 mt-0.5'>{summary.totalDistanceKm} km</p>
        </div>
        <div className='rounded-xl bg-white border border-emerald-100 px-3 py-2'>
          <p className='text-[11px] text-emerald-700 font-medium'>Total Travel Allowance</p>
          <p className='text-base font-bold text-emerald-800 mt-0.5'>{formatINR(summary.totalAllowance)}</p>
        </div>
      </div>

      {actionMessage && (
        <div className='mx-5 mt-3 rounded-lg bg-emerald-50 border border-emerald-200 px-3 py-2 text-xs text-emerald-800 font-medium'>
          {actionMessage}
        </div>
      )}

      {loading ? (
        <div className='p-8 text-center text-xs text-gray-500'>Loading employee travel &amp; route details...</div>
      ) : filteredRows.length === 0 ? (
        <div className='p-8 text-center text-xs text-gray-500'>No employees found for this filter.</div>
      ) : (
        <div className='overflow-x-auto max-h-[340px] overflow-y-auto'>
          <table className='w-full text-xs'>
            <thead className='bg-gray-50 text-gray-500 uppercase text-[10px] tracking-wider sticky top-0 z-10 border-b border-gray-100'>
              <tr>
                <th className='py-2.5 px-4 text-left font-semibold'>Employee</th>
                <th className='py-2.5 px-3 text-center font-semibold'>Journeys</th>
                <th className='py-2.5 px-3 text-center font-semibold'>Site Visits</th>
                <th className='py-2.5 px-3 text-right font-semibold'>Distance</th>
                <th className='py-2.5 px-3 text-right font-semibold'>Allowance</th>
                <th className='py-2.5 px-3 text-left font-semibold'>Route Summary</th>
                <th className='py-2.5 px-4 text-right font-semibold'>Actions</th>
              </tr>
            </thead>
            <tbody className='divide-y divide-gray-100'>
              {filteredRows.map((row) => {
                const isSelected = selectedEmployeeId === row.employeeId
                return (
                  <tr
                    key={row.employeeId}
                    className={`transition-colors ${isSelected ? 'bg-blue-50/60' : 'hover:bg-slate-50/80'}`}
                  >
                    <td className='py-2.5 px-4'>
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
                    <td className='py-2.5 px-3 text-center font-semibold text-gray-800'>{row.journeyCount}</td>
                    <td className='py-2.5 px-3 text-center font-semibold text-gray-800'>{row.visitsCount}</td>
                    <td className='py-2.5 px-3 text-right font-bold text-indigo-700 whitespace-nowrap'>
                      {row.totalDistanceKm > 0 ? `${row.totalDistanceKm} km` : '0 km'}
                    </td>
                    <td className='py-2.5 px-3 text-right font-bold text-emerald-700 whitespace-nowrap'>
                      {formatINR(row.estimatedExpense)}
                      <span className='block text-[10px] font-normal text-gray-400'>₹{row.ratePerKm}/km</span>
                    </td>
                    <td className='py-2.5 px-3 text-gray-600 max-w-[220px] truncate'>
                      {row.routeUsed || row.routeSummary || (row.journeys[0]?.startAddress ? `${row.journeys[0].startAddress}` : '—')}
                    </td>
                    <td className='py-2.5 px-4 text-right whitespace-nowrap'>
                      <div className='inline-flex items-center gap-1.5'>
                        <button
                          type='button'
                          onClick={() => setSelectedEmployeeId(isSelected ? '' : row.employeeId)}
                          className={`px-2.5 py-1 rounded-lg text-[11px] font-semibold border transition-colors ${
                            isSelected
                              ? 'bg-blue-600 text-white border-blue-600'
                              : 'bg-blue-50 text-blue-700 border-blue-200 hover:bg-blue-100'
                          }`}
                        >
                          {isSelected ? 'Hide Map' : 'Route Map'}
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
                )
              })}
            </tbody>
          </table>
        </div>
      )}

      {/* Selected Employee Route Map & Journey Breakdown */}
      {selectedRow && (
        <div className='border-t border-gray-200 p-5 bg-slate-50/50 space-y-4'>
          <div className='flex flex-wrap items-center justify-between gap-2'>
            <div>
              <h4 className='text-sm font-bold text-gray-900'>
                Route Map — {selectedRow.name} ({selectedDate})
              </h4>
              <p className='text-xs text-gray-500'>
                {selectedRow.totalDistanceKm} km · Est. Allowance: <strong>{formatINR(selectedRow.estimatedExpense)}</strong> (₹{selectedRow.ratePerKm}/km) · {selectedRow.journeyCount} journey(s)
              </p>
            </div>
            <div className='flex items-center gap-2'>
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
              <button
                type='button'
                onClick={() => setSelectedEmployeeId('')}
                className='px-2.5 py-1.5 rounded-lg border border-gray-200 bg-white text-gray-600 text-xs font-medium hover:bg-gray-50'
              >
                Close
              </button>
            </div>
          </div>

          <TravelRouteMap
            points={selectedRow.timeline}
            trackPoints={selectedRow.trackPoints}
            routeUsed={selectedRow.routeUsed}
            routeSummary={selectedRow.routeSummary}
            roadNames={selectedRow.roadNames}
            routeUrl={selectedRow.routeUrl}
            height={360}
            emptyMessage={`No GPS route recorded for ${selectedRow.name} on ${selectedDate}.`}
          />

          {selectedRow.journeys.length > 0 && (
            <div className='grid grid-cols-1 md:grid-cols-2 gap-3'>
              {selectedRow.journeys.map((j, idx) => (
                <div key={j._id || idx} className='rounded-xl bg-white border border-gray-200 p-3 text-xs space-y-1'>
                  <div className='flex items-center justify-between'>
                    <span className='font-bold text-gray-900'>Journey #{j.journeyNumber || idx + 1}</span>
                    <span className='font-bold text-indigo-700'>{j.distanceKm ?? j.totalDistanceKm ?? 0} km</span>
                  </div>
                  <p className='text-gray-600'>
                    <span className='font-medium text-gray-800'>Start:</span> {formatTime(j.startedAt)} · {j.startAddress || '—'}
                  </p>
                  <p className='text-gray-600'>
                    <span className='font-medium text-gray-800'>End:</span> {j.endedAt ? `${formatTime(j.endedAt)} · ${j.endAddress || '—'}` : 'In Progress'}
                  </p>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  )
}

export default AdminTravelAllowanceCard
