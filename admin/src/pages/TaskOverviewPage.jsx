import React, { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import api from '../api/axios'
import AdminCompanyShell from '../components/AdminCompanyShell'
import { AppIcon } from '../components/Icons'

const fmtDate = (d) => {
  if (!d) return '—'
  const x = new Date(d)
  return Number.isNaN(x.getTime())
    ? '—'
    : x.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })
}

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

const formatDuration = (minutes) => {
  const mins = Number(minutes)
  if (!Number.isFinite(mins) || mins <= 0) return '—'
  const h = Math.floor(mins / 60)
  const m = mins % 60
  if (h && m) return `${h}h ${m}m`
  if (h) return `${h}h`
  return `${m}m`
}

const statusClass = (status) => {
  switch (status) {
    case 'Completed':
      return 'bg-emerald-100 text-emerald-800'
    case 'In Progress':
      return 'bg-blue-100 text-blue-800'
    case 'Cancelled':
      return 'bg-gray-100 text-gray-600'
    default:
      return 'bg-amber-100 text-amber-800'
  }
}

const priorityClass = (priority) => {
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

const Field = ({ label, children }) => (
  <div className='flex justify-between items-start py-2.5 border-b border-gray-100 gap-4'>
    <span className='text-sm text-gray-500 shrink-0'>{label}</span>
    <div className='text-sm font-medium text-gray-900 text-right'>{children ?? '—'}</div>
  </div>
)

const TaskOverviewPage = () => {
  const { tenantId, taskId } = useParams()
  const navigate = useNavigate()
  const [task, setTask] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const tasksPath = `/company/${tenantId}/tasks`

  useEffect(() => {
    const load = async () => {
      if (!tenantId || !taskId) return
      try {
        setLoading(true)
        setError('')
        const res = await api.get(`/companies/${tenantId}/tasks/${taskId}`)
        setTask(res.data?.task || null)
      } catch (err) {
        setError(err.response?.data?.message || err.message || 'Failed to load task')
        setTask(null)
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [tenantId, taskId])

  return (
    <AdminCompanyShell activeNav='tasks'>
      {loading ? (
        <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-10 text-center text-sm text-gray-500'>
          Loading task overview…
        </div>
      ) : error || !task ? (
        <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-10 text-center'>
          <p className='text-red-600 text-sm'>{error || 'Task not found'}</p>
          <button
            type='button'
            onClick={() => navigate(tasksPath)}
            className='mt-4 text-blue-600 text-sm font-medium'
          >
            Back to Tasks
          </button>
        </div>
      ) : (
        <>
          <div className='flex flex-wrap items-start justify-between gap-4 mb-6'>
            <div>
              <div className='flex items-center gap-2 text-gray-500 text-sm mb-1'>
                <AppIcon id='tasks' className='size-4' />
                <span>Task overview</span>
              </div>
              <h1 className='text-2xl font-bold text-gray-900'>{task.title}</h1>
              <p className='text-sm text-gray-500 mt-1'>
                {task.project?.projectName || 'No project'}
                {task.project?.client?.clientName ? ` · ${task.project.client.clientName}` : ''}
              </p>
            </div>
            <div className='flex flex-wrap gap-2'>
              <button
                type='button'
                onClick={() => navigate(tasksPath)}
                className='px-4 py-2 rounded-lg border border-gray-300 text-sm font-medium hover:bg-gray-50'
              >
                All tasks
              </button>
              {task.project?._id && (
                <button
                  type='button'
                  onClick={() => navigate(`/company/${tenantId}/projects/${task.project._id}`)}
                  className='px-4 py-2 rounded-lg border border-gray-300 text-sm font-medium hover:bg-gray-50'
                >
                  Project overview
                </button>
              )}
              {task.project?.client?._id && (
                <button
                  type='button'
                  onClick={() => navigate(`/company/${tenantId}/clients/${task.project.client._id}`)}
                  className='px-4 py-2 rounded-lg border border-gray-300 text-sm font-medium hover:bg-gray-50'
                >
                  Client overview
                </button>
              )}
            </div>
          </div>

          <div className='grid grid-cols-1 lg:grid-cols-3 gap-5'>
            <div className='lg:col-span-2 bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden'>
              <div className='px-5 py-4 border-b border-blue-700 bg-blue-600'>
                <h2 className='text-lg font-bold text-white'>Task details</h2>
              </div>
              <div className='p-5'>
                {task.description ? (
                  <div className='mb-5'>
                    <p className='text-sm font-medium text-gray-500 mb-1'>Description</p>
                    <p className='text-sm text-gray-700 whitespace-pre-wrap'>{task.description}</p>
                  </div>
                ) : null}

                <Field label='Status'>
                  <span className={`px-2 py-1 rounded-full text-xs font-semibold ${statusClass(task.status)}`}>
                    {task.status || '—'}
                  </span>
                </Field>
                <Field label='Priority'>
                  <span className={`px-2 py-1 rounded-full text-xs font-semibold ${priorityClass(task.priority)}`}>
                    {task.priority || '—'}
                  </span>
                </Field>
                <Field label='Rating'>
                  {task.rating?.score != null ? (
                    <span className='font-semibold text-amber-700'>{task.rating.score}/5</span>
                  ) : (
                    '—'
                  )}
                </Field>
                <Field label='Due date'>{fmtDate(task.dueDate)}</Field>
                <Field label='Estimated duration'>{formatDuration(task.estimatedDurationMinutes)}</Field>
                <Field label='Assigned on'>{fmtDateTime(task.createdAt)}</Field>
                <Field label='Started at'>{fmtDateTime(task.startedAt)}</Field>
                <Field label='Completed on'>{fmtDateTime(task.completedAt)}</Field>
                <Field label='Last updated'>{fmtDateTime(task.updatedAt)}</Field>
              </div>
            </div>

            <div className='space-y-5'>
              <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-5'>
                <h3 className='text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3'>People</h3>
                <Field label='Assign to'>
                  <div>
                    <p>{task.assignedTo?.name || '—'}</p>
                    {task.assignedTo?.email ? (
                      <p className='text-xs text-gray-400 font-normal mt-0.5'>{task.assignedTo.email}</p>
                    ) : null}
                  </div>
                </Field>
                <Field label='Assigned by'>
                  <div>
                    <p>{task.assignedBy?.name || '—'}</p>
                    {task.assignedBy?.email ? (
                      <p className='text-xs text-gray-400 font-normal mt-0.5'>{task.assignedBy.email}</p>
                    ) : null}
                  </div>
                </Field>
                {task.rating?.ratedBy?.name ? (
                  <Field label='Rated by'>{task.rating.ratedBy.name}</Field>
                ) : null}
              </div>

              <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-5'>
                <h3 className='text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3'>Project</h3>
                <Field label='Name'>{task.project?.projectName || '—'}</Field>
                <Field label='Status'>{task.project?.status || '—'}</Field>
                <Field label='Department'>{task.project?.department || '—'}</Field>
                <Field label='Progress'>
                  {task.project?.progress != null ? `${task.project.progress}%` : '—'}
                </Field>
                <Field label='Client'>{task.project?.client?.clientName || '—'}</Field>
              </div>
            </div>
          </div>
        </>
      )}
    </AdminCompanyShell>
  )
}

export default TaskOverviewPage
