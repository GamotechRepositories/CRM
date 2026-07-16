import React, { useEffect, useMemo, useState } from 'react'
import { NavLink, useNavigate, useParams } from 'react-router-dom'
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import api from '../api/axios'
import AdminCompanyShell, { getInitials } from '../components/AdminCompanyShell'
import { AppIcon } from '../components/Icons'
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

const formatINR = (value) => {
  const amount = Number(value) || 0
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0,
  }).format(amount)
}

const formatDate = (value) => {
  if (!value) return '—'
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
}

const KpiCard = ({ title, value, subtitle, icon, iconBg, to }) => (
  <NavLink
    to={to}
    className='block bg-white rounded-2xl border border-gray-100 shadow-sm p-4 hover:shadow-md hover:border-blue-200 hover:ring-1 hover:ring-blue-100 transition-all focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500'
  >
    <div className='flex items-start gap-3'>
      <div className={`w-11 h-11 rounded-xl flex items-center justify-center shrink-0 ${iconBg}`}>
        {typeof icon === 'string' ? <AppIcon id={icon} className='size-5' /> : icon}
      </div>
      <div className='min-w-0'>
        <p className='text-sm text-gray-500'>{title}</p>
        <p className='text-2xl font-bold text-gray-900 mt-0.5 tabular-nums'>{value}</p>
        <p className='text-xs text-gray-400 mt-0.5'>{subtitle}</p>
      </div>
    </div>
  </NavLink>
)

