import React, { useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import api from '../api/axios'
import AdminCompanyShell, { getInitials } from '../components/AdminCompanyShell'
import { TENANT_NAMES } from '../config/tenants'

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

const TABS = [
  { id: 'overview', label: 'Overview' },
  { id: 'projects', label: 'Projects' },
  { id: 'clients', label: 'Clients' },
  { id: 'tasks', label: 'Tasks' },
  { id: 'attendance', label: 'Attendance & Leave' },
  { id: 'payroll', label: 'Payroll' },
  { id: 'performance', label: 'Performance' },
]

const formatDate = (value) => {
  if (!value) return '—'
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
}

const formatINR = (value) => {
  if (value == null || value === '') return '—'
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0,
  }).format(Number(value) || 0)
}

const val = (v) => (v === null || v === undefined || v === '' ? '—' : v)

const statusClass = (status) => {
  const s = String(status || '').toLowerCase()
  if (s.includes('active') || s.includes('completed') || s.includes('approved') || s.includes('present')) {
    return 'bg-emerald-50 text-emerald-700'
  }
  if (s.includes('progress') || s.includes('pending')) return 'bg-amber-50 text-amber-700'
  if (s.includes('inactive') || s.includes('absent') || s.includes('reject') || s.includes('cancel')) {
    return 'bg-rose-50 text-rose-700'
  }
  return 'bg-slate-50 text-slate-600'
}

const StatPill = ({ label, value }) => (
  <div className='rounded-xl bg-slate-50 border border-slate-100 px-3 py-2.5'>
    <p className='text-[11px] text-gray-500'>{label}</p>
    <p className='text-lg font-bold text-gray-900 mt-0.5 tabular-nums'>{value}</p>
  </div>
)

const SectionCard = ({ title, children, action }) => (
  <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-5'>
    <div className='flex items-center justify-between gap-3 mb-4'>
      <h3 className='text-sm font-semibold text-gray-900'>{title}</h3>
      {action}
    </div>
    {children}
  </div>
)

const Empty = ({ text }) => (
  <p className='text-sm text-gray-500 py-8 text-center'>{text}</p>
)

const Field = ({ label, value }) => (
  <div>
    <p className='text-[11px] uppercase tracking-wide text-gray-400'>{label}</p>
    <p className='text-sm text-gray-900 mt-0.5 break-words'>{val(value)}</p>
  </div>
)

