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
  'Meeting Revisit',
  'Booking Token',
  'Incentive Earned',
  'Pending',
]

const LeadsView = () => {
  const { user, canManageLeads } = useAuth()
  const canManage = canManageLeads()
  const [leads, setLeads] = useState([])
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
          {canManage ? (
            <button
              onClick={() => navigate('/add-lead')}
              className='bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-md text-sm font-medium'
            >
              + Add Lead
            </button>
          ) : null}
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
        <div className='bg-white rounded-lg shadow p-5 border-l-4 border-gray-400'>
          <p className='text-sm font-medium text-gray-600'>Not Interested</p>
          <p className='text-2xl font-bold text-gray-900 mt-1'>
            {loading ? '—' : leads.filter((l) => l.status === 'Not Interested').length}
          </p>
          <p className='text-xs text-gray-500 mt-1'>Based on current filters</p>
        </div>
      </div>

      <div className='bg-white rounded-lg shadow p-4 mb-6'>
        <h3 className='text-sm font-semibold text-gray-700 mb-3'>Filters</h3>
        <div className='grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4'>
          <div>
            <label className='block text-xs font-medium text-gray-600 mb-1'>Search</label>
            <input
              type='text'
              value={filters.search}
              onChange={(e) => handleFilterChange('search', e.target.value)}
              placeholder='Name, business, contact, lead source...'
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
                <option key={s} value={s}>{s}</option>
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
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Name</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Business</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Contact</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Business Type</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Lead Source</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>City</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center whitespace-nowrap'>Status</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Assigned To</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Generated By</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Actions</th>
              </tr>
            </thead>
            <tbody>
              {leads.length === 0 ? (
                <tr>
                  <td colSpan={10} className='px-4 py-12 text-center text-gray-500'>
                    No leads found
                  </td>
                </tr>
              ) : (
                leads.map((l) => (
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
                    <td className='px-4 py-3'>{l.businessType || '—'}</td>
                    <td className='px-4 py-3'>{l.leadSource || '—'}</td>
                    <td className='px-4 py-3'>{l.city || '—'}</td>
                    <td className='px-4 py-3 text-left align-middle whitespace-nowrap'>
                      <span className='inline-flex items-center whitespace-nowrap px-2.5 py-1 rounded-full text-xs font-semibold bg-blue-100 text-blue-800'>
                        {l.status}
                      </span>
                    </td>
                    <td className='px-4 py-3'>{l.assignedTo?.name || '—'}</td>
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
        </div>
      )}

      {showDistributeModal && (
        <div className='fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4'>
          <div className='w-full max-w-2xl rounded-xl bg-white shadow-xl'>
            <div className='border-b px-5 py-4 flex items-center justify-between'>
              <div>
                <h3 className='text-lg font-semibold text-gray-900'>Distribute today’s leads</h3>
                <p className='text-xs text-gray-500 mt-0.5'>
                  Unassigned leads are split equally across Sales Team Leaders, then across each leader’s team.
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
