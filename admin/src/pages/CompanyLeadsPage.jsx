import React, { useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import api from '../api/axios'
import AdminCompanyShell from '../components/AdminCompanyShell'
import { EditIcon, ViewIcon, DeleteIcon } from '../components/Icons'
import { TENANT_NAMES } from '../config/tenants'
import { leadStatusesForTenant } from './ModulePage.shared'

const statusBadgeClass = (status = '') => {
  const s = String(status || '').toLowerCase()
  if (
    [
      'interested',
      'booking token',
      'incentive earned',
      'booking done',
      'token done',
      'approved',
      'completed',
    ].some((k) => s.includes(k))
  ) {
    return 'bg-emerald-100 text-emerald-800 border border-emerald-200'
  }
  if (
    [
      'meeting schedule',
      'site visit',
      'meeting revisit',
      'zoom meeting',
      'call you after',
      'pending',
      'in progress',
    ].some((k) => s.includes(k))
  ) {
    return 'bg-amber-100 text-amber-800 border border-amber-200'
  }
  if (
    ['not interested', 'call not received', 'rejected', 'cancelled', 'inactive'].some((k) =>
      s.includes(k)
    )
  ) {
    return 'bg-rose-100 text-rose-800 border border-rose-200'
  }
  return 'bg-blue-100 text-blue-800 border border-blue-200'
}

export default function CompanyLeadsPage() {
  const { tenantId } = useParams()
  const navigate = useNavigate()
  const companyName = TENANT_NAMES[tenantId] || tenantId

  const [leads, setLeads] = useState([])
  const [employees, setEmployees] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [stats, setStats] = useState({
    total: 0,
    interested: 0,
    meetingSchedule: 0,
    notInterested: 0,
  })

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

  const statusOptions = useMemo(() => leadStatusesForTenant(tenantId), [tenantId])

  const salesEmployees = useMemo(
    () =>
      employees.filter((e) =>
        /sales/i.test(String(e.department || e.designation?.title || e.designation || ''))
      ),
    [employees]
  )

  const fetchEmployees = async () => {
    if (!tenantId) return
    try {
      const res = await api.get(`/companies/${tenantId}/employees`)
      const list = Array.isArray(res.data?.employees)
        ? res.data.employees
        : Array.isArray(res.data)
          ? res.data
          : []
      setEmployees(list)
    } catch (err) {
      console.error('Failed to load employees:', err)
    }
  }

  const fetchLeads = async () => {
    if (!tenantId) return
    try {
      setLoading(true)
      setError(null)
      const params = {}
      Object.entries(filters).forEach(([k, v]) => {
        if (v !== '' && v !== null && v !== undefined) {
          params[k] = v
        }
      })
      const res = await api.get(`/companies/${tenantId}/modules/leads`, { params })
      const items = Array.isArray(res.data?.items) ? res.data.items : []
      setLeads(items)
      if (res.data?.stats) {
        setStats(res.data.stats)
      } else {
        setStats({
          total: items.length,
          interested: items.filter((l) => l.status === 'Interested').length,
          meetingSchedule: items.filter((l) => l.status === 'Meeting Schedule').length,
          notInterested: items.filter((l) => l.status === 'Not Interested').length,
        })
      }
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Error fetching leads')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchEmployees()
  }, [tenantId])

  useEffect(() => {
    fetchLeads()
  }, [tenantId, filters])

  const handleFilterChange = (key, value) => {
    setFilters((f) => ({ ...f, [key]: value }))
  }

  const handleResetFilters = () => {
    setFilters({
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
  }

  const handleCsvUpload = async (event) => {
    const file = event.target.files?.[0]
    event.target.value = ''
    if (!file) return

    if (!/\.csv$/i.test(file.name) && file.type !== 'text/csv') {
      setError('Please upload a CSV file exported from Google Sheets')
      return
    }

    setImporting(true)
    setImportResult(null)
    setError(null)
    try {
      const csvText = await file.text()
      const res = await api.post(`/companies/${tenantId}/leads/import-csv`, {
        csvText,
        fileName: file.name,
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
    setError(null)
    setDistributionResult(null)
    setDistributing(true)
    try {
      const res = await api.get(`/companies/${tenantId}/leads/distribution-preview`)
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
      const res = await api.post(`/companies/${tenantId}/leads/distribute`)
      setDistributionResult(res.data)
      setDistributionPreview(res.data)
      await fetchLeads()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to distribute leads')
    } finally {
      setDistributing(false)
    }
  }

  const handleDeleteLead = async (e, leadId) => {
    e.stopPropagation()
    if (!window.confirm('Are you sure you want to delete this lead?')) return
    try {
      await api.delete(`/companies/${tenantId}/leads/${leadId}`)
      await fetchLeads()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to delete lead')
    }
  }

  // Active filter count (excluding default empty)
  const activeFiltersCount = useMemo(() => {
    return Object.values(filters).filter((v) => v !== '' && v !== null && v !== undefined).length
  }, [filters])

  return (
    <AdminCompanyShell activeNav='leads'>
      <div className='w-full p-4 md:p-8'>
        {/* Page Top Header */}
        <div className='flex flex-wrap items-center justify-between gap-4 mb-6'>
          <div>
            <div className='flex items-center gap-2'>
              <h1 className='text-2xl md:text-3xl font-bold text-gray-900 tracking-tight'>
                Lead Management
              </h1>
              <span className='px-2.5 py-0.5 rounded-full text-xs font-semibold bg-blue-50 text-blue-700 border border-blue-200'>
                {companyName}
              </span>
            </div>
            <p className='text-gray-500 mt-1 text-sm'>
              Manage, qualify, and distribute sales leads across teams.
            </p>
          </div>

          <div className='flex flex-wrap items-center gap-2.5'>
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
              className='inline-flex items-center gap-1.5 bg-amber-600 hover:bg-amber-700 active:bg-amber-800 text-white px-4 py-2 rounded-xl text-sm font-medium shadow-sm transition-all disabled:opacity-50 cursor-pointer'
            >
              <span>{distributing && !showDistributeModal ? 'Loading…' : 'Distribute Leads'}</span>
            </button>

            <button
              type='button'
              disabled={importing}
              onClick={() => fileInputRef.current?.click()}
              className='inline-flex items-center gap-1.5 bg-indigo-600 hover:bg-indigo-700 active:bg-indigo-800 text-white px-4 py-2 rounded-xl text-sm font-medium shadow-sm transition-all disabled:opacity-50 cursor-pointer'
            >
              <span>{importing ? 'Uploading…' : 'Upload Google Sheet (CSV)'}</span>
            </button>

            <button
              type='button'
              onClick={() => navigate(`/company/${tenantId}/add-lead`)}
              className='inline-flex items-center gap-1.5 bg-green-600 hover:bg-green-700 active:bg-green-800 text-white px-4 py-2 rounded-xl text-sm font-semibold shadow-sm transition-all cursor-pointer'
            >
              <span>+ Add Lead</span>
            </button>
          </div>
        </div>

        {/* Notifications / Alerts */}
        {error && (
          <div className='mb-4 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-800 flex items-center justify-between'>
            <span>{error}</span>
            <button
              type='button'
              onClick={() => setError(null)}
              className='text-red-500 hover:text-red-700 text-sm font-medium ml-4'
            >
              Dismiss
            </button>
          </div>
        )}

        {importResult?.summary && (
          <div className='mb-4 rounded-xl border border-indigo-200 bg-indigo-50 p-4 text-sm text-indigo-900 shadow-sm'>
            <p className='font-semibold'>Import Succeeded</p>
            <p className='mt-0.5 text-xs text-indigo-700'>
              Imported <strong>{importResult.summary.totalParsed}</strong> row(s):{' '}
              <strong>{importResult.summary.sheetCreated}</strong> new sheet leads,{' '}
              <strong>{importResult.summary.sheetUpdated}</strong> updated, CRM synced.
            </p>
            {importResult.errors?.length ? (
              <p className='mt-1 text-xs text-amber-800'>
                {importResult.errors.length} warning(s): {importResult.errors[0]}
              </p>
            ) : null}
          </div>
        )}

        {distributionResult && (
          <div className='mb-4 rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900 shadow-sm'>
            <p className='font-semibold'>Leads Distributed Successfully</p>
            <p className='mt-0.5 text-xs text-amber-800'>
              Distributed <strong>{distributionResult.updated}</strong> of{' '}
              <strong>{distributionResult.totalLeads}</strong> today’s unassigned leads across{' '}
              <strong>{distributionResult.teamLeaderCount}</strong> sales team leader(s).
            </p>
          </div>
        )}

        {/* 4 Stat Cards */}
        <div className='grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6'>
          <button
            type='button'
            onClick={() => handleFilterChange('status', '')}
            className={`text-left bg-white rounded-xl shadow-sm hover:shadow p-5 border-l-4 border-blue-500 transition-all cursor-pointer ${
              filters.status === '' ? 'ring-2 ring-blue-500/20' : ''
            }`}
          >
            <p className='text-xs font-semibold uppercase tracking-wider text-gray-500'>
              Total Leads
            </p>
            <p className='text-2xl md:text-3xl font-bold text-gray-900 mt-1 tabular-nums'>
              {loading ? '—' : stats.total ?? leads.length}
            </p>
            <p className='text-xs text-gray-400 mt-1'>
              {filters.status === '' ? 'All leads in company' : 'Click to show all'}
            </p>
          </button>

          <button
            type='button'
            onClick={() =>
              handleFilterChange('status', filters.status === 'Interested' ? '' : 'Interested')
            }
            className={`text-left bg-white rounded-xl shadow-sm hover:shadow p-5 border-l-4 border-emerald-500 transition-all cursor-pointer ${
              filters.status === 'Interested' ? 'ring-2 ring-emerald-500/30' : ''
            }`}
          >
            <p className='text-xs font-semibold uppercase tracking-wider text-gray-500'>
              Interested
            </p>
            <p className='text-2xl md:text-3xl font-bold text-emerald-700 mt-1 tabular-nums'>
              {loading
                ? '—'
                : stats.interested ?? leads.filter((l) => l.status === 'Interested').length}
            </p>
            <p className='text-xs text-gray-400 mt-1'>
              {filters.status === 'Interested' ? 'Active filter · Click to clear' : 'Click to filter'}
            </p>
          </button>

          <button
            type='button'
            onClick={() =>
              handleFilterChange(
                'status',
                filters.status === 'Meeting Schedule' ? '' : 'Meeting Schedule'
              )
            }
            className={`text-left bg-white rounded-xl shadow-sm hover:shadow p-5 border-l-4 border-amber-500 transition-all cursor-pointer ${
              filters.status === 'Meeting Schedule' ? 'ring-2 ring-amber-500/30' : ''
            }`}
          >
            <p className='text-xs font-semibold uppercase tracking-wider text-gray-500'>
              Meeting Schedule
            </p>
            <p className='text-2xl md:text-3xl font-bold text-amber-700 mt-1 tabular-nums'>
              {loading
                ? '—'
                : stats.meetingSchedule ??
                  leads.filter((l) => l.status === 'Meeting Schedule').length}
            </p>
            <p className='text-xs text-gray-400 mt-1'>
              {filters.status === 'Meeting Schedule'
                ? 'Active filter · Click to clear'
                : 'Click to filter'}
            </p>
          </button>

          <button
            type='button'
            onClick={() =>
              handleFilterChange(
                'status',
                filters.status === 'Not Interested' ? '' : 'Not Interested'
              )
            }
            className={`text-left bg-white rounded-xl shadow-sm hover:shadow p-5 border-l-4 border-rose-500 transition-all cursor-pointer ${
              filters.status === 'Not Interested' ? 'ring-2 ring-rose-500/30' : ''
            }`}
          >
            <p className='text-xs font-semibold uppercase tracking-wider text-gray-500'>
              Not Interested
            </p>
            <p className='text-2xl md:text-3xl font-bold text-rose-700 mt-1 tabular-nums'>
              {loading
                ? '—'
                : stats.notInterested ?? leads.filter((l) => l.status === 'Not Interested').length}
            </p>
            <p className='text-xs text-gray-400 mt-1'>
              {filters.status === 'Not Interested'
                ? 'Active filter · Click to clear'
                : 'Click to filter'}
            </p>
          </button>
        </div>

        {/* Filter Card */}
        <div className='bg-white rounded-xl shadow-sm border border-gray-200 p-5 mb-6'>
          <div className='flex items-center justify-between mb-4'>
            <div className='flex items-center gap-2'>
              <h2 className='text-sm font-bold text-gray-800 uppercase tracking-wider'>Filters</h2>
              {activeFiltersCount > 0 && (
                <span className='px-2 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800'>
                  {activeFiltersCount} active
                </span>
              )}
            </div>
            {activeFiltersCount > 0 && (
              <button
                type='button'
                onClick={handleResetFilters}
                className='text-xs text-blue-600 hover:text-blue-800 font-medium cursor-pointer transition-colors'
              >
                Reset All Filters
              </button>
            )}
          </div>

          <div className='grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6 gap-3.5 text-sm'>
            {/* Search */}
            <div className='xl:col-span-2'>
              <label className='block text-xs font-medium text-gray-600 mb-1'>Search</label>
              <input
                type='text'
                value={filters.search}
                onChange={(e) => handleFilterChange('search', e.target.value)}
                placeholder='Search name, business, contact, source...'
                className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white'
              />
            </div>

            {/* Status */}
            <div>
              <label className='block text-xs font-medium text-gray-600 mb-1'>Status</label>
              <select
                value={filters.status}
                onChange={(e) => handleFilterChange('status', e.target.value)}
                className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white'
              >
                <option value=''>All Status</option>
                {statusOptions.map((s) => (
                  <option key={s} value={s}>
                    {s}
                  </option>
                ))}
              </select>
            </div>

            {/* Date */}
            <div>
              <label className='block text-xs font-medium text-gray-600 mb-1'>Specific Date</label>
              <input
                type='date'
                value={filters.date}
                onChange={(e) => handleFilterChange('date', e.target.value)}
                className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white'
              />
            </div>

            {/* Date From */}
            <div>
              <label className='block text-xs font-medium text-gray-600 mb-1'>Date From</label>
              <input
                type='date'
                value={filters.dateFrom}
                onChange={(e) => handleFilterChange('dateFrom', e.target.value)}
                className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white'
              />
            </div>

            {/* Date To */}
            <div>
              <label className='block text-xs font-medium text-gray-600 mb-1'>Date To</label>
              <input
                type='date'
                value={filters.dateTo}
                onChange={(e) => handleFilterChange('dateTo', e.target.value)}
                className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white'
              />
            </div>

            {/* Employee (Generated By) */}
            <div>
              <label className='block text-xs font-medium text-gray-600 mb-1'>
                Lead Generated By
              </label>
              <select
                value={filters.employee}
                onChange={(e) => handleFilterChange('employee', e.target.value)}
                className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white'
              >
                <option value=''>All employees</option>
                {employees.map((e) => (
                  <option key={e._id} value={e._id}>
                    {e.name}
                  </option>
                ))}
              </select>
            </div>

            {/* Assigned To (Sales) */}
            <div>
              <label className='block text-xs font-medium text-gray-600 mb-1'>
                Assigned To (Sales)
              </label>
              <select
                value={filters.assignedTo}
                onChange={(e) => {
                  handleFilterChange('assignedTo', e.target.value)
                  if (e.target.value) handleFilterChange('unassigned', '')
                }}
                className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white'
              >
                <option value=''>All assignees</option>
                {salesEmployees.map((e) => (
                  <option key={e._id} value={e._id}>
                    {e.name}
                  </option>
                ))}
              </select>
            </div>

            {/* Assignment Status */}
            <div>
              <label className='block text-xs font-medium text-gray-600 mb-1'>Assignment</label>
              <select
                value={filters.unassigned}
                onChange={(e) => {
                  handleFilterChange('unassigned', e.target.value)
                  if (e.target.value) handleFilterChange('assignedTo', '')
                }}
                className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white'
              >
                <option value=''>All leads</option>
                <option value='true'>Unassigned only</option>
              </select>
            </div>

            {/* Business Type */}
            <div>
              <label className='block text-xs font-medium text-gray-600 mb-1'>Business Type</label>
              <input
                type='text'
                value={filters.businessType}
                onChange={(e) => handleFilterChange('businessType', e.target.value)}
                placeholder='Filter by business type'
                className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white'
              />
            </div>

            {/* Lead Source */}
            <div>
              <label className='block text-xs font-medium text-gray-600 mb-1'>Lead Source</label>
              <input
                type='text'
                value={filters.leadSource}
                onChange={(e) => handleFilterChange('leadSource', e.target.value)}
                placeholder='Filter by source'
                className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white'
              />
            </div>

            {/* City */}
            <div>
              <label className='block text-xs font-medium text-gray-600 mb-1'>City</label>
              <input
                type='text'
                value={filters.city}
                onChange={(e) => handleFilterChange('city', e.target.value)}
                placeholder='Filter by city'
                className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white'
              />
            </div>

            {/* State */}
            <div>
              <label className='block text-xs font-medium text-gray-600 mb-1'>State</label>
              <input
                type='text'
                value={filters.state}
                onChange={(e) => handleFilterChange('state', e.target.value)}
                placeholder='Filter by state'
                className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white'
              />
            </div>
          </div>
        </div>

        {/* Data Table */}
        <div className='bg-white rounded-xl shadow border border-gray-200 overflow-hidden'>
          <div className='overflow-x-auto'>
            <table className='w-full table-auto text-sm'>
              <thead>
                <tr className='bg-blue-600 text-white font-bold text-sm text-center'>
                  <th className='px-4 py-3.5 text-left font-semibold text-white whitespace-nowrap'>
                    Name
                  </th>
                  <th className='px-4 py-3.5 text-left font-semibold text-white whitespace-nowrap'>
                    Business
                  </th>
                  <th className='px-4 py-3.5 text-left font-semibold text-white whitespace-nowrap'>
                    Contact
                  </th>
                  <th className='px-4 py-3.5 text-left font-semibold text-white whitespace-nowrap'>
                    Business Type
                  </th>
                  <th className='px-4 py-3.5 text-left font-semibold text-white whitespace-nowrap'>
                    Lead Source
                  </th>
                  <th className='px-4 py-3.5 text-left font-semibold text-white whitespace-nowrap'>
                    City
                  </th>
                  <th className='px-4 py-3.5 text-left font-semibold text-white whitespace-nowrap'>
                    Status
                  </th>
                  <th className='px-4 py-3.5 text-left font-semibold text-white whitespace-nowrap'>
                    Assigned To
                  </th>
                  <th className='px-4 py-3.5 text-left font-semibold text-white whitespace-nowrap'>
                    Site Co-ordinator
                  </th>
                  <th className='px-4 py-3.5 text-left font-semibold text-white whitespace-nowrap'>
                    Generated By
                  </th>
                  <th className='px-4 py-3.5 text-center font-semibold text-white whitespace-nowrap'>
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className='divide-y divide-gray-100'>
                {loading ? (
                  <tr>
                    <td colSpan={11} className='px-4 py-16 text-center text-gray-500'>
                      <div className='inline-flex items-center gap-2'>
                        <svg
                          className='animate-spin h-5 w-5 text-blue-600'
                          xmlns='http://www.w3.org/2000/svg'
                          fill='none'
                          viewBox='0 0 24 24'
                        >
                          <circle
                            className='opacity-25'
                            cx='12'
                            cy='12'
                            r='10'
                            stroke='currentColor'
                            strokeWidth='4'
                          ></circle>
                          <path
                            className='opacity-75'
                            fill='currentColor'
                            d='M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z'
                          ></path>
                        </svg>
                        <span>Loading leads…</span>
                      </div>
                    </td>
                  </tr>
                ) : leads.length === 0 ? (
                  <tr>
                    <td colSpan={11} className='px-4 py-16 text-center text-gray-500'>
                      <p className='text-base font-semibold text-gray-700'>No leads found</p>
                      <p className='text-xs text-gray-400 mt-1'>
                        Try adjusting your filters or click "+ Add Lead" to create one.
                      </p>
                    </td>
                  </tr>
                ) : (
                  leads.map((l) => (
                    <tr
                      key={l._id}
                      className='border-b hover:bg-gray-50/90 cursor-pointer transition-colors'
                      onClick={() => navigate(`/company/${tenantId}/leads/view/${l._id}`)}
                      role='link'
                      tabIndex={0}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter' || e.key === ' ') {
                          e.preventDefault()
                          navigate(`/company/${tenantId}/leads/view/${l._id}`)
                        }
                      }}
                    >
                      <td className='px-4 py-3.5 font-medium text-indigo-700 hover:text-indigo-900'>
                        {l.name}
                      </td>
                      <td className='px-4 py-3.5 font-medium text-gray-900'>
                        {l.businessName || '—'}
                      </td>
                      <td className='px-4 py-3.5 text-gray-700 tabular-nums'>
                        {l.contactNumber || '—'}
                      </td>
                      <td className='px-4 py-3.5 text-gray-600'>{l.businessType || '—'}</td>
                      <td className='px-4 py-3.5 text-gray-600'>{l.leadSource || '—'}</td>
                      <td className='px-4 py-3.5 text-gray-600'>{l.city || '—'}</td>
                      <td className='px-4 py-3.5 whitespace-nowrap'>
                        <span
                          className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-semibold ${statusBadgeClass(
                            l.status
                          )}`}
                        >
                          {l.status}
                        </span>
                      </td>
                      <td className='px-4 py-3.5 text-gray-700'>
                        {l.assignedTo?.name ? (
                          <span className='font-medium'>{l.assignedTo.name}</span>
                        ) : (
                          <span className='text-gray-400'>Unassigned</span>
                        )}
                      </td>
                      <td className='px-4 py-3.5 text-gray-700'>
                        {l.siteCoordinator?.name || '—'}
                      </td>
                      <td className='px-4 py-3.5 text-gray-700'>{l.generatedBy?.name || '—'}</td>
                      <td
                        className='px-4 py-3.5 text-center cursor-default'
                        onClick={(e) => e.stopPropagation()}
                      >
                        <div className='flex items-center justify-center gap-1.5'>
                          <button
                            type='button'
                            onClick={() => navigate(`/company/${tenantId}/leads/view/${l._id}`)}
                            className='p-1.5 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100 transition-colors cursor-pointer'
                            title='View lead'
                          >
                            <ViewIcon className='size-4' />
                          </button>
                          <button
                            type='button'
                            onClick={() => navigate(`/company/${tenantId}/leads/edit/${l._id}`)}
                            className='p-1.5 rounded-lg text-blue-600 hover:text-blue-800 hover:bg-blue-50 transition-colors cursor-pointer'
                            title='Edit lead'
                          >
                            <EditIcon className='size-4' />
                          </button>
                          <button
                            type='button'
                            onClick={(e) => handleDeleteLead(e, l._id)}
                            className='p-1.5 rounded-lg text-rose-500 hover:text-rose-700 hover:bg-rose-50 transition-colors cursor-pointer'
                            title='Delete lead'
                          >
                            <DeleteIcon className='size-4' />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>

          <div className='px-5 py-3 border-t border-gray-100 bg-gray-50 flex items-center justify-between text-xs text-gray-500'>
            <span>Showing {leads.length} lead(s)</span>
            <span>Click any row to view full lead details</span>
          </div>
        </div>

        {/* Distribute Modal */}
        {showDistributeModal && (
          <div className='fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4 backdrop-blur-xs'>
            <div className='w-full max-w-2xl rounded-2xl bg-white shadow-2xl overflow-hidden border border-gray-200 animate-in fade-in duration-150'>
              <div className='border-b border-gray-100 px-6 py-4 flex items-center justify-between bg-gray-50/50'>
                <div>
                  <h3 className='text-lg font-bold text-gray-900'>Distribute today’s leads</h3>
                  <p className='text-xs text-gray-500 mt-0.5'>
                    Unassigned leads are split equally across Sales Team Leaders, then to Sales
                    Executives on each team.
                  </p>
                </div>
                <button
                  type='button'
                  className='text-gray-400 hover:text-gray-700 text-lg font-semibold cursor-pointer'
                  onClick={() => setShowDistributeModal(false)}
                >
                  ✕
                </button>
              </div>

              <div className='px-6 py-5 max-h-[60vh] overflow-y-auto space-y-4'>
                <div className='grid grid-cols-2 gap-3 text-sm'>
                  <div className='rounded-xl border border-gray-200 bg-gray-50/60 p-4'>
                    <p className='text-xs font-semibold text-gray-500 uppercase tracking-wider'>
                      Today’s unassigned leads
                    </p>
                    <p className='text-2xl font-bold text-gray-900 mt-1 tabular-nums'>
                      {distributionPreview?.totalLeads ?? 0}
                    </p>
                  </div>
                  <div className='rounded-xl border border-gray-200 bg-gray-50/60 p-4'>
                    <p className='text-xs font-semibold text-gray-500 uppercase tracking-wider'>
                      Sales Team Leaders
                    </p>
                    <p className='text-2xl font-bold text-gray-900 mt-1 tabular-nums'>
                      {distributionPreview?.teamLeaderCount ?? 0}
                    </p>
                  </div>
                </div>

                {(distributionPreview?.plan || []).map((block) => (
                  <div
                    key={block.teamLeader._id}
                    className='rounded-xl border border-gray-200 bg-white p-4 shadow-xs'
                  >
                    <p className='text-sm font-bold text-gray-900'>
                      {block.teamLeader.name}{' '}
                      <span className='text-xs font-normal text-gray-500'>
                        — {block.leadCount} lead(s)
                      </span>
                    </p>
                    <ul className='mt-2.5 space-y-1.5'>
                      {(block.members || []).map((m) => (
                        <li
                          key={m.employee._id}
                          className='text-xs text-gray-700 flex justify-between py-1 border-b border-gray-50 last:border-0'
                        >
                          <span>{m.employee.name}</span>
                          <span className='font-semibold text-blue-600'>
                            {m.leadCount} lead(s)
                          </span>
                        </li>
                      ))}
                    </ul>
                  </div>
                ))}

                {!distributionPreview?.totalLeads && (
                  <p className='text-sm text-center text-gray-500 py-6'>
                    No unassigned leads found for today to distribute.
                  </p>
                )}
              </div>

              <div className='border-t border-gray-100 px-6 py-4 flex justify-end gap-2.5 bg-gray-50/50'>
                <button
                  type='button'
                  onClick={() => setShowDistributeModal(false)}
                  className='px-4 py-2 rounded-xl border border-gray-300 text-sm font-medium text-gray-700 hover:bg-gray-100 transition-colors cursor-pointer'
                >
                  Close
                </button>
                <button
                  type='button'
                  disabled={
                    distributing ||
                    !distributionPreview?.totalLeads ||
                    Boolean(distributionResult)
                  }
                  onClick={confirmDistribute}
                  className='px-5 py-2 rounded-xl bg-amber-600 hover:bg-amber-700 active:bg-amber-800 text-white text-sm font-semibold shadow-sm disabled:opacity-50 transition-colors cursor-pointer'
                >
                  {distributing
                    ? 'Distributing…'
                    : distributionResult
                      ? 'Distributed'
                      : 'Confirm distribute'}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </AdminCompanyShell>
  )
}
