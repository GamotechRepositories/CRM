import React, { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../../api/axios'
import { useAuth } from '../../context/AuthContext'
import { getAllReporteeIds, refEmployeeId } from '../../utils/reportingHierarchy'
import { getTaskRemainingMinutes, normalizeTaskStatus } from '../../utils/taskStatus'

const PRIORITY_BADGES = {
  Urgent: 'bg-red-100 text-red-800 border-red-200',
  High: 'bg-orange-100 text-orange-800 border-orange-200',
  Medium: 'bg-yellow-100 text-yellow-800 border-yellow-200',
  Low: 'bg-green-100 text-green-800 border-green-200',
}

const formatMinutes = (minutes) => {
  const mins = Number(minutes)
  if (!Number.isFinite(mins) || mins <= 0) return '—'
  const h = Math.floor(mins / 60)
  const m = mins % 60
  if (h && m) return `${h}h ${m}m`
  if (h) return `${h}h`
  return `${m}m`
}

const formatDate = (dateStr) => {
  if (!dateStr) return '—'
  const d = new Date(dateStr)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleDateString('en-IN', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  })
}

const formatDateTime = (dateStr) => {
  if (!dateStr) return '—'
  const d = new Date(dateStr)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleString('en-IN', {
    day: 'numeric',
    month: 'short',
    hour: 'numeric',
    minute: '2-digit',
  })
}

const getInitials = (name = '') =>
  name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0])
    .join('')
    .toUpperCase() || '?'