const CompanyDashboard = () => {
  const { tenantId } = useParams()
  const navigate = useNavigate()
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

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
        const res = await api.get(`/companies/${tenantId}/dashboard`)
        if (!cancelled) setData(res.data)
      } catch (err) {
        if (!cancelled) {
          setError(err.response?.data?.message || err.message || 'Failed to load dashboard')
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
  }, [tenantId])

  const stats = data?.stats || {}
  const chartData = data?.revenueByDay || []

  const base = `/company/${tenantId}`

  const kpis = useMemo(
    () => [
      { title: 'Employees', value: stats.employees ?? 0, subtitle: 'Active Team Members', icon: 'employees', iconBg: 'bg-violet-100 text-violet-700', to: `${base}/employees` },
      { title: 'Clients', value: stats.clients ?? 0, subtitle: 'Total Clients', icon: 'clients', iconBg: 'bg-blue-100 text-blue-700', to: `${base}/clients` },
      { title: 'Projects', value: stats.projects ?? 0, subtitle: 'Total Projects', icon: 'projects', iconBg: 'bg-indigo-100 text-indigo-700', to: `${base}/projects` },
      { title: 'Active Projects', value: stats.activeProjects ?? 0, subtitle: 'Currently Active', icon: 'activeProjects', iconBg: 'bg-emerald-100 text-emerald-700', to: `${base}/projects?status=active` },
      { title: 'Leads', value: stats.leads ?? 0, subtitle: 'Total Leads', icon: 'leads', iconBg: 'bg-amber-100 text-amber-700', to: `${base}/leads` },
      { title: 'Tasks', value: stats.tasks ?? 0, subtitle: 'Total Tasks', icon: 'tasks', iconBg: 'bg-pink-100 text-pink-700', to: `${base}/tasks` },
      { title: 'Pending Tasks', value: stats.pendingTasks ?? 0, subtitle: 'Awaiting Action', icon: 'pendingTasks', iconBg: 'bg-orange-100 text-orange-700', to: `${base}/tasks?status=pending` },
      { title: 'Completed Tasks', value: stats.completedTasks ?? 0, subtitle: 'Completed', icon: 'completedTasks', iconBg: 'bg-green-100 text-green-700', to: `${base}/tasks?status=completed` },
      { title: 'Revenue', value: formatINR(stats.totalRevenue), subtitle: 'Total Revenue', icon: 'revenue', iconBg: 'bg-emerald-100 text-emerald-700', to: `${base}/reports` },
      { title: 'Expenses', value: formatINR(stats.totalExpenses), subtitle: 'Total Expenses', icon: 'expenses', iconBg: 'bg-rose-100 text-rose-700', to: `${base}/reports` },
      { title: 'Pending Leaves', value: stats.pendingLeaves ?? 0, subtitle: 'Awaiting Approval', icon: 'leaves', iconBg: 'bg-cyan-100 text-cyan-700', to: `${base}/leaves?status=pending` },
      { title: 'Pending Invoices', value: stats.pendingInvoices ?? 0, subtitle: 'Unpaid Invoices', icon: 'invoices', iconBg: 'bg-slate-100 text-slate-700', to: `${base}/invoices?status=pending` },
    ],
    [stats, base]
  )

  return (
    <AdminCompanyShell activeNav='dashboard'>
      {error && (
        <div className='mb-4 rounded-xl bg-red-50 border border-red-100 px-3 py-2'>
          <p className='text-red-600 text-sm'>{error}</p>
        </div>
      )}

      {loading ? (
        <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-10 text-center text-sm text-gray-500'>
          Loading dashboard…
        </div>
      ) : (
        <>
          <div className='grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4 mb-6'>
            {kpis.map((kpi) => (
              <KpiCard key={kpi.title} {...kpi} />
            ))}
          </div>

          <div className='grid grid-cols-1 xl:grid-cols-3 gap-5 mb-6'>
            <div className='xl:col-span-1 bg-white rounded-2xl border border-gray-100 shadow-sm p-5'>
              <div className='flex items-center justify-between mb-4'>
                <h3 className='text-sm font-semibold text-gray-900'>Revenue Overview</h3>
                <span className='text-xs text-gray-500 border border-gray-200 rounded-lg px-2 py-1'>This Month ▾</span>
              </div>
              <div className='h-56'>
                <ResponsiveContainer width='100%' height='100%'>
                  <AreaChart data={chartData} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
                    <defs>
                      <linearGradient id='revenueFill' x1='0' y1='0' x2='0' y2='1'>
                        <stop offset='5%' stopColor='#2563EB' stopOpacity={0.25} />
                        <stop offset='95%' stopColor='#2563EB' stopOpacity={0} />
                      </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray='3 3' stroke='#E5E7EB' vertical={false} />
                    <XAxis dataKey='label' tick={{ fontSize: 11, fill: '#9CA3AF' }} axisLine={false} tickLine={false} />
                    <YAxis tick={{ fontSize: 11, fill: '#9CA3AF' }} axisLine={false} tickLine={false} width={40} />
                    <Tooltip
                      formatter={(value) => [formatINR(value), 'Revenue']}
                      contentStyle={{ borderRadius: 12, borderColor: '#E5E7EB', fontSize: 12 }}
                    />
                    <Area type='monotone' dataKey='revenue' stroke='#2563EB' strokeWidth={2.5} fill='url(#revenueFill)' />
                  </AreaChart>
                </ResponsiveContainer>
              </div>
            </div>

            <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-5'>
              <div className='flex items-center justify-between mb-4'>
                <h3 className='text-sm font-semibold text-gray-900'>Recent Projects</h3>
                <NavLink to={`${base}/projects`} className='text-xs font-medium text-blue-600 hover:text-blue-700'>
                  View All
                </NavLink>
              </div>
              <div className='space-y-4'>
                {(data?.recentProjects || []).length ? (
                  data.recentProjects.map((project, index) => (
                    <div key={project._id} className='flex gap-3'>
                      <div className={`w-10 h-10 rounded-xl flex items-center justify-center shrink-0 ${AVATAR_COLORS[index % AVATAR_COLORS.length]} text-white`}>
                        <AppIcon id='projects' className='size-5' />
                      </div>
                      <div className='min-w-0 flex-1'>
                        <div className='flex items-start justify-between gap-2'>
                          <div className='min-w-0'>
                            <p className='text-sm font-semibold text-gray-900 truncate'>{project.projectName || '—'}</p>
                            <p className='text-xs text-gray-400 mt-0.5'>
                              {project.status || '—'} · {formatDate(project.deadline || project.createdAt)}
                            </p>
                          </div>
                          <span className='text-xs font-semibold text-gray-600 shrink-0'>{project.progress || 0}%</span>
                        </div>
                        <div className='mt-2 h-1.5 rounded-full bg-gray-100 overflow-hidden'>
                          <div
                            className='h-full rounded-full bg-blue-600'
                            style={{ width: `${Math.min(100, Number(project.progress) || 0)}%` }}
                          />
                        </div>
                      </div>
                    </div>
                  ))
                ) : (
                  <p className='text-sm text-gray-500 py-8 text-center'>No projects yet</p>
                )}
              </div>
            </div>

            <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-5'>
              <div className='flex items-center justify-between mb-4'>
                <h3 className='text-sm font-semibold text-gray-900'>Recent Employees</h3>
                <button
                  type='button'
                  onClick={() => navigate(`/company/${tenantId}/employees`)}
                  className='text-xs font-medium text-blue-600 hover:text-blue-700'
                >
                  View All
                </button>
              </div>
              <div className='space-y-3'>
                {(data?.recentEmployees || []).length ? (
                  data.recentEmployees.map((emp, index) => (
                    <button
                      key={emp._id}
                      type='button'
                      onClick={() => navigate(`/company/${tenantId}/employees/${emp._id}`)}
                      className='w-full flex items-center gap-3 text-left hover:bg-slate-50 rounded-xl px-1 py-1 -mx-1 transition-colors'
                    >
                      <div className={`w-10 h-10 rounded-full flex items-center justify-center text-xs font-bold text-white shrink-0 ${AVATAR_COLORS[index % AVATAR_COLORS.length]}`}>
                        {getInitials(emp.name)}
                      </div>
                      <div className='min-w-0 flex-1'>
                        <p className='text-sm font-semibold text-gray-900 truncate'>{emp.name || '—'}</p>
                        <p className='text-xs text-gray-400 truncate'>{emp.email || '—'}</p>
                      </div>
                      <span className='text-[11px] text-gray-400 shrink-0'>{formatDate(emp.createdAt)}</span>
                    </button>
                  ))
                ) : (
                  <p className='text-sm text-gray-500 py-8 text-center'>No employees yet</p>
                )}
              </div>
            </div>
          </div>

          <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-5'>
            <div className='flex items-center justify-between mb-4'>
              <h3 className='text-sm font-semibold text-gray-900'>Tasks Overview</h3>
              <NavLink to={`${base}/tasks`} className='text-xs font-medium text-blue-600 hover:text-blue-700'>
                View All Tasks
              </NavLink>
            </div>
            <div className='grid grid-cols-2 md:grid-cols-4 gap-4'>
              {[
                { label: 'Total Tasks', value: stats.tasks ?? 0, color: 'text-blue-600', bg: 'bg-blue-50', to: `${base}/tasks` },
                { label: 'Pending Tasks', value: stats.pendingTasks ?? 0, color: 'text-amber-600', bg: 'bg-amber-50', to: `${base}/tasks?status=pending` },
                { label: 'In Progress', value: stats.inProgressTasks ?? 0, color: 'text-indigo-600', bg: 'bg-indigo-50', to: `${base}/tasks?status=in-progress` },
                { label: 'Completed Tasks', value: stats.completedTasks ?? 0, color: 'text-emerald-600', bg: 'bg-emerald-50', to: `${base}/tasks?status=completed` },
              ].map((item) => (
                <NavLink
                  key={item.label}
                  to={item.to}
                  className={`rounded-xl ${item.bg} px-4 py-4 hover:ring-1 hover:ring-blue-200 transition-shadow`}
                >
                  <p className='text-xs text-gray-500'>{item.label}</p>
                  <p className={`text-2xl font-bold mt-1 ${item.color}`}>{item.value}</p>
                </NavLink>
              ))}
            </div>
          </div>
        </>
      )}
    </AdminCompanyShell>
  )
}

export default CompanyDashboard
