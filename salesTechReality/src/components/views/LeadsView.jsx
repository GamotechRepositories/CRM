import React, { useEffect, useRef, useState } from 'react'
import api from '../../api/axios'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import { EditIcon, ViewIcon } from '../Icons'

const STATUS_OPTIONS = [
  'Call not Received',
  'Call You After Sometime',
  'Interested',
  'Not Interested',
  'Meeting Schedule',
  'Site Visit',
  'Zoom Meeting',
  'Booking Done',
  'Token Done',
  'Pending',
  'Converted',
  'Lost',
  'Closed',
]

const LEADS_PER_PAGE = 100

const getLeadStatusBadge = (status) => {
  switch (status) {
    case 'Interested':
      return {
        pill: 'bg-emerald-100 text-emerald-800 border border-emerald-200',
        dot: 'bg-emerald-500',
      }
    case 'Not Interested':
      return {
        pill: 'bg-red-100 text-red-800 border border-red-200',
        dot: 'bg-red-500',
      }
    case 'Converted':
      return {
        pill: 'bg-yellow-100 text-yellow-900 border border-yellow-400',
        dot: 'bg-yellow-500',
      }
    case 'Booking Done':
    case 'Token Done':
      return {
        pill: 'bg-green-100 text-green-800 border border-green-200',
        dot: 'bg-green-500',
      }
    case 'Lost':
      return {
        pill: 'bg-rose-100 text-rose-800 border border-rose-200',
        dot: 'bg-rose-500',
      }
    case 'Closed':
      return {
        pill: 'bg-slate-200 text-slate-800 border border-slate-300',
        dot: 'bg-slate-600',
      }
    case 'Pending':
    case 'Call You After Sometime':
      return {
        pill: 'bg-amber-100 text-amber-800 border border-amber-200',
        dot: 'bg-amber-500',
      }
    default:
      return {
        pill: 'bg-blue-100 text-blue-800 border border-blue-200',
        dot: 'bg-blue-500',
      }
  }
}

const getStatusOptionLabel = (status) => {
  if (status === 'Interested') return '🟢 Interested'
  if (status === 'Not Interested') return '🔴 Not Interested'
  if (status === 'Converted') return '🟡 Converted'
  if (status === 'Lost') return '🔴 Lost'
  if (status === 'Closed') return '⚫ Closed'
  return status
}

