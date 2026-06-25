import React, { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../../api/axios'
import { useAuth } from '../../context/AuthContext'

const KpiCard = ({ title, value, subtitle, icon, color, onClick }) => (
  <button
    type='button'
    onClick={onClick}
    className={`text-left bg-white rounded-xl border border-gray-200 shadow-sm p-5 hover:shadow-md transition-shadow w-full ${onClick ? 'cursor-pointer' : ''}`}
  >
    <div className='flex items-start justify-between gap-3'>
      <div>
        <p className='text-sm text-gray-500 font-medium'>{title}</p>
        <p className='text-3xl font-bold text-gray-900 mt-1'>{value}</p>
        {subtitle && <p className='text-xs text-gray-500 mt-1'>{subtitle}</p>}
      </div>
      <div className={`w-11 h-11 rounded-xl flex items-center justify-center text-xl ${color}`}>{icon}</div>
    </div>
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

const priorityClass = (priority) => {
  const p = (priority || 'Medium').toLowerCase()
  if (p === 'high' || p === 'urgent') return 'bg-red-100 text-red-700'
  if (p === 'low') return 'bg-green-100 text-green-700'
  return 'bg-orange-100 text-orange-700'
}

const leadStatusClass = (status) => {
  if (status === 'Interested') return 'bg-orange-100 text-orange-700'
  if (status === 'Meeting Schedule') return 'bg-blue-100 text-blue-700'
  if (status === 'Call not Received') return 'bg-green-100 text-green-700'
  if (status === 'Not Interested') return 'bg-gray-100 text-gray-600'
  return 'bg-purple-100 text-purple-700'
}

const leadStatusLabel = (status) => {
  if (status === 'Call not Received') return 'New'
  if (status === 'Call You After Sometime') return 'Follow-up'
  if (status === 'Meeting Schedule') return 'Meeting'
  return status || 'Lead'
}

const formatDate = (d) => {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })
}

const formatTime = (d) => {
  if (!d) return '—'
  return new Date(d).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })
}

const getWeekRangeLabel = (date = new Date()) => {
  const start = new Date(date)
  const day = start.getDay()
  const diff = day === 0 ? -6 : 1 - day
  start.setDate(start.getDate() + diff)
  const end = new Date(start)
  end.setDate(start.getDate() + 6)
  const fmt = (d) => d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })
  return `${fmt(start)} – ${fmt(end)}`
}

const isSameDay = (a, b) => {
  const d1 = new Date(a)
  const d2 = new Date(b)
  return d1.getFullYear() === d2.getFullYear() && d1.getMonth() === d2.getMonth() && d1.getDate() === d2.getDate()
}

const isThisMonth = (d, ref = new Date()) => {
  if (!d) return false
  const dt = new Date(d)
  return dt.getMonth() === ref.getMonth() && dt.getFullYear() === ref.getFullYear()
}

const getProjectName = (task) => {
  if (!task?.project) return 'General'
  if (typeof task.project === 'object') return task.project.projectName || task.project.name || 'Project'
  return 'Project'
}

const formatINR = (amount) => `₹ ${Math.round(amount).toLocaleString('en-IN')}`

const PIPELINE_STAGE_CONFIG = [
  { label: 'Leads', fill: '#3b82f6', avgValue: 52000, clip: 'polygon(0% 0%, 100% 0%, 88% 100%, 12% 100%)' },
  { label: 'Qualified', fill: '#8b5cf6', avgValue: 65000, clip: 'polygon(12% 0%, 88% 0%, 78% 100%, 22% 100%)' },
  { label: 'Proposal', fill: '#14b8a6', avgValue: 60000, clip: 'polygon(22% 0%, 78% 0%, 68% 100%, 32% 100%)' },
  { label: 'Negotiation', fill: '#f59e0b', avgValue: 52500, clip: 'polygon(32% 0%, 68% 0%, 58% 100%, 42% 100%)' },
  { label: 'Closed Won', fill: '#10b981', avgValue: 60000, clip: 'polygon(42% 0%, 58% 0%, 52% 100%, 48% 100%)' },
]

