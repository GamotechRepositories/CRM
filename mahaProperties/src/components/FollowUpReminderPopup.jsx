import React, { useCallback, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../api/axios'
import { useAuth } from '../context/AuthContext'

const CLOSED_STATUSES = new Set([
  'Not Interested',
  'Lost',
  'Closed',
  'Converted',
  'Booking Done',
  'Token Done',
  'Booking Token',
  'Incentive Earned',
])

const SNOOZE_MS = 15 * 60 * 1000
const UPCOMING_LEAD_WINDOW_MS = 5 * 60 * 1000

const getSnoozeMap = () => {
  try {
    return JSON.parse(sessionStorage.getItem('crm_followup_snooze') || '{}')
  } catch {
    return {}
  }
}

const setSnoozeForKey = (key, untilMs) => {
  try {
    const map = getSnoozeMap()
    map[key] = untilMs
    sessionStorage.setItem('crm_followup_snooze', JSON.stringify(map))
  } catch {}
}

const toDateTimeLocal = (dateVal) => {
  const d = dateVal ? new Date(dateVal) : new Date()
  if (Number.isNaN(d.getTime())) return ''
  const pad = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

const FollowUpReminderPopup = () => {
  const { user } = useAuth()
  const navigate = useNavigate()
  const [dueItem, setDueItem] = useState(null)
  const [busy, setBusy] = useState(false)
  const [rescheduling, setRescheduling] = useState(false)
  const [rescheduleValue, setRescheduleValue] = useState('')

  const checkDueFollowUps = useCallback(async () => {
    if (!user?._id) return
    try {
      const res = await api.get('/leads', { params: { viewerId: user._id } }).catch(() => ({ data: [] }))
      const leads = Array.isArray(res.data) ? res.data : res.data?.data || []
      const nowMs = Date.now()
      const snoozeMap = getSnoozeMap()

      let nextDue = null
      for (const lead of leads) {
        if (!lead?._id || CLOSED_STATUSES.has(lead.status)) continue
        const fus = Array.isArray(lead.followUps) ? lead.followUps : []
        for (let i = 0; i < fus.length; i++) {
          const fu = fus[i]
          if (!fu || fu.completed || !fu.date) continue
          const dt = new Date(fu.date)
          if (Number.isNaN(dt.getTime())) continue
          const ms = dt.getTime()
          // Trigger popup if missed/due now or starting within 5 minutes
          if (ms > nowMs + UPCOMING_LEAD_WINDOW_MS) continue
          const key = `${lead._id}:${fu._id || i}:${ms}`
          if (snoozeMap[key] && snoozeMap[key] > nowMs) continue
          if (!nextDue || ms < nextDue.dateMs) {
            nextDue = {
              key,
              leadId: lead._id,
              lead,
              followUpIndex: i,
              followUpId: fu._id || null,
              date: dt,
              dateMs: ms,
              isMissed: ms < nowMs,
              comments: fu.comments ?? fu.text ?? '',
            }
          }
        }
      }

      setDueItem((current) => {
        if (current && nextDue && current.key === nextDue.key) return current
        if (nextDue) {
          setRescheduling(false)
          setRescheduleValue(toDateTimeLocal(new Date(Date.now() + 60 * 60 * 1000)))
        }
        return nextDue
      })
    } catch {
      // ignore transient network errors
    }
  }, [user?._id])

  useEffect(() => {
    if (!user?._id) return undefined
    checkDueFollowUps()
    const timer = setInterval(checkDueFollowUps, 30000)
    const onUpdated = () => checkDueFollowUps()
    window.addEventListener('crm:followups-updated', onUpdated)
    return () => {
      clearInterval(timer)
      window.removeEventListener('crm:followups-updated', onUpdated)
    }
  }, [user?._id, checkDueFollowUps])

  if (!dueItem) return null

  const handleSnooze = () => {
    setSnoozeForKey(dueItem.key, Date.now() + SNOOZE_MS)
    setDueItem(null)
    setRescheduling(false)
  }

  const handleComplete = async () => {
    setBusy(true)
    try {
      const nextFollowUps = (dueItem.lead.followUps || []).map((fu, idx) => {
        const match = dueItem.followUpId
          ? String(fu._id) === String(dueItem.followUpId)
          : idx === dueItem.followUpIndex
        return match ? { ...fu, completed: true, completedAt: new Date().toISOString() } : fu
      })
      await api.put(`/leads/${dueItem.leadId}`, { followUps: nextFollowUps, viewerId: user?._id })
      setDueItem(null)
      window.dispatchEvent(new Event('crm:followups-updated'))
    } catch (err) {
      console.error('Failed to complete follow-up:', err)
    } finally {
      setBusy(false)
    }
  }

  const handleReschedule = async () => {
    if (!rescheduleValue) return
    const nextDate = new Date(rescheduleValue)
    if (Number.isNaN(nextDate.getTime())) return
    setBusy(true)
    try {
      const nextFollowUps = (dueItem.lead.followUps || []).map((fu, idx) => {
        const match = dueItem.followUpId
          ? String(fu._id) === String(dueItem.followUpId)
          : idx === dueItem.followUpIndex
        return match ? { ...fu, date: nextDate.toISOString(), completed: false, completedAt: null } : fu
      })
      await api.put(`/leads/${dueItem.leadId}`, { followUps: nextFollowUps, viewerId: user?._id })
      setDueItem(null)
      setRescheduling(false)
      window.dispatchEvent(new Event('crm:followups-updated'))
    } catch (err) {
      console.error('Failed to reschedule follow-up:', err)
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className='fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4 print:hidden'>
      <div className='bg-white rounded-2xl shadow-2xl border border-gray-200 max-w-md w-full overflow-hidden'>
        <div className={`px-5 py-4 flex items-center justify-between ${dueItem.isMissed ? 'bg-red-600' : 'bg-blue-600'} text-white`}>
          <div className='flex items-center gap-2'>
            <span className='text-lg'>🔔</span>
            <div>
              <h3 className='text-sm font-bold'>
                {dueItem.isMissed ? 'Missed Follow-Up Reminder' : 'Scheduled Follow-Up Reminder'}
              </h3>
              <p className='text-[11px] opacity-90'>
                {dueItem.date.toLocaleString('en-IN', {
                  day: '2-digit',
                  month: 'short',
                  year: 'numeric',
                  hour: 'numeric',
                  minute: '2-digit',
                  hour12: true,
                })}
              </p>
            </div>
          </div>
          <button
            type='button'
            onClick={handleSnooze}
            className='text-white/80 hover:text-white text-sm font-bold px-1.5'
            title='Snooze 15 minutes'
          >
            ✕
          </button>
        </div>

        <div className='p-5 space-y-3 text-sm'>
          <div>
            <p className='font-bold text-gray-900 text-base'>{dueItem.lead.name || 'Lead'}</p>
            {dueItem.lead.businessName && (
              <p className='text-xs text-gray-500'>{dueItem.lead.businessName}</p>
            )}
            {dueItem.lead.contactNumber && (
              <a href={`tel:${dueItem.lead.contactNumber}`} className='inline-block mt-1 text-xs font-semibold text-blue-600 hover:underline'>
                📞 {dueItem.lead.contactNumber}
              </a>
            )}
          </div>

          {dueItem.comments && (
            <div className='rounded-lg bg-gray-50 border border-gray-200 p-3 text-xs text-gray-700 whitespace-pre-wrap'>
              {dueItem.comments}
            </div>
          )}

          {rescheduling && (
            <div className='space-y-2 pt-1'>
              <label className='block text-xs font-semibold text-gray-700'>New Follow-Up Date & Time</label>
              <input
                type='datetime-local'
                value={rescheduleValue}
                onChange={(e) => setRescheduleValue(e.target.value)}
                className='w-full border border-gray-300 rounded-lg px-3 py-2 text-xs'
              />
              <div className='flex gap-2'>
                <button
                  type='button'
                  disabled={busy || !rescheduleValue}
                  onClick={handleReschedule}
                  className='flex-1 py-2 rounded-lg bg-blue-600 text-white text-xs font-semibold hover:bg-blue-700 disabled:opacity-50'
                >
                  {busy ? 'Saving...' : 'Save New Time'}
                </button>
                <button
                  type='button'
                  onClick={() => setRescheduling(false)}
                  className='px-3 py-2 rounded-lg border border-gray-300 text-xs text-gray-700 hover:bg-gray-50'
                >
                  Cancel
                </button>
              </div>
            </div>
          )}
        </div>

        <div className='px-5 py-3.5 bg-gray-50 border-t border-gray-200 flex flex-wrap items-center justify-between gap-2'>
          <button
            type='button'
            onClick={() => {
              handleSnooze()
              navigate(`/leads/view/${dueItem.leadId}`)
            }}
            className='text-xs font-semibold text-blue-600 hover:underline'
          >
            View Lead
          </button>
          <div className='flex items-center gap-2'>
            <button
              type='button'
              onClick={handleSnooze}
              className='px-3 py-1.5 rounded-lg border border-gray-300 bg-white text-gray-700 text-xs font-semibold hover:bg-gray-100'
            >
              Snooze 15m
            </button>
            <button
              type='button'
              onClick={() => setRescheduling((v) => !v)}
              className='px-3 py-1.5 rounded-lg border border-blue-300 bg-blue-50 text-blue-700 text-xs font-semibold hover:bg-blue-100'
            >
              Reschedule
            </button>
            <button
              type='button'
              disabled={busy}
              onClick={handleComplete}
              className='px-3 py-1.5 rounded-lg bg-emerald-600 text-white text-xs font-semibold hover:bg-emerald-700 disabled:opacity-50'
            >
              ✓ Complete
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

export default FollowUpReminderPopup
