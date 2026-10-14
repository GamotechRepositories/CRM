import React, { useCallback, useEffect, useMemo, useState } from 'react'
import api from '../api/axios'
import { useAuth } from '../context/AuthContext'
import {
  formatCoords,
  getCurrentLocation,
  locationErrorMessage,
} from '../utils/geolocation'
import {
  getLateAfterLabel,
  getTodayDateKey,
  isLateCheckIn,
} from '../utils/attendanceLate'

const CHECKIN_POPUP_KEY = 'crm_show_checkin_popup'

const formatLiveClock = (date = new Date()) => {
  return date.toLocaleTimeString('en-IN', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: true,
  })
}

const formatDateLabel = (date = new Date()) => {
  return date.toLocaleDateString('en-IN', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  })
}

const getTimeGreeting = () => {
  const hour = new Date().getHours()
  if (hour < 12) return 'Good Morning'
  if (hour < 17) return 'Good Afternoon'
  return 'Good Evening'
}

const CheckInModal = () => {
  const { user } = useAuth()
  const [isOpen, setIsOpen] = useState(false)
  const [checkingStatus, setCheckingStatus] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [successData, setSuccessData] = useState(null)
  const [error, setError] = useState('')
  const [liveClock, setLiveClock] = useState(new Date())

  const [locState, setLocState] = useState({
    loading: false,
    latitude: null,
    longitude: null,
    address: '',
    error: '',
  })

  // Clock tick
  useEffect(() => {
    if (!isOpen) return
    const id = setInterval(() => setLiveClock(new Date()), 1000)
    return () => clearInterval(id)
  }, [isOpen])

  // Request location helper
  const acquireLocation = useCallback(async () => {
    setLocState((prev) => ({ ...prev, loading: true, error: '' }))
    try {
      const location = await getCurrentLocation({ skipGeocode: false })
      if (
        location.failed ||
        location.latitude == null ||
        location.longitude == null ||
        Number.isNaN(Number(location.latitude)) ||
        Number.isNaN(Number(location.longitude))
      ) {
        setLocState({
          loading: false,
          latitude: null,
          longitude: null,
          address: '',
          error: locationErrorMessage(location.reason || 'unavailable'),
        })
        return null
      }

      const address =
        location.address?.trim() ||
        formatCoords(location.latitude, location.longitude)

      const result = {
        loading: false,
        latitude: Number(location.latitude),
        longitude: Number(location.longitude),
        address,
        error: '',
      }
      setLocState(result)
      return result
    } catch {
      const errState = {
        loading: false,
        latitude: null,
        longitude: null,
        address: '',
        error: 'Unable to detect location. Please check your browser location settings.',
      }
      setLocState(errState)
      return null
    }
  }, [])

  // Check on mount whether this user should see the check-in popup
  useEffect(() => {
    if (!user?._id) return

    let isMounted = true
    const today = getTodayDateKey()

    const checkTodayStatus = async () => {
      try {
        const res = await api.get('/attendance/today', {
          params: { employeeId: user._id, date: today },
        })
        if (!isMounted) return

        const rows = Array.isArray(res.data) ? res.data : res.data?.attendance || []
        const alreadyCheckedIn = rows.some((r) => Boolean(r.checkIn))

        if (alreadyCheckedIn) {
          // User already checked in today, no need to show popup
          sessionStorage.removeItem(CHECKIN_POPUP_KEY)
          setIsOpen(false)
        } else {
          // Open popup and begin fetching location
          setIsOpen(true)
          acquireLocation()
        }
      } catch {
        // If check fails, show popup to be safe
        if (isMounted) {
          setIsOpen(true)
          acquireLocation()
        }
      } finally {
        if (isMounted) setCheckingStatus(false)
      }
    }

    checkTodayStatus()

    return () => {
      isMounted = false
    }
  }, [user?._id, acquireLocation])

  const handleCheckIn = async () => {
    if (!user?._id) return
    setError('')
    setSubmitting(true)

    try {
      let loc = locState
      if (!loc.latitude || !loc.longitude) {
        loc = await acquireLocation()
      }

      if (!loc || !loc.latitude || !loc.longitude) {
        setError(loc?.error || 'Location is required to check in. Please allow location access.')
        setSubmitting(false)
        return
      }

      const res = await api.post('/attendance/check-in', {
        employee: user._id,
        latitude: loc.latitude,
        longitude: loc.longitude,
        address: loc.address || formatCoords(loc.latitude, loc.longitude),
      })

      const attendance = res.data?.attendance
      setSuccessData({
        checkInTime: attendance?.checkIn ? new Date(attendance.checkIn) : new Date(),
        status: attendance?.status || 'Present',
      })

      sessionStorage.removeItem(CHECKIN_POPUP_KEY)

      // Notify any other attendance views across the app
      window.dispatchEvent(
        new CustomEvent('crm:attendance-updated', { detail: attendance })
      )

      // Auto close after 1.8 seconds
      setTimeout(() => {
        setIsOpen(false)
      }, 1800)
    } catch (err) {
      const msg = err.response?.data?.message || err.message || 'Failed to check in'
      if (msg.toLowerCase().includes('already checked in')) {
        sessionStorage.removeItem(CHECKIN_POPUP_KEY)
        setSuccessData({
          checkInTime: new Date(),
          status: 'Already Checked In',
        })
        setTimeout(() => {
          setIsOpen(false)
        }, 1500)
      } else {
        setError(msg)
      }
    } finally {
      setSubmitting(false)
    }
  }

  const isLate = useMemo(() => isLateCheckIn(liveClock), [liveClock])
  const lateCutoffLabel = useMemo(() => getLateAfterLabel(), [])

  if (checkingStatus || !isOpen) return null

  return (
    <div
      className='fixed inset-0 z-[9999] flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm animate-in fade-in duration-200'
      role='dialog'
      aria-modal='true'
      aria-labelledby='daily-checkin-modal-title'
    >
      <div className='bg-white rounded-3xl shadow-2xl border border-gray-100 max-w-lg w-full overflow-hidden transition-all transform scale-100'>
        {/* Top Header Banner */}
        <div className='relative bg-gradient-to-r from-blue-600 via-indigo-600 to-violet-600 p-6 text-white'>
          <div className='flex items-center gap-3 mb-2'>
            <div className='w-12 h-12 rounded-2xl bg-white/20 backdrop-blur-md flex items-center justify-center shadow-inner'>
              <svg className='w-6 h-6 text-yellow-300' fill='none' stroke='currentColor' viewBox='0 0 24 24'>
                <path
                  strokeLinecap='round'
                  strokeLinejoin='round'
                  strokeWidth={2}
                  d='M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z'
                />
              </svg>
            </div>
            <div>
              <p className='text-xs uppercase tracking-wider font-semibold text-blue-200'>
                {getTimeGreeting()}, {user?.name?.split(' ')[0] || 'User'}!
              </p>
              <h2 id='daily-checkin-modal-title' className='text-2xl font-bold text-white'>
                Daily Check-In
              </h2>
            </div>
          </div>
          <p className='text-blue-100 text-sm'>
            Please mark your attendance to begin your workday.
          </p>
        </div>

        {/* Content Body */}
        <div className='p-6 space-y-5'>
          {successData ? (
            <div className='py-8 text-center space-y-4'>
              <div className='w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center mx-auto ring-8 ring-emerald-50'>
                <svg className='w-9 h-9' fill='none' stroke='currentColor' viewBox='0 0 24 24'>
                  <path strokeLinecap='round' strokeLinejoin='round' strokeWidth={3} d='M5 13l4 4L19 7' />
                </svg>
              </div>
              <h3 className='text-2xl font-bold text-gray-900'>Checked In Successfully!</h3>
              <p className='text-gray-600 text-sm'>
                Attendance recorded for <span className='font-semibold text-gray-800'>{formatLiveClock(successData.checkInTime)}</span>
              </p>
              <div className='inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-800'>
                Status: {successData.status}
              </div>
              <p className='text-xs text-gray-500 pt-2'>Redirecting to your workspace...</p>
            </div>
          ) : (
            <>
              {/* Live Time & Date Card */}
              <div className='bg-slate-50 border border-slate-200/80 rounded-2xl p-4 flex items-center justify-between'>
                <div>
                  <div className='text-xs font-medium text-slate-500 uppercase tracking-wide'>Today's Date</div>
                  <div className='text-sm font-semibold text-slate-900 mt-0.5'>{formatDateLabel(liveClock)}</div>
                </div>
                <div className='text-right'>
                  <div className='text-xs font-medium text-slate-500 uppercase tracking-wide'>Current Time</div>
                  <div className='text-lg font-bold font-mono text-indigo-700 tabular-nums'>
                    {formatLiveClock(liveClock)}
                  </div>
                </div>
              </div>

              {/* Status Indicator */}
              <div className='flex items-center justify-between px-1'>
                <span className='text-xs font-medium text-gray-600'>Check-in Cutoff: 10:00 AM (Grace: {lateCutoffLabel})</span>
                <span
                  className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold ${
                    isLate
                      ? 'bg-amber-100 text-amber-800 border border-amber-200'
                      : 'bg-emerald-100 text-emerald-800 border border-emerald-200'
                  }`}
                >
                  <span
                    className={`w-1.5 h-1.5 rounded-full ${isLate ? 'bg-amber-500' : 'bg-emerald-500'} animate-pulse`}
                  />
                  {isLate ? 'Late Check-In' : 'On Time'}
                </span>
              </div>

              {/* Location Status Card */}
              <div className='rounded-2xl border border-gray-200 bg-white p-4 shadow-sm'>
                <div className='flex items-start gap-3'>
                  <div
                    className={`p-2.5 rounded-xl shrink-0 ${
                      locState.error
                        ? 'bg-rose-50 text-rose-600'
                        : locState.loading
                        ? 'bg-blue-50 text-blue-600'
                        : 'bg-emerald-50 text-emerald-600'
                    }`}
                  >
                    <svg className='w-5 h-5' fill='none' stroke='currentColor' viewBox='0 0 24 24'>
                      <path
                        strokeLinecap='round'
                        strokeLinejoin='round'
                        strokeWidth={2}
                        d='M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z'
                      />
                      <path
                        strokeLinecap='round'
                        strokeLinejoin='round'
                        strokeWidth={2}
                        d='M15 11a3 3 0 11-6 0 3 3 0 016 0z'
                      />
                    </svg>
                  </div>
                  <div className='min-w-0 flex-1'>
                    <div className='text-xs font-semibold text-gray-500 uppercase tracking-wide'>
                      Work Location
                    </div>
                    {locState.loading ? (
                      <div className='flex items-center gap-2 mt-1'>
                        <div className='w-3.5 h-3.5 border-2 border-blue-600 border-t-transparent rounded-full animate-spin' />
                        <span className='text-sm text-gray-600'>Detecting GPS coordinates…</span>
                      </div>
                    ) : locState.error ? (
                      <div className='mt-1'>
                        <p className='text-xs text-rose-600 leading-relaxed'>{locState.error}</p>
                        <button
                          type='button'
                          onClick={acquireLocation}
                          className='mt-2 inline-flex items-center gap-1 text-xs font-semibold text-blue-600 hover:text-blue-800'
                        >
                          <svg className='w-3.5 h-3.5' fill='none' stroke='currentColor' viewBox='0 0 24 24'>
                            <path
                              strokeLinecap='round'
                              strokeLinejoin='round'
                              strokeWidth={2}
                              d='M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15'
                            />
                          </svg>
                          Retry Location
                        </button>
                      </div>
                    ) : locState.address ? (
                      <div className='mt-1'>
                        <p className='text-sm font-medium text-gray-900 line-clamp-2'>{locState.address}</p>
                        <p className='text-[11px] text-emerald-600 font-medium mt-0.5'>
                          ✓ GPS Verified ({locState.latitude?.toFixed(4)}, {locState.longitude?.toFixed(4)})
                        </p>
                      </div>
                    ) : (
                      <p className='text-sm text-gray-500 mt-1'>Location not detected yet</p>
                    )}
                  </div>
                </div>
              </div>

              {/* Error Message */}
              {error && (
                <div className='p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2'>
                  <svg className='w-4 h-4 shrink-0 text-rose-500' fill='none' stroke='currentColor' viewBox='0 0 24 24'>
                    <path
                      strokeLinecap='round'
                      strokeLinejoin='round'
                      strokeWidth={2}
                      d='M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z'
                    />
                  </svg>
                  <span>{error}</span>
                </div>
              )}

              {/* Actions */}
              <div className='pt-2'>
                <button
                  type='button'
                  onClick={handleCheckIn}
                  disabled={submitting}
                  className='w-full inline-flex items-center justify-center gap-2 bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white font-semibold py-3.5 px-6 rounded-xl shadow-md shadow-blue-500/20 disabled:opacity-60 disabled:cursor-not-allowed transition-all transform active:scale-[0.98]'
                >
                  {submitting ? (
                    <>
                      <div className='w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin' />
                      <span>Checking In…</span>
                    </>
                  ) : (
                    <>
                      <svg className='w-5 h-5' fill='none' stroke='currentColor' viewBox='0 0 24 24'>
                        <path strokeLinecap='round' strokeLinejoin='round' strokeWidth={2} d='M5 13l4 4L19 7' />
                      </svg>
                      <span>Check In Now</span>
                    </>
                  )}
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  )
}

export default CheckInModal
