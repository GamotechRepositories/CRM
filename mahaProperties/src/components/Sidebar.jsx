import React, { useEffect, useMemo, useRef, useState } from 'react'
import Logo from '../assets/log.png'
import { useNavigate, useLocation } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import api from '../api/axios'
import { getSidebarNav } from '../config/sidebarNav'
import { getDashboardKind } from '../config/dashboardRoutes'
import { showsMyTeamForUser } from '../config/authPermissions'
import { SidebarSectionIcon } from '../config/sidebarIcons'
import { SettingsIcon, LogoutIcon } from './Icons'
import { getAllReporteeIds, refEmployeeId } from '../utils/reportingHierarchy'
import {
  enableTaskAssignmentAlerts,
  initTaskAssignmentAudio,
  initTaskApprovalAudio,
  initTaskSucceedAudio,
  initTaskRejectedAudio,
  notifyNewTaskAssigned,
  notifyTaskWaitingApproval,
  notifyTaskApproved,
  notifyTaskRejected,
} from '../utils/taskAssignmentAlert'
import {
  connectRealtimeSocket,
  getTenantId,
  onTaskChanged,
} from '../utils/realtimeSocket'

const getDismissedApprovalIds = (userId) => {
  if (!userId || typeof window === 'undefined') return new Set()
  try {
    const raw = window.localStorage.getItem(`crm_dismissed_approval_tasks_${userId}`)
    const parsed = raw ? JSON.parse(raw) : []
    return new Set(Array.isArray(parsed) ? parsed.map(String) : [])
  } catch {
    return new Set()
  }
}

const saveDismissedApprovalIds = (userId, idsSet) => {
  if (!userId || typeof window === 'undefined') return
  try {
    const arr = Array.from(idsSet).slice(-500)
    window.localStorage.setItem(`crm_dismissed_approval_tasks_${userId}`, JSON.stringify(arr))
  } catch {
    // Ignore storage errors
  }
}

const MenuToggleIcon = () => (
  <svg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' strokeWidth={1.5} stroke='currentColor' className='size-6'>
    <path strokeLinecap='round' strokeLinejoin='round' d='M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5' />
  </svg>
)

const ChevronIcon = ({ open }) => (
  <svg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' strokeWidth={2} stroke='currentColor' className={`size-4 transition-transform ${open ? 'rotate-90' : ''}`}>
    <path strokeLinecap='round' strokeLinejoin='round' d='m8.25 4.5 7.5 7.5-7.5 7.5' />
  </svg>
)

const isPathActive = (pathname, path) => {
  if (pathname === path) return true
  if (path !== '/' && pathname.startsWith(`${path}/`)) return true
  return false
}

