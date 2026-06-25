import React, { useEffect, useMemo, useState } from 'react'
import api from '../../api/axios'
import { BookIcon, ProjectsIcon, UsersIcon } from '../../components/Icons'
import { useAuth } from '../../context/AuthContext'
import { useNavigate, useLocation } from 'react-router-dom'
import HRDashboardView from './HRDashboardView'
import EmployeeDashboardView from './EmployeeDashboardView'
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts'

const StatCard = ({ title, value, icon, color, iconColor, onClick }) => {
  return (
    <div
      className={`bg-white rounded-lg shadow-md p-6 border-l-4 ${color} ${onClick ? 'cursor-pointer hover:shadow-lg transition-shadow' : ''}`}
      onClick={onClick}
    >
      <div className='flex items-start justify-between'>
        <div>
          <p className='text-gray-600 text-sm font-medium'>{title}</p>
          <h3 className='text-3xl font-bold text-gray-900 mt-2'>{value}</h3>
        </div>
        <div className={`text-3xl ${iconColor} opacity-20`}>
          {icon}
        </div>
      </div>
    </div>
  )
}

const ChartCard = ({ title, children }) => {
  return (
    <div className='bg-white rounded-lg shadow-md p-6'>
      <h2 className='text-lg font-bold text-gray-900 mb-4'>{title}</h2>
      {children}
    </div>
  )
}

const MONTH_NAMES = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

/** Max rows in Recent Activity (newest first across projects, clients, employees). */
const RECENT_ACTIVITY_LIMIT = 10

/** Minimum Y-axis scale for Projects by Month chart (actual data can extend higher). */
const CHART_MIN_PROJECT_AXIS = 11
/** Minimum Y-axis top for budget: ₹5 lakhs (5,00,000). */
const CHART_MIN_BUDGET_AXIS = 5_00_000
/** Budget axis tick step: ₹50,000. */
const BUDGET_TICK_STEP = 50_000

const formatBudgetAxisTick = (v) => {
  const n = Number(v)
  if (!Number.isFinite(n) || n === 0) return '₹0'
  if (n < 100000 && n % BUDGET_TICK_STEP === 0) return `₹${n / 1000}k`
  const lakhs = n / 100000
  if (Number.isInteger(lakhs)) return `₹${lakhs}L`
  return `₹${lakhs.toFixed(1)}L`
}

const buildBudgetAxisTicks = (maxAmount) => {
  const cap = Math.max(CHART_MIN_BUDGET_AXIS, Number(maxAmount) || 0)
  const top = Math.ceil(cap / BUDGET_TICK_STEP) * BUDGET_TICK_STEP
  const ticks = []
  for (let v = 0; v <= top; v += BUDGET_TICK_STEP) ticks.push(v)
  return { chartMaxBudget: top, budgetAxisTicks: ticks }
}

