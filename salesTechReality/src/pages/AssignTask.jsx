import React, { useEffect, useMemo, useState } from 'react'
import api from '../api/axios'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'

const PRIORITY_OPTIONS = ['Low', 'Medium', 'High', 'Urgent']
const RECURRENCE_TYPES = [
  { value: 'daily', label: 'Day(s)' },
  { value: 'weekly', label: 'Week(s)' },
  { value: 'monthly', label: 'Month(s)' },
]

const AVAILABILITY_STYLES = {
  available: 'bg-green-100 text-green-800 border-green-200',
  moderate: 'bg-yellow-100 text-yellow-800 border-yellow-200',
  busy: 'bg-orange-100 text-orange-800 border-orange-200',
  allocated: 'bg-red-100 text-red-800 border-red-200',
  on_leave: 'bg-red-100 text-red-800 border-red-200',
  absent: 'bg-red-100 text-red-800 border-red-200',
  checked_out: 'bg-gray-100 text-gray-700 border-gray-200',
  inactive: 'bg-gray-100 text-gray-500 border-gray-200',
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

const AssignTask = () => {
  const { user, canAssignTask } = useAuth()
  const [searchParams] = useSearchParams()
  const projectIdFromUrl = searchParams.get('projectId')
  const scopeFromUrl = searchParams.get('scope')
  const selfFromUrl = searchParams.get('self')
  const navigate = useNavigate()

  const [projects, setProjects] = useState([])
  const [employees, setEmployees] = useState([])
  const [availabilityMap, setAvailabilityMap] = useState({})
  const [availabilityLoading, setAvailabilityLoading] = useState(false)
  const [form, setForm] = useState({
    project: projectIdFromUrl || '',
    title: '',
    description: '',
    assignedTo: '',
    assignedToList: [],
    priority: 'Medium',
    dueDate: '',
    durationHours: '',
    durationMinutes: '',
    isRecurring: false,
    recurrenceType: 'daily',
    recurrenceInterval: 1,
    recurrenceStartDate: new Date().toISOString().slice(0, 10),
    recurrenceEndDate: '',
  })
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  const availabilityDate = form.dueDate || form.recurrenceStartDate || new Date().toISOString().slice(0, 10)
  const isSelfTaskMode = !canAssignTask()
  const restrictProjectsToMyMembership =
    isSelfTaskMode || scopeFromUrl === 'my-projects' || selfFromUrl === '1'

  useEffect(() => {
    const fetchProjects = async () => {
      try {
        const endpoint = restrictProjectsToMyMembership ? '/projects/my-projects' : '/projects'
        const params = restrictProjectsToMyMembership && user?._id ? { employeeId: user._id } : undefined
        const res = await api.get(endpoint, { params })
        const list = Array.isArray(res.data) ? res.data : res.data?.data || res.data?.projects || []
        setProjects(Array.isArray(list) ? list : [])
      } catch (err) {
        console.error('Failed to fetch projects:', err)
      }
    }
    const fetchEmployees = async () => {
      try {
        const res = await api.get('/employees')
        const list = Array.isArray(res.data) ? res.data : res.data?.data || []
        setEmployees(Array.isArray(list) ? list : [])
      } catch (err) {
        console.error('Failed to fetch employees:', err)
      }
    }
    fetchProjects()
    fetchEmployees()
  }, [restrictProjectsToMyMembership, user?._id])

  useEffect(() => {
    if (projectIdFromUrl) setForm((f) => ({ ...f, project: projectIdFromUrl }))
  }, [projectIdFromUrl])

  useEffect(() => {
    if (!form.project) return
    const exists = projects.some((p) => String(p._id) === String(form.project))
    if (!exists) {
      setForm((f) => ({ ...f, project: '' }))
    }
  }, [projects, form.project])

  useEffect(() => {
    let cancelled = false
    const fetchAvailability = async () => {
      setAvailabilityLoading(true)
      try {
        const res = await api.get('/employees/availability', { params: { date: availabilityDate } })
        const list = Array.isArray(res.data) ? res.data : []
        const map = {}
        list.forEach((item) => {
          map[String(item.employeeId)] = item
        })
        if (!cancelled) setAvailabilityMap(map)
      } catch (err) {
        console.error('Failed to fetch employee availability:', err)
        if (!cancelled) setAvailabilityMap({})
      } finally {
        if (!cancelled) setAvailabilityLoading(false)
      }
    }
    fetchAvailability()
    return () => {
      cancelled = true
    }
  }, [availabilityDate])

  const selectedAssignees = isSelfTaskMode
    ? (user?._id ? [user._id] : [])
    : (form.assignedToList.length ? form.assignedToList : (form.assignedTo ? [form.assignedTo] : []))
  const selectedAvailabilityCards = selectedAssignees
    .map((employeeId) => availabilityMap[String(employeeId)])
    .filter(Boolean)
  const selectedAssigneeDetails = selectedAssignees
    .map((id) => employees.find((emp) => String(emp._id) === String(id)))
    .filter(Boolean)

  useEffect(() => {
    if (!form.assignedTo) return
    const avail = availabilityMap[String(form.assignedTo)]
    if (avail?.isAssignable === false) {
      setForm((f) => ({ ...f, assignedTo: '' }))
    }
  }, [availabilityMap, form.assignedTo])

  useEffect(() => {
    if (!isSelfTaskMode || !user?._id) return
    setForm((f) => ({
      ...f,
      assignedTo: user._id,
      assignedToList: [user._id],
    }))
  }, [isSelfTaskMode, user?._id])

  const totalDurationMinutes = useMemo(() => {
    const hours = Number(form.durationHours) || 0
    const minutes = Number(form.durationMinutes) || 0
    const total = hours * 60 + minutes
    return total > 0 ? total : null
  }, [form.durationHours, form.durationMinutes])

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!user?._id) {
      setError('You must be logged in to assign tasks')
      return
    }
    if (!form.project || !form.title || !selectedAssignees.length) {
      setError('Project, title, and assignee are required')
      return
    }
    if (!totalDurationMinutes) {
      setError('Please enter a time duration for this task')
      return
    }
    const blockedAssignee = selectedAssignees.find((employeeId) => availabilityMap[String(employeeId)]?.isAssignable === false)
    if (blockedAssignee) {
      const name = employees.find((emp) => String(emp._id) === String(blockedAssignee))?.name || 'Selected employee'
      setError(`${name} is not available for assignment right now.`)
      return
    }
    setLoading(true)
    setError(null)
    try {
      await api.post('/tasks', {
        project: form.project,
        title: form.title,
        description: form.description || undefined,
        assignedTo: selectedAssignees[0],
        assignedToList: selectedAssignees,
        assignedBy: user._id,
        priority: form.priority,
        dueDate: form.dueDate || undefined,
        estimatedDurationMinutes: totalDurationMinutes,
        isRecurring: form.isRecurring,
        recurrenceEnabled: form.isRecurring,
        recurrenceType: form.isRecurring ? form.recurrenceType : undefined,
        recurrenceInterval: form.isRecurring ? Number(form.recurrenceInterval) || 1 : undefined,
        recurrenceStartDate: form.isRecurring ? form.recurrenceStartDate || form.dueDate || undefined : undefined,
        recurrenceEndDate: form.isRecurring ? form.recurrenceEndDate || undefined : undefined,
      })
      navigate(projectIdFromUrl ? '/projects' : '/tasks')
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Error assigning task')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className='p-8 w-full'>
      <div className='mb-8'>
        <h1 className='text-2xl font-bold text-gray-900'>{isSelfTaskMode ? 'Create My Task' : 'Assign Task'}</h1>
        <p className='text-gray-600 mt-1 text-sm'>
          {isSelfTaskMode
            ? 'Create and manage your own task timeline.'
            : 'Assign a task with duration. Employees can handle multiple tasks at once.'}
        </p>
      </div>

      <form onSubmit={handleSubmit} className='bg-white rounded-xl shadow-lg border border-gray-100 p-6 space-y-4'>
        <div>
          <label className='block text-sm font-medium text-gray-700 mb-1'>Project *</label>
          <select
            value={form.project}
            onChange={(e) => setForm((f) => ({ ...f, project: e.target.value }))}
            required
            className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
          >
            <option value=''>Select project</option>
            {projects.map((p) => (
              <option key={p._id} value={p._id}>
                {p.projectName} {p.client?.clientName ? `(${p.client.clientName})` : ''}
              </option>
            ))}
          </select>
        </div>

        <div>
          <label className='block text-sm font-medium text-gray-700 mb-1'>Task Title *</label>
          <input
            type='text'
            value={form.title}
            onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}
            required
            placeholder='Enter task title'
            className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
          />
        </div>

        <div>
          <label className='block text-sm font-medium text-gray-700 mb-1'>Description</label>
          <textarea
            value={form.description}
            onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
            rows={3}
            placeholder='Task description...'
            className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
          />
        </div>

        <div>
          <div className='flex items-center justify-between gap-2 mb-1'>
            <label className='block text-sm font-medium text-gray-700'>
              {isSelfTaskMode ? 'Assignee' : 'Assign To *'}
            </label>
            <span className='text-xs text-gray-500'>
              {availabilityLoading ? 'Checking availability…' : `Availability for ${availabilityDate}`}
            </span>
          </div>
          {isSelfTaskMode ? (
            <div className='w-full border border-gray-200 bg-gray-50 rounded-lg px-3 py-2 text-sm text-gray-700'>
              {user?.name || 'Current user'}
            </div>
          ) : (
            <>
              <select
                value={form.assignedTo}
                onChange={(e) => {
                  const value = e.target.value
                  setForm((f) => ({
                    ...f,
                    assignedTo: value,
                    assignedToList: value ? Array.from(new Set([...f.assignedToList, value])) : f.assignedToList,
                  }))
                }}
                className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
              >
                <option value=''>Pick employee to add</option>
                {employees.map((emp) => {
                  const avail = availabilityMap[String(emp._id)]
                  const unavailable = avail?.isAssignable === false
                  const remaining = avail?.remainingTimeLabel
                  const suffix = avail
                    ? unavailable
                      ? ` — ${avail.availabilityLabel}${remaining ? ` (${remaining} left)` : ''}`
                      : ` — ${avail.availabilityLabel}`
                    : ''
                  return (
                    <option key={emp._id} value={emp._id} disabled={unavailable}>
                      {emp.name}
                      {emp.designation?.title ? ` (${emp.designation.title})` : ''}
                      {suffix}
                      {unavailable ? ' [Unavailable]' : ''}
                    </option>
                  )
                })}
              </select>
              <div className='mt-2 flex flex-wrap gap-2'>
                {selectedAssigneeDetails.length === 0 ? (
                  <span className='text-xs text-gray-500'>No assignees selected yet.</span>
                ) : (
                  selectedAssigneeDetails.map((emp) => (
                    <span key={emp._id} className='inline-flex items-center gap-2 px-2.5 py-1 rounded-full bg-indigo-50 text-indigo-700 text-xs border border-indigo-200'>
                      {emp.name}
                      <button
                        type='button'
                        onClick={() => setForm((f) => ({
                          ...f,
                          assignedToList: f.assignedToList.filter((id) => String(id) !== String(emp._id)),
                          assignedTo: String(f.assignedTo) === String(emp._id) ? '' : f.assignedTo,
                        }))}
                        className='text-indigo-700 hover:text-indigo-900'
                        aria-label={`Remove ${emp.name}`}
                      >
                        ×
                      </button>
                    </span>
                  ))
                )}
              </div>
            </>
          )}

          {selectedAvailabilityCards.length > 0 && (
            <div className='mt-3 space-y-3'>
              {selectedAvailabilityCards.map((selectedAvailability) => (
                <div
                  key={selectedAvailability.employeeId || selectedAvailability.name}
                  className={`rounded-lg border p-4 ${AVAILABILITY_STYLES[selectedAvailability.availabilityStatus] || AVAILABILITY_STYLES.available}`}
                >
                  <div className='flex flex-wrap items-start justify-between gap-2'>
                    <div>
                      <p className='text-sm font-semibold'>{selectedAvailability.name}</p>
                      <p className='text-xs mt-0.5 opacity-90'>{selectedAvailability.availabilityLabel}</p>
                    </div>
                    <span className='text-xs font-medium px-2 py-1 rounded-full bg-white/70 border border-current/20'>
                      {selectedAvailability.openTaskCount} open task{selectedAvailability.openTaskCount === 1 ? '' : 's'}
                    </span>
                  </div>
                  <dl className='mt-3 grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs'>
                    <div>
                      <dt className='opacity-75'>Working hours</dt>
                      <dd className='font-medium mt-0.5'>{selectedAvailability.workingHours || '—'}</dd>
                    </div>
                    <div>
                      <dt className='opacity-75'>Task time left</dt>
                      <dd className='font-medium mt-0.5'>
                        {selectedAvailability.remainingTimeLabel || formatDuration(selectedAvailability.remainingMinutes) || '—'}
                      </dd>
                    </div>
                    <div>
                      <dt className='opacity-75'>Attendance</dt>
                      <dd className='font-medium mt-0.5'>
                        {selectedAvailability.attendanceToday?.status || (selectedAvailability.onLeave ? 'On leave' : 'Not checked in')}
                      </dd>
                    </div>
                    <div>
                      <dt className='opacity-75'>Assignable</dt>
                      <dd className='font-medium mt-0.5'>
                        {selectedAvailability.isAssignable === false ? 'No — unavailable today' : 'Yes'}
                      </dd>
                    </div>
                  </dl>
                  {selectedAvailability.activeTask && (
                    <div className='mt-3 pt-3 border-t border-current/20'>
                      <p className='text-xs font-semibold mb-1.5'>Current task</p>
                      <div className='flex justify-between gap-2 text-xs'>
                        <span className='truncate'>{selectedAvailability.activeTask.title}</span>
                        <span className='shrink-0 font-medium'>
                          {selectedAvailability.activeTask.remainingTimeLabel || formatDuration(selectedAvailability.activeTask.remainingMinutes)} left
                        </span>
                      </div>
                      <p className='text-[10px] mt-1 opacity-80'>Status: {selectedAvailability.activeTask.status}</p>
                    </div>
                  )}
                  {selectedAvailability.openTasks?.length > 0 && (
                    <div className='mt-3 pt-3 border-t border-current/20'>
                      <p className='text-xs font-semibold mb-1.5'>Open tasks</p>
                      <ul className='space-y-1 text-xs'>
                        {selectedAvailability.openTasks.slice(0, 4).map((t) => (
                          <li key={t._id} className='flex justify-between gap-2'>
                            <span className='truncate'>{t.title}</span>
                            <span className='shrink-0 opacity-80'>
                              {t.remainingTimeLabel || formatDuration(t.remainingMinutes)} left
                            </span>
                          </li>
                        ))}
                      </ul>
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>

        <div className='grid grid-cols-1 sm:grid-cols-2 gap-4'>
          <div>
            <label className='block text-sm font-medium text-gray-700 mb-1'>Priority</label>
            <select
              value={form.priority}
              onChange={(e) => setForm((f) => ({ ...f, priority: e.target.value }))}
              className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
            >
              {PRIORITY_OPTIONS.map((p) => (
                <option key={p} value={p}>{p}</option>
              ))}
            </select>
          </div>
          <div>
            <label className='block text-sm font-medium text-gray-700 mb-1'>Due Date</label>
            <input
              type='date'
              value={form.dueDate}
              onChange={(e) => setForm((f) => ({ ...f, dueDate: e.target.value }))}
              className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
            />
          </div>
        </div>

        <div>
          <label className='block text-sm font-medium text-gray-700 mb-1'>Time Duration *</label>
          <p className='text-xs text-gray-500 mb-2'>How long should this task take to complete?</p>
          <div className='grid grid-cols-2 sm:grid-cols-3 gap-3 items-end'>
            <div>
              <label className='block text-xs text-gray-500 mb-1'>Hours</label>
              <input
                type='number'
                min='0'
                max='999'
                value={form.durationHours}
                onChange={(e) => setForm((f) => ({ ...f, durationHours: e.target.value }))}
                placeholder='0'
                className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
              />
            </div>
            <div>
              <label className='block text-xs text-gray-500 mb-1'>Minutes</label>
              <input
                type='number'
                min='0'
                max='59'
                value={form.durationMinutes}
                onChange={(e) => setForm((f) => ({ ...f, durationMinutes: e.target.value }))}
                placeholder='0'
                className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
              />
            </div>
            <div className='text-sm text-gray-600 pb-2'>
              Total: <span className='font-semibold text-gray-900'>{totalDurationMinutes ? formatDuration(totalDurationMinutes) : '—'}</span>
            </div>
          </div>
        </div>

        <div className='rounded-lg border border-gray-200 p-4 bg-gray-50'>
          <div className='flex items-center justify-between gap-3'>
            <div>
              <p className='text-sm font-semibold text-gray-800'>Auto Task</p>
              <p className='text-xs text-gray-600 mt-0.5'>
                Create a recurring task for this employee automatically.
              </p>
            </div>
            <button
              type='button'
              onClick={() => setForm((f) => ({ ...f, isRecurring: !f.isRecurring }))}
              className={`px-3 py-1.5 rounded-md text-xs font-medium border ${
                form.isRecurring
                  ? 'bg-indigo-600 text-white border-indigo-600'
                  : 'bg-white text-gray-700 border-gray-300'
              }`}
            >
              {form.isRecurring ? 'Enabled' : 'Enable'}
            </button>
          </div>

          {form.isRecurring && (
            <div className='grid grid-cols-1 sm:grid-cols-3 gap-3 mt-4'>
              <div>
                <label className='block text-sm font-medium text-gray-700 mb-1'>Repeat Every</label>
                <input
                  type='number'
                  min='1'
                  value={form.recurrenceInterval}
                  onChange={(e) => setForm((f) => ({ ...f, recurrenceInterval: e.target.value }))}
                  className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
                />
              </div>
              <div>
                <label className='block text-sm font-medium text-gray-700 mb-1'>Frequency</label>
                <select
                  value={form.recurrenceType}
                  onChange={(e) => setForm((f) => ({ ...f, recurrenceType: e.target.value }))}
                  className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
                >
                  {RECURRENCE_TYPES.map((opt) => (
                    <option key={opt.value} value={opt.value}>
                      {opt.label}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className='block text-sm font-medium text-gray-700 mb-1'>Start Date</label>
                <input
                  type='date'
                  value={form.recurrenceStartDate}
                  onChange={(e) => setForm((f) => ({ ...f, recurrenceStartDate: e.target.value }))}
                  className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
                />
              </div>
              <div className='sm:col-span-2'>
                <label className='block text-sm font-medium text-gray-700 mb-1'>End Date (Optional)</label>
                <input
                  type='date'
                  value={form.recurrenceEndDate}
                  onChange={(e) => setForm((f) => ({ ...f, recurrenceEndDate: e.target.value }))}
                  className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
                />
              </div>
            </div>
          )}
        </div>

        {error && <p className='text-red-600 text-sm'>{error}</p>}

        <div className='flex gap-3 pt-2'>
          <button
            type='submit'
            disabled={loading}
            className='bg-indigo-600 hover:bg-indigo-700 text-white px-6 py-2 rounded-lg font-medium text-sm disabled:opacity-50 disabled:cursor-not-allowed'
          >
            {loading
              ? 'Saving...'
              : form.isRecurring
                ? (selectedAssignees.length > 1 ? 'Assign Auto Tasks' : 'Assign Auto Task')
                : (selectedAssignees.length > 1 ? 'Assign Tasks' : (isSelfTaskMode ? 'Create Task' : 'Assign Task'))}
          </button>
          <button
            type='button'
            onClick={() => navigate(-1)}
            className='px-6 py-2 border border-gray-300 rounded-lg text-sm font-medium hover:bg-gray-50'
          >
            Cancel
          </button>
        </div>
      </form>
    </div>
  )
}

export default AssignTask
