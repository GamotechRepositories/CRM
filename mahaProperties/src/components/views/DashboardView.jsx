import React from 'react'
import { Navigate, useLocation } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import AdminDashboardView from './AdminDashboardView'
import EmployeeDashboardView from './EmployeeDashboardView'
import HRDashboardView from './HRDashboardView'
import { getDashboardKind, getDashboardPathForUser, isDashboardRoute } from '../../config/dashboardRoutes'

const DashboardView = () => {
  const { user } = useAuth()
  const location = useLocation()
  const canonicalPath = getDashboardPathForUser(user)
  const kind = getDashboardKind(user)

  if (isDashboardRoute(location.pathname) && location.pathname !== canonicalPath) {
    return <Navigate to={canonicalPath} replace />
  }

  if (kind === 'admin') return <AdminDashboardView />
  if (kind === 'hr') return <HRDashboardView />
  return <EmployeeDashboardView />
}

export const RoleDashboardRedirect = () => {
  const { user, loading } = useAuth()
  if (loading) return null
  return <Navigate to={getDashboardPathForUser(user)} replace />
}

export default DashboardView
