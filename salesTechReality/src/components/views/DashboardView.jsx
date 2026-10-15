import React, { useState, useEffect } from 'react'
import { Navigate, useLocation } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import AdminDashboardView from './AdminDashboardView'
import EmployeeDashboardView from './EmployeeDashboardView'
import HRDashboardView from './HRDashboardView'
import ManagerDashboardView from './ManagerDashboardView'
import TeamLeaderDashboardView from './TeamLeaderDashboardView'
import SiteCoordinatorDashboardView from './SiteCoordinatorDashboardView'
import AssignedTasksTab from './AssignedTasksTab'
import TaskApprovalView from './TaskApprovalView'
import ChatFloatingButton from '../ChatFloatingButton'
import {
  getDashboardKind,
  getDashboardPathForUser,
  hasTravelDashboard,
  isDashboardRoute,
  isSiteCoordinatorUser,
} from '../../config/dashboardRoutes'

const DashboardTabs = ({ children }) => {
  const { canAssignTask } = useAuth()
  const location = useLocation()
  const searchParams = new URLSearchParams(location.search)
  const initialTab = searchParams.get('tab') === 'approval' ? 'approval' : (searchParams.get('tab') === 'assigned' ? 'assigned' : 'overview')
  const [tab, setTab] = useState(initialTab)

  useEffect(() => {
    const qTab = searchParams.get('tab')
    if (qTab === 'approval' || qTab === 'assigned' || qTab === 'overview') {
      setTab(qTab)
    }
  }, [location.search])

  if (!canAssignTask()) return children

  return (
    <div className='w-full min-h-full'>
      <div className='px-6 md:px-8 pt-6 pb-0 bg-[#f8f9fa] border-b border-gray-200'>
        <div className='flex flex-wrap gap-2'>
          <button
            type='button'
            onClick={() => setTab('overview')}
            className={`px-4 py-2 rounded-t-lg text-sm font-semibold border border-b-0 transition-colors ${
              tab === 'overview'
                ? 'bg-white text-blue-700 border-gray-200'
                : 'bg-transparent text-gray-600 border-transparent hover:text-gray-900'
            }`}
          >
            Overview
          </button>
          <button
            type='button'
            onClick={() => setTab('assigned')}
            className={`px-4 py-2 rounded-t-lg text-sm font-semibold border border-b-0 transition-colors ${
              tab === 'assigned'
                ? 'bg-white text-blue-700 border-gray-200'
                : 'bg-transparent text-gray-600 border-transparent hover:text-gray-900'
            }`}
          >
            Assigned Tasks
          </button>
          <button
            type='button'
            onClick={() => setTab('approval')}
            className={`px-4 py-2 rounded-t-lg text-sm font-semibold border border-b-0 transition-colors ${
              tab === 'approval'
                ? 'bg-white text-blue-700 border-gray-200'
                : 'bg-transparent text-gray-600 border-transparent hover:text-gray-900'
            }`}
          >
            Task Approval
          </button>
        </div>
      </div>
      {tab === 'assigned' ? <AssignedTasksTab /> : tab === 'approval' ? <TaskApprovalView /> : children}
    </div>
  )
}

const DashboardView = () => {
  const { user } = useAuth()
  const location = useLocation()
  const canonicalPath = getDashboardPathForUser(user)
  const kind = getDashboardKind(user)

  if (isDashboardRoute(location.pathname) && location.pathname !== canonicalPath) {
    return <Navigate to={canonicalPath} replace />
  }

  let content
  if (kind === 'admin') content = <AdminDashboardView />
  else if (kind === 'hr') content = <HRDashboardView />
  else if (kind === 'manager') content = <ManagerDashboardView />
  else if (kind === 'team_leader') content = <TeamLeaderDashboardView />
  else if (kind === 'site_coordinator') content = <SiteCoordinatorDashboardView />
  else content = <EmployeeDashboardView />

  // In STR, employee dashboard and others dashboard get travel allowance & route map with timeline.
  if (kind !== 'site_coordinator') {
    content = (
      <>
        {content}
        <SiteCoordinatorDashboardView embedded />
      </>
    )
  }

  return (
    <>
      <DashboardTabs>{content}</DashboardTabs>
      <ChatFloatingButton />
    </>
  )
}

export const RoleDashboardRedirect = () => {
  const { user, loading } = useAuth()
  if (loading) return null
  return <Navigate to={getDashboardPathForUser(user)} replace />
}

export default DashboardView