const Sidebar = ({ isOpen = true, onToggle }) => {
  const navigate = useNavigate()
  const location = useLocation()
  const { user, logout, hasFullAccess, canViewProjects, getSidebarSections, getDashboardPath } = useAuth()
  const fullAccess = hasFullAccess()
  const canViewProjectsValue = canViewProjects()
  const allowedSections = getSidebarSections()
  const dashboardPath = getDashboardPath()
  const isTeamLeader = getDashboardKind(user) === 'team_leader'
  const showsMyTeam = showsMyTeamForUser(user)

  const sections = useMemo(
    () => getSidebarNav({ fullAccess, canViewProjects: canViewProjectsValue, allowedSections, dashboardPath, isTeamLeader, showsMyTeam }),
    [fullAccess, canViewProjectsValue, allowedSections, dashboardPath, isTeamLeader, showsMyTeam]
  )

  const defaultExpanded = useMemo(() => {
    const activeGroup = sections.find(
      (s) => s.type === 'group' && s.children.some((c) => isPathActive(location.pathname, c.path))
    )
    if (activeGroup) return { [activeGroup.id]: true }
    return fullAccess ? { crm: true } : { workspace: true }
  }, [sections, location.pathname, fullAccess])

  const [expanded, setExpanded] = useState(defaultExpanded)
  const [pendingMyTasksCount, setPendingMyTasksCount] = useState(0)
  const [pendingApprovalsCount, setPendingApprovalsCount] = useState(0)
  const [approvalPopupQueue, setApprovalPopupQueue] = useState([])
  const [alertsEnabled, setAlertsEnabled] = useState(false)
  const alertsEnabledRef = useRef(false)
  const navigateRef = useRef(navigate)
  const notifiedApprovalIdsRef = useRef(new Set())
  const employeesCacheRef = useRef(null)

  const dismissApprovalPopup = () => {
    if (user?._id && approvalPopupQueue.length > 0) {
      const dismissed = getDismissedApprovalIds(user._id)
      approvalPopupQueue.forEach((item) => {
        if (item.taskId) dismissed.add(String(item.taskId))
      })
      saveDismissedApprovalIds(user._id, dismissed)
    }
    setApprovalPopupQueue([])
  }

  useEffect(() => {
    alertsEnabledRef.current = alertsEnabled
  }, [alertsEnabled])

  useEffect(() => {
    navigateRef.current = navigate
  }, [navigate])

  useEffect(() => {
    initTaskAssignmentAudio()
    initTaskApprovalAudio()
    initTaskSucceedAudio()
    initTaskRejectedAudio()
  }, [])

  useEffect(() => {
    const activeGroup = sections.find(
      (s) => s.type === 'group' && s.children.some((c) => isPathActive(location.pathname, c.path))
    )
    if (!activeGroup) return
    setExpanded((prev) => {
      if (prev[activeGroup.id] && Object.keys(prev).length === 1) return prev
      return { [activeGroup.id]: true }
    })
  }, [location.pathname, sections])

  useEffect(() => {
    const unlockAlerts = () => {
      setAlertsEnabled(true)
      enableTaskAssignmentAlerts()
    }
    window.addEventListener('click', unlockAlerts, { once: true })
    window.addEventListener('keydown', unlockAlerts, { once: true })
    return () => {
      window.removeEventListener('click', unlockAlerts)
      window.removeEventListener('keydown', unlockAlerts)
    }
  }, [])

  useEffect(() => {
    let cancelled = false
    let previousPendingCount = null
    let inFlight = false
    let refreshTimer = null
    employeesCacheRef.current = null

    const fetchPendingMyTasks = async ({ playAlert = false } = {}) => {
      if (!user?._id) {
        if (!cancelled) {
          setPendingMyTasksCount(0)
          setPendingApprovalsCount(0)
          setApprovalPopupQueue([])
        }
        return
      }
      if (inFlight) return
      inFlight = true
      try {
        const [myTasksRes, allTasksRes, empRes] = await Promise.all([
          api.get('/tasks', { params: { employeeId: user._id } }),
          api.get('/tasks').catch(() => ({ data: [] })),
          employeesCacheRef.current
            ? Promise.resolve({ data: employeesCacheRef.current })
            : api.get('/employees').catch(() => ({ data: [] })),
        ])

        const list = Array.isArray(myTasksRes.data) ? myTasksRes.data : []
        const pendingCount = list.filter((task) => String(task?.status || '').trim() === 'Pending').length
        if (
          playAlert &&
          alertsEnabledRef.current &&
          previousPendingCount !== null &&
          pendingCount > previousPendingCount
        ) {
          notifyNewTaskAssigned({
            pendingCount,
            navigate: navigateRef.current,
          })
        }
        previousPendingCount = pendingCount
        if (!cancelled) setPendingMyTasksCount(pendingCount)

        const rawEmployees = Array.isArray(empRes.data)
          ? empRes.data
          : empRes.data?.data || []
        if (rawEmployees.length > 0) {
          employeesCacheRef.current = rawEmployees
        }
        const reporteeIds = getAllReporteeIds(rawEmployees, user._id)
        const allTasks = (Array.isArray(allTasksRes.data) ? allTasksRes.data : []).filter(
          (t) => !String(t?._id || '').startsWith('social-media-')
        )

        const managerPendingApprovalTasks = allTasks.filter((t) => {
          if (t.approvalStatus !== 'Pending') return false
          const assigneeId = refEmployeeId(t.assignedTo)
          const assignerId = refEmployeeId(t.assignedBy)
          if (assignerId && String(assignerId) === String(user._id)) return false

          const directMgrAssignee = refEmployeeId(t.assignedTo?.reportingManager)
          const directMgrAssigner = refEmployeeId(t.assignedBy?.reportingManager)
          if (
            directMgrAssignee === String(user._id) ||
            directMgrAssigner === String(user._id) ||
            reporteeIds.has(assigneeId) ||
            reporteeIds.has(assignerId) ||
            fullAccess
          ) {
            return true
          }
          return false
        })

        if (!cancelled) {
          setPendingApprovalsCount(managerPendingApprovalTasks.length)
          const dismissed = getDismissedApprovalIds(user._id)
          const unseenApprovalTasks = managerPendingApprovalTasks.filter(
            (t) => !dismissed.has(String(t._id))
          )

          let newlyNotified = null
          for (const t of unseenApprovalTasks) {
            const tid = String(t._id)
            if (!notifiedApprovalIdsRef.current.has(tid)) {
              notifiedApprovalIdsRef.current.add(tid)
              if (!newlyNotified) newlyNotified = t
            }
          }

          if (newlyNotified) {
            notifyTaskWaitingApproval({
              title: newlyNotified.title,
              navigate: navigateRef.current,
            })
          }

          const activePendingIds = new Set(managerPendingApprovalTasks.map((t) => String(t._id)))
          setApprovalPopupQueue((prev) => {
            const byId = new Map()
            for (const t of unseenApprovalTasks) {
              const tid = String(t._id)
              byId.set(tid, {
                id: tid,
                taskId: tid,
                title: t.title || 'New Task',
                employeeName: t.assignedTo?.name || t.assignedBy?.name || 'Employee',
                projectName: t.project?.projectName || '',
              })
            }
            for (const existing of prev) {
              const tid = String(existing.taskId || '')
              if (tid && !byId.has(tid) && activePendingIds.has(tid) && !dismissed.has(tid)) {
                byId.set(tid, existing)
              }
            }
            return Array.from(byId.values())
          })
        }
      } catch {
        if (!cancelled) setPendingMyTasksCount(0)
      } finally {
        inFlight = false
      }
    }

    const scheduleRefresh = (opts) => {
      if (refreshTimer) window.clearTimeout(refreshTimer)
      refreshTimer = window.setTimeout(() => {
        fetchPendingMyTasks(opts)
      }, 150)
    }

    fetchPendingMyTasks()
    connectRealtimeSocket(user._id, { tenantId: getTenantId() })
    const unsubscribe = onTaskChanged((payload) => {
      const reason = String(payload?.reason || '')

      if (reason === 'approval_required') {
        const tid = payload?.taskId ? String(payload.taskId) : ''
        const dismissed = getDismissedApprovalIds(user._id)
        if (!tid || !dismissed.has(tid)) {
          if (!tid || !notifiedApprovalIdsRef.current.has(tid)) {
            if (tid) notifiedApprovalIdsRef.current.add(tid)
            notifyTaskWaitingApproval({
              title: payload?.title,
              navigate: navigateRef.current,
            })
          }
          setApprovalPopupQueue((prev) => {
            if (tid && prev.some((item) => String(item.taskId) === tid)) return prev
            return [
              {
                id: tid || `approval-${Date.now()}`,
                taskId: tid,
                title: payload?.title || 'New Task',
                employeeName: payload?.employeeName || payload?.assignedByName || 'Employee',
                projectName: payload?.projectName || '',
              },
              ...prev,
            ]
          })
        }
        scheduleRefresh()
        window.dispatchEvent(new CustomEvent('crm:task-updated'))
        return
      }

      if (reason === 'approved') {
        notifyTaskApproved({
          title: payload?.title,
          navigate: navigateRef.current,
        })
        scheduleRefresh()
        window.dispatchEvent(new CustomEvent('crm:task-updated'))
        return
      }

      if (reason === 'rejected') {
        notifyTaskRejected({
          title: payload?.title,
          reason: payload?.rejectionReason,
          navigate: navigateRef.current,
        })
        scheduleRefresh()
        window.dispatchEvent(new CustomEvent('crm:task-updated'))
        return
      }

      scheduleRefresh({ playAlert: reason === 'assigned' })
      window.dispatchEvent(new CustomEvent('crm:task-updated'))
    })

    const handleTaskUpdatedEvent = () => {
      scheduleRefresh()
    }
    const handleFocus = () => {
      if (!document.hidden) fetchPendingMyTasks()
    }
    const pollInterval = window.setInterval(() => {
      if (!document.hidden) fetchPendingMyTasks()
    }, 10000)

    window.addEventListener('crm:task-updated', handleTaskUpdatedEvent)
    window.addEventListener('focus', handleFocus)

    return () => {
      cancelled = true
      if (refreshTimer) window.clearTimeout(refreshTimer)
      window.clearInterval(pollInterval)
      unsubscribe()
      window.removeEventListener('crm:task-updated', handleTaskUpdatedEvent)
      window.removeEventListener('focus', handleFocus)
    }
  }, [user?._id, fullAccess])

  const toggleSection = (id) => {
    setExpanded((prev) => (prev[id] ? {} : { [id]: true }))
  }

  const renderChild = (child, pl = 'pl-9') => {
    const active = isPathActive(location.pathname, child.path)
    return (
      <button
        key={child.id}
        type='button'
        onClick={() => navigate(child.path)}
        className={`w-full flex items-center gap-2 py-2 rounded-lg text-sm transition-colors ${
          active
            ? 'bg-[#2563EB] text-[#E5E7EB] hover:bg-[#3B82F6]'
            : 'text-[#94A3B8] hover:bg-[#111827] hover:text-[#E5E7EB]'
        } ${isOpen ? `${pl} pr-3` : 'px-3 justify-center'}`}
        title={!isOpen ? child.label : undefined}
      >
        {isOpen ? (
          <>
            <span className='text-[#94A3B8]'>•</span>
            <span className='truncate flex-1 text-left'>{child.label}</span>
            {child.id === 'my-tasks' && pendingMyTasksCount > 0 && (
              <span className='ml-auto inline-flex min-w-5 h-5 items-center justify-center rounded-full bg-red-600 px-1.5 text-[11px] font-semibold text-white'>
                {pendingMyTasksCount > 99 ? '99+' : pendingMyTasksCount}
              </span>
            )}
            {child.id === 'task-approvals' && pendingApprovalsCount > 0 && (
              <span className='ml-auto inline-flex min-w-5 h-5 items-center justify-center rounded-full bg-amber-500 px-1.5 text-[11px] font-semibold text-white'>
                {pendingApprovalsCount > 99 ? '99+' : pendingApprovalsCount}
              </span>
            )}
          </>
        ) : (
          <span className='w-1.5 h-1.5 rounded-full bg-[#94A3B8]' />
        )}
      </button>
    )
  }

  return (
    <>
      {approvalPopupQueue.length > 0 && (
        <div
          className='fixed inset-0 z-[9999] flex items-center justify-center p-4 bg-black/45 backdrop-blur-[2px]'
          role='dialog'
          aria-modal='true'
          aria-labelledby='task-approval-popup-title'
        >
          <div className='bg-white rounded-2xl shadow-2xl border border-amber-200 max-w-md w-full overflow-hidden'>
            <div className='bg-gradient-to-r from-amber-500 to-yellow-500 px-5 py-4 flex items-center justify-between text-white'>
              <div className='flex items-center gap-2.5'>
                <span className='w-9 h-9 rounded-xl bg-white/20 flex items-center justify-center text-lg shadow-inner'>
                  🔔
                </span>
                <div>
                  <h3 id='task-approval-popup-title' className='text-sm font-bold leading-tight'>
                    New Task Waiting for Approval
                  </h3>
                  <p className='text-[11px] text-amber-50'>
                    {approvalPopupQueue.length === 1
                      ? 'A new task has been added for your approval'
                      : `${approvalPopupQueue.length} new tasks are waiting for your approval`}
                  </p>
                </div>
              </div>
              <button
                type='button'
                onClick={dismissApprovalPopup}
                className='w-7 h-7 rounded-lg bg-white/15 hover:bg-white/25 flex items-center justify-center text-white text-sm font-bold transition-colors'
                aria-label='Close notification'
              >
                ✕
              </button>
            </div>

            <div className='p-5 space-y-3 max-h-[60vh] overflow-y-auto'>
              {approvalPopupQueue.slice(0, 4).map((item) => (
                <div
                  key={item.id}
                  className='p-3.5 rounded-xl bg-yellow-50 border border-yellow-300 space-y-1.5'
                >
                  <div className='flex items-start justify-between gap-2'>
                    <p className='text-sm font-bold text-gray-900 leading-snug'>
                      {item.title}
                    </p>
                    <span className='shrink-0 px-2 py-0.5 rounded-full text-[10px] font-bold bg-yellow-200 text-yellow-900 border border-yellow-400'>
                      ⏳ Waiting for Approval
                    </span>
                  </div>
                  {item.employeeName && (
                    <p className='text-xs text-gray-700'>
                      <span className='font-semibold text-gray-500'>Employee:</span>{' '}
                      <span className='font-semibold text-gray-900'>{item.employeeName}</span>
                    </p>
                  )}
                  {item.projectName && (
                    <p className='text-xs text-gray-600'>
                      <span className='font-semibold text-gray-500'>Project:</span> {item.projectName}
                    </p>
                  )}
                </div>
              ))}
              {approvalPopupQueue.length > 4 && (
                <p className='text-xs text-center text-amber-800 font-semibold'>
                  + {approvalPopupQueue.length - 4} more task(s) waiting for approval
                </p>
              )}
            </div>

            <div className='px-5 py-3.5 bg-gray-50 border-t border-gray-100 flex items-center justify-end gap-2.5'>
              <button
                type='button'
                onClick={dismissApprovalPopup}
                className='px-4 py-2 rounded-xl border border-gray-300 bg-white hover:bg-gray-50 text-xs font-semibold text-gray-700 transition-colors'
              >
                Dismiss
              </button>
              <button
                type='button'
                onClick={() => {
                  dismissApprovalPopup()
                  navigate('/task-approvals')
                }}
                className='px-4 py-2 rounded-xl bg-amber-500 hover:bg-amber-600 text-white text-xs font-bold shadow-sm transition-colors flex items-center gap-1.5'
              >
                <span>✓</span>
                <span>Review & Approve</span>
              </button>
            </div>
          </div>
        </div>
      )}
      <aside className={`bg-[#0F172A] text-[#E5E7EB] text-sm h-screen flex flex-col shadow-2xl border-r border-[#1E293B] transition-all duration-200 flex-shrink-0 print:hidden ${isOpen ? 'w-64' : 'w-16'}`}>
      <div className='px-3 py-4 border-b border-[#1E293B] flex items-center justify-center shrink-0'>
        {isOpen ? (
          <div className='w-full flex items-center justify-between px-2'>
            <button
              type='button'
              onClick={() => navigate(dashboardPath)}
              className='flex cursor-pointer items-center gap-3 min-w-0 rounded-lg focus:outline-none focus-visible:ring-2 focus-visible:ring-[#3B82F6]'
              title='Dashboard'
            >
              <div className='h-10 rounded-lg flex-shrink-0 overflow-hidden'>
                <img src={Logo} alt='CRM' className='w-full h-full object-contain' />
              </div>
            </button>
            <button type='button' onClick={onToggle} className='p-2 rounded-lg hover:bg-[#111827] text-[#94A3B8] hover:text-[#E5E7EB] transition-colors flex-shrink-0' title='Collapse menu'>
              <MenuToggleIcon />
            </button>
          </div>
        ) : (
          <button type='button' onClick={onToggle} className='p-2 rounded-lg hover:bg-[#111827] text-[#94A3B8] hover:text-[#E5E7EB] transition-colors' title='Expand menu'>
            <MenuToggleIcon />
          </button>
        )}
      </div>

      <nav className={`sidebar-scrollbar-desktop-hide flex-1 py-3 overflow-y-auto overflow-x-hidden ${isOpen ? 'px-3' : 'px-2'}`}>
        <div className='space-y-1'>
          {sections.map((section) => {
            if (section.type === 'link') {
              const active = isPathActive(location.pathname, section.path)
              return (
                <button
                  key={section.id}
                  type='button'
                  onClick={() => navigate(section.path)}
                  className={`w-full flex items-center gap-3 py-2.5 rounded-lg transition-colors ${
                    active
                      ? 'bg-[#2563EB] text-[#E5E7EB] hover:bg-[#3B82F6]'
                      : 'text-[#E5E7EB] hover:bg-[#111827]'
                  } ${isOpen ? 'px-3' : 'px-2 justify-center'}`}
                  title={!isOpen ? section.label : undefined}
                >
                  <SidebarSectionIcon id={section.id} className='size-5 shrink-0' />
                  {isOpen && <span className='text-sm font-medium truncate'>{section.label}</span>}
                </button>
              )
            }

            const isExpanded = expanded[section.id]
            const groupActive = section.children.some((c) => isPathActive(location.pathname, c.path))

            return (
              <div key={section.id} className='pt-1'>
                <button
                  type='button'
                  onClick={() => (isOpen ? toggleSection(section.id) : navigate(section.children[0]?.path))}
                  className={`w-full flex items-center gap-3 py-2.5 rounded-lg transition-colors ${
                    groupActive ? 'text-[#E5E7EB]' : 'text-[#94A3B8] hover:bg-[#111827] hover:text-[#E5E7EB]'
                  } ${isOpen ? 'px-3' : 'px-2 justify-center'}`}
                  title={!isOpen ? section.label : undefined}
                >
                  <SidebarSectionIcon id={section.id} className='size-5 shrink-0' />
                  {isOpen && (
                    <>
                      <span className='text-sm font-medium truncate flex-1 text-left'>{section.label}</span>
                      <ChevronIcon open={isExpanded} />
                    </>
                  )}
                </button>
                {isOpen && isExpanded && (
                  <div className='mt-0.5 mb-1 space-y-0.5'>
                    {section.children.map((child) => renderChild(child))}
                  </div>
                )}
              </div>
            )
          })}
        </div>
      </nav>

      <div className={`border-t border-[#1E293B] py-3 shrink-0 ${isOpen ? 'px-3' : 'px-2'}`}>
        {isOpen && user?.name && (
          <div className='px-3 py-2 mb-2 rounded-lg bg-[#111827]'>
            <p className='text-xs font-semibold text-[#E5E7EB] truncate'>{user.name}</p>
            <p className='text-[10px] text-[#94A3B8] truncate'>{user.designation?.title || 'Employee'}</p>
          </div>
        )}
        <div className='space-y-1'>
          <button
            type='button'
            onClick={() => navigate('/settings')}
            className={`w-full flex items-center gap-3 py-2.5 rounded-lg transition-colors ${
              location.pathname === '/settings'
                ? 'bg-[#2563EB] text-[#E5E7EB] hover:bg-[#3B82F6]'
                : 'text-[#E5E7EB] hover:bg-[#111827]'
            } ${isOpen ? 'px-3' : 'px-2 justify-center'}`}
            title={!isOpen ? 'Settings' : undefined}
          >
            <span className='text-lg'><SettingsIcon /></span>
            {isOpen && <span className='font-medium'>Settings</span>}
          </button>
          <button
            type='button'
            onClick={() => { logout(); navigate('/login') }}
            className={`w-full flex items-center gap-3 py-2.5 text-[#94A3B8] hover:bg-red-900/40 hover:text-red-200 rounded-lg transition-colors ${isOpen ? 'px-3' : 'px-2 justify-center'}`}
            title={!isOpen ? 'Logout' : undefined}
          >
            <span className='text-lg'><LogoutIcon /></span>
            {isOpen && <span className='font-medium'>Logout</span>}
          </button>
        </div>
      </div>
    </aside>
    </>
  )
}

export default Sidebar
