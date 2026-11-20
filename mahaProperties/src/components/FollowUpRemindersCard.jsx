import React, { useCallback, useEffect, useMemo, useState } from 'react'
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

const toDateTimeLocal = (dateVal) => {
  const d = dateVal ? new Date(dateVal) : new Date()
  if (Number.isNaN(d.getTime())) return ''
  const pad = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

const formatDateTime = (dateVal) => {
  if (!dateVal) return '—'
  const d = new Date(dateVal)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleString('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  })
}

const formatRelative = (dateMs, nowMs) => {
  const diffMins = Math.round((dateMs - nowMs) / 60000)
  if (diffMins < 0) {
    const abs = Math.abs(diffMins)
    if (abs < 60) return `Missed ${abs}m ago`
    const h = Math.floor(abs / 60)
    if (h < 24) return `Missed ${h}h ${abs % 60}m ago`
    const days = Math.floor(h / 24)
    return `Missed ${days}d ago`
  }
  if (diffMins === 0) return 'Due now'
  if (diffMins < 60) return `In ${diffMins}m`
  const h = Math.floor(diffMins / 60)
  if (h < 24) return `In ${h}h ${diffMins % 60}m`
  const days = Math.floor(h / 24)
  return `In ${days}d`
}

const extractActiveFollowUps = (leads = [], nowMs = Date.now()) => {
  const todayStr = new Date(nowMs).toDateString()
  const items = []

  ;(Array.isArray(leads) ? leads : []).forEach((lead) => {
    if (!lead?._id || CLOSED_STATUSES.has(lead.status)) return
    const fus = Array.isArray(lead.followUps) ? lead.followUps : []
    fus.forEach((fu, index) => {
      if (!fu || fu.completed || !fu.date) return
      const dt = new Date(fu.date)
      if (Number.isNaN(dt.getTime())) return
      const ms = dt.getTime()
      const isMissed = ms < nowMs
      const isToday = dt.toDateString() === todayStr
      const bucket = isMissed ? 'missed' : isToday ? 'today' : 'upcoming'
      items.push({
        key: `${lead._id}:${fu._id || index}`,
        leadId: lead._id,
        lead,
        followUpIndex: index,
        followUpId: fu._id || null,
        date: dt,
        dateMs: ms,
        comments: fu.comments ?? fu.text ?? '',
        bucket,
      })
    })
  })

  return items.sort((a, b) => a.dateMs - b.dateMs)
}

const FollowUpRemindersCard = ({
  leads: externalLeads = null,
  title = 'Follow-Up Reminders',
  subtitle = 'Pending, upcoming, and missed lead follow-ups',
}) => {
  const { user } = useAuth()
  const navigate = useNavigate()
  const [fetchedLeads, setFetchedLeads] = useState([])
  const [loading, setLoading] = useState(!externalLeads)
  const [activeTab, setActiveTab] = useState('all')
  const [nowMs, setNowMs] = useState(() => Date.now())
  const [busyKey, setBusyKey] = useState('')
  const [rescheduleKey, setRescheduleKey] = useState('')
  const [rescheduleValue, setRescheduleValue] = useState('')

  const loadLeads = useCallback(async () => {
    if (!user?._id) return
    try {
      setLoading(true)
      const res = await api.get('/leads', { params: { viewerId: user._id } }).catch(() => ({ data: [] }))
      const list = Array.isArray(res.data) ? res.data : res.data?.data || []
      setFetchedLeads(list)
    } finally {
      setLoading(false)
    }
  }, [user?._id])

  useEffect(() => {
    if (externalLeads) {
      setFetchedLeads(externalLeads)
      setLoading(false)
    } else {
      loadLeads()
    }
  }, [externalLeads, loadLeads])

  useEffect(() => {
    const tick = setInterval(() => setNowMs(Date.now()), 30000)
    const onUpdated = () => loadLeads()
    window.addEventListener('crm:followups-updated', onUpdated)
    return () => {
      clearInterval(tick)
      window.removeEventListener('crm:followups-updated', onUpdated)
    }
  }, [loadLeads])

  const allItems = useMemo(() => extractActiveFollowUps(fetchedLeads, nowMs), [fetchedLeads, nowMs])
  const missedItems = useMemo(() => allItems.filter((i) => i.bucket === 'missed'), [allItems])
  const todayItems = useMemo(() => allItems.filter((i) => i.bucket === 'today'), [allItems])
  const upcomingItems = useMemo(() => allItems.filter((i) => i.bucket === 'upcoming'), [allItems])

  const visibleItems = useMemo(() => {
    if (activeTab === 'missed') return missedItems
    if (activeTab === 'today') return todayItems
    if (activeTab === 'upcoming') return upcomingItems
    return allItems
  }, [activeTab, allItems, missedItems, todayItems, upcomingItems])

  const persistFollowUps = async (lead, nextFollowUps) => {
    await api.put(`/leads/${lead._id}`, {
      followUps: nextFollowUps,
      viewerId: user?._id,
    })
    setFetchedLeads((prev) =>
      prev.map((l) => (l._id === lead._id ? { ...l, followUps: nextFollowUps } : l))
    )
    window.dispatchEvent(new Event('crm:followups-updated'))
  }

  const handleMarkCompleted = async (item) => {
    setBusyKey(item.key)
    try {
      const nextFollowUps = (item.lead.followUps || []).map((fu, idx) => {
        const match = item.followUpId ? String(fu._id) === String(item.followUpId) : idx === item.followUpIndex
        return match ? { ...fu, completed: true, completedAt: new Date().toISOString() } : fu
      })
      await persistFollowUps(item.lead, nextFollowUps)
    } catch (err) {
      console.error('Failed to mark follow-up completed:', err)
    } finally {
      setBusyKey('')
    }
  }

  const handleRescheduleSave = async (item) => {
    if (!rescheduleValue) return
    const nextDate = new Date(rescheduleValue)
    if (Number.isNaN(nextDate.getTime())) return
    setBusyKey(item.key)
    try {
      const nextFollowUps = (item.lead.followUps || []).map((fu, idx) => {
        const match = item.followUpId ? String(fu._id) === String(item.followUpId) : idx === item.followUpIndex
        return match ? { ...fu, date: nextDate.toISOString(), completed: false, completedAt: null } : fu
      })
      await persistFollowUps(item.lead, nextFollowUps)
      setRescheduleKey('')
      setRescheduleValue('')
    } catch (err) {
      console.error('Failed to reschedule follow-up:', err)
    } finally {
      setBusyKey('')
    }
  }

  return (
    <div className='bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden'>
      <div className='px-5 py-4 border-b border-gray-100 flex flex-wrap items-center justify-between gap-3'>
        <div>
          <h3 className='text-sm font-bold text-gray-900 flex items-center gap-2'>
            <span>🔔 {title}</span>
            {missedItems.length > 0 && (
              <span className='px-2 py-0.5 rounded-full text-[11px] font-bold bg-red-100 text-red-700 border border-red-200'>
                {missedItems.length} Missed
              </span>
            )}
          </h3>
          <p className='text-xs text-gray-500 mt-0.5'>{subtitle}</p>
        </div>
        <div className='flex flex-wrap items-center gap-1.5'>
          {[
            { id: 'all', label: `All (${allItems.length})` },
            { id: 'missed', label: `Missed (${missedItems.length})` },
            { id: 'today', label: `Due Today (${todayItems.length})` },
            { id: 'upcoming', label: `Upcoming (${upcomingItems.length})` },
          ].map((tab) => (
            <button
              key={tab.id}
              type='button'
              onClick={() => setActiveTab(tab.id)}
              className={`px-2.5 py-1 rounded-full text-xs font-semibold border transition-colors ${
                activeTab === tab.id
                  ? tab.id === 'missed'
                    ? 'bg-red-600 text-white border-red-600'
                    : 'bg-blue-600 text-white border-blue-600'
                  : tab.id === 'missed' && missedItems.length > 0
                    ? 'bg-red-50 text-red-700 border-red-200 hover:bg-red-100'
                    : 'bg-white text-gray-600 border-gray-200 hover:bg-gray-50'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {loading ? (
        <div className='p-6 text-center text-xs text-gray-500'>Loading follow-up reminders...</div>
      ) : visibleItems.length === 0 ? (
        <div className='p-8 text-center text-xs text-gray-500'>
          No {activeTab === 'all' ? 'pending or upcoming' : activeTab} follow-ups.
        </div>
      ) : (
        <div className='divide-y divide-gray-100 max-h-[380px] overflow-y-auto'>
          {visibleItems.map((item) => {
            const isMissed = item.bucket === 'missed'
            const isToday = item.bucket === 'today'
            const isRescheduling = rescheduleKey === item.key
            const isBusy = busyKey === item.key
            return (
              <div
                key={item.key}
                className={`px-5 py-3.5 flex flex-col sm:flex-row sm:items-center justify-between gap-3 ${
                  isMissed ? 'bg-red-50/40' : 'hover:bg-slate-50/70'
                }`}
              >
                <div className='min-w-0 flex-1'>
                  <div className='flex flex-wrap items-center gap-2'>
                    <button
                      type='button'
                      onClick={() => navigate(`/leads/view/${item.leadId}`)}
                      className='text-sm font-semibold text-gray-900 hover:text-blue-600 hover:underline truncate'
                    >
                      {item.lead.name || 'Lead'}
                    </button>
                    {item.lead.businessName && (
                      <span className='text-xs text-gray-500 truncate'>· {item.lead.businessName}</span>
                    )}
                    <span
                      className={`px-2 py-0.5 rounded-full text-[10px] font-bold border ${
                        isMissed
                          ? 'bg-red-100 text-red-700 border-red-200'
                          : isToday
                            ? 'bg-amber-100 text-amber-800 border-amber-200'
                            : 'bg-blue-100 text-blue-700 border-blue-200'
                      }`}
                    >
                      {formatRelative(item.dateMs, nowMs)}
                    </span>
                  </div>
                  <div className='flex flex-wrap items-center gap-3 mt-1 text-xs text-gray-600'>
                    <span className='font-medium'>🕒 {formatDateTime(item.date)}</span>
                    {item.lead.contactNumber && (
                      <a href={`tel:${item.lead.contactNumber}`} className='text-blue-600 hover:underline font-medium'>
                        📞 {item.lead.contactNumber}
                      </a>
                    )}
                    {item.lead.assignedTo?.name && (
                      <span className='text-gray-500'>Assignee: {item.lead.assignedTo.name}</span>
                    )}
                  </div>
                  {item.comments && (
                    <p className='text-xs text-gray-600 mt-1 line-clamp-2'>{item.comments}</p>
                  )}

                  {isRescheduling && (
                    <div className='mt-2.5 flex flex-wrap items-center gap-2'>
                      <input
                        type='datetime-local'
                        value={rescheduleValue}
                        onChange={(e) => setRescheduleValue(e.target.value)}
                        className='border border-gray-300 rounded-lg px-2.5 py-1 text-xs bg-white'
                      />
                      <button
                        type='button'
                        disabled={isBusy || !rescheduleValue}
                        onClick={() => handleRescheduleSave(item)}
                        className='px-2.5 py-1 rounded-lg bg-blue-600 text-white text-xs font-semibold hover:bg-blue-700 disabled:opacity-50'
                      >
                        {isBusy ? 'Saving...' : 'Save'}
                      </button>
                      <button
                        type='button'
                        onClick={() => { setRescheduleKey(''); setRescheduleValue('') }}
                        className='px-2 py-1 rounded-lg border border-gray-300 text-xs text-gray-600 hover:bg-gray-50'
                      >
                        Cancel
                      </button>
                    </div>
                  )}
                </div>

                <div className='flex items-center gap-1.5 shrink-0'>
                  <button
                    type='button'
                    disabled={isBusy}
                    onClick={() => handleMarkCompleted(item)}
                    className='px-2.5 py-1.5 rounded-lg bg-emerald-600 text-white text-xs font-semibold hover:bg-emerald-700 disabled:opacity-50'
                  >
                    ✓ Complete
                  </button>
                  <button
                    type='button'
                    disabled={isBusy}
                    onClick={() => {
                      setRescheduleKey(isRescheduling ? '' : item.key)
                      setRescheduleValue(toDateTimeLocal(new Date(Date.now() + 60 * 60 * 1000)))
                    }}
                    className='px-2.5 py-1.5 rounded-lg border border-gray-300 bg-white text-gray-700 text-xs font-semibold hover:bg-gray-50 disabled:opacity-50'
                  >
                    Reschedule
                  </button>
                </div>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}

export default FollowUpRemindersCard
