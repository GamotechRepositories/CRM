import React, { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  Area,
  AreaChart,
} from 'recharts'
import api from '../../api/axios'
import { useAuth } from '../../context/AuthContext'

const CHART_COLORS = ['#3b82f6', '#8b5cf6', '#06b6d4', '#f59e0b', '#10b981', '#ec4899', '#6366f1']
const TASK_COLORS = { Completed: '#10b981', 'In Progress': '#3b82f6', Pending: '#f59e0b', Cancelled: '#9ca3af' }

const formatINR = (n) => `₹ ${Math.round(Number(n) || 0).toLocaleString('en-IN')}`
const formatCompactINR = (n) => {
  const v = Number(n) || 0
  if (v >= 100000) return `₹${(v / 100000).toFixed(1)}L`
  if (v >= 1000) return `₹${(v / 1000).toFixed(0)}k`
  return `₹${v}`
}

const timeAgo = (date) => {
  if (!date) return ''
  const diff = Date.now() - new Date(date).getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 60) return `${Math.max(1, mins)} min ago`
  const hrs = Math.floor(mins / 60)
  if (hrs < 24) return `${hrs} hr ago`
  const days = Math.floor(hrs / 24)
  return `${days} day${days > 1 ? 's' : ''} ago`
}

const isThisMonth = (d) => {
  if (!d) return false
  const dt = new Date(d)
  const now = new Date()
  return dt.getMonth() === now.getMonth() && dt.getFullYear() === now.getFullYear()
}

const isLastMonth = (d) => {
  if (!d) return false
  const dt = new Date(d)
  const now = new Date()
  const lm = new Date(now.getFullYear(), now.getMonth() - 1, 1)
  return dt.getMonth() === lm.getMonth() && dt.getFullYear() === lm.getFullYear()
}

const growthPct = (current, previous) => {
  if (!previous) return current > 0 ? 100 : 0
  return Math.round(((current - previous) / previous) * 1000) / 10
}

const Sparkline = ({ data, color }) => {
  const points = (data || []).map((v, i) => `${(i / Math.max(data.length - 1, 1)) * 100},${24 - (v / Math.max(...data, 1)) * 20}`).join(' ')
  return (
    <svg viewBox='0 0 100 24' className='w-full h-6 mt-3' preserveAspectRatio='none'>
      <polyline fill='none' stroke={color} strokeWidth='2' points={points} />
    </svg>
  )
}

const KpiCard = ({ title, value, change, positive, icon, iconBg, sparkData, sparkColor, onClick }) => (
  <button
    type='button'
    onClick={onClick}
    className='text-left bg-white rounded-xl border border-gray-200 shadow-sm p-5 hover:shadow-md transition-shadow w-full'
  >
    <div className='flex items-start justify-between gap-3'>
      <div className='min-w-0 flex-1'>
        <p className='text-sm text-gray-500 font-medium'>{title}</p>
        <p className='text-2xl font-bold text-gray-900 mt-1 truncate'>{value}</p>
        {change != null && (
          <p className={`text-xs font-semibold mt-1 flex items-center gap-1 ${positive ? 'text-green-600' : 'text-red-600'}`}>
            <span>{positive ? '↑' : '↓'}</span>
            {Math.abs(change)}% this month
          </p>
        )}
      </div>
      <div className={`w-11 h-11 rounded-xl flex items-center justify-center text-xl shrink-0 ${iconBg}`}>{icon}</div>
    </div>
    {sparkData?.length > 0 && <Sparkline data={sparkData} color={sparkColor} />}
  </button>
)

const Panel = ({ title, actionLabel, onAction, children, className = '' }) => (
  <div className={`bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden ${className}`}>
    <div className='flex items-center justify-between px-5 py-4 border-b border-gray-100'>
      <h3 className='text-sm font-semibold text-gray-900'>{title}</h3>
      {actionLabel && (
        <button type='button' onClick={onAction} className='text-xs font-medium text-blue-600 hover:text-blue-700'>
          {actionLabel}
        </button>
      )}
    </div>
    <div className='p-5'>{children}</div>
  </div>
)

