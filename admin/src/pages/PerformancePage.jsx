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

const currentMonthValue = () => {
  const now = new Date()
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`
}

const formatDate = (value) => {
  if (!value) return '—'
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
}

const startOfMonth = (year, monthIndex) => {
  const d = new Date(year, monthIndex, 1)
  d.setHours(0, 0, 0, 0)
  return d
}

const endOfMonth = (year, monthIndex) => {
  const d = new Date(year, monthIndex + 1, 0)
  d.setHours(23, 59, 59, 999)
  return d
}

const getMonthRange = (monthValue) => {
  if (!/^\d{4}-\d{2}$/.test(monthValue || '')) return null
  const [y, m] = monthValue.split('-').map(Number)
  if (!y || !m) return null
  const monthIndex = m - 1
  return {
    start: startOfMonth(y, monthIndex),
    end: endOfMonth(y, monthIndex),
    label: new Date(y, monthIndex, 1).toLocaleDateString('en-IN', { month: 'long', year: 'numeric' }),
  }
}

const isDateInRange = (date, range) => {
  if (!range) return true
  if (!date) return false
  const d = new Date(date)
  if (Number.isNaN(d.getTime())) return false
  return d >= range.start && d <= range.end
}

const getTaskActivityDate = (task) =>
  task.ratedAt || task.completedAt || task.dueDate || task.createdAt || null

const StarRating = ({ rating = 0, size = 'md' }) => {
  const sizeClass = size === 'sm' ? 'w-4 h-4' : 'w-5 h-5'
  const stars = []
  for (let i = 1; i <= 5; i += 1) {
    stars.push(
      <svg
        key={i}
        className={`${sizeClass} ${i <= Math.round(Number(rating) || 0) ? 'text-amber-400' : 'text-gray-200'}`}
        fill='currentColor'
        viewBox='0 0 20 20'
        aria-hidden='true'
      >
        <path d='M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z' />
      </svg>
    )
  }
  return <div className='flex items-center gap-0.5'>{stars}</div>
}

const EmployeeAvatar = ({ employee, size = 'md', colorIndex = 0 }) => {
  const [imgError, setImgError] = useState(false)
  const name = employee?.name || '—'
  const photo = String(employee?.profilePhoto || '').trim()
  const showPhoto = Boolean(photo) && !imgError
  const sizeClass = size === 'lg' ? 'w-14 h-14 text-lg' : 'w-10 h-10 text-xs'

  if (showPhoto) {
    return (
      <img
        src={photo}
        alt={name}
        className={`${sizeClass} rounded-full object-cover shrink-0 border border-gray-200`}
        onError={() => setImgError(true)}
      />
    )
  }

  return (
    <div className={`${sizeClass} rounded-full flex items-center justify-center font-bold text-white shrink-0 ${AVATAR_COLORS[colorIndex % AVATAR_COLORS.length]}`}>
      {getInitials(name)}
    </div>
  )
}

const StatPill = ({ label, value }) => (
  <div className='rounded-xl bg-slate-50 border border-slate-100 px-3 py-2.5 text-center'>
    <p className='text-[11px] text-gray-500'>{label}</p>
    <p className='text-lg font-bold text-gray-900 mt-0.5'>{value}</p>
  </div>
)

const PerformancePage = () => {
  const { tenantId } = useParams()
  const navigate = useNavigate()
  const [employees, setEmployees] = useState([])
  const [selectedId, setSelectedId] = useState('')
  const [selectedMonth, setSelectedMonth] = useState(currentMonthValue())
  const [profile, setProfile] = useState(null)
  const [loading, setLoading] = useState(true)
  const [profileLoading, setProfileLoading] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    let cancelled = false
    const load = async () => {
      try {
        setLoading(true)
        setError('')
        const res = await api.get(`/companies/${tenantId}/employees`)
        if (!cancelled) setEmployees(res.data?.employees || [])
      } catch (err) {
        if (!cancelled) setError(err.response?.data?.message || err.message || 'Failed to load employees')
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
    if (!selectedId) {
      setProfile(null)
      return
    }
    let cancelled = false
    const loadProfile = async () => {
      try {
        setProfileLoading(true)
        setError('')
        const res = await api.get(`/companies/${tenantId}/employees/${selectedId}`)
        if (!cancelled) setProfile(res.data)
      } catch (err) {
        if (!cancelled) {
          setError(err.response?.data?.message || err.message || 'Failed to load performance')
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
  }, [tenantId, selectedId])

  const monthRange = useMemo(() => getMonthRange(selectedMonth), [selectedMonth])

  const derived = useMemo(() => {
    if (!profile?.employee) return null

    const employee = profile.employee
    const performance = employee.performance || profile.performance || {}
    const taskRating = profile.taskRatingPerformance || {}
    const allAssignedTasks = taskRating.assignedTasks?.length
      ? taskRating.assignedTasks
      : (profile.tasks || []).map((t) => ({
          taskId: t._id,
          title: t.title,
          projectName: t.project?.projectName || '',
          status: t.status,
          dueDate: t.dueDate,
          completedAt: t.completedAt,
          createdAt: t.createdAt,
          estimatedDurationMinutes: t.estimatedDurationMinutes,
          ratingScore: t.rating?.score ?? null,
          ratingComments: t.rating?.comments || '',
          ratedAt: t.rating?.ratedAt || null,
          ratedByName: t.rating?.ratedBy?.name || '',
        }))

    const assignedTasks = allAssignedTasks.filter((task) =>
      isDateInRange(getTaskActivityDate(task), monthRange),
    )

    const ratedInMonth = assignedTasks.filter((t) => t.ratingScore)
    const ratingScores = ratedInMonth
      .map((t) => Number(t.ratingScore))
      .filter((s) => Number.isFinite(s) && s > 0)
    const taskAvgRating = ratingScores.length
      ? Math.round((ratingScores.reduce((a, b) => a + b, 0) / ratingScores.length) * 10) / 10
      : null

    const reviewsInMonth = (performance.reviews || []).filter((r) =>
      isDateInRange(r.date, monthRange),
    )
    const appraisalsInMonth = (performance.appraisalHistory || []).filter((a) =>
      isDateInRange(a.date, monthRange),
    )
    const latestReview = reviewsInMonth[reviewsInMonth.length - 1] || null
    const hrRating = latestReview?.rating
      || appraisalsInMonth.slice(-1)[0]?.score
      || null

    const goalsInMonth = (performance.goals || []).filter((g) =>
      isDateInRange(g.dueDate, monthRange),
    )

    const attendanceRecords = profile?.attendance?.records || []
    const attendanceInMonth = attendanceRecords.filter((row) => isDateInRange(row.date, monthRange))
    const presentDays = attendanceInMonth.filter((row) => ['Full Day', 'Half Day'].includes(row.status)).length

    return {
      employee,
      performance,
      assignedTasks,
      ratedTaskCount: ratedInMonth.length,
      taskAvgRating,
      hrRating,
      latestReview,
      reviewsInMonth,
      goalsInMonth,
      presentDays,
    }
  }, [profile, monthRange])

  const selectedEmployee = employees.find((emp) => String(emp._id) === String(selectedId))
  const displayEmployee = derived?.employee || selectedEmployee
  const monthLabel = monthRange?.label || selectedMonth

  return (
    <AdminCompanyShell activeNav='performance'>
      <div className='mb-6 flex flex-wrap items-start justify-between gap-4'>
        <div>
          <h1 className='text-2xl font-bold text-gray-900'>Performance</h1>
          <p className='text-sm text-gray-500 mt-1'>
            Month-wise ratings, goals, and task performance · {TENANT_NAMES[tenantId]}
          </p>
        </div>
        <div className='flex items-center gap-2'>
          <label htmlFor='performance-month' className='text-sm text-gray-600'>Month</label>
          <input
            id='performance-month'
            type='month'
            value={selectedMonth}
            onChange={(e) => setSelectedMonth(e.target.value || currentMonthValue())}
            className='rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
          />
        </div>
      </div>

      {error && (
        <div className='mb-4 rounded-xl bg-red-50 border border-red-100 px-3 py-2 text-sm text-red-600'>{error}</div>
      )}

      <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-5 mb-5'>
        <label className='block text-xs font-semibold text-gray-500 mb-2'>Select employee</label>
        <div className='flex flex-col sm:flex-row gap-3 sm:items-center'>
          <select
            value={selectedId}
            onChange={(e) => setSelectedId(e.target.value)}
            disabled={loading}
            className='w-full max-w-md rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
          >
            <option value=''>Choose an employee…</option>
            {employees.map((emp) => (
              <option key={emp._id} value={emp._id}>
                {emp.name} · {emp.designation?.title || emp.department || 'Employee'}
              </option>
            ))}
          </select>
          {selectedId && displayEmployee && (
            <div className='flex items-center gap-2 text-sm text-gray-600'>
              <EmployeeAvatar employee={displayEmployee} size='md' />
              <span className='font-medium text-gray-900'>{displayEmployee.name}</span>
            </div>
          )}
        </div>
      </div>

      {!selectedId ? (
        <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-10 text-center text-sm text-gray-500'>
          Select an employee to view month-wise performance.
        </div>
      ) : profileLoading ? (
        <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-10 text-center text-sm text-gray-500'>
          Loading performance…
        </div>
      ) : !derived ? (
        <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-10 text-center text-sm text-gray-500'>
          No performance data found for this employee.
        </div>
      ) : (
        <div className='space-y-5'>
          <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-5'>
            <div className='flex flex-wrap items-center justify-between gap-3 mb-4'>
              <div className='flex items-center gap-3'>
                <EmployeeAvatar employee={derived.employee} size='lg' />
                <div>
                  <h2 className='text-lg font-semibold text-gray-900'>{derived.employee.name}</h2>
                  <p className='text-sm text-gray-500'>
                    {derived.employee.designation?.title || '—'} · {derived.employee.department || '—'}
                  </p>
                  <p className='text-xs text-gray-400 mt-0.5'>{derived.employee.email || '—'}</p>
                </div>
              </div>
              <div className='text-right'>
                <p className='text-xs font-semibold text-blue-600 uppercase tracking-wide'>Month</p>
                <p className='text-sm font-medium text-gray-900 mt-0.5'>{monthLabel}</p>
                {monthRange && (
                  <p className='text-xs text-gray-500 mt-0.5'>
                    {formatDate(monthRange.start)} – {formatDate(monthRange.end)}
                  </p>
                )}
                <button
                  type='button'
                  onClick={() => navigate(`/company/${tenantId}/employees/${selectedId}`)}
                  className='mt-2 text-sm font-medium text-blue-600 hover:text-blue-700'
                >
                  View full profile →
                </button>
              </div>
            </div>

            <div className='grid grid-cols-2 sm:grid-cols-4 gap-3 mb-5'>
              <StatPill label='Avg task rating' value={derived.taskAvgRating ?? '—'} />
              <StatPill label='Rated tasks' value={derived.ratedTaskCount} />
              <StatPill label='Tasks in month' value={derived.assignedTasks.length} />
              <StatPill label='Present days' value={derived.presentDays} />
            </div>

            <div className='grid grid-cols-1 md:grid-cols-2 gap-4'>
              <div className='rounded-xl border border-gray-100 bg-slate-50/60 p-4'>
                <p className='text-xs font-semibold text-gray-500 mb-2'>Average task rating · {monthLabel}</p>
                <div className='flex items-center gap-3'>
                  <StarRating rating={derived.taskAvgRating || 0} />
                  <span className='text-2xl font-bold text-gray-900'>
                    {derived.taskAvgRating != null ? `${derived.taskAvgRating} / 5` : '—'}
                  </span>
                </div>
                <p className='text-xs text-gray-500 mt-2'>
                  Calculated from {derived.ratedTaskCount} rated task{derived.ratedTaskCount === 1 ? '' : 's'} in this month
                </p>
              </div>
              <div className='rounded-xl border border-gray-100 bg-slate-50/60 p-4'>
                <p className='text-xs font-semibold text-gray-500 mb-2'>HR review rating · {monthLabel}</p>
                <div className='flex items-center gap-3'>
                  <StarRating rating={derived.hrRating || 0} />
                  <span className='text-2xl font-bold text-gray-900'>
                    {derived.hrRating != null ? `${derived.hrRating} / 5` : '—'}
                  </span>
                </div>
                {derived.latestReview ? (
                  <p className='text-xs text-gray-500 mt-2'>
                    Review: {formatDate(derived.latestReview.date)}
                    {derived.latestReview.comments ? ` — ${derived.latestReview.comments}` : ''}
                  </p>
                ) : (
                  <p className='text-xs text-gray-500 mt-2'>No HR review in this month</p>
                )}
              </div>
            </div>
          </div>

          <div className='bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden'>
            <div className='px-5 py-4 border-b border-gray-100'>
              <h3 className='text-sm font-semibold text-gray-900'>Task ratings · {monthLabel}</h3>
              <p className='text-xs text-gray-500 mt-0.5'>
                {derived.assignedTasks.length} task{derived.assignedTasks.length === 1 ? '' : 's'} in this month
              </p>
            </div>
            {derived.assignedTasks.length ? (
              <div className='overflow-x-auto'>
                <table className='min-w-full text-sm'>
                  <thead className='text-left text-xs uppercase tracking-wide text-gray-500 border-b border-gray-100 bg-slate-50'>
                    <tr>
                      <th className='px-4 py-3 font-semibold'>Task</th>
                      <th className='px-4 py-3 font-semibold'>Project</th>
                      <th className='px-4 py-3 font-semibold'>Status</th>
                      <th className='px-4 py-3 font-semibold'>Date</th>
                      <th className='px-4 py-3 font-semibold'>Rating</th>
                    </tr>
                  </thead>
                  <tbody className='divide-y divide-gray-50'>
                    {derived.assignedTasks.map((task) => (
                      <tr key={task.taskId} className='hover:bg-slate-50/70'>
                        <td className='px-4 py-3'>
                          <p className='font-medium text-gray-900'>{task.title || '—'}</p>
                          {task.ratingComments && (
                            <p className='text-xs text-gray-500 mt-1 line-clamp-2'>&ldquo;{task.ratingComments}&rdquo;</p>
                          )}
                        </td>
                        <td className='px-4 py-3 text-gray-600'>{task.projectName || '—'}</td>
                        <td className='px-4 py-3 text-gray-600'>{task.status || '—'}</td>
                        <td className='px-4 py-3 text-gray-600 whitespace-nowrap'>
                          {formatDate(task.ratedAt || task.completedAt || task.dueDate)}
                        </td>
                        <td className='px-4 py-3'>
                          {task.ratingScore != null ? (
                            <div>
                              <div className='flex items-center gap-2'>
                                <StarRating rating={task.ratingScore} size='sm' />
                                <span className='text-sm font-bold text-gray-900'>{task.ratingScore}/5</span>
                              </div>
                              {task.ratedByName && (
                                <p className='text-[11px] text-gray-400 mt-1'>
                                  by {task.ratedByName}
                                  {task.ratedAt ? ` · ${formatDate(task.ratedAt)}` : ''}
                                </p>
                              )}
                            </div>
                          ) : (
                            <span className='text-xs text-gray-400'>Not rated</span>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <p className='p-8 text-sm text-gray-500 text-center'>No tasks found for {monthLabel}.</p>
            )}
          </div>

          {derived.reviewsInMonth.length > 0 && (
            <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-5'>
              <h3 className='text-sm font-semibold text-gray-900 mb-4'>HR reviews · {monthLabel}</h3>
              <div className='space-y-3'>
                {derived.reviewsInMonth.map((r, index) => (
                  <div key={r._id || index} className='flex items-start justify-between gap-3 border-b border-gray-50 pb-3 last:border-0'>
                    <div className='min-w-0'>
                      <p className='text-sm font-medium text-gray-900'>{r.period || 'Review'}</p>
                      <p className='text-xs text-gray-400 mt-0.5'>
                        {[r.reviewer, formatDate(r.date)].filter(Boolean).join(' · ')}
                      </p>
                      {r.comments && <p className='text-xs text-gray-500 mt-1'>{r.comments}</p>}
                    </div>
                    <div className='shrink-0 text-right'>
                      <StarRating rating={r.rating || 0} size='sm' />
                      <p className='text-sm font-bold text-gray-900 mt-1'>{r.rating ?? '—'}/5</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {derived.goalsInMonth.length > 0 && (
            <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-5'>
              <h3 className='text-sm font-semibold text-gray-900 mb-4'>Goals · {monthLabel}</h3>
              <ul className='space-y-2'>
                {derived.goalsInMonth.map((goal, index) => (
                  <li key={goal._id || index} className='text-sm text-gray-700 border-b border-gray-50 pb-2 last:border-0'>
                    {goal.title || goal.name || 'Goal'}
                    {goal.status ? ` · ${goal.status}` : ''}
                    {goal.dueDate ? ` · due ${formatDate(goal.dueDate)}` : ''}
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      )}
    </AdminCompanyShell>
  )
}

export default PerformancePage