const EmployeesPage = () => {
  const { tenantId, employeeId } = useParams()
  const navigate = useNavigate()
  const [employees, setEmployees] = useState([])
  const [profile, setProfile] = useState(null)
  const [loading, setLoading] = useState(true)
  const [profileLoading, setProfileLoading] = useState(false)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('all')
  const [tab, setTab] = useState('overview')

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
        const res = await api.get(`/companies/${tenantId}/employees`)
        if (!cancelled) setEmployees(res.data?.employees || [])
      } catch (err) {
        if (!cancelled) {
          setError(err.response?.data?.message || err.message || 'Failed to load employees')
          setEmployees([])
        }
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    load()
    return () => {
      cancelled = true
    }
  }, [tenantId])

  useEffect(() => {
    let cancelled = false
    const loadProfile = async () => {
      if (!employeeId) {
        setProfile(null)
        setTab('overview')
        return
      }
      try {
        setProfileLoading(true)
        setError('')
        const res = await api.get(`/companies/${tenantId}/employees/${employeeId}`)
        if (!cancelled) {
          setProfile(res.data)
          setTab('overview')
        }
      } catch (err) {
        if (!cancelled) {
          setError(err.response?.data?.message || err.message || 'Failed to load employee')
          setProfile(null)
        }
      } finally {
        if (!cancelled) setProfileLoading(false)
      }
    }
    loadProfile()
    return () => {
      cancelled = true
    }
  }, [tenantId, employeeId])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return employees.filter((emp) => {
      const status = emp.status || emp.access?.accountStatus || 'Active'
      if (statusFilter !== 'all' && String(status).toLowerCase() !== statusFilter) return false
      if (!q) return true
      const hay = [
        emp.name,
        emp.email,
        emp.department,
        emp.employeeCode,
        emp.designation?.title,
        emp.phone,
        emp.mobile,
      ]
        .filter(Boolean)
        .join(' ')
        .toLowerCase()
      return hay.includes(q)
    })
  }, [employees, search, statusFilter])

  const openEmployee = (id) => navigate(`/company/${tenantId}/employees/${id}`)
  const backToList = () => navigate(`/company/${tenantId}/employees`)

  const emp = profile?.employee
  const attendanceSummary = profile?.attendance?.summary || {}
  const leaveBalance = profile?.attendance?.leaveBalance || {}
  const tasks = profile?.tasks || []
  const projects = profile?.assignedProjects || []
  const clients = profile?.clients || []
  const salaries = profile?.salaries || []
  const leaves = profile?.attendance?.leaveHistory || []
  const attendanceRecords = profile?.attendance?.records || []
  const taskPerf = profile?.taskRatingPerformance || {}

  return (
    <AdminCompanyShell activeNav='employees'>
      {error && (
        <div className='mb-4 rounded-xl bg-red-50 border border-red-100 px-3 py-2'>
          <p className='text-red-600 text-sm'>{error}</p>
        </div>
      )}

      {!employeeId ? (
        <>
          <div className='flex flex-wrap items-start justify-between gap-4 mb-6'>
            <div>
              <h1 className='text-2xl font-bold text-gray-900'>Employees</h1>
              <p className='text-sm text-gray-500 mt-1'>
                {filtered.length} of {employees.length} team members · {TENANT_NAMES[tenantId]}
              </p>
            </div>
            <div className='flex flex-wrap items-center gap-2'>
              <input
                type='search'
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder='Search name, email, department…'
                className='w-64 max-w-full rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
              />
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className='rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
              >
                <option value='all'>All status</option>
                <option value='active'>Active</option>
                <option value='inactive'>Inactive</option>
              </select>
            </div>
          </div>

          {loading ? (
            <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-10 text-center text-sm text-gray-500'>
              Loading employees…
            </div>
          ) : (
            <div className='bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden'>
              <div className='overflow-x-auto'>
                <table className='min-w-full text-sm'>
                  <thead className='bg-slate-50 border-b border-gray-100 text-left text-xs uppercase tracking-wide text-gray-500'>
                    <tr>
                      <th className='px-4 py-3 font-semibold'>Employee</th>
                      <th className='px-4 py-3 font-semibold'>Department</th>
                      <th className='px-4 py-3 font-semibold'>Designation</th>
                      <th className='px-4 py-3 font-semibold'>Performance</th>
                      <th className='px-4 py-3 font-semibold'>Joined</th>
                      <th className='px-4 py-3 font-semibold'>Status</th>
                    </tr>
                  </thead>
                  <tbody className='divide-y divide-gray-50'>
                    {filtered.length ? (
                      filtered.map((row, index) => {
                        const status = row.status || row.access?.accountStatus || 'Active'
                        const rating = row.performance?.averageRating
                        return (
                          <tr
                            key={row._id}
                            className='hover:bg-slate-50/80 cursor-pointer'
                            onClick={() => openEmployee(row._id)}
                          >
                            <td className='px-4 py-3'>
                              <div className='flex items-center gap-3'>
                                <div
                                  className={`w-10 h-10 rounded-full flex items-center justify-center text-xs font-bold text-white shrink-0 ${AVATAR_COLORS[index % AVATAR_COLORS.length]}`}
                                >
                                  {getInitials(row.name)}
                                </div>
                                <div className='min-w-0'>
                                  <p className='font-semibold text-gray-900 truncate'>{row.name || '—'}</p>
                                  <p className='text-xs text-gray-400 truncate'>{row.email || '—'}</p>
                                </div>
                              </div>
                            </td>
                            <td className='px-4 py-3 text-gray-600'>{val(row.department)}</td>
                            <td className='px-4 py-3 text-gray-600'>{val(row.designation?.title)}</td>
                            <td className='px-4 py-3'>
                              {rating != null ? (
                                <span className='font-semibold text-amber-700'>{rating}/5</span>
                              ) : (
                                <span className='text-gray-400'>—</span>
                              )}
                            </td>
                            <td className='px-4 py-3 text-gray-600'>{formatDate(row.dateOfJoining || row.createdAt)}</td>
                            <td className='px-4 py-3'>
                              <span className={`inline-flex px-2.5 py-1 rounded-lg text-xs font-medium ${statusClass(status)}`}>
                                {status}
                              </span>
                            </td>
                          </tr>
                        )
                      })
                    ) : (
                      <tr>
                        <td colSpan={6} className='px-4 py-12 text-center text-gray-500'>
                          No employees match your filters
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </>
      ) : profileLoading ? (
        <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-10 text-center text-sm text-gray-500'>
          Loading employee profile…
        </div>
      ) : !emp ? (
        <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-10 text-center'>
          <p className='text-sm text-gray-500 mb-4'>Employee not found</p>
          <button
            type='button'
            onClick={backToList}
            className='text-sm font-medium text-blue-600 hover:text-blue-700'
          >
            ← Back to employees
          </button>
        </div>
      ) : (
        <>
          <button
            type='button'
            onClick={backToList}
            className='text-sm font-medium text-blue-600 hover:text-blue-700 mb-4'
          >
            ← Back to employees
          </button>

          <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-5 mb-5'>
            <div className='flex flex-wrap items-start gap-4'>
              <div className={`w-16 h-16 rounded-2xl flex items-center justify-center text-xl font-bold text-white ${AVATAR_COLORS[0]}`}>
                {getInitials(emp.name)}
              </div>
              <div className='min-w-0 flex-1'>
                <div className='flex flex-wrap items-center gap-2'>
                  <h1 className='text-2xl font-bold text-gray-900'>{emp.name}</h1>
                  <span className={`inline-flex px-2.5 py-1 rounded-lg text-xs font-medium ${statusClass(emp.status || profile.access?.accountStatus)}`}>
                    {emp.status || profile.access?.accountStatus || 'Active'}
                  </span>
                </div>
                <p className='text-sm text-gray-500 mt-1'>
                  {val(emp.designation?.title)} · {val(emp.department)}
                </p>
                <p className='text-sm text-gray-400 mt-0.5'>{emp.email}</p>
              </div>
              <div className='grid grid-cols-2 sm:grid-cols-4 gap-2 w-full lg:w-auto lg:min-w-[420px]'>
                <StatPill label='Projects' value={projects.length} />
                <StatPill label='Clients' value={clients.length} />
                <StatPill label='Tasks' value={tasks.length} />
                <StatPill label='Avg Rating' value={taskPerf.averageRating ?? '—'} />
              </div>
            </div>
          </div>

          <div className='flex flex-wrap gap-1 mb-5 border-b border-gray-200 pb-1'>
            {TABS.map((item) => (
              <button
                key={item.id}
                type='button'
                onClick={() => setTab(item.id)}
                className={`px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                  tab === item.id
                    ? 'bg-blue-600 text-white'
                    : 'text-gray-600 hover:bg-gray-100'
                }`}
              >
                {item.label}
              </button>
            ))}
          </div>

          {tab === 'overview' && (
            <div className='grid grid-cols-1 xl:grid-cols-3 gap-5'>
              <SectionCard title='Personal & employment'>
                <div className='grid grid-cols-1 sm:grid-cols-2 gap-4'>
                  <Field label='Employee code' value={emp.employeeCode} />
                  <Field label='Phone' value={emp.phone || emp.mobile || emp.personalInfo?.phone} />
                  <Field label='Date of joining' value={formatDate(emp.dateOfJoining)} />
                  <Field label='Working hours' value={emp.workingHours} />
                  <Field label='Salary' value={formatINR(emp.salary)} />
                  <Field label='Reporting manager' value={emp.reportingManager?.name} />
                  <Field label='CRM role' value={profile.access?.crmRole} />
                  <Field label='Account status' value={profile.access?.accountStatus} />
                </div>
              </SectionCard>

              <SectionCard title='Attendance snapshot'>
                <div className='grid grid-cols-2 gap-3'>
                  <StatPill label='Present' value={attendanceSummary.presentDays ?? 0} />
                  <StatPill label='Absent' value={attendanceSummary.absentDays ?? 0} />
                  <StatPill label='Late marks' value={attendanceSummary.lateMarks ?? 0} />
                  <StatPill label='Records' value={attendanceSummary.totalRecords ?? 0} />
                </div>
                <div className='mt-4 grid grid-cols-3 gap-3'>
                  <StatPill label='Sick left' value={leaveBalance.sick ?? '—'} />
                  <StatPill label='Casual left' value={leaveBalance.casual ?? '—'} />
                  <StatPill label='Annual left' value={leaveBalance.annual ?? '—'} />
                </div>
              </SectionCard>

              <SectionCard title='Quick lists'>
                <div className='space-y-4'>
                  <div>
                    <p className='text-xs font-semibold text-gray-500 mb-2'>Recent projects</p>
                    {projects.slice(0, 3).length ? (
                      projects.slice(0, 3).map((p) => (
                        <div key={p._id} className='flex items-center justify-between gap-2 py-1.5'>
                          <p className='text-sm text-gray-900 truncate'>{p.projectName}</p>
                          <span className={`shrink-0 text-[11px] px-2 py-0.5 rounded-md ${statusClass(p.status)}`}>
                            {p.status || '—'}
                          </span>
                        </div>
                      ))
                    ) : (
                      <p className='text-sm text-gray-400'>No projects</p>
                    )}
                  </div>
                  <div>
                    <p className='text-xs font-semibold text-gray-500 mb-2'>Linked clients</p>
                    {clients.slice(0, 3).length ? (
                      clients.slice(0, 3).map((c) => (
                        <p key={c._id || c.name} className='text-sm text-gray-900 py-1 truncate'>
                          {c.name}
                        </p>
                      ))
                    ) : (
                      <p className='text-sm text-gray-400'>No clients</p>
                    )}
                  </div>
                </div>
              </SectionCard>
            </div>
          )}

          {tab === 'projects' && (
            <SectionCard title={`Assigned projects (${projects.length})`}>
              {projects.length ? (
                <div className='overflow-x-auto'>
                  <table className='min-w-full text-sm'>
                    <thead className='text-left text-xs uppercase tracking-wide text-gray-500 border-b border-gray-100'>
                      <tr>
                        <th className='pb-3 pr-3'>Project</th>
                        <th className='pb-3 pr-3'>Role</th>
                        <th className='pb-3 pr-3'>Client</th>
                        <th className='pb-3 pr-3'>Status</th>
                        <th className='pb-3 pr-3'>Progress</th>
                        <th className='pb-3'>Deadline</th>
                      </tr>
                    </thead>
                    <tbody className='divide-y divide-gray-50'>
                      {projects.map((p) => (
                        <tr key={p._id}>
                          <td className='py-3 pr-3 font-medium text-gray-900'>{val(p.projectName)}</td>
                          <td className='py-3 pr-3 text-gray-600'>{val(p.role)}</td>
                          <td className='py-3 pr-3 text-gray-600'>
                            {val(p.client?.clientName || p.client?.companyName || p.client?.name)}
                          </td>
                          <td className='py-3 pr-3'>
                            <span className={`inline-flex px-2 py-0.5 rounded-md text-xs ${statusClass(p.status)}`}>
                              {val(p.status)}
                            </span>
                          </td>
                          <td className='py-3 pr-3'>
                            <div className='flex items-center gap-2 min-w-[120px]'>
                              <div className='flex-1 h-1.5 rounded-full bg-gray-100 overflow-hidden'>
                                <div
                                  className='h-full rounded-full bg-blue-600'
                                  style={{ width: `${Math.min(100, Number(p.progress) || 0)}%` }}
                                />
                              </div>
                              <span className='text-xs text-gray-500'>{p.progress || 0}%</span>
                            </div>
                          </td>
                          <td className='py-3 text-gray-600'>{formatDate(p.deadline || p.endDate)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ) : (
                <Empty text='No projects assigned' />
              )}
            </SectionCard>
          )}

          {tab === 'clients' && (
            <SectionCard title={`Linked clients (${clients.length})`}>
              {clients.length ? (
                <div className='grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4'>
                  {clients.map((client) => (
                    <div
                      key={client._id || client.name}
                      className='rounded-xl border border-gray-100 bg-slate-50/60 p-4'
                    >
                      <p className='font-semibold text-gray-900'>{client.name}</p>
                      <p className='text-xs text-gray-500 mt-1'>{val(client.email)}</p>
                      <p className='text-xs text-gray-500'>{val(client.phone)}</p>
                      {(client.businessType || client.city) && (
                        <p className='text-xs text-gray-400 mt-1'>
                          {[client.businessType, client.city].filter(Boolean).join(' · ')}
                        </p>
                      )}
                      <div className='mt-3 space-y-1'>
                        <p className='text-[11px] uppercase tracking-wide text-gray-400'>Projects</p>
                        {(client.projects || []).map((p) => (
                          <div key={p._id} className='flex items-center justify-between gap-2 text-sm'>
                            <span className='truncate text-gray-800'>{p.projectName}</span>
                            <span className={`shrink-0 text-[11px] px-2 py-0.5 rounded-md ${statusClass(p.status)}`}>
                              {p.status || '—'}
                            </span>
                          </div>
                        ))}
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <Empty text='No clients linked through projects' />
              )}
            </SectionCard>
          )}

          {tab === 'tasks' && (
            <SectionCard title={`Tasks (${tasks.length})`}>
              {tasks.length ? (
                <div className='overflow-x-auto'>
                  <table className='min-w-full text-sm'>
                    <thead className='text-left text-xs uppercase tracking-wide text-gray-500 border-b border-gray-100'>
                      <tr>
                        <th className='pb-3 pr-3'>Task</th>
                        <th className='pb-3 pr-3'>Project</th>
                        <th className='pb-3 pr-3'>Priority</th>
                        <th className='pb-3 pr-3'>Status</th>
                        <th className='pb-3 pr-3'>Due</th>
                        <th className='pb-3'>Rating</th>
                      </tr>
                    </thead>
                    <tbody className='divide-y divide-gray-50'>
                      {tasks.map((t) => (
                        <tr key={t._id}>
                          <td className='py-3 pr-3 font-medium text-gray-900'>{val(t.title)}</td>
                          <td className='py-3 pr-3 text-gray-600'>{val(t.project?.projectName)}</td>
                          <td className='py-3 pr-3 text-gray-600'>{val(t.priority)}</td>
                          <td className='py-3 pr-3'>
                            <span className={`inline-flex px-2 py-0.5 rounded-md text-xs ${statusClass(t.status)}`}>
                              {val(t.status)}
                            </span>
                          </td>
                          <td className='py-3 pr-3 text-gray-600'>{formatDate(t.dueDate)}</td>
                          <td className='py-3 text-gray-600'>{t.rating?.score ?? '—'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ) : (
                <Empty text='No tasks assigned' />
              )}
            </SectionCard>
          )}

          {tab === 'attendance' && (
            <div className='grid grid-cols-1 xl:grid-cols-2 gap-5'>
              <SectionCard title='Recent attendance'>
                {attendanceRecords.length ? (
                  <div className='overflow-x-auto max-h-96 overflow-y-auto'>
                    <table className='min-w-full text-sm'>
                      <thead className='sticky top-0 bg-white text-left text-xs uppercase tracking-wide text-gray-500 border-b border-gray-100'>
                        <tr>
                          <th className='pb-3 pr-3'>Date</th>
                          <th className='pb-3 pr-3'>Status</th>
                          <th className='pb-3 pr-3'>Check in</th>
                          <th className='pb-3'>Check out</th>
                        </tr>
                      </thead>
                      <tbody className='divide-y divide-gray-50'>
                        {attendanceRecords.map((r) => (
                          <tr key={r._id}>
                            <td className='py-2.5 pr-3'>{formatDate(r.date)}</td>
                            <td className='py-2.5 pr-3'>
                              <span className={`inline-flex px-2 py-0.5 rounded-md text-xs ${statusClass(r.status)}`}>
                                {val(r.status)}
                              </span>
                            </td>
                            <td className='py-2.5 pr-3 text-gray-600'>{val(r.checkIn)}</td>
                            <td className='py-2.5 text-gray-600'>{val(r.checkOut)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                ) : (
                  <Empty text='No attendance records' />
                )}
              </SectionCard>

              <SectionCard title='Leave history'>
                {leaves.length ? (
                  <div className='overflow-x-auto max-h-96 overflow-y-auto'>
                    <table className='min-w-full text-sm'>
                      <thead className='sticky top-0 bg-white text-left text-xs uppercase tracking-wide text-gray-500 border-b border-gray-100'>
                        <tr>
                          <th className='pb-3 pr-3'>Type</th>
                          <th className='pb-3 pr-3'>From</th>
                          <th className='pb-3 pr-3'>To</th>
                          <th className='pb-3 pr-3'>Days</th>
                          <th className='pb-3'>Status</th>
                        </tr>
                      </thead>
                      <tbody className='divide-y divide-gray-50'>
                        {leaves.map((l) => (
                          <tr key={l._id}>
                            <td className='py-2.5 pr-3'>{val(l.leaveType)}</td>
                            <td className='py-2.5 pr-3'>{formatDate(l.startDate)}</td>
                            <td className='py-2.5 pr-3'>{formatDate(l.endDate)}</td>
                            <td className='py-2.5 pr-3'>{val(l.numberOfDays)}</td>
                            <td className='py-2.5'>
                              <span className={`inline-flex px-2 py-0.5 rounded-md text-xs ${statusClass(l.status)}`}>
                                {val(l.status)}
                              </span>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                ) : (
                  <Empty text='No leave history' />
                )}
              </SectionCard>
            </div>
          )}

          {tab === 'payroll' && (
            <SectionCard title={`Salary history (${salaries.length})`}>
              {salaries.length ? (
                <div className='overflow-x-auto'>
                  <table className='min-w-full text-sm'>
                    <thead className='text-left text-xs uppercase tracking-wide text-gray-500 border-b border-gray-100'>
                      <tr>
                        <th className='pb-3 pr-3'>Period</th>
                        <th className='pb-3 pr-3'>Gross</th>
                        <th className='pb-3 pr-3'>Net</th>
                        <th className='pb-3'>Status</th>
                      </tr>
                    </thead>
                    <tbody className='divide-y divide-gray-50'>
                      {salaries.map((s) => (
                        <tr key={s._id}>
                          <td className='py-3 pr-3 font-medium text-gray-900'>
                            {s.month}/{s.year}
                          </td>
                          <td className='py-3 pr-3'>{formatINR(s.grossSalary ?? s.basicSalary ?? s.amount)}</td>
                          <td className='py-3 pr-3'>{formatINR(s.netSalary ?? s.takeHome ?? s.amount)}</td>
                          <td className='py-3'>
                            <span className={`inline-flex px-2 py-0.5 rounded-md text-xs ${statusClass(s.status || s.paymentStatus)}`}>
                              {val(s.status || s.paymentStatus || 'Recorded')}
                            </span>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ) : (
                <Empty text='No salary records' />
              )}
            </SectionCard>
          )}

          {tab === 'performance' && (
            <div className='grid grid-cols-1 xl:grid-cols-3 gap-5'>
              <SectionCard title='Task ratings'>
                <div className='grid grid-cols-2 gap-3'>
                  <StatPill label='Average' value={taskPerf.averageRating ?? '—'} />
                  <StatPill label='Rated tasks' value={taskPerf.ratedTaskCount ?? 0} />
                  <StatPill label='Assigned' value={taskPerf.totalAssignedTasks ?? 0} />
                  <StatPill label='Present days' value={attendanceSummary.presentDays ?? 0} />
                </div>
              </SectionCard>
              <div className='xl:col-span-2'>
                <SectionCard title='Recent ratings'>
                  {(taskPerf.ratings || []).length ? (
                    <div className='space-y-3'>
                      {taskPerf.ratings.slice(0, 10).map((r) => (
                        <div key={r.taskId} className='flex items-start justify-between gap-3 border-b border-gray-50 pb-3 last:border-0'>
                          <div className='min-w-0'>
                            <p className='text-sm font-medium text-gray-900 truncate'>{r.title}</p>
                            <p className='text-xs text-gray-400 mt-0.5'>
                              {r.projectName || '—'} · by {r.ratedByName || '—'} · {formatDate(r.ratedAt)}
                            </p>
                            {r.comments && <p className='text-xs text-gray-500 mt-1'>{r.comments}</p>}
                          </div>
                          <span className='shrink-0 text-sm font-bold text-indigo-600'>{r.score}/5</span>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <Empty text='No task ratings yet' />
                  )}
                </SectionCard>
              </div>
            </div>
          )}
        </>
      )}
    </AdminCompanyShell>
  )
}

export default EmployeesPage