const buildPipelineStages = (leads) => {
  const counts = [
    leads.length,
    leads.filter((l) => l.status === 'Interested').length,
    leads.filter((l) => l.status === 'Meeting Schedule').length,
    leads.filter((l) => l.status === 'Call You After Sometime').length,
    leads.filter((l) => l.meetingInfoSent === true).length,
  ]

  const stages = PIPELINE_STAGE_CONFIG.map((cfg, i) => ({
    ...cfg,
    count: counts[i],
    value: counts[i] * cfg.avgValue,
  }))

  const totalValue = stages.reduce((sum, s) => sum + s.value, 0)
  const topCount = Math.max(1, stages[0].count)
  const conversionPct = stages[0].count ? Math.round((stages[stages.length - 1].count / stages[0].count) * 100) : 0

  return { stages, totalValue, conversionPct, topCount }
}

const SalesPipelineFunnel = ({ stages, totalValue, onViewPipeline }) => (
  <div className='bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden h-full'>
    <div className='flex items-center justify-between px-5 py-4 border-b border-gray-100'>
      <h3 className='text-sm font-semibold text-gray-900'>My Sales Pipeline</h3>
      <button type='button' onClick={onViewPipeline} className='text-xs font-medium text-blue-600 hover:text-blue-700'>
        View Pipeline
      </button>
    </div>

    <div className='p-5'>
      <div className='space-y-0'>
        {stages.map((stage, index) => (
          <div key={stage.label} className='grid grid-cols-[1fr_auto] gap-3 items-center' style={{ marginTop: index === 0 ? 0 : -2 }}>
            <div className='flex justify-center px-2'>
              <div
                className='w-full max-w-[200px] h-11 flex items-center justify-center transition-transform hover:scale-[1.02]'
                style={{
                  clipPath: stage.clip,
                  backgroundColor: stage.fill,
                  filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.12))',
                }}
              >
                <span className='text-white text-lg font-bold tabular-nums'>
                  {String(stage.count).padStart(2, '0')}
                </span>
              </div>
            </div>
            <div className='w-28 pr-1 text-right'>
              <p className='text-sm font-semibold text-gray-900'>{stage.label}</p>
              <p className='text-xs text-gray-500 tabular-nums mt-0.5'>{formatINR(stage.value)}</p>
            </div>
          </div>
        ))}
      </div>

      <div className='mt-5 rounded-xl bg-gradient-to-r from-gray-50 to-gray-100/80 border border-gray-100 px-4 py-3.5 flex items-center justify-between gap-3'>
        <span className='text-xs font-medium text-gray-600'>Total Pipeline Value</span>
        <span className='text-base font-bold text-gray-900 tabular-nums'>{formatINR(totalValue)}</span>
      </div>

      {stages[0].count > 0 && (
        <p className='text-[11px] text-gray-400 text-center mt-3'>
          {stages[stages.length - 1].count} closed from {stages[0].count} leads
          {' · '}
          {Math.round((stages[stages.length - 1].count / stages[0].count) * 100)}% win rate
        </p>
      )}
    </div>
  </div>
)

const PerformanceRing = ({ percent }) => {
  const p = Math.min(100, Math.max(0, percent))
  const r = 52
  const c = 2 * Math.PI * r
  const offset = c - (p / 100) * c
  return (
    <div className='relative w-36 h-36 mx-auto'>
      <svg className='w-full h-full -rotate-90' viewBox='0 0 120 120'>
        <circle cx='60' cy='60' r={r} fill='none' stroke='#e5e7eb' strokeWidth='10' />
        <circle
          cx='60'
          cy='60'
          r={r}
          fill='none'
          stroke='#10b981'
          strokeWidth='10'
          strokeLinecap='round'
          strokeDasharray={c}
          strokeDashoffset={offset}
        />
      </svg>
      <div className='absolute inset-0 flex flex-col items-center justify-center'>
        <span className='text-2xl font-bold text-gray-900'>{Math.round(p)}%</span>
        <span className='text-xs text-gray-500'>Target Achieved</span>
      </div>
    </div>
  )
}

