import React, { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../../api/axios'
import { useAuth } from '../../context/AuthContext'
import TravelRouteMap from '../TravelRouteMap'
import {
  getCurrentLocation,
  getMapsUrl,
  isCoordOnlyAddress,
  locationErrorMessage,
  resolveAddressFromCoords,
} from '../../utils/geolocation'

/** Today's date key in IST (Asia/Kolkata). */
const localYmd = (d = new Date()) =>
  new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date(d))

/** 12-hour AM/PM time in IST. */
const formatTime = (d) => {
  if (!d) return '—'
  return new Date(d).toLocaleTimeString('en-IN', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
    timeZone: 'Asia/Kolkata',
  })
}

const formatINR = (n) =>
  `₹ ${Math.round(Number(n) || 0).toLocaleString('en-IN')}`

/** Reverse-geocode coord-only addresses for timeline / visit rows. */
const PlaceAddress = ({ address, latitude, longitude, className = 'text-xs text-gray-600 mt-1 line-clamp-2' }) => {
  const [place, setPlace] = useState(() => (address && !isCoordOnlyAddress(address) ? address : ''))
  const [loading, setLoading] = useState(() => !address || isCoordOnlyAddress(address))

  useEffect(() => {
    let cancelled = false
    const run = async () => {
      const raw = String(address || '').trim()
      if (raw && !isCoordOnlyAddress(raw)) {
        if (!cancelled) {
          setPlace(raw)
          setLoading(false)
        }
        return
      }

      let lat = latitude != null ? Number(latitude) : NaN
      let lon = longitude != null ? Number(longitude) : NaN
      if ((!Number.isFinite(lat) || !Number.isFinite(lon)) && isCoordOnlyAddress(raw)) {
        const parts = raw.split(',').map((s) => Number(s.trim()))
        if (parts.length === 2 && Number.isFinite(parts[0]) && Number.isFinite(parts[1])) {
          lat = parts[0]
          lon = parts[1]
        }
      }

      if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
        if (!cancelled) {
          setPlace(raw || '—')
          setLoading(false)
        }
        return
      }

      if (!cancelled) setLoading(true)
      const resolved = await resolveAddressFromCoords(lat, lon)
      if (!cancelled) {
        setPlace(resolved || raw || '—')
        setLoading(false)
      }
    }
    run()
    return () => {
      cancelled = true
    }
  }, [address, latitude, longitude])

  if (loading && !place) {
    return <span className={className}>Resolving place…</span>
  }
  return <span className={className}>{place || '—'}</span>
}

const Kpi = ({ label, value, hint }) => (
  <div className='bg-white rounded-xl border border-gray-200 shadow-sm p-4'>
    <p className='text-sm text-gray-500 font-medium'>{label}</p>
    <p className='text-2xl font-bold text-gray-900 mt-1 tabular-nums'>{value}</p>
    {hint ? <p className='text-xs text-gray-400 mt-1'>{hint}</p> : null}
  </div>
)

