import React, { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../../api/axios'
import { useAuth } from '../../context/AuthContext'
import { getAllReporteeIds, refEmployeeId } from '../../utils/reportingHierarchy'
import { onTaskChanged } from '../../utils/realtimeSocket'

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

const isDateOverdue = (dateStr) => {
  if (!dateStr) return false
  const d = new Date(dateStr)
  if (Number.isNaN(d.getTime())) return false
  return d.getTime() < Date.now()
}

const getInitials = (name = '') =>
  name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0])
    .join('')
    .toUpperCase() || '?'

const PencilIcon = ({ className = 'w-3.5 h-3.5' }) => (
  <svg
    xmlns='http://www.w3.org/2000/svg'
    fill='none'
    viewBox='0 0 24 24'
    strokeWidth={2}
    stroke='currentColor'
    className={className}
  >
    <path
      strokeLinecap='round'
      strokeLinejoin='round'
      d='m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L6.832 19.82a4.5 4.5 0 0 1-1.897 1.13l-2.685.8.8-2.685a4.5 4.5 0 0 1 1.13-1.897L16.863 4.487Zm0 0L19.5 7.125'
    />
  </svg>
)

const TaskApprovalView = () => {
  const { user, hasFullAccess } = useAuth()
  const navigate = useNavigate()

  const [tasks, setTasks] = useState([])
  const [employees, setEmployees] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [activeTab, setActiveTab] = useState('Pending') // 'Pending' | 'Approved' | 'Rejected' | 'All'
  const [search, setSearch] = useState('')

  // Duration adjustments map: { [taskId]: { hours: number, minutes: number } }
  const [durationEdits, setDurationEdits] = useState({})
  const [editingDurationId, setEditingDurationId] = useState(null)
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

  useEffect(() => {
    const handleUpdate = () => {
      fetchTasksAndTeam()
    }
    const unsub = onTaskChanged(handleUpdate)
    window.addEventListener('crm:task-updated', handleUpdate)
    return () => {
      unsub?.()
      window.removeEventListener('crm:task-updated', handleUpdate)
    }
  }, [fetchTasksAndTeam])

  // Get list of employee IDs who report to this manager
  const reporteeIds = useMemo(() => {
    if (hasFullAccess()) return null
    return getAllReporteeIds(employees, user?._id)
  }, [employees, user?._id, hasFullAccess])

  // Filter tasks to those relevant to this manager's team
  const managerTasks = useMemo(() => {
    return tasks.filter((t) => {
      const hasApprovalStatus = Boolean(t.approvalStatus && t.approvalStatus !== 'None')
      if (!hasApprovalStatus && t.status !== 'Pending') return false

      if (hasFullAccess()) return true

      const assigneeId = refEmployeeId(t.assignedTo)
      const assignerId = refEmployeeId(t.assignedBy)

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
      const assignee = (t.assignedTo?.name || '').toLowerCase()
      const proj = (t.project?.projectName || '').toLowerCase()
      return title.includes(q) || assignee.includes(q) || proj.includes(q)
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
      window.dispatchEvent(new CustomEvent('crm:task-updated'))
      setActionSuccess(`Approved "${task.title}". Waiting for employee to accept and start timer.`)
      setTimeout(() => setActionSuccess(null), 4000)
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
      window.dispatchEvent(new CustomEvent('crm:task-updated'))
      setActionSuccess(`Task "${rejectingTask.title}" rejected.`)
      setTimeout(() => setActionSuccess(null), 4000)
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
    <div className='p-4 md:p-8 w-full bg-[#f8f9fa] min-h-full space-y-5'>
      {/* Top Header & Search */}
      <div className='flex flex-col sm:flex-row sm:items-center justify-between gap-4'>
        <div>
          <div className='flex items-center gap-2.5'>
            <h1 className='text-2xl font-bold text-gray-900'>Task Approval</h1>
            {counts.Pending > 0 && (
              <span className='px-2.5 py-0.5 rounded-full text-xs font-bold bg-amber-100 text-amber-800 border border-amber-200'>
                {counts.Pending} Pending
              </span>
            )}
          </div>
          <p className='text-xs sm:text-sm text-gray-500 mt-1'>
            Review employee tasks, adjust duration, and approve them for employee acceptance.
          </p>
        </div>

        <div className='flex items-center gap-3'>
          <div className='relative w-full sm:w-64'>
            <span className='absolute inset-y-0 left-0 flex items-center pl-3 text-gray-400 text-xs'>
              🔍
            </span>
            <input
              type='text'
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder='Search title, assignee, project…'
              className='w-full pl-8 pr-3 py-1.5 text-xs rounded-lg border border-gray-200 focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white shadow-2xs'
            />
          </div>
          <button
            type='button'
            onClick={() => navigate('/assign-task')}
            className='px-3.5 py-1.5 rounded-lg bg-blue-600 text-white text-xs font-semibold hover:bg-blue-700 shadow-2xs flex items-center gap-1.5 whitespace-nowrap'
          >
            <span>+</span> Assign Task
          </button>
        </div>
      </div>

      {/* Tabs / Filter bar */}
      <div className='flex items-center gap-2 border-b border-gray-200 pb-3'>
        {[
          { key: 'Pending', label: 'Pending Approval', count: counts.Pending },
          { key: 'Approved', label: 'Approved', count: counts.Approved },
          { key: 'Rejected', label: 'Rejected', count: counts.Rejected },
          { key: 'All', label: 'All Tasks', count: counts.All },
        ].map((tab) => {
          const isActive = activeTab === tab.key
          return (
            <button
              key={tab.key}
              type='button'
              onClick={() => setActiveTab(tab.key)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors flex items-center gap-1.5 ${
                isActive
                  ? 'bg-white text-blue-700 shadow-2xs border border-gray-200'
                  : 'text-gray-600 hover:text-gray-900 hover:bg-gray-100'
              }`}
            >
              <span>{tab.label}</span>
              <span
                className={`px-1.5 py-0.2 rounded-full text-[10px] ${
                  isActive ? 'bg-blue-100 text-blue-800 font-bold' : 'bg-gray-100 text-gray-500'
                }`}
              >
                {tab.count}
              </span>
            </button>
          )
        })}
      </div>

      {/* Success Notification */}
      {actionSuccess && (
        <div className='p-3.5 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs font-medium flex items-center justify-between'>
          <div className='flex items-center gap-2'>
            <span>✓</span>
            <span>{actionSuccess}</span>
          </div>
          <button
            type='button'
            onClick={() => setActionSuccess(null)}
            className='text-emerald-700 hover:text-emerald-900 font-bold'
          >
            ✕
          </button>
        </div>
      )}

      {/* Error Notification */}
      {error && (
        <div className='p-3.5 rounded-xl bg-rose-50 border border-rose-200 text-rose-800 text-xs font-medium flex items-center justify-between'>
          <div className='flex items-center gap-2'>
            <span>⚠️</span>
            <span>{error}</span>
          </div>
          <button
            type='button'
            onClick={() => setError(null)}
            className='text-rose-700 hover:text-rose-900 font-bold'
          >
            ✕
          </button>
        </div>
      )}

      {/* Redesigned Clean View - Showing ONLY: Task Title, Project, Assignee, Duration, Due, Action */}
      {filteredTasks.length === 0 ? (
        <div className='bg-white rounded-xl border border-gray-200 p-12 text-center shadow-2xs'>
          <div className='w-12 h-12 bg-blue-50 text-blue-600 rounded-full flex items-center justify-center mx-auto text-xl mb-3'>
            ✓
          </div>
          <h3 className='text-sm font-bold text-gray-900'>
            {activeTab === 'Pending' ? 'No tasks awaiting approval' : `No ${activeTab.toLowerCase()} tasks found`}
          </h3>
          <p className='text-xs text-gray-500 mt-1 max-w-sm mx-auto'>
            {activeTab === 'Pending'
              ? 'All employee tasks are up to date.'
              : 'Try switching to another tab or clearing your search.'}
          </p>
        </div>
      ) : (
        <div className='bg-white rounded-xl border border-gray-200 shadow-2xs overflow-hidden'>
          {/* Desktop Table View */}
          <div className='hidden md:block overflow-x-auto'>
            <table className='w-full text-left border-collapse'>
              <thead>
                <tr className='bg-gray-50/75 border-b border-gray-200 text-[11px] font-bold text-gray-500 uppercase tracking-wider'>
                  <th className='py-3.5 px-4'>Task Title</th>
                  <th className='py-3.5 px-4'>Project</th>
                  <th className='py-3.5 px-4'>Assignee</th>
                  <th className='py-3.5 px-4'>Duration</th>
                  <th className='py-3.5 px-4'>Due</th>
                  <th className='py-3.5 px-4 text-right'>Action</th>
                </tr>
              </thead>
              <tbody className='divide-y divide-gray-100 text-xs'>
                {filteredTasks.map((task) => {
                  const isPending = task.approvalStatus === 'Pending' || (!task.approvalStatus && task.status === 'Pending')
                  const isApproved = task.approvalStatus === 'Approved'
                  const isRejected = task.approvalStatus === 'Rejected'
                  const duration = durationEdits[task._id] || { hours: 1, minutes: 0 }
                  const totalEditedMins = (duration.hours || 0) * 60 + (duration.minutes || 0)
                  const isSubmitting = submittingId === task._id
                  const isOverdue = isPending && isDateOverdue(task.dueDate)

                  return (
                    <tr
                      key={task._id}
                      className={`${
                        isPending
                          ? 'bg-yellow-50/90 hover:bg-yellow-100/80 border-l-4 border-l-yellow-400'
                          : isApproved
                            ? 'bg-green-50/90 hover:bg-green-100/80 border-l-4 border-l-green-500'
                            : 'hover:bg-blue-50/20'
                      } transition-colors group`}
                    >
                      {/* 1. Task Title */}
                      <td className='py-3.5 px-4 max-w-[280px]'>
                        <div className='flex items-center gap-2'>
                          <span
                            onClick={() => navigate(`/tasks/${task._id}`)}
                            className='font-semibold text-gray-900 hover:text-blue-600 cursor-pointer truncate block'
                            title={task.title}
                          >
                            {task.title}
                          </span>
                        </div>
                        {isRejected && task.rejectionReason && (
                          <p className='text-[11px] text-rose-600 mt-0.5 truncate' title={task.rejectionReason}>
                            Reason: {task.rejectionReason}
                          </p>
                        )}
                      </td>

                      {/* 2. Project */}
                      <td className='py-3.5 px-4 whitespace-nowrap'>
                        {task.project?.projectName ? (
                          <span className='inline-flex items-center gap-1 px-2.5 py-1 rounded-md text-[11px] font-medium bg-slate-100 text-slate-700 border border-slate-200'>
                            📁 {task.project.projectName}
                          </span>
                        ) : (
                          <span className='text-gray-400'>—</span>
                        )}
                      </td>

                      {/* 3. Assignee */}
                      <td className='py-3.5 px-4 whitespace-nowrap'>
                        <div className='flex items-center gap-2.5'>
                          <div className='w-7 h-7 rounded-full bg-gradient-to-tr from-blue-600 to-indigo-600 text-white font-bold text-[10px] flex items-center justify-center shrink-0 shadow-2xs'>
                            {getInitials(task.assignedTo?.name)}
                          </div>
                          <div>
                            <span className='font-semibold text-gray-900 block leading-tight'>
                              {task.assignedTo?.name || 'Employee'}
                            </span>
                            {task.assignedTo?.designation?.title && (
                              <span className='text-[10px] text-gray-400 block'>
                                {task.assignedTo.designation.title}
                              </span>
                            )}
                          </div>
                        </div>
                      </td>

                      {/* 4. Duration */}
                      <td className='py-3.5 px-4 whitespace-nowrap'>
                        {isPending && editingDurationId === task._id ? (
                          <div className='flex items-center gap-1.5 animate-in fade-in duration-150'>
                            <div className='inline-flex items-center bg-white border border-blue-500 ring-2 ring-blue-100 rounded-lg shadow-2xs overflow-hidden'>
                              <input
                                type='number'
                                min='0'
                                max='72'
                                value={duration.hours}
                                onChange={(e) => handleDurationChange(task._id, 'hours', e.target.value)}
                                className='w-10 px-1 py-1 text-xs font-bold text-center text-gray-900 focus:outline-none'
                                title='Edit duration hours'
                                autoFocus
                              />
                              <span className='text-[11px] font-semibold text-gray-400 pr-1'>h</span>
                              <span className='text-gray-200'>:</span>
                              <input
                                type='number'
                                min='0'
                                max='59'
                                step='5'
                                value={duration.minutes}
                                onChange={(e) => handleDurationChange(task._id, 'minutes', e.target.value)}
                                className='w-10 px-1 py-1 text-xs font-bold text-center text-gray-900 focus:outline-none'
                                title='Edit duration minutes'
                              />
                              <span className='text-[11px] font-semibold text-gray-400 pr-1.5'>m</span>
                            </div>

                            {/* Done checkmark button */}
                            <button
                              type='button'
                              onClick={() => setEditingDurationId(null)}
                              className='p-1.5 rounded-lg bg-emerald-50 hover:bg-emerald-100 text-emerald-700 border border-emerald-200 text-xs font-bold transition-colors'
                              title='Done'
                            >
                              ✓
                            </button>

                            {/* Quick presets */}
                            <div className='hidden xl:flex items-center gap-1'>
                              {[30, 60, 120, 240].map((mins) => (
                                <button
                                  key={mins}
                                  type='button'
                                  onClick={() => handleQuickDuration(task._id, mins)}
                                  className={`px-1.5 py-0.5 text-[10px] font-semibold rounded border transition-colors ${
                                    totalEditedMins === mins
                                      ? 'bg-blue-600 text-white border-blue-600'
                                      : 'bg-gray-50 border-gray-200 text-gray-600 hover:bg-gray-100'
                                  }`}
                                  title={`Set duration to ${mins < 60 ? `${mins}m` : `${mins / 60}h`}`}
                                >
                                  {mins < 60 ? `${mins}m` : `${mins / 60}h`}
                                </button>
                              ))}
                            </div>
                          </div>
                        ) : (
                          <div className='inline-flex items-center gap-1.5 group'>
                            <span className='inline-flex items-center gap-1 px-2.5 py-1 rounded-md text-xs font-semibold bg-gray-100 text-gray-800 border border-gray-200'>
                              ⏱️ {formatMinutes(totalEditedMins)}
                            </span>
                            {isPending && (
                              <button
                                type='button'
                                onClick={() => setEditingDurationId(task._id)}
                                className='p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 border border-transparent hover:border-blue-200 transition-colors'
                                title='Edit duration'
                              >
                                <PencilIcon className='w-3.5 h-3.5' />
                              </button>
                            )}
                          </div>
                        )}
                      </td>

                      {/* 5. Due */}
                      <td className='py-3.5 px-4 whitespace-nowrap'>
                        {task.dueDate ? (
                          <span
                            className={`inline-flex items-center gap-1 text-xs ${
                              isOverdue
                                ? 'text-rose-600 font-semibold'
                                : 'text-gray-600'
                            }`}
                          >
                            <span>📅</span> {formatDate(task.dueDate)}
                            {isOverdue && (
                              <span className='text-[10px] px-1 py-0.2 bg-rose-100 text-rose-700 rounded font-bold'>
                                Overdue
                              </span>
                            )}
                          </span>
                        ) : (
                          <span className='text-gray-400'>—</span>
                        )}
                      </td>

                      {/* 6. Action */}
                      <td className='py-3.5 px-4 whitespace-nowrap text-right'>
                        {isPending ? (
                          <div className='inline-flex items-center justify-end gap-1.5'>
                            <button
                              type='button'
                              onClick={() => {
                                setRejectingTask(task)
                                setRejectReason('')
                              }}
                              disabled={isSubmitting}
                              className='px-2.5 py-1.5 rounded-lg border border-gray-300 text-gray-600 hover:text-rose-600 hover:bg-rose-50 text-xs font-semibold transition-colors disabled:opacity-50'
                              title='Reject task'
                            >
                              Reject
                            </button>
                            <button
                              type='button'
                              onClick={() => handleApprove(task)}
                              disabled={isSubmitting || totalEditedMins <= 0}
                              className='px-3.5 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold transition-colors shadow-2xs flex items-center gap-1.5 disabled:opacity-50'
                              title='Approve task for employee acceptance'
                            >
                              {isSubmitting ? (
                                <>
                                  <span className='w-3 h-3 border-2 border-white border-t-transparent rounded-full animate-spin' />
                                  <span>Approving…</span>
                                </>
                              ) : (
                                <>
                                  <span>✓</span>
                                  <span>Approve</span>
                                </>
                              )}
                            </button>
                          </div>
                        ) : isApproved ? (
                          <span className='inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold bg-emerald-100 text-emerald-800 border border-emerald-200'>
                            <span className='w-1.5 h-1.5 rounded-full bg-emerald-600' />
                            Approved
                          </span>
                        ) : (
                          <span className='inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold bg-rose-100 text-rose-800 border border-rose-200'>
                            ✕ Rejected
                          </span>
                        )}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>

          {/* Mobile Card View (Showing only Task Title, Project, Assignee, Duration, Due, Action) */}
          <div className='md:hidden divide-y divide-gray-100'>
            {filteredTasks.map((task) => {
              const isPending = task.approvalStatus === 'Pending' || (!task.approvalStatus && task.status === 'Pending')
              const isApproved = task.approvalStatus === 'Approved'
              const isRejected = task.approvalStatus === 'Rejected'
              const duration = durationEdits[task._id] || { hours: 1, minutes: 0 }
              const totalEditedMins = (duration.hours || 0) * 60 + (duration.minutes || 0)
              const isSubmitting = submittingId === task._id
              const isOverdue = isPending && isDateOverdue(task.dueDate)

              return (
                <div key={task._id} className='p-4 space-y-3'>
                  {/* Title & Project */}
                  <div className='flex items-start justify-between gap-2'>
                    <div>
                      <h4
                        onClick={() => navigate(`/tasks/${task._id}`)}
                        className='font-bold text-gray-900 text-sm hover:text-blue-600 cursor-pointer'
                      >
                        {task.title}
                      </h4>
                      {task.project?.projectName && (
                        <span className='inline-block text-[11px] font-medium text-slate-600 mt-0.5'>
                          📁 {task.project.projectName}
                        </span>
                      )}
                    </div>
                    {isApproved && (
                      <span className='px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-800'>
                        Approved
                      </span>
                    )}
                    {isRejected && (
                      <span className='px-2 py-0.5 rounded-full text-[10px] font-bold bg-rose-100 text-rose-800'>
                        Rejected
                      </span>
                    )}
                  </div>

                  {/* Assignee & Due */}
                  <div className='flex items-center justify-between text-xs text-gray-600 pt-1'>
                    <div className='flex items-center gap-2'>
                      <div className='w-6 h-6 rounded-full bg-blue-600 text-white font-bold text-[10px] flex items-center justify-center shrink-0'>
                        {getInitials(task.assignedTo?.name)}
                      </div>
                      <span className='font-medium text-gray-900'>
                        {task.assignedTo?.name || 'Employee'}
                      </span>
                    </div>

                    <div className='text-right'>
                      {task.dueDate ? (
                        <span className={`text-[11px] ${isOverdue ? 'text-rose-600 font-bold' : 'text-gray-500'}`}>
                          Due: {formatDate(task.dueDate)}
                        </span>
                      ) : (
                        <span className='text-gray-400 text-[11px]'>No due date</span>
                      )}
                    </div>
                  </div>

                  {/* Duration row */}
                  <div className='flex items-center justify-between gap-2 bg-gray-50 p-2.5 rounded-lg border border-gray-200'>
                    <span className='text-xs font-semibold text-gray-700'>Duration:</span>
                    {isPending && editingDurationId === task._id ? (
                      <div className='flex items-center gap-1.5'>
                        <div className='inline-flex items-center bg-white border border-blue-400 ring-1 ring-blue-100 rounded-md px-1.5 py-0.5 text-xs font-bold'>
                          <input
                            type='number'
                            min='0'
                            max='72'
                            value={duration.hours}
                            onChange={(e) => handleDurationChange(task._id, 'hours', e.target.value)}
                            className='w-8 text-center focus:outline-none'
                            autoFocus
                          />
                          <span className='text-gray-400 font-normal mr-1'>h</span>
                          <input
                            type='number'
                            min='0'
                            max='59'
                            step='5'
                            value={duration.minutes}
                            onChange={(e) => handleDurationChange(task._id, 'minutes', e.target.value)}
                            className='w-8 text-center focus:outline-none'
                          />
                          <span className='text-gray-400 font-normal'>m</span>
                        </div>
                        <button
                          type='button'
                          onClick={() => setEditingDurationId(null)}
                          className='p-1 rounded bg-blue-600 text-white font-bold text-xs'
                          title='Done'
                        >
                          ✓
                        </button>
                      </div>
                    ) : (
                      <div className='flex items-center gap-1.5'>
                        <span className='text-xs font-bold text-gray-800'>
                          ⏱️ {formatMinutes(totalEditedMins)}
                        </span>
                        {isPending && (
                          <button
                            type='button'
                            onClick={() => setEditingDurationId(task._id)}
                            className='p-1 rounded text-gray-400 hover:text-blue-600 hover:bg-blue-50'
                            title='Edit duration'
                          >
                            <PencilIcon className='w-3.5 h-3.5' />
                          </button>
                        )}
                      </div>
                    )}
                  </div>

                  {/* Actions for Pending */}
                  {isPending && (
                    <div className='flex items-center justify-end gap-2 pt-1'>
                      <button
                        type='button'
                        onClick={() => {
                          setRejectingTask(task)
                          setRejectReason('')
                        }}
                        disabled={isSubmitting}
                        className='px-3 py-1.5 rounded-lg border border-gray-300 text-xs font-semibold text-gray-700 hover:bg-gray-100 disabled:opacity-50'
                      >
                        Reject
                      </button>
                      <button
                        type='button'
                        onClick={() => handleApprove(task)}
                        disabled={isSubmitting || totalEditedMins <= 0}
                        className='px-4 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold shadow-2xs flex items-center gap-1 disabled:opacity-50'
                      >
                        <span>▶</span>
                        <span>Approve & Start</span>
                      </button>
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        </div>
      )}

      {/* Rejection Modal */}
      {rejectingTask && (
        <div className='fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4 backdrop-blur-2xs'>
          <div className='bg-white rounded-2xl max-w-md w-full p-6 shadow-xl space-y-4'>
            <div className='flex items-center justify-between'>
              <h3 className='text-base font-bold text-gray-900'>Reject Task</h3>
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
                placeholder='E.g. Duration too high, project scope needs clarification…'
                className='w-full p-2.5 text-xs rounded-xl border border-gray-300 focus:outline-none focus:ring-2 focus:ring-rose-500 bg-gray-50/50'
              />
            </div>

            {/* Quick Reasons */}
            <div className='flex flex-wrap gap-1.5'>
              {[
                'Duration needs adjustment',
                'Requirements unclear',
                'Duplicate task',
                'Wrong project',
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
                className='px-3.5 py-1.5 rounded-lg border border-gray-300 text-xs font-semibold text-gray-700 hover:bg-gray-50'
              >
                Cancel
              </button>
              <button
                type='button'
                onClick={handleRejectSubmit}
                disabled={submittingId === rejectingTask._id}
                className='px-4 py-1.5 rounded-lg bg-rose-600 hover:bg-rose-700 text-white text-xs font-bold shadow-2xs'
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
