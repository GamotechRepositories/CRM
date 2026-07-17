import React, { useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams, useSearchParams } from 'react-router-dom'
import api from '../api/axios'
import AdminCompanyShell from '../components/AdminCompanyShell'
import { TENANT_NAMES } from '../config/tenants'
import { useAuth } from '../context/AuthContext'

const TITLES = {
  clients: 'Clients',
  projects: 'Projects',
  leads: 'Leads',
  tasks: 'Tasks',
  invoices: 'Invoices',
  leaves: 'Leaves',
  reports: 'Reports',
  settings: 'Settings',
}

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

const statusClass = (status) => {
  const s = String(status || '').toLowerCase()
  if (['active', 'completed', 'approved', 'paid', 'interested'].some((k) => s.includes(k))) {
    return 'bg-emerald-50 text-emerald-700'
  }
  if (['progress', 'pending', 'scheduled', 'meeting'].some((k) => s.includes(k))) {
    return 'bg-amber-50 text-amber-700'
  }
  if (['inactive', 'reject', 'cancel', 'not interested', 'hold'].some((k) => s.includes(k))) {
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
  const title = TITLES[moduleId] || 'Module'
  const company = TENANT_NAMES[tenantId] || tenantId

  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [selectedMonth, setSelectedMonth] = useState(currentMonthValue)
  const [processingLeaveId, setProcessingLeaveId] = useState('')

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
        if ((moduleId === 'reports' || moduleId === 'tasks') && selectedMonth) {
          params.month = selectedMonth
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
  }, [tenantId, moduleId, status, selectedMonth])

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
    if (moduleId === 'clients') {
      return [
        { key: 'clientName', label: 'Client', render: (r) => <span className='font-medium text-blue-600'>{val(r.clientName)}</span> },
        { key: 'mailId', label: 'Email', render: (r) => val(r.mailId) },
        { key: 'clientNumber', label: 'Phone', render: (r) => val(r.clientNumber) },
        { key: 'businessType', label: 'Business', render: (r) => val(r.businessType) },
        { key: 'clientType', label: 'Type', render: (r) => <Badge>{r.clientType}</Badge> },
        { key: 'date', label: 'Date', render: (r) => formatDate(r.date || r.createdAt) },
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
      ]
    }
    if (moduleId === 'leads') {
      return [
        { key: 'businessName', label: 'Business', render: (r) => <span className='font-medium text-gray-900'>{val(r.businessName || r.name)}</span> },
        { key: 'name', label: 'Contact', render: (r) => val(r.name) },
        { key: 'contactNumber', label: 'Phone', render: (r) => val(r.contactNumber) },
        { key: 'status', label: 'Status', render: (r) => <Badge>{r.status}</Badge> },
        { key: 'leadSource', label: 'Source', render: (r) => val(r.leadSource) },
        { key: 'meetingTime', label: 'Meeting', render: (r) => formatDate(r.meetingTime) },
      ]
    }
    if (moduleId === 'tasks') {
      return [
        { key: 'title', label: 'Task', render: (r) => <span className='font-medium text-gray-900'>{val(r.title)}</span> },
        { key: 'project', label: 'Project', render: (r) => val(r.project?.projectName) },
        { key: 'assignedTo', label: 'Assigned to', render: (r) => val(r.assignedTo?.name) },
        { key: 'assignedBy', label: 'Assigned by', render: (r) => val(r.assignedBy?.name) },
        { key: 'priority', label: 'Priority', render: (r) => val(r.priority) },
        { key: 'status', label: 'Status', render: (r) => <Badge>{r.status}</Badge> },
        {
          key: 'rating',
          label: 'Rating',
          render: (r) => {
            const score = r.rating?.score
            if (score == null || score === '') return '—'
            return <span className='font-semibold text-amber-700'>{score}/5</span>
          },
        },
        { key: 'dueDate', label: 'Due', render: (r) => formatDate(r.dueDate) },
      ]
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
        { key: 'employee', label: 'Employee', render: (r) => <span className='font-medium text-gray-900'>{val(r.employee?.name)}</span> },
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
    return []
  }, [moduleId, processingLeaveId, tenantId, user?._id])

  const subtitle = moduleId === 'reports' || moduleId === 'tasks'
    ? (data?.monthLabel || selectedMonth || 'Selected month')
    : status
      ? `${filteredItems.length} shown · filter: ${status}`
      : `${filteredItems.length} record${filteredItems.length === 1 ? '' : 's'}`

  const showMonthPicker = moduleId === 'reports' || moduleId === 'tasks'

  return (
    <AdminCompanyShell activeNav={moduleId}>
      <div className='flex flex-wrap items-start justify-between gap-4 mb-6'>
        <div>
          <h1 className='text-2xl font-bold text-gray-900'>{title}</h1>
          <p className='text-sm text-gray-500 mt-1'>
            {company} · {subtitle}
            {moduleId === 'tasks' ? ` · ${filteredItems.length} task${filteredItems.length === 1 ? '' : 's'}` : ''}
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
          {moduleId !== 'reports' && moduleId !== 'settings' && (
            <input
              type='search'
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder={`Search ${title.toLowerCase()}…`}
              className='w-64 max-w-full rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
            />
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
          emptyText={`No ${title.toLowerCase()} found`}
          onRowClick={
            moduleId === 'clients'
              ? (row) => navigate(`/company/${tenantId}/clients/${row._id}`)
              : moduleId === 'projects'
                ? (row) => navigate(`/company/${tenantId}/projects/${row._id}`)
                : moduleId === 'tasks'
                  ? (row) => {
                      if (String(row._id || '').startsWith('social-media-')) return
                      navigate(`/company/${tenantId}/tasks/${row._id}`)
                    }
                  : moduleId === 'invoices'
                    ? (row) => navigate(`/company/${tenantId}/invoices/${row._id}`)
                    : undefined
          }
        />
      )}
    </AdminCompanyShell>
  )
}

export default ModulePage
