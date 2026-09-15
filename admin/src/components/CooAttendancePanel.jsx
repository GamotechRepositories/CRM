import React, { useCallback, useEffect, useMemo, useState } from 'react'
import { TENANT_LOGOS, TENANT_NAMES } from '../config/tenants'
import { createTenantClient } from '../utils/tenantApi'
import {
  formatCoords,
  getCurrentLocation,
  locationErrorMessage,
} from '../utils/geolocation'

const UNDO_CHECKOUT_MS = 2 * 60 * 1000

const getTodayDateKey = () => {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

const formatTime = (value) => {
  if (!value) return '—'
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
}

const formatCountdown = (ms) => {
  const totalSeconds = Math.max(0, Math.floor(ms / 1000))
  const minutes = Math.floor(totalSeconds / 60)
  const seconds = totalSeconds % 60
  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`
}

const getEmployeeId = (session) => session?._id || session?.id || null

const CooAttendancePanel = ({ allowedTenants = [], companySessions = {}, scopeTenantId = '' }) => {
  const [attendanceByTenant, setAttendanceByTenant] = useState({})
  const [loading, setLoading] = useState(true)
  const [busyTenant, setBusyTenant] = useState('')
  const [bulkBusy, setBulkBusy] = useState('')
  const [error, setError] = useState('')
  const [now, setNow] = useState(() => Date.now())

  const tenants = useMemo(() => {
    const base = allowedTenants.filter((tenantId) => getEmployeeId(companySessions[tenantId]))
    if (scopeTenantId) return base.filter((tenantId) => tenantId === scopeTenantId)
    return base
  }, [allowedTenants, companySessions, scopeTenantId])

  const fetchTodayAttendance = useCallback(async () => {
    if (!tenants.length) {
      setAttendanceByTenant({})
      setLoading(false)
      return
    }

    setLoading(true)
    setError('')
    const date = getTodayDateKey()
    const next = {}

    await Promise.all(
      tenants.map(async (tenantId) => {
        const employeeId = getEmployeeId(companySessions[tenantId])
        if (!employeeId) return
        try {
          const client = createTenantClient(tenantId)
          const res = await client.get('/attendance/today', {
            params: { employeeId, date },
          })
          const rows = Array.isArray(res.data) ? res.data : []
          next[tenantId] = rows[0] || null
        } catch {
          next[tenantId] = null
        }
      })
    )

    setAttendanceByTenant(next)
    setLoading(false)
  }, [tenants, companySessions])

  useEffect(() => {
    fetchTodayAttendance()
  }, [fetchTodayAttendance])

  useEffect(() => {
    const id = window.setInterval(() => setNow(Date.now()), 1000)
    return () => window.clearInterval(id)
  }, [])

  const resolveLocationPayload = async () => {
    const location = await getCurrentLocation()
    if (
      location.failed ||
      location.latitude == null ||
      location.longitude == null ||
      Number.isNaN(Number(location.latitude)) ||
      Number.isNaN(Number(location.longitude))
    ) {
      throw new Error(locationErrorMessage(location.reason || 'unavailable'))
    }
    const address =
      location.address?.trim() || formatCoords(location.latitude, location.longitude)
    return {
      latitude: Number(location.latitude),
      longitude: Number(location.longitude),
      address,
    }
  }

  const runCheckIn = async (tenantId) => {
    const employeeId = getEmployeeId(companySessions[tenantId])
    if (!employeeId) throw new Error('Employee session missing for this company')
    const location = await resolveLocationPayload()
    const client = createTenantClient(tenantId)
    await client.post('/attendance/check-in', {
      employee: employeeId,
      ...location,
    })
  }

  const runCheckOut = async (tenantId) => {
    const employeeId = getEmployeeId(companySessions[tenantId])
    if (!employeeId) throw new Error('Employee session missing for this company')
    const location = await resolveLocationPayload()
    const client = createTenantClient(tenantId)
    await client.post('/attendance/check-out', {
      employee: employeeId,
      ...location,
    })
  }

  const runUndoCheckOut = async (tenantId) => {
    const employeeId = getEmployeeId(companySessions[tenantId])
    if (!employeeId) throw new Error('Employee session missing for this company')
    const client = createTenantClient(tenantId)
    await client.post('/attendance/undo-check-out', { employee: employeeId })
  }

  const handleCheckIn = async (tenantId) => {
    setBusyTenant(tenantId)
    setError('')
    try {
      await runCheckIn(tenantId)
      await fetchTodayAttendance()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Check-in failed')
    } finally {
      setBusyTenant('')
    }
  }

  const handleCheckOut = async (tenantId) => {
    setBusyTenant(tenantId)
    setError('')
    try {
      await runCheckOut(tenantId)
      await fetchTodayAttendance()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Check-out failed')
    } finally {
      setBusyTenant('')
    }
  }

  const handleUndoCheckOut = async (tenantId) => {
    setBusyTenant(tenantId)
    setError('')
    try {
      await runUndoCheckOut(tenantId)
      await fetchTodayAttendance()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Undo check-out failed')
    } finally {
      setBusyTenant('')
    }
  }

  const handleBulkCheckIn = async () => {
    setBulkBusy('in')
    setError('')
    try {
      const pending = tenants.filter((tenantId) => !attendanceByTenant[tenantId]?.checkIn)
      for (const tenantId of pending) {
        await runCheckIn(tenantId)
      }
      await fetchTodayAttendance()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Bulk check-in failed')
    } finally {
      setBulkBusy('')
    }
  }

  const handleBulkCheckOut = async () => {
    setBulkBusy('out')
    setError('')
    try {
      const pending = tenants.filter(
        (tenantId) =>
          attendanceByTenant[tenantId]?.checkIn && !attendanceByTenant[tenantId]?.checkOut
      )
      for (const tenantId of pending) {
        await runCheckOut(tenantId)
      }
      await fetchTodayAttendance()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Bulk check-out failed')
    } finally {
      setBulkBusy('')
    }
  }

  if (!tenants.length) return null

  const canBulkCheckIn = tenants.some((tenantId) => !attendanceByTenant[tenantId]?.checkIn)
  const canBulkCheckOut = tenants.some(
    (tenantId) =>
      attendanceByTenant[tenantId]?.checkIn && !attendanceByTenant[tenantId]?.checkOut
  )

  return (
    <section className='mb-8 bg-white rounded-2xl border border-emerald-100 shadow-sm overflow-hidden'>
      <div className='px-5 py-4 border-b border-emerald-50 bg-gradient-to-r from-emerald-50 to-white flex flex-wrap items-center justify-between gap-3'>
        <div>
          <p className='text-xs font-semibold uppercase tracking-wide text-emerald-700'>My Attendance</p>
          <h2 className='text-lg font-semibold text-gray-900'>Check in / Check out</h2>
          <p className='text-sm text-gray-500 mt-0.5'>
            Mark attendance in each company where you are present
          </p>
        </div>
        <div className='flex flex-wrap gap-2'>
          <button
            type='button'
            onClick={handleBulkCheckIn}
            disabled={Boolean(bulkBusy || busyTenant || !canBulkCheckIn)}
            className='px-4 py-2 rounded-lg bg-emerald-700 text-white text-sm font-semibold hover:bg-emerald-800 disabled:opacity-50'
          >
            {bulkBusy === 'in' ? 'Checking in…' : 'Check In All'}
          </button>
          <button
            type='button'
            onClick={handleBulkCheckOut}
            disabled={Boolean(bulkBusy || busyTenant || !canBulkCheckOut)}
            className='px-4 py-2 rounded-lg border border-emerald-700 text-emerald-800 text-sm font-semibold hover:bg-emerald-50 disabled:opacity-50'
          >
            {bulkBusy === 'out' ? 'Checking out…' : 'Check Out All'}
          </button>
        </div>
      </div>

      {error && (
        <div className='mx-5 mt-4 rounded-lg bg-red-50 border border-red-100 px-3 py-2'>
          <p className='text-red-600 text-sm'>{error}</p>
        </div>
      )}

      {loading ? (
        <div className='p-8 text-center text-sm text-gray-500'>Loading today&apos;s attendance…</div>
      ) : (
        <div className='p-5 grid grid-cols-1 md:grid-cols-2 gap-4'>
          {tenants.map((tenantId) => {
            const row = attendanceByTenant[tenantId]
            const hasCheckedIn = Boolean(row?.checkIn)
            const hasCheckedOut = Boolean(row?.checkOut)
            const isSessionActive = hasCheckedIn && !hasCheckedOut
            const checkOutAtMs = row?.checkOut ? new Date(row.checkOut).getTime() : NaN
            const undoRemainingMs =
              hasCheckedOut && !Number.isNaN(checkOutAtMs)
                ? Math.max(0, UNDO_CHECKOUT_MS - (now - checkOutAtMs))
                : 0
            const canUndo = hasCheckedOut && undoRemainingMs > 0
            const isBusy = busyTenant === tenantId || Boolean(bulkBusy)

            return (
              <div
                key={tenantId}
                className='rounded-xl border border-gray-200 p-4 flex flex-col gap-3'
              >
                <div className='flex items-center gap-3'>
                  <img
                    src={TENANT_LOGOS[tenantId]}
                    alt={TENANT_NAMES[tenantId]}
                    className='w-10 h-10 rounded-lg object-contain border border-gray-100 bg-white'
                  />
                  <div className='min-w-0 flex-1'>
                    <p className='font-semibold text-gray-900 truncate'>{TENANT_NAMES[tenantId]}</p>
                    <p className='text-xs text-gray-500'>
                      {isSessionActive
                        ? 'Checked in'
                        : hasCheckedOut
                          ? 'Checked out'
                          : 'Not checked in'}
                    </p>
                  </div>
                  <span
                    className={`text-xs font-semibold px-2 py-1 rounded-full ${
                      isSessionActive
                        ? 'bg-emerald-50 text-emerald-700'
                        : hasCheckedOut
                          ? 'bg-blue-50 text-blue-700'
                          : 'bg-gray-100 text-gray-600'
                    }`}
                  >
                    {isSessionActive ? 'Active' : hasCheckedOut ? 'Done' : 'Pending'}
                  </span>
                </div>

                <div className='grid grid-cols-2 gap-3 text-sm'>
                  <div className='rounded-lg bg-gray-50 px-3 py-2'>
                    <p className='text-xs text-gray-500'>Check In</p>
                    <p className='font-mono font-medium text-gray-900'>{formatTime(row?.checkIn)}</p>
                  </div>
                  <div className='rounded-lg bg-gray-50 px-3 py-2'>
                    <p className='text-xs text-gray-500'>Check Out</p>
                    <p className='font-mono font-medium text-gray-900'>{formatTime(row?.checkOut)}</p>
                  </div>
                </div>

                <div className='flex gap-2'>
                  <button
                    type='button'
                    onClick={() => handleCheckIn(tenantId)}
                    disabled={isBusy || hasCheckedIn}
                    className='flex-1 py-2 rounded-lg bg-emerald-700 text-white text-sm font-semibold hover:bg-emerald-800 disabled:opacity-50'
                  >
                    Check In
                  </button>
                  <button
                    type='button'
                    onClick={() => handleCheckOut(tenantId)}
                    disabled={isBusy || !isSessionActive}
                    className='flex-1 py-2 rounded-lg border border-emerald-700 text-emerald-800 text-sm font-semibold hover:bg-emerald-50 disabled:opacity-50'
                  >
                    Check Out
                  </button>
                </div>

                {canUndo && (
                  <button
                    type='button'
                    onClick={() => handleUndoCheckOut(tenantId)}
                    disabled={isBusy}
                    className='w-full py-2 rounded-lg border border-amber-500 bg-amber-50 text-amber-800 text-sm font-semibold hover:bg-amber-100 disabled:opacity-50'
                  >
                    Undo Check Out · {formatCountdown(undoRemainingMs)}
                  </button>
                )}
              </div>
            )
          })}
        </div>
      )}
    </section>
  )
}

export default CooAttendancePanel
