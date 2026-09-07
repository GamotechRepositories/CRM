import React, { useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import api from '../api/axios'
import AdminCompanyShell from '../components/AdminCompanyShell'
import { TENANT_NAMES } from '../config/tenants'

const currentDayValue = () => {
  const now = new Date()
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
}

const currentMonthValue = () => {
  const now = new Date()
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`
}

const normalizeTaskStatus = (status) => {
  if (status == null || status === '') return ''
  const value = String(status).trim()
  if (value === 'InProgress' || value.toLowerCase() === 'in progress') return 'In Progress'
  if (value.toLowerCase() === 'paused' || value.toLowerCase() === 'on hold') return 'Paused'
  return value
}

const getTaskStatusColor = (status) => {
  switch (normalizeTaskStatus(status)) {
    case 'Completed':
      return 'bg-green-100 text-green-800'
    case 'In Progress':
      return 'bg-blue-100 text-blue-800'
    case 'Paused':
      return 'bg-violet-100 text-violet-800'
    case 'Pending':
      return 'bg-amber-100 text-amber-800'
    case 'Cancelled':
      return 'bg-gray-100 text-gray-600'
    default:
      return 'bg-gray-100 text-gray-800'
  }
}

const getPriorityColor = (priority) => {
  switch (priority) {
    case 'Urgent':
      return 'bg-red-100 text-red-800'
    case 'High':
      return 'bg-orange-100 text-orange-800'
    case 'Medium':
      return 'bg-yellow-100 text-yellow-800'
    default:
      return 'bg-green-100 text-green-800'
  }
}

const getTaskRemainingMinutes = (task, nowMs = Date.now()) => {
  const estimated = Number(task?.estimatedDurationMinutes)
  if (!Number.isFinite(estimated) || estimated <= 0) return null
  const status = normalizeTaskStatus(task?.status)
  if ((status === 'In Progress' || status === 'Paused') && task?.startedAt) {
    const startedMs = new Date(task.startedAt).getTime()
    if (!Number.isNaN(startedMs)) {
      const endMs =
        status === 'Paused' && task?.pausedAt
          ? new Date(task.pausedAt).getTime()
          : nowMs
      const refMs = Number.isNaN(endMs) ? nowMs : endMs
      const elapsed = Math.floor((refMs - startedMs) / 60000)
      return Math.max(0, estimated - elapsed)
    }
  }
  return estimated
}

const formatTaskDuration = (minutes) => {
  const mins = Number(minutes)
  if (!Number.isFinite(mins) || mins <= 0) return null
  const h = Math.floor(mins / 60)
  const m = mins % 60
  if (h && m) return `${h}h ${m}m`
  if (h) return `${h}h`
  return `${m}m`
}

const formatShortName = (name) => {
  if (!name || typeof name !== 'string') return '—'
  const parts = name.trim().split(/\s+/).filter(Boolean)
  if (!parts.length) return '—'
  if (parts.length === 1) return parts[0]
  return `${parts[0]} ${parts[parts.length - 1]}`
}

const PersonShortName = ({ name }) => (
  <span className='text-sm text-gray-900 font-medium whitespace-nowrap' title={name || undefined}>
    {formatShortName(name)}
  </span>
)

const TaskStatCard = ({ title, value, subtitle, icon, color, accentClass, onClick }) => (
  <button
    type='button'
    onClick={onClick}
    className={`text-left bg-white rounded-xl border border-gray-200 shadow-sm p-4 hover:shadow-md transition-shadow w-full min-w-0 border-t-[3px] ${accentClass} ${onClick ? 'cursor-pointer' : ''}`}
  >
    <div className='flex items-center justify-between gap-2'>
      <div className='min-w-0 flex-1'>
        <p className='text-sm text-gray-500 font-medium truncate'>{title}</p>
        <div className='flex items-baseline gap-2 mt-1 min-w-0'>
          <span className='text-2xl font-bold text-gray-900 tabular-nums leading-none shrink-0'>{value}</span>
          {subtitle && <span className='text-xs text-gray-500 truncate'>{subtitle}</span>}
        </div>
      </div>
      <div className={`w-10 h-10 rounded-xl flex items-center justify-center text-lg shrink-0 ${color}`}>{icon}</div>
    </div>
  </button>
)

const fmtDateTime = (d) => {
  if (!d) return '—'
  const x = new Date(d)
  return Number.isNaN(x.getTime())
    ? '—'
    : x.toLocaleString(undefined, {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      })
}

const TasksPage = () => {
  const { tenantId } = useParams()
  const navigate = useNavigate()
  const company = TENANT_NAMES[tenantId] || tenantId

  const [tasks, setTasks] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [rangeMode, setRangeMode] = useState('day')
  const [selectedDate, setSelectedDate] = useState(currentDayValue())
  const [selectedMonth, setSelectedMonth] = useState(currentMonthValue())
  const [rangeLabel, setRangeLabel] = useState('')
  const [filterProject, setFilterProject] = useState('')
  const [filterAssignee, setFilterAssignee] = useState('')
  const [filterStatus, setFilterStatus] = useState('All')
  const [employees, setEmployees] = useState([])

  useEffect(() => {
    let cancelled = false
    const loadEmployees = async () => {
      if (!tenantId) return
      try {
        const res = await api.get(`/companies/${tenantId}/employees`)
        const list = Array.isArray(res.data?.employees)
          ? res.data.employees
          : Array.isArray(res.data)
            ? res.data
            : []
        if (!cancelled) setEmployees(list)
      } catch {
        if (!cancelled) setEmployees([])
      }
    }
    loadEmployees()
    return () => {
      cancelled = true
    }
  }, [tenantId])

  useEffect(() => {
    let cancelled = false
    const load = async () => {
      if (!tenantId) return
      try {
        setLoading(true)
        setError('')
        const params =
          rangeMode === 'month'
            ? { range: 'month', month: selectedMonth || currentMonthValue() }
            : { range: 'day', date: selectedDate || currentDayValue() }
        const res = await api.get(`/companies/${tenantId}/modules/tasks`, { params })
        if (cancelled) return
        setTasks(Array.isArray(res.data?.items) ? res.data.items : [])
        setRangeLabel(
          rangeMode === 'month'
            ? res.data?.monthLabel || selectedMonth
            : res.data?.dateLabel || selectedDate
        )
      } catch (err) {
        if (cancelled) return
        setError(err.response?.data?.message || err.message || 'Failed to load tasks')
        setTasks([])
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    load()
    return () => {
      cancelled = true
    }
  }, [tenantId, rangeMode, selectedDate, selectedMonth])

  const isDelayed = (t) => {
    if (!t?.dueDate) return false
    const status = normalizeTaskStatus(t.status)
    return new Date(t.dueDate) < new Date() && status !== 'Completed' && status !== 'Cancelled'
  }

  const tasksForStats = useMemo(() => {
    return tasks.filter((t) => {
      if (filterProject) {
        const projectId = String(t.project?._id || t.project || '')
        if (projectId !== filterProject) return false
      }
      if (filterAssignee) {
        const assigneeId = String(t.assignedTo?._id || t.assignedTo || '')
        if (assigneeId !== filterAssignee) return false
      }
      return true
    })
  }, [tasks, filterProject, filterAssignee])

  const filteredTasks = useMemo(() => {
    return tasksForStats.filter((t) => {
      if (filterStatus === 'Delayed') return isDelayed(t)
      if (filterStatus !== 'All') return normalizeTaskStatus(t.status) === filterStatus
      return true
    })
  }, [tasksForStats, filterStatus])

  const uniqueProjects = useMemo(() => {
    return Array.from(
      new Map(
        tasks
          .filter((t) => t.project)
          .map((t) => {
            const p = t.project
            const id = String(p._id || p)
            return [id, { _id: id, projectName: p.projectName || 'Project' }]
          })
      ).values()
    )
  }, [tasks])

  const totalTasks = tasksForStats.length
  const completedTasks = tasksForStats.filter((t) => normalizeTaskStatus(t.status) === 'Completed').length
  const inProgressTasks = tasksForStats.filter((t) => normalizeTaskStatus(t.status) === 'In Progress').length
  const pendingTasks = tasksForStats.filter((t) => normalizeTaskStatus(t.status) === 'Pending').length
  const overdueTasks = tasksForStats.filter((t) => {
    if (!t.dueDate || normalizeTaskStatus(t.status) === 'Completed') return false
    return new Date(t.dueDate) < new Date(new Date().toDateString())
  }).length
  const urgentTasks = tasksForStats.filter((t) => t.priority === 'Urgent').length
  const completionPct = totalTasks ? Math.round((completedTasks / totalTasks) * 100) : 0

  const hasActiveFilters = filterStatus !== 'All' || filterProject || filterAssignee
  const hiddenByFilters = !loading && filteredTasks.length === 0 && tasksForStats.length > 0

  const clearAllFilters = () => {
    setFilterStatus('All')
    setFilterProject('')
    setFilterAssignee('')
  }

  return (
    <AdminCompanyShell activeNav='tasks'>
      <div className='mb-8 flex justify-between items-center gap-4 flex-wrap'>
        <div>
          <h1 className='text-3xl font-bold text-gray-900'>Tasks</h1>
          <p className='text-base text-gray-600 mt-2'>
            Manage team tasks and deadlines.
            {rangeLabel ? (
              <span className='text-gray-500'>
                {' '}
                · {company} · {rangeLabel} · {filteredTasks.length} task
                {filteredTasks.length === 1 ? '' : 's'} created
              </span>
            ) : null}
          </p>
        </div>
      </div>

      {error && (
        <div className='mb-4 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700'>
          {error}
        </div>
      )}

      <div className='grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6'>
        <TaskStatCard
          title='Total Tasks'
          value={totalTasks}
          subtitle={`${pendingTasks} pending, ${inProgressTasks} in progress`}
          icon='📋'
          color='bg-indigo-50'
          accentClass='border-t-indigo-500'
          onClick={() => setFilterStatus('All')}
        />
        <TaskStatCard
          title='Completed'
          value={completedTasks}
          subtitle={`${completionPct}% completion`}
          icon='✅'
          color='bg-green-50'
          accentClass='border-t-green-500'
          onClick={() => setFilterStatus('Completed')}
        />
        <TaskStatCard
          title='Overdue'
          value={overdueTasks}
          subtitle='Attention needed'
          icon='⏳'
          color='bg-orange-50'
          accentClass='border-t-orange-500'
          onClick={() => setFilterStatus('Delayed')}
        />
        <TaskStatCard
          title='Urgent'
          value={urgentTasks}
          subtitle='High priority'
          icon='🔥'
          color='bg-red-50'
          accentClass='border-t-red-500'
        />
      </div>

      <div className='mb-6 flex flex-wrap items-center gap-4'>
        <div className='flex items-center gap-2'>
          <label className='text-sm font-medium text-gray-700'>View</label>
          <select
            value={rangeMode}
            onChange={(e) => setRangeMode(e.target.value === 'month' ? 'month' : 'day')}
            className='border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500'
          >
            <option value='day'>Day</option>
            <option value='month'>Month</option>
          </select>
        </div>

        {rangeMode === 'day' ? (
          <div className='flex items-center gap-2'>
            <label className='text-sm font-medium text-gray-700'>Date</label>
            <input
              type='date'
              value={selectedDate}
              max={currentDayValue()}
              onChange={(e) => setSelectedDate(e.target.value || currentDayValue())}
              className='border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500'
            />
            {selectedDate !== currentDayValue() && (
              <button
                type='button'
                onClick={() => setSelectedDate(currentDayValue())}
                className='px-3 py-2 text-sm text-gray-600 hover:bg-gray-100 rounded-lg'
              >
                Today
              </button>
            )}
          </div>
        ) : (
          <div className='flex items-center gap-2'>
            <label className='text-sm font-medium text-gray-700'>Month</label>
            <input
              type='month'
              value={selectedMonth}
              onChange={(e) => setSelectedMonth(e.target.value || currentMonthValue())}
              className='border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500'
            />
            {selectedMonth !== currentMonthValue() && (
              <button
                type='button'
                onClick={() => setSelectedMonth(currentMonthValue())}
                className='px-3 py-2 text-sm text-gray-600 hover:bg-gray-100 rounded-lg'
              >
                This month
              </button>
            )}
          </div>
        )}

        <div className='flex items-center gap-2'>
          <label className='text-sm font-medium text-gray-700'>Project</label>
          <select
            value={filterProject}
            onChange={(e) => setFilterProject(e.target.value)}
            className='border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500'
          >
            <option value=''>All Projects</option>
            {uniqueProjects.map((p) => (
              <option key={p._id} value={p._id}>
                {p.projectName}
              </option>
            ))}
          </select>
        </div>

        <div className='flex items-center gap-2'>
          <label className='text-sm font-medium text-gray-700'>Assign to</label>
          <select
            value={filterAssignee}
            onChange={(e) => setFilterAssignee(e.target.value)}
            className='border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 min-w-[160px]'
          >
            <option value=''>All</option>
            {employees.map((emp) => (
              <option key={emp._id} value={emp._id}>
                {emp.name}
              </option>
            ))}
          </select>
        </div>

        <div className='flex items-center gap-2'>
          <label className='text-sm font-medium text-gray-700'>Status</label>
          <select
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value)}
            className='border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500'
          >
            <option value='All'>All status</option>
            <option value='Pending'>Pending</option>
            <option value='In Progress'>In Progress</option>
            <option value='Paused'>Paused</option>
            <option value='Completed'>Completed</option>
            <option value='Cancelled'>Cancelled</option>
            <option value='Delayed'>Delayed</option>
          </select>
        </div>
      </div>

      <div className='bg-white rounded-lg shadow-md overflow-x-auto'>
        <table className='w-full min-w-[1100px]'>
          <thead className='text-left border-b border-blue-700 bg-blue-600 text-white font-bold text-sm'>
            <tr>
              <th className='text-left py-4 px-6 border-b border-blue-700/30'>Task</th>
              <th className='text-left py-4 px-6 border-b border-blue-700/30'>Project</th>
              <th className='text-left py-4 px-6 border-b border-blue-700/30'>Assign to</th>
              <th className='text-left py-4 px-6 border-b border-blue-700/30'>Signed by</th>
              <th className='text-left py-4 px-6 border-b border-blue-700/30'>Assigned (date & time)</th>
              <th className='text-left py-4 px-6 border-b border-blue-700/30'>Updated (date & time)</th>
              <th className='text-left py-4 px-6 border-b border-blue-700/30'>Due Date</th>
              <th className='text-left py-4 px-6 border-b border-blue-700/30'>Priority</th>
              <th className='text-left py-4 px-6 border-b border-blue-700/30'>Status</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={9} className='py-12 text-center text-sm text-gray-500'>
                  Loading...
                </td>
              </tr>
            ) : filteredTasks.length === 0 ? (
              <tr>
                <td colSpan={9} className='py-12 text-center text-sm text-gray-500'>
                  {hiddenByFilters ? (
                    <div className='space-y-3'>
                      <p>No tasks match the current filters.</p>
                      {hasActiveFilters && (
                        <button
                          type='button'
                          onClick={clearAllFilters}
                          className='text-indigo-600 hover:text-indigo-700 font-medium'
                        >
                          Clear all filters
                        </button>
                      )}
                    </div>
                  ) : rangeMode === 'month' ? (
                    `No tasks created in ${rangeLabel || 'this month'}`
                  ) : (
                    `No tasks created on ${rangeLabel || 'this date'}`
                  )}
                </td>
              </tr>
            ) : (
              filteredTasks.map((task) => (
                <tr
                  key={task._id}
                  onClick={() => navigate(`/company/${tenantId}/tasks/${task._id}`)}
                  className='border-b border-gray-100 hover:bg-gray-50 transition-colors cursor-pointer'
                >
                  <td className='py-4 px-6'>
                    <p className='text-sm font-medium text-gray-900'>{task.title}</p>
                    {task.description && (
                      <p className='text-sm text-gray-500 mt-0.5 line-clamp-1'>{task.description}</p>
                    )}
                  </td>
                  <td className='py-4 px-6 text-gray-700 text-sm'>
                    {task.project?.projectName || '—'}
                  </td>
                  <td className='py-4 px-6'>
                    <PersonShortName name={task.assignedTo?.name} />
                  </td>
                  <td className='py-4 px-6'>
                    <PersonShortName name={task.assignedBy?.name} />
                  </td>
                  <td className='py-4 px-6 text-gray-700 text-sm whitespace-nowrap'>
                    {fmtDateTime(task.createdAt)}
                  </td>
                  <td className='py-4 px-6 text-gray-700 text-sm whitespace-nowrap'>
                    {fmtDateTime(task.updatedAt)}
                  </td>
                  <td className='py-4 px-6 text-gray-700 text-sm'>
                    {task.dueDate ? new Date(task.dueDate).toLocaleDateString() : '—'}
                  </td>
                  <td className='py-4 px-6'>
                    <span className={`px-3 py-1 rounded-full text-xs font-semibold ${getPriorityColor(task.priority)}`}>
                      {task.priority || '—'}
                    </span>
                  </td>
                  <td className='py-4 px-6'>
                    <div className='flex flex-col gap-0.5'>
                      <span
                        className={`inline-flex w-fit px-3 py-1 rounded-full text-xs font-semibold ${getTaskStatusColor(task.status)}`}
                      >
                        {normalizeTaskStatus(task.status) || task.status || '—'}
                      </span>
                      {(normalizeTaskStatus(task.status) === 'In Progress' ||
                        normalizeTaskStatus(task.status) === 'Paused') &&
                        getTaskRemainingMinutes(task) != null && (
                          <span className='text-xs text-blue-700'>
                            {formatTaskDuration(getTaskRemainingMinutes(task))} left
                          </span>
                        )}
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </AdminCompanyShell>
  )
}

export default TasksPage
