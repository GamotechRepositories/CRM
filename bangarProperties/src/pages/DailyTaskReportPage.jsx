import React, { useEffect, useMemo, useRef, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import html2canvas from 'html2canvas'
import jsPDF from 'jspdf'
import api from '../api/axios'
import { useAuth } from '../context/AuthContext'
import { getAllReporteeIds, refEmployeeId } from '../utils/reportingHierarchy'
import { formatTaskDuration, normalizeTaskStatus } from '../utils/taskStatus'

const toLocalYmd = (date = new Date()) => {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

const shiftYmd = (ymd, deltaDays) => {
  const [y, m, d] = ymd.split('-').map(Number)
  const dt = new Date(y, (m || 1) - 1, (d || 1) + deltaDays)
  return toLocalYmd(dt)
}

const formatDisplayDate = (ymd) => {
  if (!ymd) return '—'
  const [y, m, d] = ymd.split('-').map(Number)
  const dt = new Date(y, (m || 1) - 1, d || 1)
  if (Number.isNaN(dt.getTime())) return ymd
  return dt.toLocaleDateString('en-IN', {
    weekday: 'short',
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  })
}

const formatTimeShort = (value) => {
  if (!value) return '—'
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })
}

const matchesDateYmd = (value, targetYmd) => {
  if (!value || !targetYmd) return false
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return false
  return toLocalYmd(d) === targetYmd || d.toISOString().slice(0, 10) === targetYmd
}

const taskMatchesDay = (task, selectedDate, todayYmd) => {
  if (!task || task.isRecurringTemplate) return false
  const status = normalizeTaskStatus(task.status)
  if (selectedDate === todayYmd && status === 'In Progress') return true
  return (
    matchesDateYmd(task.dueDate, selectedDate) ||
    matchesDateYmd(task.scheduledStartAt, selectedDate) ||
    matchesDateYmd(task.completedAt, selectedDate) ||
    matchesDateYmd(task.startedAt, selectedDate) ||
    matchesDateYmd(task.createdAt, selectedDate) ||
    matchesDateYmd(task.updatedAt, selectedDate)
  )
}

const getStatusBadgeStyle = (status) => {
  switch (normalizeTaskStatus(status)) {
    case 'Completed':
      return { backgroundColor: '#dcfce7', color: '#166534' }
    case 'In Progress':
      return { backgroundColor: '#dbeafe', color: '#1e40af' }
    case 'Paused':
      return { backgroundColor: '#ede9fe', color: '#5b21b6' }
    case 'Pending':
      return { backgroundColor: '#fef3c7', color: '#92400e' }
    case 'Cancelled':
      return { backgroundColor: '#f3f4f6', color: '#4b5563' }
    default:
      return { backgroundColor: '#f3f4f6', color: '#1f2937' }
  }
}

const getPriorityBadgeStyle = (priority) => {
  switch (String(priority || 'Medium')) {
    case 'Urgent':
      return { backgroundColor: '#fee2e2', color: '#991b1b' }
    case 'High':
      return { backgroundColor: '#ffedd5', color: '#9a3412' }
    case 'Low':
      return { backgroundColor: '#f1f5f9', color: '#475569' }
    default:
      return { backgroundColor: '#eff6ff', color: '#1d4ed8' }
  }
}

const stripUnsupportedColors = (cssText) => {
  if (!cssText || typeof cssText !== 'string') return cssText
  let out = cssText
  const replaceParenFunc = (name, replacement) => {
    const re = new RegExp(name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '\\s*\\(', 'gi')
    let match
    while ((match = re.exec(out)) !== null) {
      const idx = match.index
      const start = out.indexOf('(', idx)
      let depth = 1
      let end = start + 1
      while (depth > 0 && end < out.length) {
        if (out[end] === '(') depth++
        else if (out[end] === ')') depth--
        end++
      }
      out = out.slice(0, idx) + replacement + out.slice(end)
      re.lastIndex = 0
    }
  }
  replaceParenFunc('oklch', 'inherit')
  replaceParenFunc('oklab', 'inherit')
  replaceParenFunc('color-mix', 'inherit')
  return out
}

