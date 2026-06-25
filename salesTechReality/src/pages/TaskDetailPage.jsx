import React, { useEffect, useState, useCallback } from 'react'
import api from '../api/axios'
import { useNavigate, useParams, useLocation } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'

const STATUS_OPTIONS = ['Pending', 'In Progress', 'Completed', 'Cancelled']
const SOCIAL_PLATFORMS = ['Instagram', 'Facebook', 'Twitter', 'LinkedIn', 'YouTube', 'Other']

const TaskDetailPage = ({ isMyTasks = false }) => {
  const { taskId } = useParams()
  const location = useLocation()
  const navigate = useNavigate()
  const { user, canAssignTask } = useAuth()

  const [task, setTask] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [updatingStatus, setUpdatingStatus] = useState(false)
  const [uploadingPostLink, setUploadingPostLink] = useState(false)
  const [socialUpload, setSocialUpload] = useState({ platform: '', url: '' })

  const listPath = isMyTasks ? '/my-tasks' : '/tasks'

  const fmtDateTime = (d) => {
    if (!d) return '—'
    const x = new Date(d)
    return Number.isNaN(x.getTime())
      ? '—'
      : x.toLocaleString(undefined, { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
  }

  const isImageUpload = (upload) => {
    const mime = (upload?.mimeType || '').toLowerCase()
    const name = (upload?.fileName || '').toLowerCase()
    return mime.startsWith('image/') || /\.(png|jpe?g|gif|webp|bmp|svg)$/.test(name)
  }

  const getPlatformSpecificReferenceLinks = (taskVal) => {
    const selected = (taskVal?.platform || '').toLowerCase()
    const links = Array.isArray(taskVal?.uploadedLinks) ? taskVal.uploadedLinks : []
    if (!selected) return links
    return links.filter((l) => (l?.platform || '').toLowerCase() === selected)
  }

  const getPriorityColor = (priority) => {
    switch (priority) {
      case 'Urgent': return 'bg-red-100 text-red-800'
      case 'High': return 'bg-orange-100 text-orange-800'
      case 'Medium': return 'bg-yellow-100 text-yellow-800'
      default: return 'bg-green-100 text-green-800'
    }
  }

  const getStatusColor = (status) => {
    switch (status) {
      case 'Completed': return 'bg-green-100 text-green-800'
      case 'In Progress': return 'bg-blue-100 text-blue-800'
      case 'Cancelled': return 'bg-gray-100 text-gray-800'
      default: return 'bg-gray-100 text-gray-800'
    }
  }

  const taskStatusToSocialStatus = (status) => {
    if (status === 'Completed') return 'Published'
    if (status === 'Cancelled') return 'Cancelled'
    return 'Scheduled'
  }

  const canUpdateTaskStatus = useCallback(
    (t) => {
      if (!t || !user?._id) return false
      if (t.source === 'social_media') return true
      const assigneeId = t.assignedTo?._id || t.assignedTo
      return assigneeId === user._id || canAssignTask()
    },
    [user?._id, canAssignTask]
  )

  useEffect(() => {
    let cancelled = false
    const idStr = taskId ? decodeURIComponent(taskId) : ''

    const run = async () => {
      setLoading(true)
      setError(null)

      const fromState = location.state?.task
      if (fromState && String(fromState._id) === String(idStr)) {
        if (!cancelled) {
          setTask(fromState)
          setLoading(false)
        }
        return
      }

      if (!idStr) {
        if (!cancelled) {
          setError('Invalid task')
          setLoading(false)
        }
        return
      }

      if (idStr.startsWith('social-media-')) {
        const params = {}
        if (isMyTasks && user?._id) params.employeeId = user._id
        else if (!canAssignTask() && user?._id) params.employeeId = user._id
        try {
          const res = await api.get('/tasks', { params })
          const list = Array.isArray(res.data) ? res.data : []
          const found = list.find((t) => String(t._id) === idStr)
          if (!cancelled) {
            if (found) setTask(found)
            else setError('Task not found')
          }
        } catch (e) {
          if (!cancelled) setError(e?.response?.data?.message || e.message || 'Failed to load task')
        } finally {
          if (!cancelled) setLoading(false)
        }
        return
      }

      try {
        const res = await api.get(`/tasks/${idStr}`)
        if (!cancelled) setTask(res.data)
      } catch (e) {
        if (!cancelled) setError(e?.response?.data?.message || e.message || 'Failed to load task')
      } finally {
        if (!cancelled) setLoading(false)
      }
    }

    run()
    return () => {
      cancelled = true
    }
  }, [taskId, location.state, isMyTasks, user?._id, canAssignTask])

  const handleStatusChange = async (t, newStatus) => {
    const tid = t._id
    if (!tid || !newStatus) return
    setUpdatingStatus(true)
    try {
      if (t.source === 'social_media' && t.clientId && t.postId) {
        const socialStatus = taskStatusToSocialStatus(newStatus)
        await api.put(`/social-calendars/client/${t.clientId}/posts/${t.postId}`, {
          status: socialStatus,
        })
        setTask((prev) => (prev?._id === tid ? { ...prev, status: newStatus } : prev))
      } else {
        const res = await api.put(`/tasks/${tid}`, { status: newStatus })
        setTask((prev) => res.data?.task || (prev?._id === tid ? { ...prev, status: newStatus } : prev))
      }
    } catch (err) {
      console.error('Failed to update task status:', err)
    } finally {
      setUpdatingStatus(false)
    }
  }

  const handleAddUploadedLink = async () => {
    if (!task?.source || task.source !== 'social_media') return
    if (!task.clientId || !task.postId) return
    if (!socialUpload.url.trim()) return

    setUploadingPostLink(true)
    try {
      const res = await api.post(
        `/social-calendars/client/${task.clientId}/posts/${task.postId}/upload-links`,
        {
          platform: socialUpload.platform || '',
          url: socialUpload.url.trim(),
          addedBy: user?._id || undefined,
        }
      )
      const updatedCalendar = res.data?.calendar
      const updatedPost = updatedCalendar?.posts?.find((p) => p._id === task.postId)
      if (updatedPost) {
        setTask((prev) => (prev ? { ...prev, uploadedLinks: updatedPost.uploadedLinks || [] } : prev))
      } else {
        setTask((prev) =>
          prev
            ? {
                ...prev,
                uploadedLinks: [...(prev.uploadedLinks || []), { platform: socialUpload.platform || '', url: socialUpload.url.trim() }],
              }
            : prev
        )
      }
      setSocialUpload({ platform: '', url: '' })
    } catch (err) {
      console.error('Failed to add uploaded post link:', err)
    } finally {
      setUploadingPostLink(false)
    }
  }

  if (loading) {
    return (
      <div className='p-8'>
        <p className='text-sm text-gray-600'>Loading task…</p>
      </div>
    )
  }

  if (error || !task) {
    return (
      <div className='p-8 w-full'>
        <p className='text-red-600 text-sm mb-4'>{error || 'Task not found'}</p>
        <button
          type='button'
          onClick={() => navigate(listPath)}
          className='px-4 py-2 rounded-lg border border-gray-300 text-sm font-medium hover:bg-gray-50'
        >
          Back to tasks
        </button>
      </div>
    )
  }

  return (
    <div className='p-4 md:p-8 w-full'>
      <button
        type='button'
        onClick={() => navigate(listPath)}
        className='mb-6 text-sm text-indigo-600 hover:text-indigo-800 font-medium flex items-center gap-1'
      >
        <span aria-hidden='true'>←</span> Back to tasks
      </button>

      <div className='bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden'>
        <div className='px-4 py-3 md:px-6 border-b border-blue-700 bg-blue-600'>
          <h1 className='text-lg md:text-xl font-bold text-white'>Task details</h1>
          <p className='text-sm text-blue-100 mt-0.5 line-clamp-2'>{task.title}</p>
        </div>

        <div className='p-6 max-h-[calc(100vh-12rem)] overflow-y-auto'>
          {task.description && (
            <div className='mb-6'>
              <p className='text-sm font-medium text-gray-500 mb-1'>Description</p>
              <p className='text-sm text-gray-700 whitespace-pre-wrap'>{task.description}</p>
            </div>
          )}

          <div className='space-y-3'>
            {task.source === 'social_media' && (
              <>
                <div className='py-2 border-b border-gray-100'>
                  <span className='text-sm text-gray-500'>Post Type</span>
                  <p className='text-sm font-medium text-gray-900 mt-1'>{task.contentType || '—'}</p>
                </div>
                <div className='py-2 border-b border-gray-100'>
                  <span className='text-sm text-gray-500'>Platform</span>
                  <p className='text-sm font-medium text-gray-900 mt-1'>{task.platform || '—'}</p>
                </div>
                <div className='py-2 border-b border-gray-100'>
                  <span className='text-sm text-gray-500'>Post Status</span>
                  <p className='text-sm font-medium text-gray-900 mt-1'>{task.socialPostStatus || 'Scheduled'}</p>
                </div>
                <div className='py-2 border-b border-gray-100'>
                  <span className='text-sm text-gray-500'>Post Description</span>
                  <p className='text-sm font-medium text-gray-900 mt-1 whitespace-pre-wrap'>
                    {task.description || 'No description'}
                  </p>
                </div>
                <div className='py-2 border-b border-gray-100'>
                  <span className='text-sm text-gray-500'>Reference</span>
                  <div className='mt-1'>
                    {task.referenceLink ? (
                      <a href={task.referenceLink} target='_blank' rel='noopener noreferrer' className='text-sm text-indigo-600 hover:underline break-all'>
                        {task.referenceLink}
                      </a>
                    ) : task.referenceUpload?.dataUrl ? (
                      <a href={task.referenceUpload.dataUrl} target='_blank' rel='noopener noreferrer' className='text-sm text-indigo-600 hover:underline break-all'>
                        {task.referenceUpload.fileName || 'Open uploaded reference'}
                      </a>
                    ) : (
                      <p className='text-sm text-gray-500'>No reference shared</p>
                    )}
                    {task.referenceUpload?.dataUrl && isImageUpload(task.referenceUpload) && (
                      <a href={task.referenceUpload.dataUrl} target='_blank' rel='noopener noreferrer'>
                        <img
                          src={task.referenceUpload.dataUrl}
                          alt={task.referenceUpload.fileName || 'Reference preview'}
                          className='mt-2 max-h-28 rounded border border-gray-200 object-cover'
                        />
                      </a>
                    )}
                  </div>
                </div>
                {task.contentType === 'Carousel' && Array.isArray(task.carouselItems) && task.carouselItems.length > 0 && (
                  <div className='py-2 border-b border-gray-100'>
                    <span className='text-sm text-gray-500'>Carousel Slide References</span>
                    <div className='mt-2 space-y-2'>
                      {task.carouselItems.map((slide, idx) => (
                        <div key={`slide-ref-${idx}`} className='rounded border border-gray-200 p-2'>
                          <p className='text-xs font-semibold text-gray-600'>Slide {idx + 1}</p>
                          {slide?.referenceUpload?.dataUrl ? (
                            <div className='mt-1'>
                              <a href={slide.referenceUpload.dataUrl} target='_blank' rel='noopener noreferrer' className='text-xs text-indigo-600 hover:underline break-all'>
                                {slide.referenceUpload.fileName || `Slide ${idx + 1} reference`}
                              </a>
                              {isImageUpload(slide.referenceUpload) && (
                                <a href={slide.referenceUpload.dataUrl} target='_blank' rel='noopener noreferrer'>
                                  <img
                                    src={slide.referenceUpload.dataUrl}
                                    alt={slide.referenceUpload.fileName || `Slide ${idx + 1}`}
                                    className='mt-1 max-h-24 rounded border border-gray-200 object-cover'
                                  />
                                </a>
                              )}
                            </div>
                          ) : (
                            <p className='text-xs text-gray-500 mt-1'>No reference upload</p>
                          )}
                        </div>
                      ))}
                    </div>
                  </div>
                )}
                <div className='py-2 border-b border-gray-100'>
                  <span className='text-sm text-gray-500'>Client Note</span>
                  <p className='text-sm font-medium text-gray-900 mt-1 whitespace-pre-wrap'>
                    {task.clientNote || 'No client note'}
                  </p>
                </div>
                <div className='py-2 border-b border-gray-100'>
                  <span className='text-sm text-gray-500'>Uploaded Post Links</span>
                  {getPlatformSpecificReferenceLinks(task).length > 0 ? (
                    <div className='mt-2 space-y-1.5'>
                      {getPlatformSpecificReferenceLinks(task).map((link, idx) => (
                        <div key={`${link.url}-${idx}`} className='text-sm'>
                          <span className='text-gray-500'>{link.platform || 'Platform'}: </span>
                          <a href={link.url} target='_blank' rel='noopener noreferrer' className='text-indigo-600 hover:underline break-all'>
                            {link.url}
                          </a>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p className='text-sm text-gray-500 mt-1'>No uploaded links for selected platform yet.</p>
                  )}
                  <div className='grid grid-cols-1 sm:grid-cols-3 gap-2 mt-3'>
                    <select
                      value={socialUpload.platform}
                      onChange={(e) => setSocialUpload((p) => ({ ...p, platform: e.target.value }))}
                      className='border border-gray-300 rounded-lg px-2 py-1.5 text-sm'
                    >
                      <option value=''>Select platform</option>
                      {SOCIAL_PLATFORMS.map((platform) => (
                        <option key={platform} value={platform}>{platform}</option>
                      ))}
                    </select>
                    <input
                      type='url'
                      placeholder='https://uploaded-post-link'
                      value={socialUpload.url}
                      onChange={(e) => setSocialUpload((p) => ({ ...p, url: e.target.value }))}
                      className='sm:col-span-2 border border-gray-300 rounded-lg px-2 py-1.5 text-sm'
                    />
                  </div>
                  <button
                    type='button'
                    onClick={handleAddUploadedLink}
                    disabled={uploadingPostLink || !socialUpload.url.trim()}
                    className='mt-2 px-3 py-1.5 rounded-lg text-sm font-medium border border-indigo-600 text-indigo-700 hover:bg-indigo-50 disabled:opacity-50'
                  >
                    {uploadingPostLink ? 'Adding...' : 'Add Uploaded Link'}
                  </button>
                </div>
              </>
            )}
            <div className='flex justify-between items-center py-2 border-b border-gray-100 gap-4'>
              <span className='text-sm text-gray-500 shrink-0'>Project</span>
              <span className='text-sm font-medium text-gray-900 text-right'>
                {task.project?.projectName || '—'}
                {task.source === 'social_media' && task.clientName && ` (${task.clientName})`}
              </span>
            </div>
            <div className='flex justify-between items-center py-2 border-b border-gray-100 gap-4'>
              <span className='text-sm text-gray-500'>Assign to</span>
              <span className='text-sm font-medium text-gray-900'>{task.assignedTo?.name || '—'}</span>
            </div>
            <div className='flex justify-between items-center py-2 border-b border-gray-100 gap-4'>
              <span className='text-sm text-gray-500'>Signed by</span>
              <span className='text-sm font-medium text-gray-900'>{task.assignedBy?.name || '—'}</span>
            </div>
            <div className='flex justify-between items-center py-2 border-b border-gray-100 gap-4'>
              <span className='text-sm text-gray-500'>Status</span>
              {canUpdateTaskStatus(task) ? (
                <select
                  value={task.status}
                  onChange={(e) => handleStatusChange(task, e.target.value)}
                  disabled={updatingStatus}
                  className='text-sm font-semibold rounded-lg px-2 py-1 border border-gray-300 focus:outline-none focus:ring-2 focus:ring-indigo-500 disabled:opacity-50 max-w-[11rem]'
                >
                  {STATUS_OPTIONS.map((s) => (
                    <option key={s} value={s}>{s}</option>
                  ))}
                </select>
              ) : (
                <span className={`px-2 py-1 rounded-full text-xs font-semibold ${getStatusColor(task.status)}`}>
                  {task.status}
                </span>
              )}
            </div>
            <div className='flex justify-between items-center py-2 border-b border-gray-100 gap-4'>
              <span className='text-sm text-gray-500'>Priority</span>
              <span className={`px-2 py-1 rounded-full text-xs font-semibold ${getPriorityColor(task.priority)}`}>
                {task.priority || '—'}
              </span>
            </div>
            <div className='flex justify-between items-center py-2 border-b border-gray-100 gap-4'>
              <span className='text-sm text-gray-500'>Due Date</span>
              <span className='text-sm font-medium text-gray-900'>
                {task.dueDate ? new Date(task.dueDate).toLocaleDateString() : '—'}
              </span>
            </div>
            <div className='flex justify-between items-center py-2 border-b border-gray-100 gap-4'>
              <span className='text-sm text-gray-500'>Assigned (date & time)</span>
              <span className='text-sm text-gray-700'>{task.createdAt ? fmtDateTime(task.createdAt) : '—'}</span>
            </div>
            <div className='flex justify-between items-center py-2 gap-4'>
              <span className='text-sm text-gray-500'>Updated (date & time)</span>
              <span className='text-sm text-gray-700'>{task.updatedAt ? fmtDateTime(task.updatedAt) : '—'}</span>
            </div>
          </div>
        </div>

        <div className='px-6 py-4 border-t border-gray-200 bg-gray-50'>
          <button
            type='button'
            onClick={() => navigate(listPath)}
            className='w-full sm:w-auto px-5 py-2.5 rounded-xl border border-gray-300 text-sm font-medium hover:bg-white'
          >
            Close
          </button>
        </div>
      </div>
    </div>
  )
}

export default TaskDetailPage
