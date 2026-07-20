import React, { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../../api/axios'
import {
  formatVisitDateTime,
  SITE_VISIT_STATUS_STYLES,
  SITE_VISIT_STATUSES,
} from '../../config/siteVisit'

const SiteVisitsView = () => {
  const navigate = useNavigate()
  const [visits, setVisits] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState('')
  const [viewVisit, setViewVisit] = useState(null)

  const fetchVisits = async () => {
    try {
      setLoading(true)
      setError(null)
      const res = await api.get('/site-visits')
      setVisits(Array.isArray(res.data) ? res.data : [])
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Error fetching site visits')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchVisits()
  }, [])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return visits.filter((v) => {
      if (status && v.status !== status) return false
      if (!q) return true
      const haystack = [
        v.visitorName,
        v.visitorPhone,
        v.visitorEmail,
        v.property?.title,
        v.property?.propertyCode,
        v.assignedTo?.name,
        v.city,
        v.meetingPoint,
      ]
        .filter(Boolean)
        .join(' ')
        .toLowerCase()
      return haystack.includes(q)
    })
  }, [visits, search, status])

  const stats = useMemo(() => {
    const now = new Date()
    const todayStart = new Date(now)
    todayStart.setHours(0, 0, 0, 0)
    const todayEnd = new Date(now)
    todayEnd.setHours(23, 59, 59, 999)
    return {
      total: visits.length,
      today: visits.filter((v) => {
        const d = new Date(v.scheduledAt)
        return d >= todayStart && d <= todayEnd && !['Cancelled', 'Completed'].includes(v.status)
      }).length,
      scheduled: visits.filter((v) => v.status === 'Scheduled' || v.status === 'Confirmed').length,
      completed: visits.filter((v) => v.status === 'Completed').length,
    }
  }, [visits])

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this site visit?')) return
    try {
      await api.delete(`/site-visits/${id}`)
      fetchVisits()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Error deleting site visit')
    }
  }

  return (
    <div className='p-6 md:p-8 w-full bg-[#f4f6f9] min-h-full space-y-5'>
      <div className='flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3'>
        <div>
          <h1 className='text-2xl font-bold text-gray-900'>Site Visits</h1>
          <p className='text-sm text-gray-500 mt-1'>Schedule and track property site visits</p>
        </div>
        <button
          type='button'
          onClick={() => navigate('/schedule-site-visit')}
          className='inline-flex items-center justify-center rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-medium text-white hover:bg-blue-700'
        >
          + Schedule Visit
        </button>
      </div>

      <div className='grid grid-cols-2 lg:grid-cols-4 gap-3'>
        {[
          { label: 'Total Visits', value: stats.total },
          { label: 'Today', value: stats.today },
          { label: 'Upcoming', value: stats.scheduled },
          { label: 'Completed', value: stats.completed },
        ].map((card) => (
          <div key={card.label} className='bg-white rounded-xl border border-gray-100 shadow-sm p-4'>
            <p className='text-xs text-gray-500 font-medium'>{card.label}</p>
            <p className='text-2xl font-bold text-gray-900 mt-1'>{card.value}</p>
          </div>
        ))}
      </div>

      <div className='bg-white rounded-xl border border-gray-100 shadow-sm'>
        <div className='flex flex-col sm:flex-row gap-3 p-4 border-b border-gray-100'>
          <input
            type='text'
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder='Search visitor, property, agent, city...'
            className='flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
          />
          <select
            value={status}
            onChange={(e) => setStatus(e.target.value)}
            className='rounded-lg border border-gray-300 px-3 py-2 text-sm'
          >
            <option value=''>All Statuses</option>
            {SITE_VISIT_STATUSES.map((s) => (
              <option key={s} value={s}>{s}</option>
            ))}
          </select>
        </div>

        {error && (
          <div className='mx-4 mt-4 rounded-lg bg-red-50 border border-red-100 px-3 py-2'>
            <p className='text-red-600 text-sm'>{error}</p>
          </div>
        )}

        {loading ? (
          <p className='p-8 text-sm text-gray-500 text-center'>Loading site visits…</p>
        ) : (
          <div className='overflow-x-auto'>
            <table className='min-w-full text-sm'>
              <thead>
                <tr className='text-left text-xs text-gray-500 uppercase tracking-wide border-b border-gray-100 bg-gray-50'>
                  <th className='px-4 py-3 font-medium'>When</th>
                  <th className='px-4 py-3 font-medium'>Visitor</th>
                  <th className='px-4 py-3 font-medium'>Property</th>
                  <th className='px-4 py-3 font-medium'>Assigned To</th>
                  <th className='px-4 py-3 font-medium'>Type</th>
                  <th className='px-4 py-3 font-medium'>Status</th>
                  <th className='px-4 py-3 font-medium'>Actions</th>
                </tr>
              </thead>
              <tbody className='divide-y divide-gray-50'>
                {filtered.length === 0 ? (
                  <tr>
                    <td colSpan={7} className='px-4 py-12 text-center text-gray-500'>
                      No site visits found. Schedule your first visit to get started.
                    </td>
                  </tr>
                ) : (
                  filtered.map((v) => (
                    <tr key={v._id} className='hover:bg-gray-50/70'>
                      <td className='px-4 py-3 whitespace-nowrap text-gray-700'>
                        {formatVisitDateTime(v.scheduledAt)}
                        <p className='text-xs text-gray-400'>{v.durationMinutes || 60} mins</p>
                      </td>
                      <td className='px-4 py-3'>
                        <p className='font-medium text-gray-900'>{v.visitorName}</p>
                        <p className='text-xs text-gray-400'>{v.visitorPhone || v.visitorEmail || '—'}</p>
                      </td>
                      <td className='px-4 py-3'>
                        <p className='text-gray-900'>{v.property?.title || '—'}</p>
                        <p className='text-xs text-gray-400'>{v.property?.locality || v.city || ''}</p>
                      </td>
                      <td className='px-4 py-3 text-gray-700'>{v.assignedTo?.name || '—'}</td>
                      <td className='px-4 py-3 text-gray-700'>{v.visitType}</td>
                      <td className='px-4 py-3'>
                        <span className={`inline-flex rounded-full border px-2.5 py-1 text-xs font-medium ${SITE_VISIT_STATUS_STYLES[v.status] || SITE_VISIT_STATUS_STYLES.Scheduled}`}>
                          {v.status}
                        </span>
                      </td>
                      <td className='px-4 py-3'>
                        <div className='flex items-center gap-2'>
                          <button type='button' onClick={() => setViewVisit(v)} className='text-xs font-medium text-gray-600 hover:text-gray-900'>View</button>
                          <button type='button' onClick={() => navigate(`/site-visits/edit/${v._id}`)} className='text-xs font-medium text-blue-600 hover:text-blue-700'>Edit</button>
                          <button type='button' onClick={() => handleDelete(v._id)} className='text-xs font-medium text-red-600 hover:text-red-700'>Delete</button>
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {viewVisit && (
        <div className='fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50' role='dialog' aria-modal='true'>
          <div className='bg-white rounded-xl shadow-xl max-w-lg w-full p-5 max-h-[90vh] overflow-y-auto'>
            <div className='flex items-start justify-between gap-3 mb-4'>
              <div>
                <h2 className='text-lg font-semibold text-gray-900'>Site Visit Details</h2>
                <p className='text-sm text-gray-500'>{formatVisitDateTime(viewVisit.scheduledAt)}</p>
              </div>
              <button type='button' onClick={() => setViewVisit(null)} className='text-gray-400 hover:text-gray-600 text-xl leading-none'>&times;</button>
            </div>
            <div className='grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm'>
              {[
                ['Visitor', viewVisit.visitorName],
                ['Phone', viewVisit.visitorPhone || '—'],
                ['Email', viewVisit.visitorEmail || '—'],
                ['Property', viewVisit.property?.title || '—'],
                ['Assigned To', viewVisit.assignedTo?.name || '—'],
                ['Type', viewVisit.visitType],
                ['Status', viewVisit.status],
                ['Duration', `${viewVisit.durationMinutes || 60} mins`],
                ['Meeting Point', viewVisit.meetingPoint || '—'],
                ['City', viewVisit.city || '—'],
                ['Interested', viewVisit.interested === true ? 'Yes' : viewVisit.interested === false ? 'No' : '—'],
              ].map(([label, value]) => (
                <div key={label}>
                  <span className='block text-xs font-medium text-gray-500'>{label}</span>
                  <p className='text-gray-900 mt-0.5'>{value}</p>
                </div>
              ))}
            </div>
            {viewVisit.address && (
              <div className='mt-3 text-sm'>
                <span className='block text-xs font-medium text-gray-500'>Address</span>
                <p className='text-gray-900 mt-0.5'>{viewVisit.address}</p>
              </div>
            )}
            {viewVisit.notes && (
              <div className='mt-3 text-sm'>
                <span className='block text-xs font-medium text-gray-500'>Notes</span>
                <p className='text-gray-900 mt-0.5 whitespace-pre-wrap'>{viewVisit.notes}</p>
              </div>
            )}
            {viewVisit.outcome && (
              <div className='mt-3 text-sm'>
                <span className='block text-xs font-medium text-gray-500'>Outcome</span>
                <p className='text-gray-900 mt-0.5 whitespace-pre-wrap'>{viewVisit.outcome}</p>
              </div>
            )}
            {viewVisit.feedback && (
              <div className='mt-3 text-sm'>
                <span className='block text-xs font-medium text-gray-500'>Feedback</span>
                <p className='text-gray-900 mt-0.5 whitespace-pre-wrap'>{viewVisit.feedback}</p>
              </div>
            )}
            <div className='flex gap-2 mt-5'>
              <button
                type='button'
                onClick={() => { setViewVisit(null); navigate(`/site-visits/edit/${viewVisit._id}`) }}
                className='flex-1 bg-blue-600 text-white py-2 rounded-lg text-sm font-medium hover:bg-blue-700'
              >
                Edit Visit
              </button>
              <button
                type='button'
                onClick={() => setViewVisit(null)}
                className='flex-1 border border-gray-300 py-2 rounded-lg text-sm font-medium hover:bg-gray-50'
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default SiteVisitsView