const csvEscape = (value) => {
  const s = String(value ?? '')
  if (/[",\n]/.test(s)) return `"${s.replace(/"/g, '""')}"`
  return s
}

const getTaskRatingScore = (task) => {
  const raw = task?.rating && typeof task.rating === 'object' ? task.rating.score : task?.rating
  const n = Number(raw)
  return Number.isFinite(n) && n >= 1 && n <= 5 ? n : null
}

const getTaskRatingTitle = (task) =>
  task?.rating && typeof task.rating === 'object' ? String(task.rating.title || '').trim() : ''

const formatMinsCompact = (minutes) => {
  const mins = Math.max(0, Math.round(Number(minutes) || 0))
  if (mins === 0) return '0m'
  const h = Math.floor(mins / 60)
  const m = mins % 60
  if (h === 0) return `${m}m`
  if (m === 0) return `${h}h`
  return `${h}h ${m}m`
}

const getAttendanceMetrics = (att, isViewingToday) => {
  if (!att) {
    return {
      hasRecord: false,
      checkIn: '—',
      checkOut: '—',
      breakMins: 0,
      meetingMins: 0,
      workingMins: 0,
    }
  }
  const nowMs = Date.now()
  let breakMins = Number(att.breakDurationMinutes) || 0
  if (att.breakStartedAt && !att.checkOut && isViewingToday) {
    breakMins += Math.max(0, Math.floor((nowMs - new Date(att.breakStartedAt).getTime()) / 60000))
  }
  let meetingMins = Number(att.meetingDurationMinutes) || 0
  if (att.meetingStartedAt && !att.checkOut && isViewingToday) {
    meetingMins += Math.max(0, Math.floor((nowMs - new Date(att.meetingStartedAt).getTime()) / 60000))
  }

  let totalSpanMins = 0
  if (att.checkIn) {
    const startMs = new Date(att.checkIn).getTime()
    const endMs = att.checkOut
      ? new Date(att.checkOut).getTime()
      : isViewingToday
        ? nowMs
        : startMs
    if (!Number.isNaN(startMs) && !Number.isNaN(endMs) && endMs > startMs) {
      totalSpanMins = Math.floor((endMs - startMs) / 60000)
    } else if (Number(att.durationHours) > 0) {
      totalSpanMins = Math.round(Number(att.durationHours) * 60)
    }
  } else if (Number(att.durationHours) > 0) {
    totalSpanMins = Math.round(Number(att.durationHours) * 60)
  }

  const workingMins = Math.max(0, totalSpanMins - breakMins)
  return {
    hasRecord: Boolean(att.checkIn || att.checkOut || breakMins > 0 || meetingMins > 0 || workingMins > 0),
    checkIn: formatTimeShort(att.checkIn),
    checkOut: formatTimeShort(att.checkOut),
    breakMins: Math.round(breakMins),
    meetingMins: Math.round(meetingMins),
    workingMins: Math.round(workingMins),
  }
}

const DailyTaskReportPage = () => {
  const { user, hasFullAccess, canAssignTask } = useAuth()
  const [searchParams, setSearchParams] = useSearchParams()
  const printRef = useRef(null)

  const todayYmd = useMemo(() => toLocalYmd(new Date()), [])
  const currentUserId = refEmployeeId(user?._id || user?.id)
  const isFullAccess = hasFullAccess()
  const isLeaderOrAbove = isFullAccess || canAssignTask()

  const initialDate = searchParams.get('date') || todayYmd
  const initialEmployee = searchParams.get('employeeId') || (isLeaderOrAbove ? 'all' : currentUserId)

  const [selectedDate, setSelectedDate] = useState(initialDate)
  const [selectedEmployeeId, setSelectedEmployeeId] = useState(initialEmployee)
  const [statusFilter, setStatusFilter] = useState('All')
  const [departmentFilter, setDepartmentFilter] = useState('all')

  const [company, setCompany] = useState(null)
  const [logoSrc, setLogoSrc] = useState('')
  const [employees, setEmployees] = useState([])
  const [tasks, setTasks] = useState([])
  const [dayAttendances, setDayAttendances] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [downloading, setDownloading] = useState(false)
  const [downloadError, setDownloadError] = useState(null)

  const getBackendOrigin = () => {
    const base = api.defaults.baseURL || import.meta.env.VITE_API_URL || 'http://localhost:5014'
    try {
      const u = new URL(base)
      return `${u.protocol}//${u.host}`
    } catch {
      return 'http://localhost:5014'
    }
  }

  const toBase64 = async (url) => {
    if (!url || typeof url !== 'string') return ''
    if (url.startsWith('data:image')) return url
    const targetUrl =
      url.startsWith('http://') || url.startsWith('https://')
        ? `${getBackendOrigin()}/api/proxy-image?url=${encodeURIComponent(url)}`
        : url
    try {
      const res = await fetch(targetUrl)
      if (res.ok) {
        const blob = await res.blob()
        return await new Promise((resolve) => {
          const reader = new FileReader()
          reader.onloadend = () => resolve(reader.result || '')
          reader.readAsDataURL(blob)
        })
      }
    } catch {}
    return ''
  }

  useEffect(() => {
    let active = true
    const load = async () => {
      try {
        setLoading(true)
        setError(null)
        const [compRes, empRes, taskRes] = await Promise.all([
          api.get('/company-profile').catch(() => ({ data: {} })),
          api.get('/employees').catch(() => ({ data: [] })),
          api.get('/tasks').catch(() => ({ data: [] })),
        ])
        if (!active) return
        setCompany(compRes.data || {})
        const empList = Array.isArray(empRes.data) ? empRes.data : empRes.data?.data || []
        const taskList = Array.isArray(taskRes.data) ? taskRes.data : taskRes.data?.data || []
        setEmployees(empList.filter((e) => e.status !== 'Inactive'))
        setTasks(taskList)
      } catch (err) {
        if (!active) return
        setError(err.response?.data?.message || err.message || 'Failed to load daily task report')
      } finally {
        if (active) setLoading(false)
      }
    }
    if (currentUserId) load()
    return () => {
      active = false
    }
  }, [currentUserId])

  useEffect(() => {
    let active = true
    const loadAttendance = async () => {
      if (!currentUserId || !selectedDate) return
      try {
        const params = { date: selectedDate }
        if (!isLeaderOrAbove) params.employeeId = currentUserId
        const res = await api.get('/attendance/today', { params }).catch(() => ({ data: [] }))
        if (!active) return
        const list = Array.isArray(res.data) ? res.data : res.data?.data || []
        setDayAttendances(list)
      } catch {
        if (active) setDayAttendances([])
      }
    }
    loadAttendance()
    return () => {
      active = false
    }
  }, [currentUserId, selectedDate, isLeaderOrAbove])

  useEffect(() => {
    let mounted = true
    const loadLogo = async () => {
      if (!company?.companyLogo) {
        if (mounted) setLogoSrc('')
        return
      }
      const b64 = await toBase64(company.companyLogo)
      if (mounted) setLogoSrc(b64 || company.companyLogo)
    }
    loadLogo()
    return () => {
      mounted = false
    }
  }, [company])

  // Determine which employees this user is allowed to generate reports for
  const allowedEmployees = useMemo(() => {
    if (!currentUserId) return []
    const byId = new Map(employees.map((e) => [refEmployeeId(e), e]))
    const selfRecord = byId.get(currentUserId) || user

    if (isFullAccess) {
      return [...employees].sort((a, b) => (a.name || '').localeCompare(b.name || ''))
    }

    const reporteeIds = getAllReporteeIds(employees, currentUserId)
    if (isLeaderOrAbove || reporteeIds.size > 0) {
      const list = []
      if (selfRecord) list.push(selfRecord)
      employees.forEach((emp) => {
        const eid = refEmployeeId(emp)
        if (eid && eid !== currentUserId && reporteeIds.has(eid)) {
          list.push(emp)
        }
      })
      return list.sort((a, b) => (a.name || '').localeCompare(b.name || ''))
    }

    return selfRecord ? [selfRecord] : []
  }, [employees, currentUserId, user, isFullAccess, isLeaderOrAbove])

  const canSelectMultipleEmployees = allowedEmployees.length > 1

  const allowedEmployeeIds = useMemo(
    () => new Set(allowedEmployees.map((e) => refEmployeeId(e)).filter(Boolean)),
    [allowedEmployees]
  )

  const departments = useMemo(() => {
    const set = new Set()
    allowedEmployees.forEach((e) => {
      const dep = e.department || e.designation?.department
      if (dep) set.add(dep)
    })
    return Array.from(set).sort()
  }, [allowedEmployees])

  const filteredAllowedEmployees = useMemo(() => {
    if (departmentFilter === 'all') return allowedEmployees
    return allowedEmployees.filter(
      (e) => (e.department || e.designation?.department || '') === departmentFilter
    )
  }, [allowedEmployees, departmentFilter])

  // Keep selectedEmployeeId valid for the current user's scope
  useEffect(() => {
    if (!canSelectMultipleEmployees) {
      if (selectedEmployeeId !== currentUserId) setSelectedEmployeeId(currentUserId)
      return
    }
    if (selectedEmployeeId !== 'all' && !allowedEmployeeIds.has(selectedEmployeeId)) {
      setSelectedEmployeeId('all')
    }
  }, [canSelectMultipleEmployees, currentUserId, selectedEmployeeId, allowedEmployeeIds])

  const updateUrlParams = (nextDate, nextEmpId) => {
    const next = new URLSearchParams(searchParams)
    if (nextDate) next.set('date', nextDate)
    if (nextEmpId) next.set('employeeId', nextEmpId)
    setSearchParams(next, { replace: true })
  }

  const handleDateChange = (val) => {
    if (!val) return
    setSelectedDate(val)
    updateUrlParams(val, selectedEmployeeId)
  }

  const handleEmployeeChange = (val) => {
    setSelectedEmployeeId(val)
    updateUrlParams(selectedDate, val)
  }

  // Filter tasks for the selected day and employee scope
  const dayTasks = useMemo(() => {
    const allowedIdsInDept = new Set(filteredAllowedEmployees.map((e) => refEmployeeId(e)))
    return tasks
      .filter((t) => {
        if (!taskMatchesDay(t, selectedDate, todayYmd)) return false
        const assigneeId = refEmployeeId(t.assignedTo)
        if (!assigneeId) return false
        if (selectedEmployeeId === 'all') {
          if (!allowedIdsInDept.has(assigneeId)) return false
        } else if (assigneeId !== selectedEmployeeId) {
          return false
        }
        if (statusFilter !== 'All' && normalizeTaskStatus(t.status) !== statusFilter) {
          return false
        }
        return true
      })
      .sort((a, b) => {
        const nameA = a.assignedTo?.name || ''
        const nameB = b.assignedTo?.name || ''
        if (nameA !== nameB) return nameA.localeCompare(nameB)
        return new Date(b.updatedAt || b.createdAt || 0) - new Date(a.updatedAt || a.createdAt || 0)
      })
  }, [tasks, selectedDate, todayYmd, selectedEmployeeId, statusFilter, filteredAllowedEmployees])

  const stats = useMemo(() => {
    let completed = 0
    let inProgress = 0
    let pending = 0
    let paused = 0
    let cancelled = 0
    let estMinutes = 0
    let actualMinutes = 0

    dayTasks.forEach((t) => {
      const st = normalizeTaskStatus(t.status)
      if (st === 'Completed') completed++
      else if (st === 'In Progress') inProgress++
      else if (st === 'Paused') paused++
      else if (st === 'Cancelled') cancelled++
      else pending++

      if (Number(t.estimatedDurationMinutes) > 0) estMinutes += Number(t.estimatedDurationMinutes)
      if (Number(t.actualDurationMinutes) > 0) actualMinutes += Number(t.actualDurationMinutes)
    })

    const total = dayTasks.length
    const completionRate = total > 0 ? Math.round((completed / total) * 100) : 0
    return { total, completed, inProgress, pending, paused, cancelled, estMinutes, actualMinutes, completionRate }
  }, [dayTasks])

  const attendanceByEmpId = useMemo(() => {
    const map = new Map()
    dayAttendances.forEach((a) => {
      const eid = refEmployeeId(a.employee)
      if (!eid) return
      const existing = map.get(eid)
      if (!existing || new Date(a.updatedAt || a.checkIn || 0) > new Date(existing.updatedAt || existing.checkIn || 0)) {
        map.set(eid, a)
      }
    })
    return map
  }, [dayAttendances])

  // Per-employee summary when viewing multiple employees
  const employeeSummary = useMemo(() => {
    if (selectedEmployeeId !== 'all') return []
    const isViewingToday = selectedDate === todayYmd
    const map = new Map()
    filteredAllowedEmployees.forEach((emp) => {
      const eid = refEmployeeId(emp)
      const attMetrics = getAttendanceMetrics(attendanceByEmpId.get(eid), isViewingToday)
      map.set(eid, {
        id: eid,
        name: emp.name || '—',
        designation: emp.designation?.title || emp.designation?.name || '—',
        department: emp.department || emp.designation?.department || '—',
        total: 0,
        completed: 0,
        inProgress: 0,
        pending: 0,
        estMinutes: 0,
        actualMinutes: 0,
        ratingSum: 0,
        ratingCount: 0,
        attMetrics,
      })
    })
    dayTasks.forEach((t) => {
      const eid = refEmployeeId(t.assignedTo)
      if (!eid) return
      if (!map.has(eid)) {
        map.set(eid, {
          id: eid,
          name: t.assignedTo?.name || '—',
          designation: t.assignedTo?.designation?.title || '—',
          department: t.assignedTo?.department || '—',
          total: 0,
          completed: 0,
          inProgress: 0,
          pending: 0,
          estMinutes: 0,
          actualMinutes: 0,
          ratingSum: 0,
          ratingCount: 0,
          attMetrics: getAttendanceMetrics(attendanceByEmpId.get(eid), isViewingToday),
        })
      }
      const row = map.get(eid)
      row.total += 1
      const st = normalizeTaskStatus(t.status)
      if (st === 'Completed') row.completed += 1
      else if (st === 'In Progress') row.inProgress += 1
      else if (st !== 'Cancelled') row.pending += 1
      if (Number(t.estimatedDurationMinutes) > 0) row.estMinutes += Number(t.estimatedDurationMinutes)
      if (Number(t.actualDurationMinutes) > 0) row.actualMinutes += Number(t.actualDurationMinutes)
      const score = getTaskRatingScore(t)
      if (score != null) {
        row.ratingSum += score
        row.ratingCount += 1
      }
    })
    return Array.from(map.values()).filter((r) => r.total > 0 || r.attMetrics.hasRecord)
  }, [selectedEmployeeId, filteredAllowedEmployees, dayTasks, attendanceByEmpId, selectedDate, todayYmd])

  const selectedEmployeeObj = useMemo(() => {
    if (selectedEmployeeId === 'all') return null
    return allowedEmployees.find((e) => refEmployeeId(e) === selectedEmployeeId) || user
  }, [selectedEmployeeId, allowedEmployees, user])

  const selectedEmployeeAttendance = useMemo(() => {
    if (!selectedEmployeeObj) return null
    const eid = refEmployeeId(selectedEmployeeObj._id || selectedEmployeeObj.id)
    return getAttendanceMetrics(attendanceByEmpId.get(eid), selectedDate === todayYmd)
  }, [selectedEmployeeObj, attendanceByEmpId, selectedDate, todayYmd])

  const reportScopeLabel =
    selectedEmployeeId === 'all'
      ? isFullAccess
        ? departmentFilter === 'all'
          ? 'All Employees'
          : `${departmentFilter} Department`
        : 'My Team'
      : selectedEmployeeObj?.name || 'Employee'

  const handleExportCsv = () => {
    const isViewingToday = selectedDate === todayYmd
    const headers = [
      'Date',
      'Employee',
      'Designation',
      'Check In Time',
      'Check Out Time',
      'Break Total (mins)',
      'Meeting Total (mins)',
      'Total Working Time',
      'Project',
      'Task Title',
      'Priority',
      'Status',
      'Estimated Duration',
      'Actual Duration',
      'Completed At',
      'Rating',
    ]
    const rows = dayTasks.map((t) => {
      const eid = refEmployeeId(t.assignedTo) || refEmployeeId(selectedEmployeeObj)
      const attM = getAttendanceMetrics(attendanceByEmpId.get(eid), isViewingToday)
      return [
        selectedDate,
        t.assignedTo?.name || selectedEmployeeObj?.name || '—',
        t.assignedTo?.designation?.title || selectedEmployeeObj?.designation?.title || '—',
        attM.checkIn,
        attM.checkOut,
        attM.hasRecord ? `${attM.breakMins}` : '—',
        attM.hasRecord ? `${attM.meetingMins}` : '—',
        attM.hasRecord ? formatMinsCompact(attM.workingMins) : '—',
        t.project?.projectName || t.project?.name || '—',
        t.title || '—',
        t.priority || 'Medium',
        normalizeTaskStatus(t.status) || 'Pending',
        t.estimatedDurationMinutes ? formatTaskDuration(t.estimatedDurationMinutes) : '—',
        t.actualDurationMinutes ? formatTaskDuration(t.actualDurationMinutes) : '—',
        t.completedAt ? formatTimeShort(t.completedAt) : '—',
        getTaskRatingScore(t) != null ? `${getTaskRatingScore(t)}/5` : '—',
      ]
    })
    const csv = [headers.map(csvEscape).join(','), ...rows.map((r) => r.map(csvEscape).join(','))].join('\n')
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    const safeScope = reportScopeLabel.replace(/\s+/g, '_')
    a.href = url
    a.download = `DailyTaskReport-${safeScope}-${selectedDate}.csv`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
  }

  const handleDownloadPdf = async () => {
    const element = printRef.current
    if (!element) return
    setDownloading(true)
    setDownloadError(null)
    let fontMetricsFixStyle = null
    try {
      let activeLogo = logoSrc
      if (company?.companyLogo && (!activeLogo || !activeLogo.startsWith('data:image'))) {
        activeLogo = (await toBase64(company.companyLogo)) || activeLogo
      }

      let strippedLinkedCss = ''
      const links = document.querySelectorAll('link[rel="stylesheet"]')
      if (links.length > 0) {
        const hrefs = Array.from(links).map((l) => l.href).filter(Boolean)
        const texts = await Promise.all(hrefs.map((h) => fetch(h).then((r) => r.text()).catch(() => '')))
        strippedLinkedCss = texts.map(stripUnsupportedColors).join('\n')
      }

      // Restore inline display for html2canvas 1x1 font-baseline measurement images
      // so badge and table text renders vertically centered instead of shifted down.
      fontMetricsFixStyle = document.createElement('style')
      fontMetricsFixStyle.setAttribute('data-html2canvas-fontmetrics-fix', '')
      fontMetricsFixStyle.textContent =
        'body > div > img[width="1"][height="1"] { display: inline !important; }'
      document.head.appendChild(fontMetricsFixStyle)

      let avoidRanges = []
      let clonedWidthPx = 794

      const canvas = await html2canvas(element, {
        scale: 2,
        useCORS: true,
        allowTaint: true,
        backgroundColor: '#ffffff',
        logging: false,
        onclone: (clonedDoc, clonedElement) => {
          clonedDoc.querySelectorAll('style').forEach((style) => {
            if (style.textContent) style.textContent = stripUnsupportedColors(style.textContent)
          })
          clonedDoc.querySelectorAll('link[rel="stylesheet"]').forEach((l) => l.remove())
          if (strippedLinkedCss) {
            const style = clonedDoc.createElement('style')
            style.textContent = strippedLinkedCss
            clonedDoc.head.appendChild(style)
          }
          clonedElement.querySelectorAll('[style]').forEach((el) => {
            const s = el.getAttribute('style')
            if (s && /oklch/i.test(s)) el.setAttribute('style', stripUnsupportedColors(s))
          })

          clonedElement.style.width = '794px'
          clonedElement.style.maxWidth = '794px'
          clonedElement.style.boxSizing = 'border-box'
          clonedElement.style.margin = '0 auto'
          clonedElement.style.boxShadow = 'none'
          clonedElement.style.borderRadius = '0px'
          clonedElement.style.border = 'none'
          clonedElement.style.padding = '32px 36px 40px 36px'
          clonedElement.style.backgroundColor = '#ffffff'

          clonedElement.querySelectorAll('.print-hide-in-pdf').forEach((el) => {
            el.style.display = 'none'
          })

          const logoEl = clonedElement.querySelector('.report-company-logo')
          if (logoEl && activeLogo) logoEl.src = activeLogo

          const rootRect = clonedElement.getBoundingClientRect()
          clonedWidthPx = rootRect.width || 794
          const blocks = clonedElement.querySelectorAll('tr, thead, p, h1, h2, h3, h4')
          avoidRanges = Array.from(blocks)
            .map((el) => {
              const r = el.getBoundingClientRect()
              return { top: r.top - rootRect.top, bottom: r.bottom - rootRect.top }
            })
            .filter((r) => r.bottom > r.top && r.bottom - r.top < 1000)
        },
      })

      const pageWidth = 210
      const pageHeight = 297
      const bottomMargin = 20
      const nextPageTopMargin = 12

      const pdf = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' })
      const contentHeight = (canvas.height * pageWidth) / canvas.width
      const firstPageUsableHeight = pageHeight - bottomMargin

      if (contentHeight <= firstPageUsableHeight + 2) {
        const imgData = canvas.toDataURL('image/jpeg', 0.98)
        pdf.addImage(imgData, 'JPEG', 0, 0, pageWidth, Math.min(contentHeight, firstPageUsableHeight))
      } else {
        const pxPerMm = canvas.width / pageWidth
        const cssToCanvas = canvas.width / clonedWidthPx
        const avoidCanvasRanges = avoidRanges.map((r) => ({
          top: r.top * cssToCanvas,
          bottom: r.bottom * cssToCanvas,
        }))
        const minSliverPx = Math.ceil(2 * pxPerMm)
        const minProgressPx = Math.ceil(20 * pxPerMm)
        let sourceY = 0
        let pageIndex = 0

        while (sourceY < canvas.height) {
          const remainingPx = canvas.height - sourceY
          if (pageIndex > 0 && remainingPx < minSliverPx) break

          const pageTopMm = pageIndex === 0 ? 0 : nextPageTopMargin
          const usableHeightMm = pageHeight - pageTopMm - bottomMargin
          const maxSlicePx = Math.floor(usableHeightMm * pxPerMm)
          let cutY = Math.min(sourceY + maxSlicePx, canvas.height)

          if (cutY < canvas.height) {
            let adjusted = true
            while (adjusted) {
              adjusted = false
              let earliestTop = cutY
              for (const range of avoidCanvasRanges) {
                if (range.top < cutY && range.bottom > cutY && range.top < earliestTop) {
                  earliestTop = range.top
                }
              }
              if (earliestTop < cutY && earliestTop > sourceY + minProgressPx) {
                cutY = Math.floor(earliestTop)
                adjusted = true
              }
            }
          }

          const sliceHeightPx = Math.max(1, cutY - sourceY)
          const pageCanvas = document.createElement('canvas')
          pageCanvas.width = canvas.width
          pageCanvas.height = sliceHeightPx
          const ctx = pageCanvas.getContext('2d')
          ctx.fillStyle = '#ffffff'
          ctx.fillRect(0, 0, pageCanvas.width, pageCanvas.height)
          ctx.drawImage(canvas, 0, sourceY, canvas.width, sliceHeightPx, 0, 0, canvas.width, sliceHeightPx)

          if (pageIndex > 0) pdf.addPage()
          pdf.addImage(
            pageCanvas.toDataURL('image/jpeg', 0.98),
            'JPEG',
            0,
            pageTopMm,
            pageWidth,
            sliceHeightPx / pxPerMm
          )
          sourceY += sliceHeightPx
          pageIndex++
        }
      }

      const safeScope = reportScopeLabel.replace(/\s+/g, '_')
      pdf.save(`DailyTaskReport-${safeScope}-${selectedDate}.pdf`)
    } catch (err) {
      console.error('Daily task report PDF download failed:', err)
      setDownloadError(err?.message || 'PDF download failed. Try Print then Save as PDF.')
    } finally {
      if (fontMetricsFixStyle?.parentNode) {
        fontMetricsFixStyle.parentNode.removeChild(fontMetricsFixStyle)
      }
      setDownloading(false)
    }
  }

  return (
    <div className='p-4 md:p-6 bg-gray-50 min-h-full'>
      <style>{`
        @page { size: A4 portrait; margin: 10mm; }
        @media print {
          body * { visibility: hidden !important; }
          #daily-task-report-printable, #daily-task-report-printable * { visibility: visible !important; }
          #daily-task-report-printable {
            position: absolute !important;
            left: 0 !important;
            top: 0 !important;
            width: 100% !important;
            max-width: 100% !important;
            margin: 0 !important;
            padding: 0 !important;
            border: none !important;
            box-shadow: none !important;
            background: #ffffff !important;
          }
          .print\\:hidden, .print-hide-in-pdf { display: none !important; }
        }
      `}</style>

      <div className='max-w-6xl mx-auto space-y-5'>
        {/* Top Header */}
        <div className='flex flex-wrap items-start justify-between gap-4 print:hidden'>
          <div>
            <h1 className='text-2xl font-bold text-gray-900'>Daily Task Report</h1>
            <p className='text-sm text-gray-600 mt-1'>
              {canSelectMultipleEmployees
                ? 'Generate, view, print, or export daily task reports for yourself and employees.'
                : 'Generate, view, print, or export your daily task report.'}
            </p>
          </div>
          <div className='flex flex-wrap gap-2'>
            <button
              type='button'
              onClick={handleExportCsv}
              disabled={loading || dayTasks.length === 0}
              className='px-3.5 py-2 rounded-lg border border-gray-300 bg-white text-gray-800 text-sm font-medium hover:bg-gray-50 disabled:opacity-50'
            >
              Export CSV
            </button>
            <button
              type='button'
              onClick={() => window.print()}
              disabled={loading}
              className='px-3.5 py-2 rounded-lg bg-gray-700 text-white text-sm font-medium hover:bg-gray-800 disabled:opacity-50'
            >
              Print
            </button>
            <button
              type='button'
              onClick={handleDownloadPdf}
              disabled={loading || downloading}
              className='px-4 py-2 rounded-lg bg-blue-600 text-white text-sm font-medium hover:bg-blue-700 disabled:opacity-50 shadow-sm'
            >
              {downloading ? 'Generating PDF...' : 'Download PDF'}
            </button>
          </div>
        </div>

        {/* Filters Bar */}
        <div className='bg-white rounded-xl border border-gray-200 shadow-sm p-4 print:hidden'>
          <div className='flex flex-wrap items-end gap-3'>
            <div>
              <label className='block text-xs font-semibold text-gray-600 mb-1'>Report Date</label>
              <div className='flex items-center gap-1.5'>
                <button
                  type='button'
                  onClick={() => handleDateChange(shiftYmd(selectedDate, -1))}
                  className='px-2.5 py-2 rounded-lg border border-gray-300 text-xs font-medium hover:bg-gray-50'
                >
                  Prev
                </button>
                <input
                  type='date'
                  value={selectedDate}
                  onChange={(e) => handleDateChange(e.target.value)}
                  className='border border-gray-300 rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
                />
                <button
                  type='button'
                  onClick={() => handleDateChange(shiftYmd(selectedDate, 1))}
                  className='px-2.5 py-2 rounded-lg border border-gray-300 text-xs font-medium hover:bg-gray-50'
                >
                  Next
                </button>
                {selectedDate !== todayYmd && (
                  <button
                    type='button'
                    onClick={() => handleDateChange(todayYmd)}
                    className='px-2.5 py-2 rounded-lg text-xs font-semibold text-blue-700 hover:bg-blue-50'
                  >
                    Today
                  </button>
                )}
              </div>
            </div>

            {canSelectMultipleEmployees && departments.length > 1 && (
              <div>
                <label className='block text-xs font-semibold text-gray-600 mb-1'>Department</label>
                <select
                  value={departmentFilter}
                  onChange={(e) => {
                    setDepartmentFilter(e.target.value)
                    setSelectedEmployeeId('all')
                  }}
                  className='border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
                >
                  <option value='all'>All Departments</option>
                  {departments.map((d) => (
                    <option key={d} value={d}>{d}</option>
                  ))}
                </select>
              </div>
            )}

            {canSelectMultipleEmployees && (
              <div className='min-w-[200px]'>
                <label className='block text-xs font-semibold text-gray-600 mb-1'>Employee</label>
                <select
                  value={selectedEmployeeId}
                  onChange={(e) => handleEmployeeChange(e.target.value)}
                  className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
                >
                  <option value='all'>
                    {isFullAccess ? `All Employees (${filteredAllowedEmployees.length})` : `All Team Members (${filteredAllowedEmployees.length})`}
                  </option>
                  {filteredAllowedEmployees.map((emp) => (
                    <option key={refEmployeeId(emp)} value={refEmployeeId(emp)}>
                      {emp.name}
                      {refEmployeeId(emp) === currentUserId ? ' (You)' : ''}
                      {emp.designation?.title ? ` — ${emp.designation.title}` : ''}
                    </option>
                  ))}
                </select>
              </div>
            )}

            <div>
              <label className='block text-xs font-semibold text-gray-600 mb-1'>Status</label>
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className='border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
              >
                <option value='All'>All Statuses</option>
                <option value='Completed'>Completed</option>
                <option value='In Progress'>In Progress</option>
                <option value='Pending'>Pending</option>
                <option value='Paused'>Paused</option>
                <option value='Cancelled'>Cancelled</option>
              </select>
            </div>
          </div>
        </div>

        {error && (
          <div className='p-4 rounded-xl bg-red-50 border border-red-200 text-red-700 text-sm print:hidden'>
            {error}
          </div>
        )}
        {downloadError && (
          <div className='p-3 rounded-xl bg-amber-50 border border-amber-200 text-amber-800 text-xs print:hidden'>
            {downloadError}
          </div>
        )}

        {loading ? (
          <div className='bg-white rounded-xl border border-gray-200 p-10 text-center text-sm text-gray-500'>
            Loading daily task report...
          </div>
        ) : (
          <div
            id='daily-task-report-printable'
            ref={printRef}
            className='bg-white rounded-xl border border-gray-200 shadow-sm p-6 md:p-8 space-y-6'
            style={{ backgroundColor: '#ffffff', color: '#111827' }}
          >
            {/* Printable Report Header */}
            <div className='flex flex-wrap items-start justify-between gap-4 pb-4' style={{ borderBottom: '1px solid #e5e7eb' }}>
              <div className='flex items-center gap-3'>
                {logoSrc && (
                  <img
                    src={logoSrc}
                    alt='Company Logo'
                    className='report-company-logo h-12 w-auto max-w-[140px] object-contain'
                  />
                )}
                <div>
                  <h2 className='text-lg font-bold uppercase tracking-tight' style={{ color: '#111827' }}>
                    {company?.companyName || 'Daily Task Report'}
                  </h2>
                  <p className='text-xs font-medium' style={{ color: '#4b5563' }}>
                    Daily Employee Task Summary & Work Log
                  </p>
                </div>
              </div>
              <div className='text-right border-r-4 pr-3 shrink-0' style={{ borderColor: '#2563eb' }}>
                <span className='text-[10px] font-bold uppercase tracking-wider block' style={{ color: '#2563eb' }}>
                  Daily Task Report
                </span>
                <p className='text-sm font-bold' style={{ color: '#111827' }}>
                  {formatDisplayDate(selectedDate)}
                </p>
                <p className='text-xs' style={{ color: '#4b5563' }}>
                  Scope: <strong>{reportScopeLabel}</strong>
                </p>
                <p className='text-[10px] mt-0.5' style={{ color: '#6b7280' }}>
                  Generated by {user?.name || 'Employee'} on {new Date().toLocaleDateString('en-IN')}
                </p>
              </div>
            </div>

            {/* Individual Employee Meta & Attendance Time Summary */}
            {selectedEmployeeObj && (
              <div className='space-y-3'>
                <div
                  className='rounded-lg p-3 grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs'
                  style={{ backgroundColor: '#f9fafb', border: '1px solid #e5e7eb' }}
                >
                  <div>
                    <span className='block text-[10px] font-medium' style={{ color: '#6b7280' }}>Employee Name</span>
                    <span className='font-bold' style={{ color: '#111827' }}>{selectedEmployeeObj.name || '—'}</span>
                  </div>
                  <div>
                    <span className='block text-[10px] font-medium' style={{ color: '#6b7280' }}>Employee ID</span>
                    <span className='font-semibold' style={{ color: '#1f2937' }}>{selectedEmployeeObj.employeeCode || '—'}</span>
                  </div>
                  <div>
                    <span className='block text-[10px] font-medium' style={{ color: '#6b7280' }}>Designation</span>
                    <span className='font-semibold' style={{ color: '#1f2937' }}>
                      {selectedEmployeeObj.designation?.title || selectedEmployeeObj.designation?.name || '—'}
                    </span>
                  </div>
                  <div>
                    <span className='block text-[10px] font-medium' style={{ color: '#6b7280' }}>Department</span>
                    <span className='font-semibold' style={{ color: '#1f2937' }}>
                      {selectedEmployeeObj.department || selectedEmployeeObj.designation?.department || '—'}
                    </span>
                  </div>
                </div>

                {selectedEmployeeAttendance && (
                  <div
                    className='rounded-lg p-3 grid grid-cols-2 sm:grid-cols-5 gap-3 text-xs'
                    style={{ backgroundColor: '#f8fafc', border: '1px solid #e2e8f0' }}
                  >
                    <div>
                      <span className='block text-[10px] font-semibold uppercase' style={{ color: '#64748b' }}>Check In Time</span>
                      <span className='font-bold text-sm block mt-0.5' style={{ color: '#0f172a' }}>
                        {selectedEmployeeAttendance.checkIn}
                      </span>
                    </div>
                    <div>
                      <span className='block text-[10px] font-semibold uppercase' style={{ color: '#64748b' }}>Check Out Time</span>
                      <span className='font-bold text-sm block mt-0.5' style={{ color: '#0f172a' }}>
                        {selectedEmployeeAttendance.checkOut}
                      </span>
                    </div>
                    <div>
                      <span className='block text-[10px] font-semibold uppercase' style={{ color: '#b45309' }}>Break Total</span>
                      <span className='font-bold text-sm block mt-0.5' style={{ color: '#92400e' }}>
                        {selectedEmployeeAttendance.hasRecord ? `${selectedEmployeeAttendance.breakMins} min` : '—'}
                      </span>
                    </div>
                    <div>
                      <span className='block text-[10px] font-semibold uppercase' style={{ color: '#6b21a8' }}>Meeting Total</span>
                      <span className='font-bold text-sm block mt-0.5' style={{ color: '#7e22ce' }}>
                        {selectedEmployeeAttendance.hasRecord ? `${selectedEmployeeAttendance.meetingMins} min` : '—'}
                      </span>
                    </div>
                    <div>
                      <span className='block text-[10px] font-semibold uppercase' style={{ color: '#166534' }}>Total Working Time</span>
                      <span className='font-bold text-sm block mt-0.5' style={{ color: '#15803d' }}>
                        {selectedEmployeeAttendance.hasRecord ? formatMinsCompact(selectedEmployeeAttendance.workingMins) : '—'}
                      </span>
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* KPI Summary Cards */}
            <div className='grid grid-cols-2 sm:grid-cols-5 gap-3'>
              <div className='rounded-lg p-3 text-center' style={{ backgroundColor: '#f8fafc', border: '1px solid #e2e8f0' }}>
                <span className='text-[10px] font-bold uppercase block' style={{ color: '#475569' }}>Total Tasks</span>
                <span className='text-xl font-extrabold block mt-0.5' style={{ color: '#0f172a' }}>{stats.total}</span>
              </div>
              <div className='rounded-lg p-3 text-center' style={{ backgroundColor: '#f0fdf4', border: '1px solid #bbf7d0' }}>
                <span className='text-[10px] font-bold uppercase block' style={{ color: '#166534' }}>Completed</span>
                <span className='text-xl font-extrabold block mt-0.5' style={{ color: '#15803d' }}>
                  {stats.completed} <span className='text-xs font-semibold'>({stats.completionRate}%)</span>
                </span>
              </div>
              <div className='rounded-lg p-3 text-center' style={{ backgroundColor: '#eff6ff', border: '1px solid #bfdbfe' }}>
                <span className='text-[10px] font-bold uppercase block' style={{ color: '#1e40af' }}>In Progress</span>
                <span className='text-xl font-extrabold block mt-0.5' style={{ color: '#1d4ed8' }}>{stats.inProgress}</span>
              </div>
              <div className='rounded-lg p-3 text-center' style={{ backgroundColor: '#fffbeb', border: '1px solid #fde68a' }}>
                <span className='text-[10px] font-bold uppercase block' style={{ color: '#92400e' }}>Pending / Paused</span>
                <span className='text-xl font-extrabold block mt-0.5' style={{ color: '#b45309' }}>
                  {stats.pending + stats.paused}
                </span>
              </div>
              <div className='rounded-lg p-3 text-center' style={{ backgroundColor: '#faf5ff', border: '1px solid #e9d5ff' }}>
                <span className='text-[10px] font-bold uppercase block' style={{ color: '#6b21a8' }}>Logged / Est. Time</span>
                <span className='text-sm font-extrabold block mt-1.5' style={{ color: '#7e22ce' }}>
                  {stats.actualMinutes > 0
                    ? formatTaskDuration(stats.actualMinutes)
                    : stats.estMinutes > 0
                      ? formatTaskDuration(stats.estMinutes)
                      : '—'}
                </span>
              </div>
            </div>

            {/* Per-Employee Summary Table (when viewing All Employees / Team) */}
            {selectedEmployeeId === 'all' && employeeSummary.length > 0 && (
              <div>
                <h3 className='text-xs font-bold uppercase tracking-wider mb-2' style={{ color: '#1f2937' }}>
                  Employee-wise Summary
                </h3>
                <div className='overflow-x-auto'>
                  <table className='w-full text-xs border-collapse' style={{ border: '1px solid #d1d5db' }}>
                    <thead>
                      <tr style={{ backgroundColor: '#f3f4f6', borderBottom: '1px solid #d1d5db', color: '#1f2937' }}>
                        <th className='py-2 px-2.5 text-left font-bold'>Employee</th>
                        <th className='py-2 px-2 text-center font-bold'>Check In</th>
                        <th className='py-2 px-2 text-center font-bold'>Check Out</th>
                        <th className='py-2 px-2 text-center font-bold'>Break</th>
                        <th className='py-2 px-2 text-center font-bold'>Meeting</th>
                        <th className='py-2 px-2 text-center font-bold'>Working</th>
                        <th className='py-2 px-2 text-center font-bold'>Tasks</th>
                        <th className='py-2 px-2 text-center font-bold'>Done</th>
                        <th className='py-2 px-2 text-center font-bold'>Avg Rating</th>
                        <th className='py-2 px-2 text-right font-bold'>Completion</th>
                        <th className='py-2 px-2.5 text-right font-bold print-hide-in-pdf'>Action</th>
                      </tr>
                    </thead>
                    <tbody>
                      {employeeSummary.map((row) => {
                        const pct = row.total > 0 ? Math.round((row.completed / row.total) * 100) : 0
                        const avgRating = row.ratingCount > 0 ? (row.ratingSum / row.ratingCount).toFixed(1) : null
                        const attM = row.attMetrics
                        return (
                          <tr key={row.id} style={{ borderBottom: '1px solid #e5e7eb' }}>
                            <td className='py-2 px-2.5'>
                              <div className='font-semibold' style={{ color: '#111827' }}>{row.name}</div>
                              <div className='text-[10px]' style={{ color: '#6b7280' }}>{row.designation}</div>
                            </td>
                            <td className='py-2 px-2 text-center whitespace-nowrap'>{attM.checkIn}</td>
                            <td className='py-2 px-2 text-center whitespace-nowrap'>{attM.checkOut}</td>
                            <td className='py-2 px-2 text-center whitespace-nowrap' style={{ color: '#92400e' }}>
                              {attM.hasRecord ? `${attM.breakMins}m` : '—'}
                            </td>
                            <td className='py-2 px-2 text-center whitespace-nowrap' style={{ color: '#7e22ce' }}>
                              {attM.hasRecord ? `${attM.meetingMins}m` : '—'}
                            </td>
                            <td className='py-2 px-2 text-center font-semibold whitespace-nowrap' style={{ color: '#15803d' }}>
                              {attM.hasRecord ? formatMinsCompact(attM.workingMins) : '—'}
                            </td>
                            <td className='py-2 px-2 text-center font-semibold'>{row.total}</td>
                            <td className='py-2 px-2 text-center font-semibold' style={{ color: '#15803d' }}>{row.completed}</td>
                            <td className='py-2 px-2 text-center font-semibold' style={{ color: '#b45309' }}>
                              {avgRating ? `${avgRating}/5` : '—'}
                            </td>
                            <td className='py-2 px-2 text-right font-bold'>{pct}%</td>
                            <td className='py-2 px-2.5 text-right print-hide-in-pdf'>
                              <button
                                type='button'
                                onClick={() => handleEmployeeChange(row.id)}
                                className='text-blue-600 hover:underline font-medium'
                              >
                                View Report
                              </button>
                            </td>
                          </tr>
                        )
                      })}
                    </tbody>
                  </table>
                </div>
              </div>
            )}

            {/* Detailed Tasks Table */}
            <div>
              <h3 className='text-xs font-bold uppercase tracking-wider mb-2' style={{ color: '#1f2937' }}>
                Task Details ({dayTasks.length})
              </h3>
              {dayTasks.length === 0 ? (
                <div
                  className='rounded-lg p-8 text-center text-sm'
                  style={{ backgroundColor: '#f9fafb', border: '1px solid #e5e7eb', color: '#6b7280' }}
                >
                  No tasks recorded for {reportScopeLabel} on {formatDisplayDate(selectedDate)}.
                </div>
              ) : (
                <div className='overflow-x-auto'>
                  <table className='w-full text-xs border-collapse' style={{ border: '1px solid #d1d5db' }}>
                    <thead>
                      <tr style={{ backgroundColor: '#f3f4f6', borderBottom: '1px solid #d1d5db', color: '#1f2937' }}>
                        <th className='py-2 px-2.5 text-left font-bold'>#</th>
                        {selectedEmployeeId === 'all' && <th className='py-2 px-2.5 text-left font-bold'>Employee</th>}
                        <th className='py-2 px-2.5 text-left font-bold'>Task & Project</th>
                        <th className='py-2 px-2.5 text-center font-bold'>Priority</th>
                        <th className='py-2 px-2.5 text-center font-bold'>Status</th>
                        <th className='py-2 px-2.5 text-center font-bold'>Rating</th>
                        <th className='py-2 px-2.5 text-right font-bold'>Duration</th>
                        <th className='py-2 px-2.5 text-right font-bold'>Updated / Completed</th>
                      </tr>
                    </thead>
                    <tbody>
                      {dayTasks.map((task, idx) => {
                        const statusLabel = normalizeTaskStatus(task.status) || 'Pending'
                        const projectName = task.project?.projectName || task.project?.name || '—'
                        const ratingScore = getTaskRatingScore(task)
                        const ratingTitle = getTaskRatingTitle(task)
                        const estText = task.estimatedDurationMinutes
                          ? formatTaskDuration(task.estimatedDurationMinutes)
                          : ''
                        const actText = task.actualDurationMinutes
                          ? formatTaskDuration(task.actualDurationMinutes)
                          : ''
                        const durationDisplay =
                          actText && estText ? `${actText} / ${estText}` : actText || estText || '—'
                        return (
                          <tr key={task._id || idx} style={{ borderBottom: '1px solid #e5e7eb' }}>
                            <td className='py-2 px-2.5 align-top' style={{ color: '#6b7280' }}>{idx + 1}</td>
                            {selectedEmployeeId === 'all' && (
                              <td className='py-2 px-2.5 align-top font-semibold whitespace-nowrap' style={{ color: '#111827' }}>
                                {task.assignedTo?.name || '—'}
                              </td>
                            )}
                            <td className='py-2.5 px-2.5 align-top'>
                              <div className='font-semibold leading-snug' style={{ color: '#111827' }}>{task.title || '—'}</div>
                              <div className='text-[11px] leading-snug mt-0.5' style={{ color: '#4b5563' }}>Project: {projectName}</div>
                              {task.description && (
                                <div className='text-[11px] leading-snug mt-1 break-words' style={{ color: '#6b7280' }}>
                                  {task.description}
                                </div>
                              )}
                            </td>
                            <td className='py-2.5 px-2.5 align-top text-center'>
                              <span
                                className='inline-block px-2.5 py-1 rounded-full text-[10px] font-semibold leading-none'
                                style={getPriorityBadgeStyle(task.priority)}
                              >
                                {task.priority || 'Medium'}
                              </span>
                            </td>
                            <td className='py-2.5 px-2.5 align-top text-center'>
                              <span
                                className='inline-block px-2.5 py-1 rounded-full text-[10px] font-semibold leading-none whitespace-nowrap'
                                style={getStatusBadgeStyle(statusLabel)}
                              >
                                {statusLabel}
                              </span>
                            </td>
                            <td className='py-2.5 px-2.5 align-top text-center whitespace-nowrap'>
                              {ratingScore != null ? (
                                <div>
                                  <span
                                    className='inline-block px-2.5 py-1 rounded-full text-[10px] font-bold leading-none'
                                    style={{ backgroundColor: '#fef3c7', color: '#92400e' }}
                                    title={ratingTitle || `${ratingScore} out of 5`}
                                  >
                                    {ratingScore}/5
                                  </span>
                                  {ratingTitle && (
                                    <div className='text-[10px] leading-snug mt-1' style={{ color: '#6b7280' }}>
                                      {ratingTitle}
                                    </div>
                                  )}
                                </div>
                              ) : (
                                <span style={{ color: '#9ca3af' }}>—</span>
                              )}
                            </td>
                            <td className='py-2 px-2.5 align-top text-right whitespace-nowrap' style={{ color: '#374151' }}>
                              {durationDisplay}
                            </td>
                            <td className='py-2 px-2.5 align-top text-right whitespace-nowrap' style={{ color: '#374151' }}>
                              {task.completedAt
                                ? `Done ${formatTimeShort(task.completedAt)}`
                                : formatTimeShort(task.updatedAt || task.createdAt)}
                            </td>
                          </tr>
                        )
                      })}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

export default DailyTaskReportPage