const TaskApprovalView = () => {
  const { user, hasFullAccess, canAssignTask } = useAuth()
  const navigate = useNavigate()

  const [tasks, setTasks] = useState([])
  const [employees, setEmployees] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [activeTab, setActiveTab] = useState('Pending') // 'Pending' | 'Approved' | 'Rejected' | 'All'
  const [search, setSearch] = useState('')

  // Duration adjustments map: { [taskId]: { hours: number, minutes: number } }
  const [durationEdits, setDurationEdits] = useState({})
  const [submittingId, setSubmittingId] = useState(null)
  const [rejectingTask, setRejectingTask] = useState(null)
  const [rejectReason, setRejectReason] = useState('')
  const [actionSuccess, setActionSuccess] = useState(null)

  const fetchTasksAndTeam = useCallback(async () => {
    if (!user?._id) return
    try {
      setLoading(true)
      setError(null)

      const [taskRes, empRes] = await Promise.all([
        api.get('/tasks'),
        api.get('/employees').catch(() => ({ data: [] })),
      ])

      const rawTasks = Array.isArray(taskRes.data) ? taskRes.data : []
      const rawEmployees = Array.isArray(empRes.data)
        ? empRes.data
        : empRes.data?.data || []

      setEmployees(rawEmployees)
      setTasks(rawTasks.filter((t) => !String(t._id).startsWith('social-media-')))
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to load tasks')
    } finally {
      setLoading(false)
    }
  }, [user?._id])

  useEffect(() => {
    fetchTasksAndTeam()
  }, [fetchTasksAndTeam])

  // Get list of employee IDs who report to this manager
  const reporteeIds = useMemo(() => {
    if (hasFullAccess()) return null // null means full access (all employees)
    return getAllReporteeIds(employees, user?._id)
  }, [employees, user?._id, hasFullAccess])

  // Filter tasks to those relevant to this manager's team
  const managerTasks = useMemo(() => {
    return tasks.filter((t) => {
      // If task has approvalStatus explicitly set (Pending, Approved, Rejected)
      const hasApprovalStatus = Boolean(t.approvalStatus && t.approvalStatus !== 'None')
      if (!hasApprovalStatus && t.status !== 'Pending') return false

      if (hasFullAccess()) return true

      const assigneeId = refEmployeeId(t.assignedTo)
      const assignerId = refEmployeeId(t.assignedBy)

      // Included if assignee or assigner is in reportee tree or self
      if (reporteeIds) {
        if (reporteeIds.has(assigneeId) || reporteeIds.has(assignerId)) return true
      }
      return false
    })
  }, [tasks, hasFullAccess, reporteeIds])

  // Initialize duration edits when tasks are loaded
  useEffect(() => {
    const edits = {}
    managerTasks.forEach((t) => {
      const totalMins = Number(t.estimatedDurationMinutes) || 60
      edits[t._id] = {
        hours: Math.floor(totalMins / 60),
        minutes: totalMins % 60,
      }
    })
    setDurationEdits(edits)
  }, [managerTasks])

  const counts = useMemo(() => {
    const p = managerTasks.filter((t) => t.approvalStatus === 'Pending' || (!t.approvalStatus && t.status === 'Pending')).length
    const a = managerTasks.filter((t) => t.approvalStatus === 'Approved').length
    const r = managerTasks.filter((t) => t.approvalStatus === 'Rejected').length
    return {
      Pending: p,
      Approved: a,
      Rejected: r,
      All: managerTasks.length,
    }
  }, [managerTasks])

  const filteredTasks = useMemo(() => {
    let list = managerTasks

    if (activeTab === 'Pending') {
      list = list.filter((t) => t.approvalStatus === 'Pending' || (!t.approvalStatus && t.status === 'Pending'))
    } else if (activeTab === 'Approved') {
      list = list.filter((t) => t.approvalStatus === 'Approved')
    } else if (activeTab === 'Rejected') {
      list = list.filter((t) => t.approvalStatus === 'Rejected')
    }

    const q = search.trim().toLowerCase()
    if (!q) return list

    return list.filter((t) => {
      const title = (t.title || '').toLowerCase()
      const desc = (t.description || '').toLowerCase()
      const assignee = (t.assignedTo?.name || '').toLowerCase()
      const proj = (t.project?.projectName || '').toLowerCase()
      return title.includes(q) || desc.includes(q) || assignee.includes(q) || proj.includes(q)
    })
  }, [managerTasks, activeTab, search])

  const handleDurationChange = (taskId, field, value) => {
    const num = Math.max(0, parseInt(value, 10) || 0)
    setDurationEdits((prev) => {
      const current = prev[taskId] || { hours: 1, minutes: 0 }
      return {
        ...prev,
        [taskId]: {
          ...current,
          [field]: field === 'minutes' ? Math.min(59, num) : num,
        },
      }
    })
  }

  const handleQuickDuration = (taskId, totalMins) => {
    setDurationEdits((prev) => ({
      ...prev,
      [taskId]: {
        hours: Math.floor(totalMins / 60),
        minutes: totalMins % 60,
      },
    }))
  }

  const handleApprove = async (task) => {
    const edit = durationEdits[task._id] || { hours: 1, minutes: 0 }
    const totalMinutes = Math.max(1, (edit.hours || 0) * 60 + (edit.minutes || 0))

    try {
      setSubmittingId(task._id)
      setError(null)
      const res = await api.put(`/tasks/${task._id}/approve`, {
        estimatedDurationMinutes: totalMinutes,
        approvedBy: user?._id,
      })

      const updated = res.data?.task || res.data
      setTasks((prev) =>
        prev.map((t) => (String(t._id) === String(updated._id) ? updated : t))
      )
      setActionSuccess(`Task "${task.title}" approved! Timer started for ${task.assignedTo?.name || 'employee'}.`)
      setTimeout(() => setActionSuccess(null), 5000)
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to approve task')
    } finally {
      setSubmittingId(null)
    }
  }

  const handleRejectSubmit = async () => {
    if (!rejectingTask) return
    try {
      setSubmittingId(rejectingTask._id)
      setError(null)
      const res = await api.put(`/tasks/${rejectingTask._id}/reject`, {
        rejectionReason: rejectReason.trim() || 'Rejected by reporting manager',
        rejectedBy: user?._id,
      })

      const updated = res.data?.task || res.data
      setTasks((prev) =>
        prev.map((t) => (String(t._id) === String(updated._id) ? updated : t))
      )
      setActionSuccess(`Task "${rejectingTask.title}" has been rejected.`)
      setTimeout(() => setActionSuccess(null), 5000)
      setRejectingTask(null)
      setRejectReason('')
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to reject task')
    } finally {
      setSubmittingId(null)
    }
  }

  if (loading) {
    return (
      <div className='p-8 flex items-center justify-center min-h-[300px]'>
        <div className='text-center space-y-2'>
          <div className='w-8 h-8 border-3 border-blue-600 border-t-transparent rounded-full animate-spin mx-auto' />
          <p className='text-sm text-gray-500'>Loading task approvals…</p>
        </div>
      </div>
    )
  }

  return (
    <div className='p-6 md:p-8 w-full bg-[#f8f9fa] min-h-full space-y-6'>
      {/* Header */}
      <div className='flex flex-wrap items-start justify-between gap-4'>
        <div>
          <div className='flex items-center gap-3'>
            <h1 className='text-2xl font-bold text-gray-900'>Task Approval</h1>
            {counts.Pending > 0 && (
              <span className='px-2.5 py-0.5 rounded-full text-xs font-bold bg-amber-100 text-amber-800 border border-amber-200 animate-pulse'>
                {counts.Pending} Pending
              </span>
            )}
          </div>
          <p className='text-gray-600 mt-1 text-sm'>
            Review tasks created by your team, adjust estimated durations, and approve to start task timers.
          </p>
        </div>
        <div className='flex items-center gap-2'>
          <button
            type='button'
            onClick={() => navigate('/assign-task')}
            className='px-4 py-2 rounded-lg bg-blue-600 text-white text-sm font-medium hover:bg-blue-700 shadow-sm flex items-center gap-1.5'
          >
            <span>+</span> Assign Task
          </button>
        </div>
      </div>

      {/* KPI Cards */}
      <div className='grid grid-cols-2 lg:grid-cols-4 gap-4'>
        <button
          type='button'
          onClick={() => setActiveTab('Pending')}
          className={`text-left rounded-xl p-4 border transition-all ${
            activeTab === 'Pending'
              ? 'bg-amber-50 border-amber-300 shadow-sm'
              : 'bg-white border-gray-100 shadow-xs hover:border-gray-200'
          }`}
        >
          <div className='flex items-center justify-between'>
            <span className='text-xs font-semibold text-gray-500 uppercase tracking-wider'>Pending Approval</span>
            <span className='text-lg'>⏳</span>
          </div>
          <p className='text-3xl font-extrabold text-amber-600 mt-2'>{counts.Pending}</p>
          <p className='text-xs text-gray-400 mt-1'>Awaiting your review</p>
        </button>

        <button
          type='button'
          onClick={() => setActiveTab('Approved')}
          className={`text-left rounded-xl p-4 border transition-all ${
            activeTab === 'Approved'
              ? 'bg-emerald-50 border-emerald-300 shadow-sm'
              : 'bg-white border-gray-100 shadow-xs hover:border-gray-200'
          }`}
        >
          <div className='flex items-center justify-between'>
            <span className='text-xs font-semibold text-gray-500 uppercase tracking-wider'>Approved</span>
            <span className='text-lg'>✅</span>
          </div>
          <p className='text-3xl font-extrabold text-emerald-600 mt-2'>{counts.Approved}</p>
          <p className='text-xs text-gray-400 mt-1'>Timer active / in progress</p>
        </button>

        <button
          type='button'
          onClick={() => setActiveTab('Rejected')}
          className={`text-left rounded-xl p-4 border transition-all ${
            activeTab === 'Rejected'
              ? 'bg-rose-50 border-rose-300 shadow-sm'
              : 'bg-white border-gray-100 shadow-xs hover:border-gray-200'
          }`}
        >
          <div className='flex items-center justify-between'>
            <span className='text-xs font-semibold text-gray-500 uppercase tracking-wider'>Rejected</span>
            <span className='text-lg'>✕</span>
          </div>
          <p className='text-3xl font-extrabold text-rose-600 mt-2'>{counts.Rejected}</p>
          <p className='text-xs text-gray-400 mt-1'>Needs revision</p>
        </button>

        <button
          type='button'
          onClick={() => setActiveTab('All')}
          className={`text-left rounded-xl p-4 border transition-all ${
            activeTab === 'All'
              ? 'bg-blue-50 border-blue-300 shadow-sm'
              : 'bg-white border-gray-100 shadow-xs hover:border-gray-200'
          }`}
        >
          <div className='flex items-center justify-between'>
            <span className='text-xs font-semibold text-gray-500 uppercase tracking-wider'>Total Submitted</span>
            <span className='text-lg'>📋</span>
          </div>
          <p className='text-3xl font-extrabold text-gray-800 mt-2'>{counts.All}</p>
          <p className='text-xs text-gray-400 mt-1'>All team tasks</p>
        </button>
      </div>

      {/* Success Banner */}
      {actionSuccess && (
        <div className='p-4 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-sm flex items-center justify-between'>
          <div className='flex items-center gap-2'>
            <span>✓</span>
            <span className='font-medium'>{actionSuccess}</span>
          </div>
          <button
            type='button'
            onClick={() => setActionSuccess(null)}
            className='text-emerald-700 hover:text-emerald-900 font-bold ml-4'
          >
            ✕
          </button>
        </div>
      )}

      {/* Error Banner */}
      {error && (
        <div className='p-4 rounded-xl bg-rose-50 border border-rose-200 text-rose-800 text-sm flex items-center justify-between'>
          <div className='flex items-center gap-2'>
            <span>⚠️</span>
            <span>{error}</span>
          </div>
          <button
            type='button'
            onClick={() => setError(null)}
            className='text-rose-700 hover:text-rose-900 font-bold ml-4'
          >
            ✕
          </button>
        </div>
      )}

      {/* Search & Tabs */}
      <div className='flex flex-col sm:flex-row sm:items-center justify-between gap-3 bg-white p-4 rounded-xl border border-gray-100 shadow-xs'>
        <div className='flex flex-wrap gap-1.5'>
          {['Pending', 'Approved', 'Rejected', 'All'].map((tab) => (
            <button
              key={tab}
              type='button'
              onClick={() => setActiveTab(tab)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors ${
                activeTab === tab
                  ? 'bg-blue-600 text-white shadow-xs'
                  : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
              }`}
            >
              {tab === 'Pending' ? `Pending (${counts.Pending})` : tab}
            </button>
          ))}
        </div>

        <div className='relative w-full sm:w-72'>
          <span className='absolute inset-y-0 left-0 flex items-center pl-3 text-gray-400'>
            🔍
          </span>
          <input
            type='text'
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder='Search task, employee, project…'
            className='w-full pl-9 pr-3 py-1.5 text-xs rounded-lg border border-gray-200 focus:outline-none focus:ring-2 focus:ring-blue-500 bg-gray-50/50'
          />
        </div>
      </div>

      {/* Task List */}
      {filteredTasks.length === 0 ? (
        <div className='bg-white rounded-2xl border border-gray-100 p-12 text-center shadow-xs'>
          <div className='w-16 h-16 bg-blue-50 rounded-full flex items-center justify-center mx-auto text-2xl text-blue-500 mb-3'>
            ✓
          </div>
          <h3 className='text-base font-bold text-gray-900'>
            {activeTab === 'Pending'
              ? 'No pending task approvals'
              : `No ${activeTab.toLowerCase()} tasks found`}
          </h3>
          <p className='text-xs text-gray-500 mt-1 max-w-sm mx-auto'>
            {activeTab === 'Pending'
              ? 'All tasks submitted by your team members have been reviewed.'
              : 'Try selecting a different filter or search term.'}
          </p>
        </div>
      ) : (
        <div className='space-y-4'>
          {filteredTasks.map((task) => {
            const isPending = task.approvalStatus === 'Pending' || (!task.approvalStatus && task.status === 'Pending')
            const isApproved = task.approvalStatus === 'Approved'
            const isRejected = task.approvalStatus === 'Rejected'
            const duration = durationEdits[task._id] || { hours: 1, minutes: 0 }
            const totalEditedMins = (duration.hours || 0) * 60 + (duration.minutes || 0)
            const isSubmitting = submittingId === task._id

            return (
              <div
                key={task._id}
                className={`bg-white rounded-2xl border shadow-xs transition-shadow hover:shadow-md ${
                  isPending
                    ? 'border-amber-200/80 ring-1 ring-amber-100'
                    : isApproved
                      ? 'border-emerald-100'
                      : 'border-gray-100'
                }`}
              >
                <div className='p-5 md:p-6 space-y-4'>
                  {/* Top Bar: Project, Priority, Status */}
                  <div className='flex flex-wrap items-center justify-between gap-2'>
                    <div className='flex flex-wrap items-center gap-2'>
                      <span className='px-2.5 py-1 rounded-md text-xs font-bold bg-indigo-50 text-indigo-700 border border-indigo-100'>
                        📁 {task.project?.projectName || 'Project Task'}
                      </span>
                      <span
                        className={`px-2 py-0.5 rounded-md text-xs font-semibold border ${
                          PRIORITY_BADGES[task.priority] || PRIORITY_BADGES.Medium
                        }`}
                      >
                        {task.priority || 'Medium'} Priority
                      </span>
                      {isPending && (
                        <span className='px-2.5 py-0.5 rounded-full text-xs font-bold bg-amber-100 text-amber-800 border border-amber-200 flex items-center gap-1'>
                          <span>⏳</span> Awaiting Manager Approval
                        </span>
                      )}
                      {isApproved && (
                        <span className='px-2.5 py-0.5 rounded-full text-xs font-bold bg-emerald-100 text-emerald-800 border border-emerald-200 flex items-center gap-1'>
                          <span>✅</span> Approved · Timer Started
                        </span>
                      )}
                      {isRejected && (
                        <span className='px-2.5 py-0.5 rounded-full text-xs font-bold bg-rose-100 text-rose-800 border border-rose-200 flex items-center gap-1'>
                          <span>✕</span> Rejected
                        </span>
                      )}
                    </div>

                    <div className='text-xs text-gray-400'>
                      Submitted: <span className='font-medium text-gray-600'>{formatDateTime(task.createdAt)}</span>
                    </div>
                  </div>

                  {/* Title & Description */}
                  <div>
                    <h3 className='text-lg font-bold text-gray-900 hover:text-blue-600 cursor-pointer' onClick={() => navigate(`/tasks/${task._id}`)}>
                      {task.title}
                    </h3>
                    {task.description && (
                      <p className='text-sm text-gray-600 mt-1 whitespace-pre-line line-clamp-3'>
                        {task.description}
                      </p>
                    )}
                  </div>

                  {/* Assignee / Requester Row */}
                  <div className='flex flex-wrap items-center justify-between gap-3 pt-3 border-t border-gray-100'>
                    <div className='flex items-center gap-3'>
                      <div className='w-9 h-9 rounded-full bg-gradient-to-tr from-blue-600 to-indigo-500 text-white font-bold text-xs flex items-center justify-center shrink-0 shadow-xs'>
                        {getInitials(task.assignedTo?.name)}
                      </div>
                      <div>
                        <div className='flex items-center gap-2'>
                          <span className='text-sm font-semibold text-gray-900'>
                            {task.assignedTo?.name || 'Employee'}
                          </span>
                          {task.assignedTo?.employeeCode && (
                            <span className='text-xs font-mono text-gray-400'>
                              ({task.assignedTo.employeeCode})
                            </span>
                          )}
                        </div>
                        <p className='text-xs text-gray-500'>
                          {task.assignedTo?.designation?.title || task.assignedTo?.department || 'Team Member'}
                          {task.assignedTo?.email && ` · ${task.assignedTo.email}`}
                        </p>
                      </div>
                    </div>

                    <div className='flex items-center gap-4 text-xs text-gray-500'>
                      {task.dueDate && (
                        <div>
                          <span className='text-gray-400'>Due Date:</span>{' '}
                          <span className='font-semibold text-gray-700'>{formatDate(task.dueDate)}</span>
                        </div>
                      )}
                      <div>
                        <span className='text-gray-400'>Requested Duration:</span>{' '}
                        <span className='font-semibold text-gray-700'>
                          {formatMinutes(task.estimatedDurationMinutes) || 'Not specified'}
                        </span>
                      </div>
                    </div>
                  </div>

                  {/* Rejection Note Display */}
                  {isRejected && task.rejectionReason && (
                    <div className='p-3 rounded-xl bg-rose-50 border border-rose-100 text-xs text-rose-800'>
                      <span className='font-bold'>Rejection Reason:</span> {task.rejectionReason}
                    </div>
                  )}

                  {/* Approval Actions Section (for Pending tasks) */}
                  {isPending && (
                    <div className='mt-4 p-4 rounded-xl bg-amber-50/60 border border-amber-200/70 space-y-3'>
                      <div className='flex flex-wrap items-center justify-between gap-2'>
                        <div>
                          <span className='text-xs font-bold text-amber-900 uppercase tracking-wider'>
                            Review & Set Task Duration
                          </span>
                          <p className='text-xs text-amber-800 mt-0.5'>
                            You can edit this task duration. Once approved, the active task timer will immediately start for {task.assignedTo?.name || 'the employee'}.
                          </p>
                        </div>
                        <span className='px-2.5 py-1 rounded-lg bg-amber-200/70 text-amber-900 text-xs font-bold'>
                          Approved Duration: {formatMinutes(totalEditedMins)}
                        </span>
                      </div>

                      {/* Duration Editor Controls */}
                      <div className='flex flex-wrap items-center gap-3'>
                        <div className='flex items-center gap-1.5'>
                          <label className='text-xs font-semibold text-gray-700'>Hours:</label>
                          <input
                            type='number'
                            min='0'
                            max='72'
                            value={duration.hours}
                            onChange={(e) => handleDurationChange(task._id, 'hours', e.target.value)}
                            className='w-16 px-2 py-1 text-xs font-bold text-center bg-white border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:outline-none'
                          />
                        </div>

                        <div className='flex items-center gap-1.5'>
                          <label className='text-xs font-semibold text-gray-700'>Mins:</label>
                          <input
                            type='number'
                            min='0'
                            max='59'
                            step='5'
                            value={duration.minutes}
                            onChange={(e) => handleDurationChange(task._id, 'minutes', e.target.value)}
                            className='w-16 px-2 py-1 text-xs font-bold text-center bg-white border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:outline-none'
                          />
                        </div>

                        {/* Quick Buttons */}
                        <div className='flex items-center gap-1'>
                          {[
                            { label: '30m', mins: 30 },
                            { label: '1h', mins: 60 },
                            { label: '2h', mins: 120 },
                            { label: '4h', mins: 240 },
                            { label: '8h', mins: 480 },
                          ].map((btn) => (
                            <button
                              key={btn.label}
                              type='button'
                              onClick={() => handleQuickDuration(task._id, btn.mins)}
                              className={`px-2 py-1 text-[11px] font-semibold rounded-md transition-colors ${
                                totalEditedMins === btn.mins
                                  ? 'bg-blue-600 text-white shadow-xs'
                                  : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-100'
                              }`}
                            >
                              {btn.label}
                            </button>
                          ))}
                        </div>
                      </div>

                      {/* Action Buttons */}
                      <div className='flex flex-wrap items-center justify-end gap-2 pt-2 border-t border-amber-200/50'>
                        <button
                          type='button'
                          onClick={() => {
                            setRejectingTask(task)
                            setRejectReason('')
                          }}
                          disabled={isSubmitting}
                          className='px-3.5 py-2 rounded-lg border border-gray-300 bg-white hover:bg-gray-50 text-gray-700 text-xs font-semibold transition-colors disabled:opacity-50'
                        >
                          ✕ Reject
                        </button>

                        <button
                          type='button'
                          onClick={() => handleApprove(task)}
                          disabled={isSubmitting || totalEditedMins <= 0}
                          className='px-5 py-2 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold transition-all shadow-sm hover:shadow flex items-center gap-2 disabled:opacity-50'
                        >
                          {isSubmitting ? (
                            <>
                              <div className='w-3.5 h-3.5 border-2 border-white border-t-transparent rounded-full animate-spin' />
                              <span>Approving…</span>
                            </>
                          ) : (
                            <>
                              <span>▶</span>
                              <span>Approve & Start Timer ({formatMinutes(totalEditedMins)})</span>
                            </>
                          )}
                        </button>
                      </div>
                    </div>
                  )}

                  {/* Details / Timer indicator for Approved tasks */}
                  {isApproved && (
                    <div className='p-3 rounded-xl bg-emerald-50/60 border border-emerald-200/60 flex flex-wrap items-center justify-between gap-2 text-xs'>
                      <div className='flex items-center gap-2'>
                        <span className='w-2.5 h-2.5 rounded-full bg-emerald-500 animate-ping' />
                        <span className='font-semibold text-emerald-900'>Active Timer Running</span>
                        <span className='text-emerald-700'>
                          · Started {formatDateTime(task.startedAt || task.updatedAt)}
                        </span>
                      </div>
                      <div className='text-emerald-800 font-semibold'>
                        Duration: {formatMinutes(task.estimatedDurationMinutes)}
                      </div>
                    </div>
                  )}
                </div>
              </div>
            )
          })}
        </div>
      )}

      {/* Rejection Modal */}
      {rejectingTask && (
        <div className='fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4 backdrop-blur-xs'>
          <div className='bg-white rounded-2xl max-w-md w-full p-6 shadow-xl space-y-4 animate-in fade-in zoom-in-95 duration-150'>
            <div className='flex items-center justify-between'>
              <h3 className='text-lg font-bold text-gray-900'>Reject Task</h3>
              <button
                type='button'
                onClick={() => setRejectingTask(null)}
                className='text-gray-400 hover:text-gray-600 text-lg'
              >
                ✕
              </button>
            </div>

            <p className='text-xs text-gray-600'>
              Please specify the reason for rejecting <span className='font-bold text-gray-800'>"{rejectingTask.title}"</span>. The employee will be notified with this reason.
            </p>

            <div className='space-y-1.5'>
              <label className='text-xs font-semibold text-gray-700'>Rejection Reason</label>
              <textarea
                rows={3}
                value={rejectReason}
                onChange={(e) => setRejectReason(e.target.value)}
                placeholder='E.g. Task duration is too high, project scope needs clarification, duplicate task…'
                className='w-full p-2.5 text-xs rounded-xl border border-gray-300 focus:outline-none focus:ring-2 focus:ring-rose-500 bg-gray-50/50'
              />
            </div>

            {/* Quick Reasons */}
            <div className='flex flex-wrap gap-1.5'>
              {[
                'Duration needs adjustment',
                'Requirements unclear',
                'Duplicate task',
                'Assigned to wrong project',
              ].map((reason) => (
                <button
                  key={reason}
                  type='button'
                  onClick={() => setRejectReason(reason)}
                  className='px-2.5 py-1 rounded-md text-[11px] font-medium bg-gray-100 hover:bg-gray-200 text-gray-700 transition-colors'
                >
                  {reason}
                </button>
              ))}
            </div>

            <div className='flex items-center justify-end gap-2 pt-3 border-t border-gray-100'>
              <button
                type='button'
                onClick={() => setRejectingTask(null)}
                disabled={submittingId === rejectingTask._id}
                className='px-4 py-2 rounded-lg border border-gray-300 text-xs font-semibold text-gray-700 hover:bg-gray-50'
              >
                Cancel
              </button>
              <button
                type='button'
                onClick={handleRejectSubmit}
                disabled={submittingId === rejectingTask._id}
                className='px-4 py-2 rounded-lg bg-rose-600 hover:bg-rose-700 text-white text-xs font-bold shadow-sm'
              >
                {submittingId === rejectingTask._id ? 'Rejecting…' : 'Confirm Rejection'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default TaskApprovalView
