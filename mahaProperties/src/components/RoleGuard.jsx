import React from 'react'
import { Navigate, useLocation } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'

const HR_ONLY_PATHS = [
  '/admin-dashboard',
  '/clients',
  '/add-client',
  '/employees',
  '/add-employee',
  '/salaries',
  '/add-salary',
  '/billings',
  '/campaigns',
  '/reports',
  '/calendar',
]

const isHROnlyPath = (pathname) => {
  return HR_ONLY_PATHS.some((p) => pathname === p || pathname.startsWith(p + '/'))
}

const isAddProjectPath = (pathname) => {
  return pathname === '/add-project' || pathname.startsWith('/projects/edit/')
}

const isProjectsOnlyPath = (pathname) => {
  if (pathname === '/projects') return true
  if (/^\/projects\/[^/]+\/dashboard$/.test(pathname)) return true
  if (pathname.startsWith('/projects/edit/')) return true
  return false
}

const isAssignTaskPath = (pathname) => pathname === '/assign-task'
const isTasksListPath = (pathname) => pathname === '/tasks'

const RoleGuard = ({ children }) => {
  const { hasFullAccess, canAddProject, canViewProjects, canAssignTask, getDashboardPath } = useAuth()
  const location = useLocation()
  const dashboardPath = getDashboardPath()

  if (hasFullAccess()) return children

  const tasksDetailMatch = location.pathname.match(/^\/tasks\/([^/]+)$/)
  if (tasksDetailMatch) {
    return <Navigate to={`/my-tasks/${tasksDetailMatch[1]}`} replace />
  }
  if (isHROnlyPath(location.pathname)) {
    return <Navigate to={dashboardPath} replace />
  }
  if (isProjectsOnlyPath(location.pathname) && !canViewProjects()) {
    return <Navigate to={dashboardPath} replace />
  }
  if (isAddProjectPath(location.pathname) && !canAddProject()) {
    return <Navigate to={dashboardPath} replace />
  }
  if (isAssignTaskPath(location.pathname) && !canAssignTask()) {
    return <Navigate to={dashboardPath} replace />
  }
  if (isTasksListPath(location.pathname) && !hasFullAccess()) {
    return <Navigate to='/my-tasks' replace />
  }
  return children
}

export default RoleGuard