const SiteCoordinatorDashboardView = ({ embedded = false } = {}) => {
  const { user } = useAuth()
  const navigate = useNavigate()
  const [date, setDate] = useState(localYmd)
  const [loading, setLoading] = useState(true)
  const [busyId, setBusyId] = useState('')
  const [journeyBusy, setJourneyBusy] = useState('')
  const [allocating, setAllocating] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const [timelineData, setTimelineData] = useState(null)
  const [upcoming, setUpcoming] = useState([])

  const load = useCallback(async () => {
    if (!user?._id) return
    setLoading(true)
    setError('')
    try {
      const day = date || localYmd()
      const [travelRes, visitsRes] = await Promise.all([
        api.get('/site-visits/travel-timeline', {
          params: { employeeId: user._id, date: day },
        }),
        api.get('/site-visits', {
          params: {
            assignedTo: user._id,
            from: `${day}T00:00:00`,
            to: `${day}T23:59:59`,
          },
        }),
      ])
      setTimelineData(travelRes.data || null)
      setUpcoming(Array.isArray(visitsRes.data) ? visitsRes.data : [])
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to load travel data')
      setTimelineData(null)
      setUpcoming([])
    } finally {
      setLoading(false)
    }
  }, [user?._id, date])

  useEffect(() => {
    load()
  }, [load])

  const journey = timelineData?.journey || null
  const journeyStarted = Boolean(timelineData?.journeyStarted && journey?.startedAt)
  const journeyActive = journeyStarted && journey?.status === 'active'
  const journeyEnded = journeyStarted && journey?.status === 'ended'

  const captureAndPost = async (visitId, action) => {
    setBusyId(`${visitId}:${action}`)
    setError('')
    setSuccess('')
    try {
      const loc = await getCurrentLocation()
      if (loc.failed) {
        setError(locationErrorMessage(loc.reason))
        return
      }
      const payload = {
        employeeId: user._id,
        latitude: loc.latitude,
        longitude: loc.longitude,
        address: loc.address || '',
      }
      const path =
        action === 'check-in'
          ? `/site-visits/${visitId}/check-in`
          : `/site-visits/${visitId}/check-out`
      const res = await api.post(path, payload)
      if (action === 'check-in' && !res.data?.journeyStarted) {
        setSuccess('Checked in. Start journey first to calculate route distance.')
      } else {
        setSuccess(action === 'check-in' ? 'Checked in — distance added to journey.' : 'Checked out.')
      }
      await load()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Location action failed')
    } finally {
      setBusyId('')
    }
  }

  const startOrEndJourney = async (action) => {
    setJourneyBusy(action)
    setError('')
    setSuccess('')
    try {
      const loc = await getCurrentLocation()
      if (loc.failed) {
        setError(locationErrorMessage(loc.reason))
        return
      }
      const payload = {
        employeeId: user._id,
        date,
        latitude: loc.latitude,
        longitude: loc.longitude,
        address: loc.address || '',
      }
      if (action === 'start') {
        await api.post('/site-visits/start-journey', payload)
        setSuccess('Journey started. Check in at sites — distance is calculated from this start point.')
      } else {
        await api.post('/site-visits/end-journey', payload)
        setSuccess('Journey ended. You can allocate travel expense for the full route.')
      }
      await load()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Journey action failed')
    } finally {
      setJourneyBusy('')
    }
  }

  const allocateExpense = async () => {
    if (!user?._id) return
    if (!journeyStarted) {
      setError('Start your journey first before allocating travel expense.')
      return
    }
    const ok = window.confirm(
      `Allocate travel expense for ${date}?\n\nDistance: ${timelineData?.totalDistanceKm || 0} km\nEstimated: ${formatINR(timelineData?.estimatedExpense)}`
    )
    if (!ok) return
    setAllocating(true)
    setError('')
    setSuccess('')
    try {
      const res = await api.post('/site-visits/allocate-travel-expense', {
        employeeId: user._id,
        date,
      })
      setSuccess(
        `Travel expense allocated: ${formatINR(res.data?.amount)} for ${res.data?.totalDistanceKm} km.`
      )
      await load()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to allocate expense')
    } finally {
      setAllocating(false)
    }
  }

  const timeline = timelineData?.timeline || []
  const visitsById = useMemo(() => {
    const map = new Map()
    upcoming.forEach((v) => map.set(String(v._id), v))
    return map
  }, [upcoming])

  return (
    <div
      className={`${
        embedded
          ? 'p-6 md:p-8 pt-2 space-y-6 bg-[#f8f9fa] border-t border-gray-200'
          : 'p-6 md:p-8 space-y-6 bg-[#f8f9fa] min-h-full'
      }`}
    >
      <div className='flex flex-wrap items-start justify-between gap-4'>
        <div>
          <h1 className='text-2xl font-bold text-gray-900'>
            {embedded ? 'Travel allowance & route map' : 'Travel Dashboard'}
          </h1>
          <p className='text-sm text-gray-500 mt-1'>
            Start your journey, then check in at each site. Route distance is calculated only after the
            journey starts.
          </p>
        </div>
        <div className='flex flex-wrap items-center gap-2'>
          <label className='text-sm text-gray-600' htmlFor='sc-date'>
            Date
          </label>
          <input
            id='sc-date'
            type='date'
            value={date}
            onChange={(e) => setDate(e.target.value || localYmd())}
            className='rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm'
          />
          <button
            type='button'
            onClick={load}
            className='rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm hover:bg-gray-50'
          >
            Refresh
          </button>
        </div>
      </div>

      {error && (
        <div className='rounded-xl border border-red-100 bg-red-50 px-4 py-3 text-sm text-red-700'>{error}</div>
      )}
      {success && (
        <div className='rounded-xl border border-emerald-100 bg-emerald-50 px-4 py-3 text-sm text-emerald-800'>
          {success}
        </div>
      )}

      <section className='bg-white rounded-xl border border-gray-200 shadow-sm p-5'>
        <div className='flex flex-wrap items-start justify-between gap-4'>
          <div className='min-w-0'>
            <h2 className='text-sm font-semibold text-gray-900'>Today&apos;s journey</h2>
            {!loading && !journeyStarted ? (
              <p className='text-sm text-amber-800 mt-1'>
                Journey not started. Tap <strong>Start journey</strong> to begin tracking distance.
              </p>
            ) : null}
            {journeyActive ? (
              <p className='text-sm text-emerald-800 mt-1'>
                Journey active since {formatTime(journey.startedAt)}
                {journey.startAddress ? (
                  <>
                    {' · '}
                    <PlaceAddress
                      address={journey.startAddress}
                      latitude={journey.startLatitude}
                      longitude={journey.startLongitude}
                      className='inline text-sm text-emerald-800'
                    />
                  </>
                ) : null}
              </p>
            ) : null}
            {journeyEnded ? (
              <p className='text-sm text-slate-700 mt-1'>
                Journey ended at {formatTime(journey.endedAt)}. Distance is ready to allocate.
              </p>
            ) : null}
          </div>
          <div className='flex flex-wrap gap-2'>
            {!journeyStarted || journeyEnded ? (
              <button
                type='button'
                disabled={loading || Boolean(journeyBusy) || journeyActive}
                onClick={() => startOrEndJourney('start')}
                className='inline-flex items-center rounded-xl bg-blue-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-blue-700 disabled:opacity-50'
              >
                {journeyBusy === 'start' ? 'Starting…' : journeyEnded ? 'Restart journey' : 'Start journey'}
              </button>
            ) : null}
            {journeyActive ? (
              <button
                type='button'
                disabled={loading || Boolean(journeyBusy)}
                onClick={() => startOrEndJourney('end')}
                className='inline-flex items-center rounded-xl bg-slate-800 px-4 py-2.5 text-sm font-semibold text-white hover:bg-slate-900 disabled:opacity-50'
              >
                {journeyBusy === 'end' ? 'Ending…' : 'End journey'}
              </button>
            ) : null}
          </div>
        </div>
      </section>

      <div className='grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4'>
        <Kpi
          label='Journey status'
          value={loading ? '—' : journeyActive ? 'Active' : journeyEnded ? 'Ended' : 'Not started'}
          hint={journeyStarted ? `Started ${formatTime(journey.startedAt)}` : 'Start to track km'}
        />
        <Kpi
          label='Distance travelled'
          value={loading ? '—' : journeyStarted ? `${timelineData?.totalDistanceKm ?? 0} km` : '0 km'}
          hint={
            journeyStarted
              ? `@ ₹${timelineData?.ratePerKm ?? 12}/km`
              : 'Calculated after start'
          }
        />
        <Kpi
          label='Estimated expense'
          value={loading ? '—' : journeyStarted ? formatINR(timelineData?.estimatedExpense) : formatINR(0)}
          hint='From journey start → check-ins'
        />
        <Kpi
          label='Visits scheduled'
          value={loading ? '—' : upcoming.length}
          hint='Assigned to you'
        />
      </div>

      <div className='flex flex-wrap gap-2'>
        {timelineData?.routeUrl && journeyStarted ? (
          <a
            href={timelineData.routeUrl}
            target='_blank'
            rel='noopener noreferrer'
            className='inline-flex items-center rounded-xl bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700'
          >
            Open Google Maps route
          </a>
        ) : null}
        <button
          type='button'
          disabled={allocating || loading || !journeyStarted || !(timelineData?.totalDistanceKm > 0)}
          onClick={allocateExpense}
          className='inline-flex items-center rounded-xl bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-700 disabled:opacity-50'
        >
          {allocating ? 'Allocating…' : 'Allocate travel expense'}
        </button>
        <button
          type='button'
          onClick={() => navigate('/site-visits')}
          className='inline-flex items-center rounded-xl border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50'
        >
          All site visits
        </button>
      </div>

      <section className='bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden'>
        <div className='px-5 py-4 border-b border-gray-100 flex flex-wrap items-center justify-between gap-2'>
          <div>
            <h2 className='text-sm font-semibold text-gray-900'>Route map</h2>
            <p className='text-xs text-gray-500 mt-0.5'>
              {journeyStarted
                ? 'Live path from journey start through check-ins'
                : 'Start journey and check in to see the route on the map'}
            </p>
          </div>
          {timelineData?.routeUrl && journeyStarted ? (
            <a
              href={timelineData.routeUrl}
              target='_blank'
              rel='noopener noreferrer'
              className='text-xs font-medium text-indigo-600 hover:underline'
            >
              Full screen in Google Maps →
            </a>
          ) : null}
        </div>
        <TravelRouteMap
          points={timeline}
          routeUrl={journeyStarted ? timelineData?.routeUrl : null}
          height={400}
          emptyMessage={
            journeyStarted
              ? 'Waiting for GPS points… check in at a site to plot the route.'
              : 'Start your journey to display the route map.'
          }
        />
      </section>

      <div className='grid grid-cols-1 xl:grid-cols-2 gap-6'>
        <section className='bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden'>
          <div className='px-5 py-4 border-b border-gray-100'>
            <h2 className='text-sm font-semibold text-gray-900'>Travel timeline</h2>
            <p className='text-xs text-gray-500 mt-0.5'>
              {journeyStarted
                ? 'Journey start → check-ins · segment km from previous stop'
                : 'Start journey to begin the timeline and distance'}
            </p>
          </div>
          <div className='divide-y divide-gray-50'>
            {loading ? (
              <p className='p-6 text-sm text-gray-500'>Loading timeline…</p>
            ) : !journeyStarted ? (
              <p className='p-6 text-sm text-gray-500'>
                No active journey. Use <strong>Start journey</strong> above, then check in at visits.
              </p>
            ) : timeline.length === 0 ? (
              <p className='p-6 text-sm text-gray-500'>
                Journey started. Check in at a visit to add stops and distance.
              </p>
            ) : (
              timeline.map((point, idx) => {
                const isStart = point.type === 'journey_start'
                const isEnd = point.type === 'journey_end'
                const label = isStart
                  ? 'Journey start'
                  : isEnd
                    ? 'Journey end'
                    : point.property?.title || point.visitorName || 'Site visit'
                return (
                  <div key={`${point.type}-${point.siteVisitId || idx}`} className='px-5 py-4 flex gap-3'>
                    <div className='flex flex-col items-center pt-1'>
                      <span
                        className={`w-8 h-8 rounded-full text-xs font-bold flex items-center justify-center ${
                          isStart || isEnd
                            ? 'bg-slate-800 text-white'
                            : 'bg-indigo-100 text-indigo-700'
                        }`}
                      >
                        {isStart ? 'S' : isEnd ? 'E' : idx}
                      </span>
                      {idx < timeline.length - 1 ? (
                        <span className='w-px flex-1 bg-indigo-100 mt-1 min-h-[24px]' />
                      ) : null}
                    </div>
                    <div className='min-w-0 flex-1'>
                      <div className='flex flex-wrap items-center justify-between gap-2'>
                        <p className='font-medium text-gray-900 truncate'>{label}</p>
                        {!isStart ? (
                          <span className='text-xs font-semibold text-amber-700 tabular-nums'>
                            +{point.segmentKm || 0} km
                          </span>
                        ) : (
                          <span className='text-xs font-semibold text-slate-500'>Origin</span>
                        )}
                      </div>
                      <p className='text-xs text-gray-500 mt-0.5'>
                        {formatTime(point.checkInAt)}
                        {point.checkOutAt ? ` → ${formatTime(point.checkOutAt)}` : ''}
                        {point.city ? ` · ${point.city}` : ''}
                      </p>
                      <PlaceAddress
                        address={point.address}
                        latitude={point.latitude}
                        longitude={point.longitude}
                        className='block text-xs text-gray-600 mt-1 line-clamp-2'
                      />
                      {point.mapsUrl ? (
                        <a
                          href={point.mapsUrl}
                          target='_blank'
                          rel='noopener noreferrer'
                          className='inline-block mt-2 text-xs font-medium text-indigo-600 hover:underline'
                        >
                          View on Google Maps
                        </a>
                      ) : null}
                    </div>
                  </div>
                )
              })
            )}
          </div>
        </section>

        <section className='bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden'>
          <div className='px-5 py-4 border-b border-gray-100'>
            <h2 className='text-sm font-semibold text-gray-900'>Today&apos;s assigned visits</h2>
            <p className='text-xs text-gray-500 mt-0.5'>
              {journeyStarted
                ? 'Check in on arrival · check out when leaving'
                : 'You can still check in, but distance starts only after Start journey'}
            </p>
          </div>
          <div className='divide-y divide-gray-50'>
            {loading ? (
              <p className='p-6 text-sm text-gray-500'>Loading visits…</p>
            ) : upcoming.length === 0 ? (
              <p className='p-6 text-sm text-gray-500'>No site visits assigned to you for this date.</p>
            ) : (
              upcoming.map((visit) => {
                const checkedIn = Boolean(visit.checkInAt)
                const checkedOut = Boolean(visit.checkOutAt)
                const propMaps =
                  visit.property?.latitude != null && visit.property?.longitude != null
                    ? getMapsUrl(visit.property.latitude, visit.property.longitude)
                    : visit.property?.googleMapLink || null
                return (
                  <div key={visit._id} className='px-5 py-4'>
                    <div className='flex flex-wrap items-start justify-between gap-2'>
                      <div className='min-w-0'>
                        <p className='font-medium text-gray-900'>
                          {visit.property?.title || visit.visitorName}
                        </p>
                        <p className='text-xs text-gray-500 mt-0.5'>
                          {formatTime(visit.scheduledAt)} · {visit.status}
                          {visit.city ? ` · ${visit.city}` : ''}
                        </p>
                        <p className='text-xs text-gray-600 mt-1 line-clamp-2'>
                          {visit.address || visit.meetingPoint || '—'}
                        </p>
                      </div>
                      <div className='flex flex-wrap gap-2'>
                        {propMaps ? (
                          <a
                            href={propMaps}
                            target='_blank'
                            rel='noopener noreferrer'
                            className='rounded-lg border border-gray-200 px-3 py-1.5 text-xs font-medium text-gray-700 hover:bg-gray-50'
                          >
                            Map
                          </a>
                        ) : null}
                        {!checkedIn ? (
                          <button
                            type='button'
                            disabled={Boolean(busyId)}
                            onClick={() => captureAndPost(visit._id, 'check-in')}
                            className='rounded-lg bg-blue-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-blue-700 disabled:opacity-50'
                          >
                            {busyId === `${visit._id}:check-in` ? '…' : 'Check in'}
                          </button>
                        ) : !checkedOut ? (
                          <button
                            type='button'
                            disabled={Boolean(busyId)}
                            onClick={() => captureAndPost(visit._id, 'check-out')}
                            className='rounded-lg bg-slate-800 px-3 py-1.5 text-xs font-semibold text-white hover:bg-slate-900 disabled:opacity-50'
                          >
                            {busyId === `${visit._id}:check-out` ? '…' : 'Check out'}
                          </button>
                        ) : (
                          <span className='rounded-lg bg-emerald-50 px-3 py-1.5 text-xs font-semibold text-emerald-700'>
                            Done
                          </span>
                        )}
                      </div>
                    </div>
                    {checkedIn && visitsById.get(String(visit._id))?.checkInLatitude != null ? (
                      <p className='text-[11px] text-gray-400 mt-2'>
                        In: {formatTime(visit.checkInAt)}
                        {journeyStarted && visit.travelFromPreviousKm != null
                          ? ` · +${visit.travelFromPreviousKm} km from previous`
                          : !journeyStarted
                            ? ' · distance pending (start journey)'
                            : ''}
                      </p>
                    ) : null}
                  </div>
                )
              })
            )}
          </div>
        </section>
      </div>
    </div>
  )
}

export default SiteCoordinatorDashboardView
