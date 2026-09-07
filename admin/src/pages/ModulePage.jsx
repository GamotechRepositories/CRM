import React, { useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams, useSearchParams } from 'react-router-dom'
import api from '../api/axios'
import AdminCompanyShell, { getInitials } from '../components/AdminCompanyShell'
import ClientFormModal from '../components/ClientFormModal'
import ProjectFormModal from '../components/ProjectFormModal'
import LeadFormModal from '../components/LeadFormModal'
import { TENANT_NAMES } from '../config/tenants'
import { moduleSupportsCrud } from '../config/companyAdminFeatures'
import { useAuth } from '../context/AuthContext'
import { MODULE_TITLES, leadStatusesForTenant } from './ModulePage.shared'

const formatDate = (value) => {
  if (!value) return '—'
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
}

const formatINR = (value) =>
  new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0,
  }).format(Number(value) || 0)

const val = (v) => (v === null || v === undefined || v === '' ? '—' : v)

const AVATAR_COLORS = [
  'bg-violet-500',
  'bg-blue-500',
  'bg-emerald-500',
  'bg-amber-500',
  'bg-rose-500',
  'bg-cyan-500',
  'bg-indigo-500',
  'bg-pink-500',
]

const EmployeeCell = ({ employee }) => {
  const [imgError, setImgError] = useState(false)
  const name = employee?.name || '—'
  const email = employee?.email || ''
  const photo = String(employee?.profilePhoto || '').trim()
  const showPhoto = Boolean(photo) && !imgError
  const colorIndex = String(employee?._id || name)
    .split('')
    .reduce((sum, ch) => sum + ch.charCodeAt(0), 0)

  return (
    <div className='flex items-center gap-3 min-w-[180px]'>
      {showPhoto ? (
        <img
          src={photo}
          alt={name}
          className='w-9 h-9 rounded-full object-cover shrink-0 border border-gray-200'
          onError={() => setImgError(true)}
        />
      ) : (
        <div className={`w-9 h-9 rounded-full flex items-center justify-center text-[11px] font-bold text-white shrink-0 ${AVATAR_COLORS[colorIndex % AVATAR_COLORS.length]}`}>
          {getInitials(name)}
        </div>
      )}
      <div className='min-w-0'>
        <p className='font-medium text-gray-900 truncate'>{name}</p>
        {email ? <p className='text-xs text-gray-400 truncate'>{email}</p> : null}
      </div>
    </div>
  )
}

const statusClass = (status) => {
  const s = String(status || '').toLowerCase()
  if (
    [
      'active',
      'completed',
      'approved',
      'paid',
      'interested',
      'incentive earned',
      'booking token',
      'booking done',
      'token done',
    ].some((k) => s.includes(k))
  ) {
    return 'bg-emerald-50 text-emerald-700'
  }
  if (
    ['progress', 'pending', 'scheduled', 'meeting schedule', 'meeting revisit', 'site visit', 'zoom meeting', 'call you after'].some(
      (k) => s.includes(k)
    )
  ) {
    return 'bg-amber-50 text-amber-700'
  }
  if (['inactive', 'reject', 'cancel', 'not interested', 'hold', 'call not received'].some((k) => s.includes(k))) {
    return 'bg-rose-50 text-rose-700'
  }
  return 'bg-slate-50 text-slate-600'
}

const Badge = ({ children }) => (
  <span className={`inline-flex px-2 py-0.5 rounded-md text-xs font-medium ${statusClass(children)}`}>
    {val(children)}
  </span>
)