const MiniStat = ({ title, value, change, icon, iconBg, onClick }) => (
  <button type='button' onClick={onClick} className='bg-white rounded-xl border border-gray-200 shadow-sm p-4 hover:shadow-md transition-shadow text-left w-full'>
    <div className='flex items-center justify-between gap-2'>
      <div>
        <p className='text-xs text-gray-500'>{title}</p>
        <p className='text-xl font-bold text-gray-900 mt-1'>{value}</p>
        {change != null && (
          <p className={`text-[11px] font-medium mt-0.5 ${change >= 0 ? 'text-green-600' : 'text-red-600'}`}>
            {change >= 0 ? '+' : ''}{change}%
          </p>
        )}
      </div>
      <div className={`w-10 h-10 rounded-lg flex items-center justify-center text-lg ${iconBg}`}>{icon}</div>
    </div>
  </button>
)

const getWeekRangeLabel = () => {
  const now = new Date()
  const start = new Date(now)
  start.setDate(now.getDate() - 6)
  const fmt = (d) => d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })
  return `${fmt(start)} – ${fmt(now)}`
}

const AdminDashboardView = () => {
  const { user } = useAuth()
  const navigate = useNavigate()
  const [loading, setLoading] = useState(true)
  const [employees, setEmployees] = useState([])
  const [clients, setClients] = useState([])
  const [projects, setProjects] = useState([])
  const [leads, setLeads] = useState([])
  const [tasks, setTasks] = useState([])
  const [billings, setBillings] = useState([])
  const [leaves, setLeaves] = useState([])

  useEffect(() => {
    const load = async () => {
      try {
        setLoading(true)
        const [empRes, cliRes, projRes, leadRes, taskRes, billRes, leaveRes] = await Promise.all([
          api.get('/employees'),
          api.get('/clients'),
          api.get('/projects'),
          api.get('/leads').catch(() => ({ data: [] })),
          api.get('/tasks').catch(() => ({ data: [] })),
          api.get('/billing').catch(() => ({ data: [] })),
          api.get('/leave').catch(() => ({ data: [] })),
        ])
        const list = (res) => (Array.isArray(res.data) ? res.data : res.data?.data || [])
        setEmployees(list(empRes))
        setClients(list(cliRes))
        setProjects(list(projRes))
        setLeads(list(leadRes))
        setTasks(list(taskRes))
        setBillings(list(billRes))
        setLeaves(list(leaveRes))
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [])

  const stats = useMemo(() => {
    const revenue = billings.reduce((s, b) => s + (Number(b.paymentDetails?.amount) || 0), 0)
    const revenueThisMonth = billings
      .filter((b) => isThisMonth(b.paymentDetails?.paymentDate || b.createdAt))
      .reduce((s, b) => s + (Number(b.paymentDetails?.amount) || 0), 0)
    const revenueLastMonth = billings
      .filter((b) => isLastMonth(b.paymentDetails?.paymentDate || b.createdAt))
      .reduce((s, b) => s + (Number(b.paymentDetails?.amount) || 0), 0)

    const newLeadsThisMonth = leads.filter((l) => isThisMonth(l.createdAt)).length
    const newLeadsLastMonth = leads.filter((l) => isLastMonth(l.createdAt)).length
    const openDeals = leads.filter((l) => ['Interested', 'Meeting Schedule', 'Call You After Sometime'].includes(l.status)).length
    const openDealsThisMonth = leads.filter((l) => ['Interested', 'Meeting Schedule'].includes(l.status) && isThisMonth(l.updatedAt || l.createdAt)).length
    const openDealsLastMonth = leads.filter((l) => ['Interested', 'Meeting Schedule'].includes(l.status) && isLastMonth(l.updatedAt || l.createdAt)).length

    const completedTasks = tasks.filter((t) => t.status === 'Completed')
    const completedThisMonth = completedTasks.filter((t) => isThisMonth(t.completedAt || t.updatedAt)).length
    const completedLastMonth = completedTasks.filter((t) => isLastMonth(t.completedAt || t.updatedAt)).length

    const employeesThisMonth = employees.filter((e) => isThisMonth(e.createdAt || e.dateOfJoining)).length
    const employeesLastMonth = employees.filter((e) => isLastMonth(e.createdAt || e.dateOfJoining)).length

    const activeProjects = projects.filter((p) => p.status === 'In Progress').length
    const pendingInvoices = billings.filter((b) => !b.paymentDetails?.amount || Number(b.paymentDetails.amount) === 0).length
    const openTickets = leaves.filter((l) => l.status === 'Pending').length

    const revenueByDay = []
    for (let i = 6; i >= 0; i--) {
      const d = new Date()
      d.setDate(d.getDate() - i)
      d.setHours(0, 0, 0, 0)
      const next = new Date(d)
      next.setDate(next.getDate() + 1)
      const dayTotal = billings
        .filter((b) => {
          const pd = new Date(b.paymentDetails?.paymentDate || b.createdAt)
          return pd >= d && pd < next
        })
        .reduce((s, b) => s + (Number(b.paymentDetails?.amount) || 0), 0)
      revenueByDay.push({
        day: d.toLocaleDateString('en-IN', { weekday: 'short' }),
        revenue: dayTotal,
        label: d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }),
      })
    }

    const sourceMap = {}
    leads.forEach((l) => {
      const src = (l.leadSource || 'Other').trim() || 'Other'
      sourceMap[src] = (sourceMap[src] || 0) + 1
    })
    const leadsBySource = Object.entries(sourceMap)
      .map(([name, value]) => ({ name, value }))
      .sort((a, b) => b.value - a.value)

    const taskStatusMap = { Completed: 0, 'In Progress': 0, Pending: 0, Cancelled: 0 }
    tasks.forEach((t) => {
      const s = taskStatusMap[t.status] !== undefined ? t.status : 'Pending'
      taskStatusMap[s] += 1
    })
    const taskChart = Object.entries(taskStatusMap)
      .filter(([, v]) => v > 0)
      .map(([name, value]) => ({ name, value, color: TASK_COLORS[name] || '#9ca3af' }))

    const leadCountByEmployee = {}
    leads.forEach((l) => {
      const id = l.generatedBy?._id || l.generatedBy
      if (!id) return
      const key = String(id)
      if (!leadCountByEmployee[key]) {
        leadCountByEmployee[key] = {
          employee: typeof l.generatedBy === 'object' ? l.generatedBy : employees.find((e) => String(e._id) === key),
          count: 0,
        }
      }
      leadCountByEmployee[key].count += 1
    })
    const topEmployees = Object.values(leadCountByEmployee)
      .sort((a, b) => b.count - a.count)
      .slice(0, 5)
      .map((item) => ({
        name: item.employee?.name || 'Employee',
        designation: item.employee?.designation?.title || item.employee?.department || '—',
        count: item.count,
        value: item.count * 50000,
      }))

    const activities = [
      ...projects.map((p) => ({ type: 'Project', icon: '📁', title: `Project "${p.projectName}" updated`, date: p.updatedAt || p.createdAt, path: `/projects?focus=${p._id}` })),
      ...clients.map((c) => ({ type: 'Client', icon: '🏢', title: `Client "${c.clientName}" added`, date: c.createdAt, path: `/clients?focus=${c._id}` })),
      ...employees.map((e) => ({ type: 'Employee', icon: '👤', title: `Employee "${e.name}" joined`, date: e.createdAt || e.dateOfJoining, path: `/employees/${e._id}/profile` })),
      ...leads.map((l) => ({ type: 'Lead', icon: '🎯', title: `New lead "${l.businessName || l.name}"`, date: l.createdAt, path: `/leads/view/${l._id}` })),
      ...tasks.filter((t) => t.status === 'Completed').map((t) => ({ type: 'Task', icon: '✅', title: `Task completed: ${t.title}`, date: t.completedAt || t.updatedAt, path: '/tasks' })),
    ]
      .filter((a) => a.date)
      .sort((a, b) => new Date(b.date) - new Date(a.date))
      .slice(0, 8)

    const spark = (arr) => arr.map((_, i) => Math.max(1, i + 2))

    return {
      revenue,
      revenueGrowth: growthPct(revenueThisMonth, revenueLastMonth),
      employeeGrowth: growthPct(employeesThisMonth, employeesLastMonth),
      leadGrowth: growthPct(newLeadsThisMonth, newLeadsLastMonth),
      dealGrowth: growthPct(openDealsThisMonth, openDealsLastMonth),
      taskGrowth: growthPct(completedThisMonth, completedLastMonth),
      newLeadsThisMonth,
      openDeals,
      completedTasks: completedTasks.length,
      activeProjects,
      pendingInvoices,
      openTickets,
      revenueByDay,
      leadsBySource,
      taskChart,
      topEmployees,
      activities,
      sparks: {
        users: spark(employees),
        revenue: revenueByDay.map((d) => d.revenue),
        leads: spark(leads),
        deals: spark([openDeals]),
        tasks: spark(completedTasks),
      },
    }
  }, [employees, clients, projects, leads, tasks, billings, leaves])

  if (loading) {
    return <div className='p-8 text-sm text-gray-600'>Loading admin dashboard...</div>
  }

  const firstName = (user?.name || 'Admin').split(' ')[0]

  return (
    <div className='p-6 md:p-8 w-full bg-gray-50 min-h-full'>
      <div className='flex flex-wrap items-start justify-between gap-4 mb-6'>
        <div>
          <h1 className='text-2xl font-bold text-gray-900'>Dashboard</h1>
          <p className='text-gray-600 mt-1 text-sm'>Welcome back, {firstName}! Here&apos;s your organization overview.</p>
        </div>
        <div className='text-sm text-gray-500 bg-white border border-gray-200 rounded-lg px-4 py-2'>
          {getWeekRangeLabel()}
        </div>
      </div>

      <div className='grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-4 mb-6'>
        <KpiCard title='Total Users' value={employees.length} change={stats.employeeGrowth} positive={stats.employeeGrowth >= 0} icon='👥' iconBg='bg-purple-50' sparkData={stats.sparks.users} sparkColor='#8b5cf6' onClick={() => navigate('/employees')} />
        <KpiCard title='Total Revenue' value={formatINR(stats.revenue)} change={stats.revenueGrowth} positive={stats.revenueGrowth >= 0} icon='💰' iconBg='bg-green-50' sparkData={stats.sparks.revenue} sparkColor='#10b981' onClick={() => navigate('/revenue')} />
        <KpiCard title='New Leads' value={stats.newLeadsThisMonth} change={stats.leadGrowth} positive={stats.leadGrowth >= 0} icon='🎯' iconBg='bg-orange-50' sparkData={stats.sparks.leads} sparkColor='#f59e0b' onClick={() => navigate('/leads')} />
        <KpiCard title='Open Deals' value={stats.openDeals} change={stats.dealGrowth} positive={stats.dealGrowth >= 0} icon='💼' iconBg='bg-blue-50' sparkData={stats.sparks.deals} sparkColor='#3b82f6' onClick={() => navigate('/lead-management')} />
        <KpiCard title='Tasks Completed' value={stats.completedTasks} change={stats.taskGrowth} positive={stats.taskGrowth >= 0} icon='✅' iconBg='bg-pink-50' sparkData={stats.sparks.tasks} sparkColor='#ec4899' onClick={() => navigate('/tasks')} />
      </div>

      <div className='grid grid-cols-1 xl:grid-cols-3 gap-6 mb-6'>
        <Panel title='Revenue Overview' className='xl:col-span-2' actionLabel='This Week' onAction={() => navigate('/revenue')}>
          <div className='h-64'>
            <ResponsiveContainer width='100%' height='100%'>
              <AreaChart data={stats.revenueByDay}>
                <defs>
                  <linearGradient id='revenueGrad' x1='0' y1='0' x2='0' y2='1'>
                    <stop offset='0%' stopColor='#3b82f6' stopOpacity={0.3} />
                    <stop offset='100%' stopColor='#3b82f6' stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray='3 3' stroke='#f0f0f0' />
                <XAxis dataKey='day' tick={{ fontSize: 11 }} />
                <YAxis tickFormatter={formatCompactINR} tick={{ fontSize: 11 }} />
                <Tooltip formatter={(v) => [formatINR(v), 'Revenue']} labelFormatter={(_, payload) => payload?.[0]?.payload?.label} />
                <Area type='monotone' dataKey='revenue' stroke='#3b82f6' fill='url(#revenueGrad)' strokeWidth={2} />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </Panel>

        <Panel title='Leads by Source' actionLabel='View Report' onAction={() => navigate('/leads')}>
          {stats.leadsBySource.length ? (
            <>
              <div className='h-40 relative'>
                <ResponsiveContainer width='100%' height='100%'>
                  <PieChart>
                    <Pie data={stats.leadsBySource} dataKey='value' cx='50%' cy='50%' innerRadius={45} outerRadius={65} paddingAngle={2}>
                      {stats.leadsBySource.map((_, i) => <Cell key={i} fill={CHART_COLORS[i % CHART_COLORS.length]} />)}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
                <div className='absolute inset-0 flex items-center justify-center pointer-events-none'>
                  <div className='text-center'>
                    <p className='text-xl font-bold text-gray-900'>{leads.length}</p>
                    <p className='text-[10px] text-gray-500'>Total Leads</p>
                  </div>
                </div>
              </div>
              <div className='mt-3 space-y-1.5'>
                {stats.leadsBySource.slice(0, 5).map((d, i) => (
                  <div key={d.name} className='flex items-center justify-between text-xs'>
                    <span className='flex items-center gap-2 truncate'>
                      <span className='w-2 h-2 rounded-full shrink-0' style={{ background: CHART_COLORS[i % CHART_COLORS.length] }} />
                      {d.name}
                    </span>
                    <span className='font-semibold text-gray-700'>{leads.length ? Math.round((d.value / leads.length) * 100) : 0}%</span>
                  </div>
                ))}
              </div>
            </>
          ) : (
            <p className='text-sm text-gray-500 text-center py-12'>No lead data yet</p>
          )}
        </Panel>
      </div>

      <div className='grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6'>
        <Panel title='Recent Activities'>
          <div className='space-y-4 max-h-80 overflow-y-auto'>
            {stats.activities.length ? stats.activities.map((a, i) => (
              <button key={`${a.type}-${i}`} type='button' onClick={() => navigate(a.path)} className='w-full flex gap-3 text-left hover:bg-gray-50 rounded-lg p-2 -mx-2'>
                <span className='text-lg shrink-0'>{a.icon}</span>
                <div className='min-w-0 flex-1'>
                  <p className='text-sm font-medium text-gray-900'>{a.title}</p>
                  <p className='text-xs text-gray-400 mt-0.5'>{timeAgo(a.date)}</p>
                </div>
              </button>
            )) : (
              <p className='text-sm text-gray-500 text-center py-6'>No recent activity</p>
            )}
          </div>
        </Panel>

        <Panel title='Top Performing Employees' actionLabel='View All' onAction={() => navigate('/employees')}>
          <div className='space-y-3'>
            {stats.topEmployees.length ? stats.topEmployees.map((e, i) => (
              <div key={e.name + i} className='flex items-center gap-3'>
                <span className='w-6 text-xs font-bold text-gray-400'>{i + 1}</span>
                <div className='w-9 h-9 rounded-full bg-blue-100 text-blue-700 flex items-center justify-center text-xs font-bold shrink-0'>
                  {e.name.charAt(0)}
                </div>
                <div className='min-w-0 flex-1'>
                  <p className='text-sm font-semibold text-gray-900 truncate'>{e.name}</p>
                  <p className='text-xs text-gray-500 truncate'>{e.designation}</p>
                </div>
                <div className='text-right shrink-0'>
                  <p className='text-xs font-bold text-gray-900'>{formatCompactINR(e.value)}</p>
                  <p className='text-[10px] text-green-600'>{e.count} leads</p>
                </div>
              </div>
            )) : (
              <p className='text-sm text-gray-500 text-center py-6'>No performance data yet</p>
            )}
          </div>
        </Panel>

        <Panel title='Tasks Overview' actionLabel='View All' onAction={() => navigate('/tasks')}>
          {stats.taskChart.length ? (
            <>
              <div className='h-40 relative'>
                <ResponsiveContainer width='100%' height='100%'>
                  <PieChart>
                    <Pie data={stats.taskChart} dataKey='value' cx='50%' cy='50%' innerRadius={45} outerRadius={65} paddingAngle={2}>
                      {stats.taskChart.map((d) => <Cell key={d.name} fill={d.color} />)}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
                <div className='absolute inset-0 flex items-center justify-center pointer-events-none'>
                  <div className='text-center'>
                    <p className='text-xl font-bold text-gray-900'>{tasks.length}</p>
                    <p className='text-[10px] text-gray-500'>Total Tasks</p>
                  </div>
                </div>
              </div>
              <div className='mt-3 space-y-1.5'>
                {stats.taskChart.map((d) => (
                  <div key={d.name} className='flex items-center justify-between text-xs'>
                    <span className='flex items-center gap-2'>
                      <span className='w-2 h-2 rounded-full' style={{ background: d.color }} />
                      {d.name}
                    </span>
                    <span className='font-semibold'>{d.value} ({tasks.length ? Math.round((d.value / tasks.length) * 100) : 0}%)</span>
                  </div>
                ))}
              </div>
            </>
          ) : (
            <p className='text-sm text-gray-500 text-center py-12'>No tasks yet</p>
          )}
        </Panel>
      </div>

      <div className='grid grid-cols-2 md:grid-cols-3 xl:grid-cols-5 gap-4'>
        <MiniStat title='Total Projects' value={projects.length} change={growthPct(projects.filter((p) => isThisMonth(p.createdAt)).length, projects.filter((p) => isLastMonth(p.createdAt)).length)} icon='📁' iconBg='bg-purple-50' onClick={() => navigate('/projects')} />
        <MiniStat title='Active Projects' value={stats.activeProjects} change={8.4} icon='🚀' iconBg='bg-green-50' onClick={() => navigate('/projects')} />
        <MiniStat title='Total Clients' value={clients.length} change={growthPct(clients.filter((c) => isThisMonth(c.createdAt)).length, clients.filter((c) => isLastMonth(c.createdAt)).length)} icon='🏢' iconBg='bg-indigo-50' onClick={() => navigate('/clients')} />
        <MiniStat title='Pending Leave' value={stats.openTickets} change={-5.6} icon='🎫' iconBg='bg-orange-50' onClick={() => navigate('/leave')} />
        <MiniStat title='Pending Invoices' value={stats.pendingInvoices} change={7.3} icon='📄' iconBg='bg-blue-50' onClick={() => navigate('/billings')} />
      </div>
    </div>
  )
}

export default AdminDashboardView