const LeadsView = () => {
  const { user, canManageLeads } = useAuth()
  const canManage = canManageLeads()
  const [leads, setLeads] = useState([])
  const [currentPage, setCurrentPage] = useState(1)
  const [employees, setEmployees] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [filters, setFilters] = useState({
    status: '',
    date: '',
    dateFrom: '',
    dateTo: '',
    employee: '',
    assignedTo: '',
    unassigned: '',
    businessType: '',
    leadSource: '',
    city: '',
    state: '',
    search: '',
  })
  const [importing, setImporting] = useState(false)
  const [importResult, setImportResult] = useState(null)
  const [distributing, setDistributing] = useState(false)
  const [distributionPreview, setDistributionPreview] = useState(null)
  const [distributionResult, setDistributionResult] = useState(null)
  const [showDistributeModal, setShowDistributeModal] = useState(false)
  const fileInputRef = useRef(null)
  const navigate = useNavigate()

  const totalPages = Math.max(1, Math.ceil(leads.length / LEADS_PER_PAGE))
  const safePage = Math.min(currentPage, totalPages)
  const startIdx = (safePage - 1) * LEADS_PER_PAGE
  const paginatedLeads = leads.slice(startIdx, startIdx + LEADS_PER_PAGE)

  useEffect(() => {
    setCurrentPage(1)
  }, [filters])

  const salesEmployees = employees.filter((e) =>
    /sales/i.test(String(e.department || ''))
  )

  const fetchLeads = async () => {
    if (!user?._id) return
    try {
      setLoading(true)
      const params = new URLSearchParams()
      params.append('viewerId', user._id)
      Object.entries(filters).forEach(([k, v]) => {
        if (!v) return
        if (!canManage && (k === 'assignedTo' || k === 'unassigned' || k === 'employee')) return
        params.append(k, v)
      })
      const res = await api.get(`/leads?${params.toString()}`)
      setLeads(Array.isArray(res.data) ? res.data : [])
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Error fetching leads')
    } finally {
      setLoading(false)
    }
  }

  const fetchEmployees = async () => {
    try {
      const res = await api.get('/employees')
      setEmployees(Array.isArray(res.data) ? res.data : res.data?.data || [])
    } catch (err) {
      console.error('Failed to fetch employees:', err)
    }
  }

  useEffect(() => {
    fetchEmployees()
  }, [])

  useEffect(() => {
    fetchLeads()
  }, [filters, user?._id, canManage])

  const handleFilterChange = (key, value) => {
    setFilters((f) => ({ ...f, [key]: value }))
  }

  const handleCsvUpload = async (event) => {
    const file = event.target.files?.[0]
    event.target.value = ''
    if (!file) return
    if (!canManage) {
      setError('Only Admin, Sales Manager, or Sales Team Lead can upload leads')
      return
    }

    if (!/\.csv$/i.test(file.name) && file.type !== 'text/csv') {
      setError('Please upload a CSV file exported from Google Sheets')
      return
    }

    setImporting(true)
    setImportResult(null)
    setError(null)
    try {
      const csvText = await file.text()
      const res = await api.post('/leads/import-csv', {
        csvText,
        fileName: file.name,
        importedBy: user?._id,
      })
      setImportResult(res.data)
      await fetchLeads()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'CSV import failed')
    } finally {
      setImporting(false)
    }
  }

  const openDistributeModal = async () => {
    if (!canManage) {
      setError('Only Admin, Sales Manager, or Sales Team Lead can distribute leads')
      return
    }
    setError(null)
    setDistributionResult(null)
    setDistributing(true)
    try {
      const res = await api.get('/leads/distribution-preview', {
        params: { actorId: user?._id },
      })
      setDistributionPreview(res.data)
      setShowDistributeModal(true)
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to load distribution preview')
    } finally {
      setDistributing(false)
    }
  }

  const confirmDistribute = async () => {
    setDistributing(true)
    setError(null)
    try {
      const res = await api.post('/leads/distribute', {
        distributedBy: user?._id,
      })
      setDistributionResult(res.data)
      setDistributionPreview(res.data)
      await fetchLeads()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to distribute leads')
    } finally {
      setDistributing(false)
    }
  }

  return (
    <div className='p-8'>
      <div className='flex flex-wrap items-center justify-between gap-3 mb-6'>
        <div>
          <h1 className='text-2xl font-bold text-gray-900'>Lead Management</h1>
          <p className='text-gray-600 mt-1 text-sm'>Manage and qualify sales leads.</p>
        </div>
        <div className='flex flex-wrap items-center gap-2'>
          {canManage ? (
            <>
              <input
                ref={fileInputRef}
                type='file'
                accept='.csv,text/csv'
                className='hidden'
                onChange={handleCsvUpload}
              />
              <button
                type='button'
                disabled={distributing}
                onClick={openDistributeModal}
                className='bg-amber-600 hover:bg-amber-700 text-white px-4 py-2 rounded-md text-sm font-medium disabled:opacity-50'
              >
                {distributing && !showDistributeModal ? 'Loading…' : 'Distribute Leads'}
              </button>
              <button
                type='button'
                disabled={importing}
                onClick={() => fileInputRef.current?.click()}
                className='bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-md text-sm font-medium disabled:opacity-50'
              >
                {importing ? 'Uploading…' : 'Upload Google Sheet (CSV)'}
              </button>
            </>
          ) : (
            <p className='text-sm text-gray-500 mr-2'>Showing leads assigned to you</p>
          )}
          <button
            onClick={() => navigate('/add-lead')}
            className='bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-md text-sm font-medium'
          >
            + Add Lead
          </button>
        </div>
      </div>

      {importResult?.summary && (
        <div className='mb-4 rounded-lg border border-indigo-200 bg-indigo-50 px-4 py-3 text-sm text-indigo-900'>
          Imported <strong>{importResult.summary.totalParsed}</strong> row(s):{' '}
          {importResult.summary.sheetCreated} new sheet leads,{' '}
          {importResult.summary.sheetUpdated} updated, CRM synced. Refresh filters if needed.
          {importResult.errors?.length ? (
            <p className='mt-1 text-xs text-amber-800'>
              {importResult.errors.length} warning(s): {importResult.errors[0]}
            </p>
          ) : null}
        </div>
      )}

      {distributionResult && (
        <div className='mb-4 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900'>
          Distributed <strong>{distributionResult.updated}</strong> of{' '}
          <strong>{distributionResult.totalLeads}</strong> today’s unassigned leads across{' '}
          <strong>{distributionResult.teamLeaderCount}</strong> sales team leader(s).
        </div>
      )}

      <div className='grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6'>
        <div className='bg-white rounded-lg shadow p-5 border-l-4 border-blue-500'>
          <p className='text-sm font-medium text-gray-600'>Total Leads</p>
          <p className='text-2xl font-bold text-gray-900 mt-1'>
            {loading ? '—' : leads.length}
          </p>
          <p className='text-xs text-gray-500 mt-1'>Based on current filters</p>
        </div>
        <div className='bg-white rounded-lg shadow p-5 border-l-4 border-green-500'>
          <p className='text-sm font-medium text-gray-600'>Interested</p>
          <p className='text-2xl font-bold text-gray-900 mt-1'>
            {loading ? '—' : leads.filter((l) => l.status === 'Interested').length}
          </p>
          <p className='text-xs text-gray-500 mt-1'>Based on current filters</p>
        </div>
        <div className='bg-white rounded-lg shadow p-5 border-l-4 border-amber-500'>
          <p className='text-sm font-medium text-gray-600'>Meeting Schedule</p>
          <p className='text-2xl font-bold text-gray-900 mt-1'>
            {loading ? '—' : leads.filter((l) => l.status === 'Meeting Schedule').length}
          </p>
          <p className='text-xs text-gray-500 mt-1'>Based on current filters</p>
        </div>
        <div className='bg-white rounded-lg shadow p-5 border-l-4 border-red-500'>
          <p className='text-sm font-medium text-red-700 flex items-center gap-1.5'>
            <span className='w-2.5 h-2.5 rounded-full bg-red-500 inline-block' />
            Not Interested
          </p>
          <p className='text-2xl font-bold text-gray-900 mt-1'>
            {loading ? '—' : leads.filter((l) => l.status === 'Not Interested').length}
          </p>
          <p className='text-xs text-gray-500 mt-1'>Based on current filters</p>
        </div>
      </div>

      <div className='bg-white rounded-lg shadow p-4 mb-6'>
        <div className='flex flex-wrap items-center justify-between gap-3 mb-3'>
          <h3 className='text-sm font-semibold text-gray-700'>Filters</h3>
          <div className='flex flex-wrap items-center gap-2'>
            <button
              type='button'
              onClick={() => handleFilterChange('status', '')}
              className={`px-3 py-1 rounded-full text-xs font-semibold border transition-colors ${
                filters.status === ''
                  ? 'bg-gray-800 text-white border-gray-800'
                  : 'bg-white text-gray-700 border-gray-300 hover:bg-gray-50'
              }`}
            >
              All Status
            </button>
            <button
              type='button'
              onClick={() => handleFilterChange('status', filters.status === 'Interested' ? '' : 'Interested')}
              className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold border transition-colors ${
                filters.status === 'Interested'
                  ? 'bg-emerald-600 text-white border-emerald-600 shadow-sm'
                  : 'bg-emerald-50 text-emerald-800 border-emerald-200 hover:bg-emerald-100'
              }`}
            >
              <span className={`w-2 h-2 rounded-full ${filters.status === 'Interested' ? 'bg-white' : 'bg-emerald-500'}`} />
              Interested
            </button>
            <button
              type='button'
              onClick={() => handleFilterChange('status', filters.status === 'Not Interested' ? '' : 'Not Interested')}
              className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold border transition-colors ${
                filters.status === 'Not Interested'
                  ? 'bg-red-600 text-white border-red-600 shadow-sm'
                  : 'bg-red-50 text-red-800 border-red-200 hover:bg-red-100'
              }`}
            >
              <span className={`w-2 h-2 rounded-full ${filters.status === 'Not Interested' ? 'bg-white' : 'bg-red-500'}`} />
              Not Interested
            </button>
            <button
              type='button'
              onClick={() => handleFilterChange('status', filters.status === 'Converted' ? '' : 'Converted')}
              className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold border transition-colors ${
                filters.status === 'Converted'
                  ? 'bg-yellow-500 text-white border-yellow-600 shadow-sm'
                  : 'bg-yellow-50 text-yellow-900 border-yellow-400 hover:bg-yellow-100'
              }`}
            >
              <span className={`w-2 h-2 rounded-full ${filters.status === 'Converted' ? 'bg-white' : 'bg-yellow-500'}`} />
              Converted
            </button>
            <button
              type='button'
              onClick={() => handleFilterChange('status', filters.status === 'Lost' ? '' : 'Lost')}
              className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold border transition-colors ${
                filters.status === 'Lost'
                  ? 'bg-rose-600 text-white border-rose-600 shadow-sm'
                  : 'bg-rose-50 text-rose-800 border-rose-200 hover:bg-rose-100'
              }`}
            >
              <span className={`w-2 h-2 rounded-full ${filters.status === 'Lost' ? 'bg-white' : 'bg-rose-500'}`} />
              Lost
            </button>
            <button
              type='button'
              onClick={() => handleFilterChange('status', filters.status === 'Closed' ? '' : 'Closed')}
              className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold border transition-colors ${
                filters.status === 'Closed'
                  ? 'bg-slate-700 text-white border-slate-700 shadow-sm'
                  : 'bg-slate-100 text-slate-800 border-slate-300 hover:bg-slate-200'
              }`}
            >
              <span className={`w-2 h-2 rounded-full ${filters.status === 'Closed' ? 'bg-white' : 'bg-slate-600'}`} />
              Closed
            </button>
          </div>
        </div>
        <div className='grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4'>
          <div>
            <label className='block text-xs font-medium text-gray-600 mb-1'>Search</label>
            <input
              type='text'
              value={filters.search}
              onChange={(e) => handleFilterChange('search', e.target.value)}
              placeholder='Client, project, contact, lead source...'
              className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm'
            />
          </div>
          <div>
            <label className='block text-xs font-medium text-gray-600 mb-1'>Status</label>
            <select
              value={filters.status}
              onChange={(e) => handleFilterChange('status', e.target.value)}
              className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm'
            >
              <option value=''>All status</option>
              {STATUS_OPTIONS.map((s) => (
                <option key={s} value={s}>{getStatusOptionLabel(s)}</option>
              ))}
            </select>
          </div>
          <div>
            <label className='block text-xs font-medium text-gray-600 mb-1'>Date</label>
            <input
              type='date'
              value={filters.date}
              onChange={(e) => handleFilterChange('date', e.target.value)}
              className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm'
            />
          </div>
          <div>
            <label className='block text-xs font-medium text-gray-600 mb-1'>Date From</label>
            <input
              type='date'
              value={filters.dateFrom}
              onChange={(e) => handleFilterChange('dateFrom', e.target.value)}
              className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm'
            />
          </div>
          <div>
            <label className='block text-xs font-medium text-gray-600 mb-1'>Date To</label>
            <input
              type='date'
              value={filters.dateTo}
              onChange={(e) => handleFilterChange('dateTo', e.target.value)}
              className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm'
            />
          </div>
          {canManage ? (
            <>
              <div>
                <label className='block text-xs font-medium text-gray-600 mb-1'>Employee</label>
                <select
                  value={filters.employee}
                  onChange={(e) => handleFilterChange('employee', e.target.value)}
                  className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm'
                >
                  <option value=''>All</option>
                  {employees.map((e) => (
                    <option key={e._id} value={e._id}>{e.name}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className='block text-xs font-medium text-gray-600 mb-1'>Assigned To (Sales)</label>
                <select
                  value={filters.assignedTo}
                  onChange={(e) => {
                    handleFilterChange('assignedTo', e.target.value)
                    if (e.target.value) handleFilterChange('unassigned', '')
                  }}
                  className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm'
                >
                  <option value=''>All assignees</option>
                  {salesEmployees.map((e) => (
                    <option key={e._id} value={e._id}>{e.name}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className='block text-xs font-medium text-gray-600 mb-1'>Assignment</label>
                <select
                  value={filters.unassigned}
                  onChange={(e) => {
                    handleFilterChange('unassigned', e.target.value)
                    if (e.target.value) handleFilterChange('assignedTo', '')
                  }}
                  className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm'
                >
                  <option value=''>All</option>
                  <option value='true'>Unassigned only</option>
                </select>
              </div>
            </>
          ) : null}
          <div>
            <label className='block text-xs font-medium text-gray-600 mb-1'>Business Type</label>
            <input
              type='text'
              value={filters.businessType}
              onChange={(e) => handleFilterChange('businessType', e.target.value)}
              placeholder='Filter by business type'
              className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm'
            />
          </div>
          <div>
            <label className='block text-xs font-medium text-gray-600 mb-1'>Lead Source</label>
            <input
              type='text'
              value={filters.leadSource}
              onChange={(e) => handleFilterChange('leadSource', e.target.value)}
              placeholder='Filter by lead source'
              className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm'
            />
          </div>
          <div>
            <label className='block text-xs font-medium text-gray-600 mb-1'>City</label>
            <input
              type='text'
              value={filters.city}
              onChange={(e) => handleFilterChange('city', e.target.value)}
              placeholder='Filter by city'
              className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm'
            />
          </div>
          <div>
            <label className='block text-xs font-medium text-gray-600 mb-1'>State</label>
            <input
              type='text'
              value={filters.state}
              onChange={(e) => handleFilterChange('state', e.target.value)}
              placeholder='Filter by state'
              className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm'
            />
          </div>
        </div>
      </div>

      {loading ? (
        <p className='text-sm'>Loading...</p>
      ) : error ? (
        <p className='text-red-600 text-sm'>{error}</p>
      ) : (
        <div className='bg-white rounded-lg shadow overflow-x-auto'>
          <table className='w-full table-auto text-sm'>
            <thead className='text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>
              <tr className='text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Client Name</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Project Name</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Contact</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Requirement</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Client Budget</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Business Type</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Lead Source</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>City</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center whitespace-nowrap'>Status</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Assigned To</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Site Co-ordinator</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Generated By</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Actions</th>
              </tr>
            </thead>
            <tbody>
              {leads.length === 0 ? (
                <tr>
                  <td colSpan={13} className='px-4 py-12 text-center text-gray-500'>
                    No leads found
                  </td>
                </tr>
              ) : (
                paginatedLeads.map((l) => (
                  <tr
                    key={l._id}
                    className='border-b hover:bg-gray-50 cursor-pointer transition-colors'
                    onClick={() => navigate(`/leads/view/${l._id}`)}
                    role='link'
                    tabIndex={0}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter' || e.key === ' ') {
                        e.preventDefault()
                        navigate(`/leads/view/${l._id}`)
                      }
                    }}
                  >
                    <td className='px-4 py-3 font-medium text-indigo-700'>{l.name}</td>
                    <td className='px-4 py-3'>{l.businessName}</td>
                    <td className='px-4 py-3'>{l.contactNumber}</td>
                    <td className='px-4 py-3'>{l.requirement || '—'}</td>
                    <td className='px-4 py-3 whitespace-nowrap'>{l.clientBudget || '—'}</td>
                    <td className='px-4 py-3'>{l.businessType || '—'}</td>
                    <td className='px-4 py-3'>{l.leadSource || '—'}</td>
                    <td className='px-4 py-3'>{l.city || '—'}</td>
                    <td className='px-4 py-3 text-left align-middle whitespace-nowrap'>
                      {(() => {
                        const badge = getLeadStatusBadge(l.status)
                        return (
                          <span className={`inline-flex items-center gap-1.5 whitespace-nowrap px-2.5 py-1 rounded-full text-xs font-semibold ${badge.pill}`}>
                            <span className={`w-2 h-2 rounded-full shrink-0 ${badge.dot}`} />
                            {l.status}
                          </span>
                        )
                      })()}
                    </td>
                    <td className='px-4 py-3'>{l.assignedTo?.name || '—'}</td>
                    <td className='px-4 py-3'>{l.siteCoordinator?.name || '—'}</td>
                    <td className='px-4 py-3'>{l.generatedBy?.name || '—'}</td>
                    <td className='px-4 py-3 cursor-default' onClick={(e) => e.stopPropagation()}>
                      <div className='flex items-center gap-2'>
                        <button
                          type='button'
                          onClick={() => navigate(`/leads/view/${l._id}`)}
                          className='p-1.5 rounded-lg text-gray-700 hover:bg-gray-100 transition-colors'
                          title='View details'
                        >
                          <ViewIcon />
                        </button>
                        <button
                          type='button'
                          onClick={() => navigate(`/leads/edit/${l._id}`)}
                          className='p-1.5 rounded-lg text-blue-600 hover:bg-blue-50 transition-colors'
                          title='Edit'
                        >
                          <EditIcon />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
          {leads.length > 0 && (
            <div className='px-4 py-3 border-t border-gray-200 bg-gray-50 flex flex-wrap items-center justify-between gap-3 text-sm'>
              <span className='text-gray-600'>
                Showing <strong>{startIdx + 1}</strong>–<strong>{Math.min(startIdx + LEADS_PER_PAGE, leads.length)}</strong> of <strong>{leads.length}</strong> leads
              </span>
              <div className='flex items-center gap-1.5'>
                <button
                  type='button'
                  disabled={safePage <= 1}
                  onClick={() => { setCurrentPage(1); window.scrollTo({ top: 0, behavior: 'smooth' }) }}
                  className='px-2.5 py-1.5 rounded-lg border border-gray-300 bg-white text-gray-700 hover:bg-gray-100 disabled:opacity-40 disabled:cursor-not-allowed text-xs font-medium'
                >
                  First
                </button>
                <button
                  type='button'
                  disabled={safePage <= 1}
                  onClick={() => { setCurrentPage((p) => Math.max(1, p - 1)); window.scrollTo({ top: 0, behavior: 'smooth' }) }}
                  className='px-3 py-1.5 rounded-lg border border-gray-300 bg-white text-gray-700 hover:bg-gray-100 disabled:opacity-40 disabled:cursor-not-allowed text-xs font-medium'
                >
                  Prev
                </button>
                <span className='px-3 py-1.5 text-xs font-semibold text-gray-700'>
                  Page {safePage} of {totalPages}
                </span>
                <button
                  type='button'
                  disabled={safePage >= totalPages}
                  onClick={() => { setCurrentPage((p) => Math.min(totalPages, p + 1)); window.scrollTo({ top: 0, behavior: 'smooth' }) }}
                  className='px-3 py-1.5 rounded-lg border border-gray-300 bg-white text-gray-700 hover:bg-gray-100 disabled:opacity-40 disabled:cursor-not-allowed text-xs font-medium'
                >
                  Next
                </button>
                <button
                  type='button'
                  disabled={safePage >= totalPages}
                  onClick={() => { setCurrentPage(totalPages); window.scrollTo({ top: 0, behavior: 'smooth' }) }}
                  className='px-2.5 py-1.5 rounded-lg border border-gray-300 bg-white text-gray-700 hover:bg-gray-100 disabled:opacity-40 disabled:cursor-not-allowed text-xs font-medium'
                >
                  Last
                </button>
              </div>
            </div>
          )}
        </div>
      )}

      {showDistributeModal && (
        <div className='fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4'>
          <div className='w-full max-w-2xl rounded-xl bg-white shadow-xl'>
            <div className='border-b px-5 py-4 flex items-center justify-between'>
              <div>
                <h3 className='text-lg font-semibold text-gray-900'>Distribute today’s leads</h3>
                <p className='text-xs text-gray-500 mt-0.5'>
                  Unassigned leads are split equally across Sales Team Leaders, then only to Sales Executives on each team (not Site Co-ordinators).
                </p>
              </div>
              <button
                type='button'
                className='text-gray-500 hover:text-gray-800'
                onClick={() => setShowDistributeModal(false)}
              >
                ✕
              </button>
            </div>
            <div className='px-5 py-4 max-h-[60vh] overflow-y-auto space-y-4'>
              <div className='grid grid-cols-2 gap-3 text-sm'>
                <div className='rounded-lg border bg-gray-50 p-3'>
                  <p className='text-xs text-gray-500'>Today’s unassigned leads</p>
                  <p className='text-xl font-bold text-gray-900'>{distributionPreview?.totalLeads ?? 0}</p>
                </div>
                <div className='rounded-lg border bg-gray-50 p-3'>
                  <p className='text-xs text-gray-500'>Sales Team Leaders</p>
                  <p className='text-xl font-bold text-gray-900'>{distributionPreview?.teamLeaderCount ?? 0}</p>
                </div>
              </div>
              {(distributionPreview?.plan || []).map((block) => (
                <div key={block.teamLeader._id} className='rounded-lg border border-gray-200 p-3'>
                  <p className='text-sm font-semibold text-gray-900'>
                    {block.teamLeader.name}{' '}
                    <span className='text-xs font-normal text-gray-500'>— {block.leadCount} lead(s)</span>
                  </p>
                  <ul className='mt-2 space-y-1'>
                    {(block.members || []).map((m) => (
                      <li key={m.employee._id} className='text-xs text-gray-700 flex justify-between'>
                        <span>{m.employee.name}</span>
                        <span className='font-medium'>{m.leadCount}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
              {!distributionPreview?.totalLeads ? (
                <p className='text-sm text-gray-500'>No unassigned leads for today to distribute.</p>
              ) : null}
            </div>
            <div className='border-t px-5 py-4 flex justify-end gap-2'>
              <button
                type='button'
                onClick={() => setShowDistributeModal(false)}
                className='px-4 py-2 rounded-lg border text-sm'
              >
                Close
              </button>
              <button
                type='button'
                disabled={distributing || !distributionPreview?.totalLeads || Boolean(distributionResult)}
                onClick={confirmDistribute}
                className='px-4 py-2 rounded-lg bg-amber-600 text-white text-sm font-medium disabled:opacity-50'
              >
                {distributing ? 'Distributing…' : distributionResult ? 'Distributed' : 'Confirm distribute'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default LeadsView