const currentMonthValue = () => {
  const now = new Date()
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`
}

const MONTHLY_MODULES = ['reports', 'leaves', 'invoices', 'expenses', 'salaries', 'quotations']

const DataTable = ({ columns, rows, emptyText, onRowClick }) => (
  <div className='bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden'>
    <div className='overflow-x-auto'>
      <table className='min-w-full text-sm'>
        <thead className='bg-slate-50 border-b border-gray-100 text-left text-xs uppercase tracking-wide text-gray-500'>
          <tr>
            {columns.map((col) => (
              <th key={col.key} className='px-4 py-3 font-semibold whitespace-nowrap'>{col.label}</th>
            ))}
          </tr>
        </thead>
        <tbody className='divide-y divide-gray-50'>
          {rows.length ? (
            rows.map((row) => (
              <tr
                key={row._id || row.key}
                className={`hover:bg-slate-50/70 ${onRowClick ? 'cursor-pointer' : ''}`}
                onClick={onRowClick ? () => onRowClick(row) : undefined}
              >
                {columns.map((col) => (
                  <td key={col.key} className='px-4 py-3 text-gray-700 align-top'>
                    {col.render ? col.render(row) : val(row[col.key])}
                  </td>
                ))}
              </tr>
            ))
          ) : (
            <tr>
              <td colSpan={columns.length} className='px-4 py-12 text-center text-gray-500'>
                {emptyText}
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  </div>
)

const ModulePage = ({ moduleId }) => {
  const { tenantId } = useParams()
  const navigate = useNavigate()
  const { user } = useAuth()
  const [searchParams] = useSearchParams()
  const status = searchParams.get('status') || ''
  const title = MODULE_TITLES[moduleId] || 'Module'
  const company = TENANT_NAMES[tenantId] || tenantId

  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [selectedMonth, setSelectedMonth] = useState(currentMonthValue())
  const [processingLeaveId, setProcessingLeaveId] = useState('')
  const [leadStatusFilter, setLeadStatusFilter] = useState('')
  const [leadSourceFilter, setLeadSourceFilter] = useState('')
  const [leadSortBy, setLeadSortBy] = useState('createdAt')
  const [leadSortDir, setLeadSortDir] = useState('desc')
  const [leadDateFrom, setLeadDateFrom] = useState('')
  const [leadDateTo, setLeadDateTo] = useState('')
  const [formModal, setFormModal] = useState({ open: false, mode: 'create', record: null })
  const [clientOptions, setClientOptions] = useState([])

  const canCreate = moduleSupportsCrud(moduleId, 'create')
  const canUpdate = moduleSupportsCrud(moduleId, 'update')

  const reloadData = async () => {
    const params = {}
    if (status) params.status = status
    if (MONTHLY_MODULES.includes(moduleId) && selectedMonth) params.month = selectedMonth
    if (moduleId === 'leads') {
      if (leadStatusFilter) params.status = leadStatusFilter
      if (leadSourceFilter) params.leadSource = leadSourceFilter
      if (leadSortBy) params.sortBy = leadSortBy
      if (leadSortDir) params.sortDir = leadSortDir
      if (leadDateFrom) params.dateFrom = leadDateFrom
      if (leadDateTo) params.dateTo = leadDateTo
    }
    const res = await api.get(`/companies/${tenantId}/modules/${moduleId}`, {
      params: Object.keys(params).length ? params : undefined,
    })
    setData(res.data)
  }

  useEffect(() => {
    setLeadStatusFilter('')
    setLeadSourceFilter('')
    setLeadSortBy('createdAt')
    setLeadSortDir('desc')
    setLeadDateFrom('')
    setLeadDateTo('')
  }, [tenantId, moduleId])

  useEffect(() => {
    let cancelled = false
    const load = async () => {
      if (!TENANT_NAMES[tenantId]) {
        setError('Unknown company')
        setLoading(false)
        return
      }
      try {
        setLoading(true)
        setError('')
        setData(null)
        const params = {}
        if (status) params.status = status
        if (MONTHLY_MODULES.includes(moduleId) && selectedMonth) {
          params.month = selectedMonth
        }
        if (moduleId === 'leads') {
          if (leadStatusFilter) params.status = leadStatusFilter
          if (leadSourceFilter) params.leadSource = leadSourceFilter
          if (leadSortBy) params.sortBy = leadSortBy
          if (leadSortDir) params.sortDir = leadSortDir
          if (leadDateFrom) params.dateFrom = leadDateFrom
          if (leadDateTo) params.dateTo = leadDateTo
        }
        const res = await api.get(`/companies/${tenantId}/modules/${moduleId}`, {
          params: Object.keys(params).length ? params : undefined,
        })
        if (!cancelled) setData(res.data)
      } catch (err) {
        if (!cancelled) {
          setError(err.response?.data?.message || err.message || 'Failed to load data')
          setData(null)
        }
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    load()
    return () => {
      cancelled = true
    }
  }, [
    tenantId,
    moduleId,
    status,
    selectedMonth,
    leadStatusFilter,
    leadSourceFilter,
    leadSortBy,
    leadSortDir,
    leadDateFrom,
    leadDateTo,
  ])

  useEffect(() => {
    if (!tenantId || moduleId !== 'projects') return
    let cancelled = false
    api.get(`/companies/${tenantId}/modules/clients`)
      .then((res) => {
        if (!cancelled) setClientOptions(res.data?.items || [])
      })
      .catch(() => {
        if (!cancelled) setClientOptions([])
      })
    return () => {
      cancelled = true
    }
  }, [tenantId, moduleId, formModal.open])

  const items = data?.items || []

  const filteredItems = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return items
    return items.filter((row) => JSON.stringify(row).toLowerCase().includes(q))
  }, [items, search])

  const handleFinalLeaveDecision = async (leave, action) => {
    const confirmed = window.confirm(
      action === 'Approve'
        ? 'Approve this leave as the final decision?'
        : 'Reject this leave as the final decision?'
    )
    if (!confirmed) return
    const comment = action === 'Reject'
      ? (window.prompt('Rejection reason (optional)') || '')
      : ''
    try {
      setProcessingLeaveId(leave._id)
      setError('')
      const res = await api.patch(`/companies/${tenantId}/leaves/${leave._id}/status`, {
        action,
        comment,
        centralAdminId: user?._id,
        centralAdminEmail: user?.email,
      })
      const updated = res.data?.leave
      if (updated) {
        setData((current) => ({
          ...current,
          items: (current?.items || []).map((item) => item._id === updated._id ? updated : item),
        }))
      }
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to update leave')
    } finally {
      setProcessingLeaveId('')
    }
  }

  const columns = useMemo(() => {
    const editAction = (row) => (
      canUpdate ? (
        <button
          type='button'
          onClick={(e) => {
            e.stopPropagation()
            setFormModal({ open: true, mode: 'edit', record: row })
          }}
          className='rounded-lg border border-gray-200 px-2.5 py-1 text-xs font-semibold text-blue-700 hover:bg-blue-50'
        >
          Edit
        </button>
      ) : null
    )

    if (moduleId === 'clients') {
      return [
        { key: 'clientName', label: 'Client', render: (r) => <span className='font-medium text-blue-600'>{val(r.clientName)}</span> },
        { key: 'mailId', label: 'Email', render: (r) => val(r.mailId) },
        { key: 'clientNumber', label: 'Phone', render: (r) => val(r.clientNumber) },
        { key: 'businessType', label: 'Business', render: (r) => val(r.businessType) },
        { key: 'clientType', label: 'Type', render: (r) => <Badge>{r.clientType}</Badge> },
        { key: 'date', label: 'Date', render: (r) => formatDate(r.date || r.createdAt) },
        { key: 'actions', label: '', render: editAction },
      ]
    }
    if (moduleId === 'projects') {
      return [
        { key: 'projectName', label: 'Project', render: (r) => <span className='font-medium text-blue-600'>{val(r.projectName)}</span> },
        { key: 'client', label: 'Client', render: (r) => val(r.client?.clientName) },
        { key: 'status', label: 'Status', render: (r) => <Badge>{r.status}</Badge> },
        { key: 'priority', label: 'Priority', render: (r) => val(r.priority) },
        { key: 'progress', label: 'Progress', render: (r) => `${r.progress || 0}%` },
        { key: 'deadline', label: 'Deadline', render: (r) => formatDate(r.deadline || r.endDate) },
        { key: 'actions', label: '', render: editAction },
      ]
    }
    if (moduleId === 'leads') {
      const cols = [
        { key: 'businessName', label: 'Business', render: (r) => <span className='font-medium text-gray-900'>{val(r.businessName || r.name)}</span> },
        { key: 'name', label: 'Contact', render: (r) => val(r.name) },
        { key: 'contactNumber', label: 'Phone', render: (r) => val(r.contactNumber) },
        { key: 'status', label: 'Status', render: (r) => <Badge>{r.status}</Badge> },
        { key: 'leadSource', label: 'Source', render: (r) => val(r.leadSource) },
      ]
      if (tenantId !== 'adsResearchGlobal') {
        cols.push(
          { key: 'assignedTo', label: 'Assigned To', render: (r) => val(r.assignedTo?.name) },
          { key: 'siteCoordinator', label: 'Site Co-ordinator', render: (r) => val(r.siteCoordinator?.name) },
        )
      }
      cols.push({ key: 'createdAt', label: 'Created', render: (r) => formatDate(r.createdAt) })
      cols.push({ key: 'actions', label: '', render: editAction })
      return cols
    }
    if (moduleId === 'invoices') {
      return [
        { key: 'invoiceNumber', label: 'Invoice', render: (r) => <span className='font-medium text-gray-900'>{val(r.invoiceNumber || r._id?.slice?.(-6))}</span> },
        { key: 'client', label: 'Client', render: (r) => val(r.client?.clientName) },
        { key: 'billType', label: 'Type', render: (r) => val(r.billType) },
        {
          key: 'amount',
          label: 'Amount',
          render: (r) => formatINR(r.paymentDetails?.amount || r.amountPaid || r.totalAmount),
        },
        {
          key: 'paymentDate',
          label: 'Payment date',
          render: (r) => formatDate(r.paymentDetails?.paymentDate || r.createdAt),
        },
        {
          key: 'mode',
          label: 'Mode',
          render: (r) => val(r.paymentDetails?.modeOfTransaction || r.status),
        },
      ]
    }
    if (moduleId === 'leaves') {
      return [
        { key: 'employee', label: 'Employee', render: (r) => <EmployeeCell employee={r.employee} /> },
        { key: 'leaveType', label: 'Type', render: (r) => val(r.leaveType) },
        { key: 'startDate', label: 'From', render: (r) => formatDate(r.startDate) },
        { key: 'endDate', label: 'To', render: (r) => formatDate(r.endDate) },
        { key: 'numberOfDays', label: 'Days', render: (r) => val(r.numberOfDays) },
        { key: 'status', label: 'Status', render: (r) => <Badge>{r.status}</Badge> },
        {
          key: 'approvalStage',
          label: 'Approval Stage',
          render: (r) => r.status === 'Pending'
            ? val(String(r.approvalStage || 'team_leader').replaceAll('_', ' '))
            : 'Completed',
        },
        {
          key: 'actions',
          label: 'Final Decision',
          render: (r) => r.status === 'Pending' && r.approvalStage === 'central_admin' ? (
            <div className='flex items-center gap-2'>
              <button
                type='button'
                disabled={processingLeaveId === r._id}
                onClick={() => handleFinalLeaveDecision(r, 'Approve')}
                className='rounded-lg bg-emerald-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-emerald-700 disabled:opacity-50'
              >
                Approve
              </button>
              <button
                type='button'
                disabled={processingLeaveId === r._id}
                onClick={() => handleFinalLeaveDecision(r, 'Reject')}
                className='rounded-lg bg-rose-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-rose-700 disabled:opacity-50'
              >
                Reject
              </button>
            </div>
          ) : (
            <span className='text-xs text-gray-400'>
              {r.status === 'Pending' ? 'Awaiting previous stage' : 'Decision recorded'}
            </span>
          ),
        },
      ]
    }
    if (moduleId === 'expenses') {
      return [
        { key: 'title', label: 'Expense', render: (r) => val(r.title || r.description) },
        { key: 'category', label: 'Category', render: (r) => val(r.category) },
        { key: 'amount', label: 'Amount', render: (r) => formatINR(r.amount || r.totalAmount) },
        { key: 'date', label: 'Date', render: (r) => formatDate(r.date || r.createdAt) },
        { key: 'status', label: 'Status', render: (r) => <Badge>{r.status || r.paymentStatus}</Badge> },
      ]
    }
    if (moduleId === 'salaries') {
      return [
        { key: 'employee', label: 'Employee', render: (r) => val(r.employee?.name) },
        { key: 'period', label: 'Period', render: (r) => `${r.month || '—'}/${r.year || '—'}` },
        { key: 'amount', label: 'Net pay', render: (r) => formatINR(r.netSalary ?? r.amount) },
        { key: 'status', label: 'Status', render: (r) => <Badge>{r.status || r.paymentStatus || 'Recorded'}</Badge> },
      ]
    }
    if (moduleId === 'attendance') {
      return [
        { key: 'employee', label: 'Employee', render: (r) => val(r.employee?.name) },
        { key: 'date', label: 'Date', render: (r) => formatDate(r.date) },
        { key: 'status', label: 'Status', render: (r) => <Badge>{r.status}</Badge> },
        { key: 'checkIn', label: 'Check in', render: (r) => val(r.checkIn) },
        { key: 'checkOut', label: 'Check out', render: (r) => val(r.checkOut) },
      ]
    }
    if (moduleId === 'properties') {
      return [
        { key: 'title', label: 'Property', render: (r) => val(r.title || r.propertyName) },
        { key: 'locality', label: 'Locality', render: (r) => val(r.locality) },
        { key: 'city', label: 'City', render: (r) => val(r.city) },
        { key: 'price', label: 'Price', render: (r) => formatINR(r.price || r.expectedPrice) },
        { key: 'status', label: 'Status', render: (r) => <Badge>{r.status || r.verificationStatus}</Badge> },
      ]
    }
    if (moduleId === 'quotations') {
      return [
        { key: 'quotationNumber', label: 'Quotation', render: (r) => val(r.quotationNumber || r._id?.slice?.(-6)) },
        { key: 'client', label: 'Client', render: (r) => val(r.client?.clientName) },
        { key: 'amount', label: 'Amount', render: (r) => formatINR(r.totalAmount || r.amount) },
        { key: 'status', label: 'Status', render: (r) => <Badge>{r.status}</Badge> },
        { key: 'createdAt', label: 'Created', render: (r) => formatDate(r.createdAt) },
      ]
    }
    return []
  }, [moduleId, processingLeaveId, tenantId, user?._id, canUpdate])

  const subtitle = MONTHLY_MODULES.includes(moduleId)
    ? (data?.monthLabel || selectedMonth || 'Selected month')
    : moduleId === 'leads'
      ? `${filteredItems.length} shown${leadStatusFilter ? ` · status: ${leadStatusFilter}` : ''}${leadSourceFilter ? ` · source: ${leadSourceFilter}` : ''}${leadDateFrom || leadDateTo ? ` · created: ${leadDateFrom || '…'} → ${leadDateTo || '…'}` : ''}`
      : status
        ? `${filteredItems.length} shown · filter: ${status}`
        : `${filteredItems.length} record${filteredItems.length === 1 ? '' : 's'}`

  const showMonthPicker = MONTHLY_MODULES.includes(moduleId)
  const leadStatusOptions = useMemo(() => {
    const fromApi = data?.filters?.statuses || []
    const defaults = leadStatusesForTenant(tenantId)
    return [...new Set([...defaults, ...fromApi])].filter(Boolean)
  }, [data?.filters?.statuses, tenantId])
  const leadSourceOptions = data?.filters?.sources || []

  return (
    <AdminCompanyShell activeNav={moduleId}>
      <div className='flex flex-wrap items-start justify-between gap-4 mb-6'>
        <div>
          <h1 className='text-2xl font-bold text-gray-900'>{title}</h1>
          <p className='text-sm text-gray-500 mt-1'>
            {company} · {subtitle}
            {moduleId === 'leaves' ? ` · ${filteredItems.length} leave${filteredItems.length === 1 ? '' : 's'}` : ''}
          </p>
        </div>
        <div className='flex flex-wrap items-center gap-3'>
          {showMonthPicker && (
            <div className='flex flex-wrap items-center gap-2'>
              <label htmlFor='module-month' className='text-sm text-gray-600'>
                Month
              </label>
              <input
                id='module-month'
                type='month'
                value={selectedMonth}
                onChange={(e) => setSelectedMonth(e.target.value || currentMonthValue())}
                className='rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
              />
            </div>
          )}
          {moduleId === 'leads' && (
            <>
              <select
                value={leadStatusFilter}
                onChange={(e) => setLeadStatusFilter(e.target.value)}
                className='rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
                aria-label='Filter by status'
              >
                <option value=''>All statuses</option>
                {leadStatusOptions.map((s) => (
                  <option key={s} value={s}>{s}</option>
                ))}
              </select>
              <select
                value={leadSourceFilter}
                onChange={(e) => setLeadSourceFilter(e.target.value)}
                className='rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
                aria-label='Filter by source'
              >
                <option value=''>All sources</option>
                {leadSourceOptions.map((s) => (
                  <option key={s} value={s}>{s}</option>
                ))}
              </select>
              <div className='flex flex-wrap items-center gap-2'>
                <label htmlFor='lead-date-from' className='text-sm text-gray-600 whitespace-nowrap'>
                  Created from
                </label>
                <input
                  id='lead-date-from'
                  type='date'
                  value={leadDateFrom}
                  onChange={(e) => setLeadDateFrom(e.target.value)}
                  className='rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
                />
                <label htmlFor='lead-date-to' className='text-sm text-gray-600 whitespace-nowrap'>
                  to
                </label>
                <input
                  id='lead-date-to'
                  type='date'
                  value={leadDateTo}
                  min={leadDateFrom || undefined}
                  onChange={(e) => setLeadDateTo(e.target.value)}
                  className='rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
                />
                {(leadDateFrom || leadDateTo) && (
                  <button
                    type='button'
                    onClick={() => {
                      setLeadDateFrom('')
                      setLeadDateTo('')
                    }}
                    className='rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm text-gray-600 hover:bg-slate-50'
                  >
                    Clear dates
                  </button>
                )}
              </div>
              <select
                value={`${leadSortBy}:${leadSortDir}`}
                onChange={(e) => {
                  const [by, dir] = String(e.target.value).split(':')
                  setLeadSortBy(by || 'createdAt')
                  setLeadSortDir(dir || 'desc')
                }}
                className='rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
                aria-label='Sort leads'
              >
                <option value='createdAt:desc'>Sort by date (newest)</option>
                <option value='createdAt:asc'>Sort by date (oldest)</option>
                <option value='status:asc'>Sort by status (A–Z)</option>
                <option value='status:desc'>Sort by status (Z–A)</option>
                <option value='source:asc'>Sort by source (A–Z)</option>
                <option value='source:desc'>Sort by source (Z–A)</option>
              </select>
            </>
          )}
          {moduleId !== 'reports' && moduleId !== 'settings' && (
            <input
              type='search'
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder={`Search ${title.toLowerCase()}…`}
              className='w-64 max-w-full rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
            />
          )}
          {canCreate && (
            <button
              type='button'
              onClick={() => setFormModal({ open: true, mode: 'create', record: null })}
              className='inline-flex items-center gap-1.5 rounded-xl bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-700'
            >
              <span className='text-lg leading-none'>+</span>
              Add {title.slice(0, -1).toLowerCase() || title.toLowerCase()}
            </button>
          )}
        </div>
      </div>

      {error && (
        <div className='mb-4 rounded-xl bg-red-50 border border-red-100 px-3 py-2'>
          <p className='text-red-600 text-sm'>{error}</p>
        </div>
      )}

      {loading ? (
        <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-10 text-center text-sm text-gray-500'>
          Loading {title.toLowerCase()}…
        </div>
      ) : moduleId === 'reports' ? (
        <div className='space-y-5'>
          <div className='grid grid-cols-2 md:grid-cols-4 gap-4'>
            {[
              { label: 'New employees', value: data?.summary?.employees ?? 0 },
              { label: 'New clients', value: data?.summary?.clients ?? 0 },
              { label: 'New projects', value: data?.summary?.projects ?? 0 },
              { label: 'New tasks', value: data?.summary?.tasks ?? 0 },
              { label: 'New leads', value: data?.summary?.leads ?? 0 },
              { label: 'Revenue', value: formatINR(data?.summary?.totalRevenue) },
              { label: 'Expenses', value: formatINR(data?.summary?.totalExpenses) },
              { label: 'Payroll', value: formatINR(data?.summary?.totalPayroll) },
              { label: 'Net', value: formatINR(data?.summary?.net) },
            ].map((card) => (
              <div key={card.label} className='bg-white rounded-2xl border border-gray-100 shadow-sm p-4'>
                <p className='text-xs text-gray-500'>{card.label}</p>
                <p className='text-xl font-bold text-gray-900 mt-1'>{card.value}</p>
              </div>
            ))}
          </div>

          <div>
            <h2 className='text-sm font-semibold text-gray-900 mb-2'>
              Employee payroll
              <span className='ml-2 font-normal text-gray-500'>({data?.summary?.payrollCount ?? 0})</span>
            </h2>
            <DataTable
              columns={[
                {
                  key: 'employee',
                  label: 'Employee',
                  render: (r) => <span className='font-medium text-gray-900'>{val(r.employee?.name)}</span>,
                },
                {
                  key: 'email',
                  label: 'Email',
                  render: (r) => val(r.employee?.email),
                },
                {
                  key: 'department',
                  label: 'Department',
                  render: (r) => val(r.employee?.department),
                },
                {
                  key: 'amount',
                  label: 'Amount',
                  render: (r) => <span className='font-semibold text-amber-700'>{formatINR(r.amount)}</span>,
                },
              ]}
              rows={data?.salaries || []}
              emptyText='No payroll records for this month'
            />
          </div>

          <div>
            <h2 className='text-sm font-semibold text-gray-900 mb-2'>
              Invoices this month
              <span className='ml-2 font-normal text-gray-500'>({data?.summary?.invoiceCount ?? 0})</span>
            </h2>
            <DataTable
              columns={[
                {
                  key: 'invoiceNumber',
                  label: 'Invoice',
                  render: (r) => (
                    <span className='font-medium text-gray-900'>{val(r.invoiceNumber || r._id?.slice?.(-6))}</span>
                  ),
                },
                { key: 'client', label: 'Client', render: (r) => val(r.client?.clientName) },
                {
                  key: 'amount',
                  label: 'Amount',
                  render: (r) => formatINR(r.paymentDetails?.amount || r.amountPaid || r.totalAmount),
                },
                {
                  key: 'paymentDate',
                  label: 'Date',
                  render: (r) => formatDate(r.paymentDetails?.paymentDate || r.createdAt),
                },
              ]}
              rows={data?.billings || []}
              emptyText='No invoices for this month'
              onRowClick={(row) => navigate(`/company/${tenantId}/invoices/${row._id}`)}
            />
          </div>

          <div>
            <h2 className='text-sm font-semibold text-gray-900 mb-2'>Expenses this month</h2>
            <DataTable
              columns={[
                { key: 'description', label: 'Expense', render: (r) => <span className='font-medium text-gray-900'>{val(r.description)}</span> },
                { key: 'category', label: 'Category', render: (r) => val(r.category) },
                { key: 'amount', label: 'Amount', render: (r) => formatINR(r.amount) },
                { key: 'date', label: 'Date', render: (r) => formatDate(r.date) },
              ]}
              rows={data?.expenses || []}
              emptyText='No expenses for this month'
            />
          </div>
        </div>
      ) : moduleId === 'settings' ? (
        <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-6'>
          {data?.company ? (
            <div className='grid grid-cols-1 sm:grid-cols-2 gap-4'>
              {[
                ['Company name', data.company.companyName],
                ['Email', data.company.email],
                ['Phone', data.company.phone],
                ['Website', data.company.website],
                ['Address', data.company.address],
                ['PAN', data.company.pan],
                ['GSTIN', data.company.gstin],
                ['State', data.company.state],
                ['Bank', data.company.bankName],
                ['Account', data.company.bankAccountNumber],
              ].map(([label, value]) => (
                <div key={label}>
                  <p className='text-[11px] uppercase tracking-wide text-gray-400'>{label}</p>
                  <p className='text-sm text-gray-900 mt-0.5 break-words'>{val(value)}</p>
                </div>
              ))}
            </div>
          ) : (
            <p className='text-sm text-gray-500 text-center py-8'>No company settings configured</p>
          )}
        </div>
      ) : (
        <DataTable
          columns={columns}
          rows={filteredItems}
          emptyText={
            moduleId === 'leaves'
              ? `No leaves found for ${data?.monthLabel || selectedMonth || 'this month'}`
              : ['invoices', 'expenses', 'salaries', 'quotations'].includes(moduleId)
                ? `No ${title.toLowerCase()} found for ${data?.monthLabel || selectedMonth || 'this month'}`
                : `No ${title.toLowerCase()} found`
          }
          onRowClick={
            moduleId === 'clients'
              ? (row) => navigate(`/company/${tenantId}/clients/${row._id}`)
              : moduleId === 'projects'
                ? (row) => navigate(`/company/${tenantId}/projects/${row._id}`)
                : moduleId === 'invoices'
                  ? (row) => navigate(`/company/${tenantId}/invoices/${row._id}`)
                  : undefined
          }
        />
      )}

      <ClientFormModal
        open={moduleId === 'clients' && formModal.open}
        mode={formModal.mode}
        tenantId={tenantId}
        client={formModal.mode === 'edit' ? formModal.record : null}
        onClose={() => setFormModal({ open: false, mode: 'create', record: null })}
        onSaved={async () => { await reloadData() }}
      />
      <ProjectFormModal
        open={moduleId === 'projects' && formModal.open}
        mode={formModal.mode}
        tenantId={tenantId}
        project={formModal.mode === 'edit' ? formModal.record : null}
        clients={clientOptions}
        onClose={() => setFormModal({ open: false, mode: 'create', record: null })}
        onSaved={async () => { await reloadData() }}
      />
      <LeadFormModal
        open={moduleId === 'leads' && formModal.open}
        mode={formModal.mode}
        tenantId={tenantId}
        lead={formModal.mode === 'edit' ? formModal.record : null}
        onClose={() => setFormModal({ open: false, mode: 'create', record: null })}
        onSaved={async () => { await reloadData() }}
      />
    </AdminCompanyShell>
  )
}

export default ModulePage
export { leadStatusesForTenant }