const EmployeeDashboardView = () => {
  const { user } = useAuth()
  const navigate = useNavigate()
  const [loading, setLoading] = useState(true)
  const [tasks, setTasks] = useState([])
  const [myLeads, setMyLeads] = useState([])
  const [taskTab, setTaskTab] = useState('pending')
  const now = new Date()
  const firstName = (user?.name || 'there').split(' ')[0]
  const designation = user?.designation?.title || user?.designation?.name || 'Employee'

  useEffect(() => {
    const load = async () => {
      if (!user?._id) return
      try {
        setLoading(true)
        const [tasksRes, leadsRes] = await Promise.all([
          api.get('/tasks', { params: { employeeId: user._id } }),
          api.get('/leads').catch(() => ({ data: [] })),
        ])
        setTasks(Array.isArray(tasksRes.data) ? tasksRes.data : [])
        const allLeads = Array.isArray(leadsRes.data) ? leadsRes.data : []
        const related = allLeads.filter((l) => {
          const generatedById = l.generatedBy?._id || l.generatedBy
          const meetingPerson = (l.meetingPersonName || '').toLowerCase()
          const userName = (user?.name || '').toLowerCase()
          return String(generatedById) === String(user._id) || (meetingPerson && meetingPerson === userName)
        })
        setMyLeads(related)
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [user?._id, user?.name])

  const stats = useMemo(() => {
    const pendingTasks = tasks.filter((t) => ['Pending', 'In Progress'].includes(t.status))
    const completedTasks = tasks.filter((t) => t.status === 'Completed')
    const completedThisMonth = completedTasks.filter((t) => isThisMonth(t.completedAt || t.updatedAt, now))
    const openDeals = myLeads.filter((l) => ['Interested', 'Meeting Schedule', 'Call You After Sometime'].includes(l.status))
    const meetingsToday = myLeads.filter(
      (l) => l.status === 'Meeting Schedule' && l.meetingTime && isSameDay(l.meetingTime, now)
    )

    const pipelineData = buildPipelineStages(myLeads)

    const todaySchedule = [
      ...meetingsToday.map((m) => ({
        id: m._id,
        time: m.meetingTime,
        title: m.businessName || m.name,
        subtitle: `${m.meetingType || 'Meeting'} · ${m.meetingPersonName || 'Client'}`,
        duration: '60 min',
        color: 'bg-blue-500',
        path: `/leads/view/${m._id}`,
      })),
      ...tasks
        .filter((t) => t.dueDate && isSameDay(t.dueDate, now) && t.status !== 'Completed')
        .map((t) => ({
          id: t._id,
          time: t.dueDate,
          title: t.title,
          subtitle: getProjectName(t),
          duration: 'Task',
          color: 'bg-purple-500',
          path: `/my-tasks/${t._id}`,
        })),
    ].sort((a, b) => new Date(a.time) - new Date(b.time))

    const recentLeads = [...myLeads]
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
      .slice(0, 5)

    const monthlyTarget = pendingTasks.length + completedThisMonth.length
    const performancePct = monthlyTarget ? (completedThisMonth.length / monthlyTarget) * 100 : 0

    const tabTasks = taskTab === 'pending'
      ? pendingTasks.sort((a, b) => new Date(a.dueDate || 0) - new Date(b.dueDate || 0))
      : completedTasks.sort((a, b) => new Date(b.completedAt || b.updatedAt) - new Date(a.completedAt || a.updatedAt))

    return {
      pendingTasks,
      completedTasks,
      completedThisMonth,
      openDeals,
      meetingsToday,
      pipelineData,
      todaySchedule,
      recentLeads,
      performancePct,
      tabTasks,
      followUps: myLeads.reduce((sum, l) => sum + (Array.isArray(l.followUps) ? l.followUps.length : 0), 0),
      dealsClosed: myLeads.filter((l) => l.meetingInfoSent === true).length,
    }
  }, [tasks, myLeads, taskTab, now])

  const announcements = [
    { icon: '📢', title: 'Use My Tasks to track daily work', desc: 'Check pending items and mark them complete on time.', date: formatDate(now) },
    { icon: '📅', title: 'Keep your meetings updated', desc: 'Schedule client meetings from Lead Management.', date: formatDate(now) },
    { icon: '✅', title: 'Mark attendance daily', desc: 'Check in from the Attendance page each working day.', date: formatDate(now) },
  ]

  if (loading) {
    return <div className='p-8 text-sm text-gray-600'>Loading your dashboard...</div>
  }

  return (
    <div className='p-6 md:p-8 w-full bg-gray-50 min-h-full'>
      <div className='flex flex-wrap items-start justify-between gap-4 mb-6'>
        <div>
          <h1 className='text-2xl font-bold text-gray-900'>Welcome back, {firstName}! 👋</h1>
          <p className='text-gray-600 mt-1 text-sm'>Here&apos;s what&apos;s happening with your work today.</p>
          <p className='text-xs text-gray-400 mt-1'>{designation}</p>
        </div>
        <div className='text-sm text-gray-500 bg-white border border-gray-200 rounded-lg px-4 py-2'>
          {getWeekRangeLabel(now)}
        </div>
      </div>

      <div className='grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-4 mb-6'>
        <KpiCard title='My Tasks' value={stats.pendingTasks.length} subtitle='Pending Tasks' icon='📋' color='bg-blue-50' onClick={() => navigate('/my-tasks?status=Pending')} />
        <KpiCard title='Tasks Completed' value={stats.completedThisMonth.length} subtitle='This Month' icon='✅' color='bg-green-50' onClick={() => navigate('/my-tasks?status=Completed')} />
        <KpiCard title='My Leads' value={myLeads.length} subtitle='Total Leads' icon='🎯' color='bg-purple-50' onClick={() => navigate('/lead-management')} />
        <KpiCard title='My Deals' value={stats.openDeals.length} subtitle='Open Deals' icon='💼' color='bg-orange-50' onClick={() => navigate('/lead-management')} />
        <KpiCard title='Meetings Today' value={stats.meetingsToday.length} subtitle='Scheduled' icon='📅' color='bg-cyan-50' onClick={() => navigate('/lead-management')} />
      </div>

      <div className='grid grid-cols-1 xl:grid-cols-3 gap-6 mb-6'>
        <Panel title='My Tasks' actionLabel='View All' onAction={() => navigate('/my-tasks')}>
          <div className='flex gap-2 mb-4'>
            <button
              type='button'
              onClick={() => setTaskTab('pending')}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold ${taskTab === 'pending' ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-600'}`}
            >
              Pending ({stats.pendingTasks.length})
            </button>
            <button
              type='button'
              onClick={() => setTaskTab('completed')}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold ${taskTab === 'completed' ? 'bg-green-600 text-white' : 'bg-gray-100 text-gray-600'}`}
            >
              Completed ({stats.completedTasks.length})
            </button>
          </div>
          <div className='space-y-3 max-h-80 overflow-y-auto'>
            {stats.tabTasks.length ? stats.tabTasks.slice(0, 6).map((task) => (
              <button
                key={task._id}
                type='button'
                onClick={() => navigate(`/my-tasks/${task._id}`)}
                className='w-full flex items-start gap-3 text-left p-3 rounded-lg border border-gray-100 hover:bg-gray-50 transition-colors'
              >
                <span className={`mt-1 w-4 h-4 rounded border shrink-0 ${task.status === 'Completed' ? 'bg-green-500 border-green-500' : 'border-gray-300'}`} />
                <div className='min-w-0 flex-1'>
                  <p className='text-sm font-medium text-gray-900 truncate'>{task.title}</p>
                  <p className='text-xs text-gray-500 truncate'>{getProjectName(task)}</p>
                </div>
                <div className='flex flex-col items-end gap-1 shrink-0'>
                  <span className={`text-[10px] font-semibold px-2 py-0.5 rounded-full ${priorityClass(task.priority)}`}>
                    {task.priority || 'Medium'}
                  </span>
                  <span className='text-[10px] text-gray-400'>{formatDate(task.dueDate)}</span>
                </div>
              </button>
            )) : (
              <p className='text-sm text-gray-500 py-6 text-center'>No {taskTab} tasks</p>
            )}
          </div>
        </Panel>

        <SalesPipelineFunnel
          stages={stats.pipelineData.stages}
          totalValue={stats.pipelineData.totalValue}
          onViewPipeline={() => navigate('/lead-management')}
        />

        <Panel title="Today's Schedule" actionLabel='Add Meeting' onAction={() => navigate('/add-lead?meeting=1')}>
          {stats.todaySchedule.length ? (
            <div className='space-y-4'>
              {stats.todaySchedule.map((item) => (
                <button
                  key={item.id}
                  type='button'
                  onClick={() => navigate(item.path)}
                  className='w-full flex gap-3 text-left group'
                >
                  <div className='flex flex-col items-center'>
                    <span className={`w-2.5 h-2.5 rounded-full ${item.color} ring-4 ring-white`} />
                    <span className='w-px flex-1 bg-gray-200 min-h-[2rem]' />
                  </div>
                  <div className='pb-4 flex-1 group-hover:bg-gray-50 rounded-lg px-2 -mx-2 py-1'>
                    <p className='text-xs font-semibold text-blue-600'>{formatTime(item.time)}</p>
                    <p className='text-sm font-medium text-gray-900'>{item.title}</p>
                    <p className='text-xs text-gray-500'>{item.subtitle}</p>
                    <p className='text-[10px] text-gray-400 mt-0.5'>{item.duration}</p>
                  </div>
                </button>
              ))}
            </div>
          ) : (
            <p className='text-sm text-gray-500 py-8 text-center'>No meetings or tasks scheduled for today</p>
          )}
        </Panel>
      </div>

      <div className='grid grid-cols-1 lg:grid-cols-3 gap-6'>
        <Panel title='My Performance'>
          <PerformanceRing percent={stats.performancePct} />
          <div className='mt-5 space-y-2'>
            {[
              ['Leads Assigned', myLeads.length],
              ['Deals Closed', stats.dealsClosed],
              ['Tasks Done (Month)', stats.completedThisMonth.length],
              ['Pending Tasks', stats.pendingTasks.length],
            ].map(([label, value]) => (
              <div key={label} className='flex items-center justify-between text-sm py-1.5 border-b border-gray-50 last:border-0'>
                <span className='text-gray-600'>{label}</span>
                <span className='font-semibold text-gray-900'>{value}</span>
              </div>
            ))}
          </div>
        </Panel>

        <Panel title='Recent Leads' actionLabel='View All' onAction={() => navigate('/lead-management')}>
          <div className='space-y-3'>
            {stats.recentLeads.length ? stats.recentLeads.map((lead) => (
              <button
                key={lead._id}
                type='button'
                onClick={() => navigate(`/leads/view/${lead._id}`)}
                className='w-full flex items-center gap-3 text-left hover:bg-gray-50 rounded-lg p-2 -mx-2'
              >
                <div className='w-10 h-10 rounded-full bg-blue-100 text-blue-700 flex items-center justify-center text-xs font-bold shrink-0'>
                  {(lead.businessName || lead.name || '?').slice(0, 2).toUpperCase()}
                </div>
                <div className='min-w-0 flex-1'>
                  <p className='text-sm font-semibold text-gray-900 truncate'>{lead.businessName || lead.name}</p>
                  <p className='text-xs text-gray-500 truncate'>{lead.businessType || lead.city || 'Lead'}</p>
                </div>
                <div className='text-right shrink-0'>
                  <span className={`text-[10px] font-semibold px-2 py-0.5 rounded-full ${leadStatusClass(lead.status)}`}>
                    {leadStatusLabel(lead.status)}
                  </span>
                  <p className='text-[10px] text-gray-400 mt-1'>{formatDate(lead.createdAt)}</p>
                </div>
              </button>
            )) : (
              <p className='text-sm text-gray-500 py-6 text-center'>No leads yet</p>
            )}
          </div>
        </Panel>

        <Panel title='Announcements'>
          <div className='space-y-4'>
            {announcements.map((item) => (
              <div key={item.title} className='flex gap-3 pb-3 border-b border-gray-50 last:border-0 last:pb-0'>
                <span className='text-xl shrink-0'>{item.icon}</span>
                <div>
                  <p className='text-sm font-semibold text-gray-900'>{item.title}</p>
                  <p className='text-xs text-gray-500 mt-0.5'>{item.desc}</p>
                  <p className='text-[10px] text-gray-400 mt-1'>{item.date}</p>
                </div>
              </div>
            ))}
          </div>
        </Panel>
      </div>
    </div>
  )
}

export default EmployeeDashboardView