const DashboardView = () => {
  const { hasFullAccess, isHRManager } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const isAdminRoute = location.pathname.includes('admin-dashboard')
  const showCrmAdminDashboard = hasFullAccess() && isAdminRoute && !isHRManager()
  const [clients, setClients] = useState([])

  const [projects, setProjects] = useState([])
  const [employees, setEmployees] = useState([])
  const [leads, setLeads] = useState([])
  const [collaborators, setCollaborators] = useState([])
  const [adminTasks, setAdminTasks] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [chartData, setChartData] = useState([])
  const [chartLoading, setChartLoading] = useState(true)
  const [filterYear, setFilterYear] = useState(new Date().getFullYear())
  const [filterDepartment, setFilterDepartment] = useState('All')

  const yearOptions = Array.from({ length: 6 }, (_, i) => new Date().getFullYear() - 2 + i)

  useEffect(() => {
    if (!showCrmAdminDashboard) return
    const fetchChartData = async () => {
      try {
        setChartLoading(true)
        const res = await api.get(`/projects/stats/by-month?year=${filterYear}&department=${filterDepartment}`)
        setChartData(Array.isArray(res.data) ? res.data : [])
        // eslint-disable-next-line no-unused-vars
      } catch (err) {
        setChartData(Array.from({ length: 12 }, (_, i) => ({ month: MONTH_NAMES[i], monthNum: i + 1, projectCount: 0, totalAmount: 0 })))
      } finally {
        setChartLoading(false)
      }
    }
    fetchChartData()
  }, [filterYear, filterDepartment, showCrmAdminDashboard])

  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true)
        if (showCrmAdminDashboard) {
          const [clientsRes, projectsRes, employeesRes, tasksRes, leadsRes, collabRes] = await Promise.all([
            api.get('/clients'),
            api.get('/projects'),
            api.get('/employees'),
            api.get('/tasks').catch(() => ({ data: [] })),
            api.get('/leads').catch(() => ({ data: [] })),
            api.get('/collaborators').catch(() => ({ data: [] })),
          ])
          const clientsList = Array.isArray(clientsRes.data) ? clientsRes.data : clientsRes.data?.data || []
          const projectsList = Array.isArray(projectsRes.data) ? projectsRes.data : projectsRes.data?.data || []
          const employeesList = Array.isArray(employeesRes.data) ? employeesRes.data : employeesRes.data?.data || []
          const tasksList = Array.isArray(tasksRes.data) ? tasksRes.data : []
          const leadsList = Array.isArray(leadsRes.data) ? leadsRes.data : leadsRes.data?.data || []
          const collabList = Array.isArray(collabRes.data) ? collabRes.data : collabRes.data?.data || []
          setClients(Array.isArray(clientsList) ? clientsList : [])
          setProjects(Array.isArray(projectsList) ? projectsList : [])
          setEmployees(Array.isArray(employeesList) ? employeesList : [])
          setAdminTasks(tasksList)
          setLeads(Array.isArray(leadsList) ? leadsList : [])
          setCollaborators(Array.isArray(collabList) ? collabList : [])
        }
      } catch (err) {
        setError(err.message || 'Error loading dashboard data')
      } finally {
        setLoading(false)
      }
    }
    fetchData()
  }, [showCrmAdminDashboard])

  const recentActivity = useMemo(() => {
    const clientById = new Map(clients.map((c) => [String(c._id), c]))

    const projectItems = projects.map((p) => {
      let clientDoc =
        p.client && typeof p.client === 'object' && p.client.clientName != null ? p.client : null
      if (!clientDoc && p.client) clientDoc = clientById.get(String(p.client)) || null

      const mgr =
        p.projectManager && typeof p.projectManager === 'object' ? p.projectManager.name : null

      const budgetNum = Number(p.budget)
      const detailLines = [
        clientDoc?.clientName && `Client: ${clientDoc.clientName}`,
        p.department && `Department: ${p.department}`,
        p.status && `Status: ${p.status}`,
        mgr && `Project manager: ${mgr}`,
        p.budget != null && p.budget !== '' && Number.isFinite(budgetNum) && `Budget: ₹${budgetNum.toLocaleString('en-IN')}`,
      ].filter(Boolean)

      return {
        type: 'Project',
        name: p.projectName,
        date: p.createdAt || p.startDate,
        id: p._id,
        detailLines,
      }
    })

    const clientItems = clients.map((c) => {
      const ob = c.onboardBy && typeof c.onboardBy === 'object' ? c.onboardBy.name : null
      const loc = [c.city, c.state].filter(Boolean).join(', ')
      const detailLines = [
        c.mailId && `Email: ${c.mailId}`,
        c.clientNumber && `Contact: ${c.clientNumber}`,
        c.businessType && `Business: ${c.businessType}`,
        ob && `Onboarded by: ${ob}`,
        loc && `Location: ${loc}`,
        c.status && `Status: ${c.status}`,
      ].filter(Boolean)

      return {
        type: 'Client',
        name: c.clientName,
        date: c.createdAt || c.date,
        id: c._id,
        detailLines,
      }
    })

    const employeeItems = employees.map((e) => {
      const des =
        e.designation && typeof e.designation === 'object'
          ? e.designation.title || e.designation.name
          : null
      const detailLines = [
        e.email && `Email: ${e.email}`,
        e.department && `Department: ${e.department}`,
        des && `Designation: ${des}`,
        e.status && `Status: ${e.status}`,
        e.workingHours && `Working hours: ${e.workingHours}`,
      ].filter(Boolean)

      return {
        type: 'Employee',
        name: e.name,
        date: e.createdAt || e.dateOfJoining,
        id: e._id,
        detailLines,
      }
    })

    return [...projectItems, ...clientItems, ...employeeItems]
      .filter((a) => a.date)
      .sort((a, b) => new Date(b.date) - new Date(a.date))
      .slice(0, RECENT_ACTIVITY_LIMIT)
  }, [projects, clients, employees])

  const todayStr = (() => {
    const n = new Date()
    const y = n.getFullYear()
    const m = String(n.getMonth() + 1).padStart(2, '0')
    const day = String(n.getDate()).padStart(2, '0')
    return `${y}-${m}-${day}`
  })()
  const adminTodayStart = new Date(); adminTodayStart.setHours(0, 0, 0, 0)
  const adminTodayEnd = new Date(adminTodayStart); adminTodayEnd.setDate(adminTodayEnd.getDate() + 1)
  const adminTodayTasks = adminTasks.filter((t) => {
    if (!t?.dueDate) return false
    const d = new Date(t.dueDate)
    return d >= adminTodayStart && d < adminTodayEnd
  })
  const adminInProgress = adminTasks.filter((t) => t.status === 'In Progress')
  const adminCompleted = adminTasks.filter((t) => t.status === 'Completed')
  const adminPending = adminTasks.filter((t) => t.status === 'Pending')
  const adminDelayed = adminTasks.filter((t) => {
    if (!t?.dueDate) return false
    return new Date(t.dueDate) < new Date() && !['Completed', 'Cancelled'].includes(t.status)
  })

  const chartMaxProjectCount = Math.max(
    CHART_MIN_PROJECT_AXIS,
    ...chartData.map((d) => Number(d.projectCount) || 0)
  )
  const rawMaxBudget = Math.max(
    CHART_MIN_BUDGET_AXIS,
    ...chartData.map((d) => Number(d.totalAmount) || 0)
  )
  const { chartMaxBudget, budgetAxisTicks } = buildBudgetAxisTicks(rawMaxBudget)
  /** Integer ticks 0…max so the axis steps by 1 (Recharts default “nice” ticks often use steps of 2–3). */
  const projectCountAxisTicks = Array.from(
    { length: chartMaxProjectCount + 1 },
    (_, i) => i
  )

  if (isAdminRoute && isHRManager()) {
    return <HRDashboardView />
  }

  if (!showCrmAdminDashboard) {
    return <EmployeeDashboardView />
  }

  return (
    <div className='p-8'>
      {/* Header */}
      <div className='mb-8'>
        <h1 className='text-3xl font-bold text-gray-900'>Dashboard</h1>
        <p className='text-gray-600 mt-2'>Welcome back! Here&apos;s your CRM overview.</p>
      </div>

      {loading ? (
        <p className='text-sm text-gray-600'>Loading...</p>
      ) : error ? (
        <p className='text-red-600 text-sm'>{error}</p>
      ) : (
        showCrmAdminDashboard && (
        <>
          {/* Today's Task Stats */}
          <div className='grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4 mb-6'>
            <StatCard
              title="Today's Tasks"
              value={adminTodayTasks.length}
              icon={<ProjectsIcon />}
              color='border-blue-500 bg-gradient-to-br from-blue-50 to-blue-100'
              iconColor='text-blue-500'
              onClick={() => navigate(`/tasks?date=${todayStr}&status=All`)}
            />
            <StatCard
              title='In Progress'
              value={adminInProgress.length}
              icon={<ProjectsIcon />}
              color='border-indigo-500 bg-gradient-to-br from-indigo-50 to-indigo-100'
              iconColor='text-indigo-500'
              onClick={() => navigate(`/tasks?date=&status=In Progress`)}
            />
            <StatCard
              title='Completed'
              value={adminCompleted.length}
              icon={<ProjectsIcon />}
              color='border-green-500 bg-gradient-to-br from-green-50 to-green-100'
              iconColor='text-green-500'
              onClick={() => navigate(`/tasks?date=&status=Completed`)}
            />
            <StatCard
              title='Pending'
              value={adminPending.length}
              icon={<ProjectsIcon />}
              color='border-amber-500 bg-gradient-to-br from-amber-50 to-amber-100'
              iconColor='text-amber-500'
              onClick={() => navigate(`/tasks?date=&status=Pending`)}
            />
            <StatCard
              title='Delayed'
              value={adminDelayed.length}
              icon={<ProjectsIcon />}
              color='border-red-500 bg-gradient-to-br from-red-50 to-red-100'
              iconColor='text-red-500'
              onClick={() => navigate(`/tasks?date=&status=Delayed`)}
            />
          </div>

          {/* Stats Grid */}
          <div className='grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-6 mb-8'>
            <StatCard
              title='Total Clients'
              value={clients.length}
              icon={<BookIcon />}
              color='border-blue-500 bg-gradient-to-br from-blue-50 to-blue-100'
              iconColor='text-blue-500'
              onClick={() => navigate('/clients')}
            />
            <StatCard
              title='Total Projects'
              value={projects.length}
              icon={<ProjectsIcon />}
              color='border-purple-500 bg-gradient-to-br from-purple-50 to-purple-100'
              iconColor='text-purple-500'
              onClick={() => navigate('/projects')}
            />
            <StatCard
              title='Total Employees'
              value={employees.length}
              icon={<UsersIcon />}
              color='border-green-500 bg-gradient-to-br from-green-50 to-green-100'
              iconColor='text-green-500'
              onClick={() => navigate('/employees')}
            />
            <StatCard
              title='Total Leads'
              value={leads.length}
              icon={<BookIcon />}
              color='border-cyan-500 bg-gradient-to-br from-cyan-50 to-cyan-100'
              iconColor='text-cyan-500'
              onClick={() => navigate('/leads')}
            />
            <StatCard
              title='Total Collaborators'
              value={collaborators.length}
              icon={<UsersIcon />}
              color='border-amber-500 bg-gradient-to-br from-amber-50 to-amber-100'
              iconColor='text-amber-500'
              onClick={() => navigate('/collaborators')}
            />
          </div>

          {/* Projects by Month */}
          <div className='mb-8'>
            <ChartCard title='Projects by Month'>
              <div className='mb-4 flex flex-wrap gap-4 items-center'>
                <div className='flex items-center gap-2'>
                  <label className='text-sm font-medium text-gray-700'>Year</label>
                  <select
                    value={filterYear}
                    onChange={(e) => setFilterYear(Number(e.target.value))}
                    className='border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
                  >
                    {yearOptions.map((y) => (
                      <option key={y} value={y}>{y}</option>
                    ))}
                  </select>
                </div>
                <div className='flex items-center gap-2'>
                  <label className='text-sm font-medium text-gray-700'>Department</label>
                  <select
                    value={filterDepartment}
                    onChange={(e) => setFilterDepartment(e.target.value)}
                    className='border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
                  >
                    <option value='All'>All</option>
                    <option value='IT'>IT</option>
                    <option value='Marketing'>Marketing</option>
                  </select>
                </div>
              </div>
              {chartLoading ? (
                <p className='text-sm text-gray-500 py-8'>Loading chart...</p>
              ) : (
                <div className='h-80'>
                  <ResponsiveContainer width='100%' height='100%'>
                    <LineChart data={chartData} margin={{ top: 20, right: 60, left: 20, bottom: 5 }}>
                      <CartesianGrid strokeDasharray='3 3' stroke='#e5e7eb' />
                      <XAxis dataKey='month' tick={{ fontSize: 12 }} interval={0} />
                      <YAxis
                        yAxisId='left'
                        orientation='left'
                        domain={[0, chartMaxProjectCount]}
                        allowDecimals={false}
                        ticks={projectCountAxisTicks}
                        interval={0}
                        tick={{ fontSize: 12 }}
                        label={{ value: 'Projects', angle: -90, position: 'insideLeft' }}
                      />
                      <YAxis
                        yAxisId='right'
                        orientation='right'
                        domain={[0, chartMaxBudget]}
                        ticks={budgetAxisTicks}
                        interval={0}
                        tick={{ fontSize: 12 }}
                        tickFormatter={formatBudgetAxisTick}
                        label={{ value: 'Total Project Budget (₹)', angle: 90, position: 'insideRight' }}
                      />
                      <Tooltip
                        formatter={(value, name) => {
                          const isProjects = name === 'Projects' || name === 'projectCount'
                          return [isProjects ? value : `₹${Number(value).toLocaleString('en-IN')}`, isProjects ? 'Projects' : 'Total Project Budget']
                        }}
                        labelFormatter={(label) => `Month: ${label}`}
                      />
                      <Legend />
                      <Line
                        yAxisId='left'
                        type='monotone'
                        dataKey='projectCount'
                        name='Projects'
                        stroke='#8b5cf6'
                        strokeWidth={2}
                        dot={{ r: 4, fill: '#8b5cf6' }}
                        activeDot={{ r: 6 }}
                      />
                      <Line
                        yAxisId='right'
                        type='monotone'
                        dataKey='totalAmount'
                        name='Total Project Budget'
                        stroke='#06b6d4'
                        strokeWidth={2}
                        dot={{ r: 4, fill: '#06b6d4' }}
                        activeDot={{ r: 6 }}
                      />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              )}
            </ChartCard>
          </div>

          {/* Recent Activity — same card + table structure as list views */}
          <section aria-labelledby='dashboard-recent-activity' className='grid grid-cols-1 gap-6'>
            <div className='bg-white rounded-lg shadow-md border border-gray-100 overflow-hidden'>
              <header className='px-6 py-4 shadow-2xl  text-black border-blue-600'>
                <h2 id='dashboard-recent-activity' className='text-lg font-bold '>
                  Recent Activity
                </h2>
                <p className='text-sm text-black mt-1'>
                  {RECENT_ACTIVITY_LIMIT} most recent entries (projects, clients, employees). Click a row to open that record on its page.
                </p>
              </header>
              <div className='overflow-x-auto'>
                <table className='w-full table-fixed text-sm min-w-[720px] border-collapse'>
                  <colgroup>
                    <col className='w-[12%]' />
                    <col className='w-[22%]' />
                    <col className='w-[50%]' />
                    <col className='w-[16%]' />
                  </colgroup>
                  <thead className='text-left border-b bg-blue-600 text-white font-bold text-sm'>
                    <tr>
                      <th scope='col' className='px-4 py-3 text-center border-b border-blue-700/30'>
                        Type
                      </th>
                      <th scope='col' className='px-4 py-3 text-left border-b border-blue-700/30'>
                        Name
                      </th>
                      <th scope='col' className='px-4 py-3 text-left border-b border-blue-700/30'>
                        Details
                      </th>
                      <th scope='col' className='px-4 py-3 text-center border-b border-blue-700/30'>
                        Date
                      </th>
                    </tr>
                  </thead>
                  <tbody className='bg-white'>
                    {recentActivity.length === 0 ? (
                      <tr>
                        <td colSpan={4} className='py-10 px-4 text-center text-gray-500 border-b border-gray-100'>
                          No recent activity
                        </td>
                      </tr>
                    ) : (
                      recentActivity.map((item) => (
                        <tr
                          key={`${item.type}-${item.id}`}
                          role='button'
                          tabIndex={0}
                          onClick={() => {
                            const id = item.id
                            if (item.type === 'Project') navigate(`/projects?focus=${id}`)
                            else if (item.type === 'Client') navigate(`/clients?focus=${id}`)
                            else navigate(`/employees?focus=${id}`)
                          }}
                          onKeyDown={(e) => {
                            if (e.key === 'Enter' || e.key === ' ') {
                              e.preventDefault()
                              const id = item.id
                              if (item.type === 'Project') navigate(`/projects?focus=${id}`)
                              else if (item.type === 'Client') navigate(`/clients?focus=${id}`)
                              else navigate(`/employees?focus=${id}`)
                            }
                          }}
                          className='border-b border-gray-100 last:border-b-0 hover:bg-gray-50/80 transition-colors cursor-pointer'
                        >
                          <td className='px-4 py-3 align-top text-center'>
                            <span
                              className={`inline-flex items-center justify-center px-3 py-1 rounded-full text-xs font-semibold whitespace-nowrap ${
                                item.type === 'Project'
                                  ? 'bg-purple-100 text-purple-800'
                                  : item.type === 'Client'
                                    ? 'bg-blue-100 text-blue-800'
                                    : 'bg-green-100 text-green-800'
                              }`}
                            >
                              {item.type}
                            </span>
                          </td>
                          <td className='px-4 py-3 align-top text-left text-gray-900 font-medium'>
                            <span className='line-clamp-2 break-words' title={item.name}>
                              {item.name}
                            </span>
                          </td>
                          <td className='px-4 py-3 align-top text-left'>
                            {item.detailLines?.length ? (
                              <ul className='space-y-0.5 text-xs text-gray-600 leading-snug'>
                                {item.detailLines.map((line, idx) => (
                                  <li key={idx} className='break-words'>
                                    {line}
                                  </li>
                                ))}
                              </ul>
                            ) : (
                              <span className='text-xs text-gray-400'>—</span>
                            )}
                          </td>
                          <td className='px-4 py-3 align-top text-center text-gray-600 whitespace-nowrap'>
                            {new Date(item.date).toLocaleDateString(undefined, {
                              year: 'numeric',
                              month: 'short',
                              day: 'numeric',
                            })}
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </section>
        </>
        )
      )}
    </div>
  )
}

export default DashboardView
