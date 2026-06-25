import React, { useState } from 'react'
import Logo from '../assets/Asset.png'
import { useNavigate, useLocation } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import {
  DashboardIcon,
  UsersIcon,
  SettingsIcon,
  LogoutIcon,
  HomeIcon,
  ProjectsIcon,
  TasksIcon,
  AttendanceIcon,
  LeadIcon,
  CalendarAltIcon,
  BookIcon,
  BillingIcon,
  Salaries,
} from './Icons'

const MenuToggleIcon = () => (
  <svg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' strokeWidth={1.5} stroke='currentColor' className='size-6'>
    <path strokeLinecap='round' strokeLinejoin='round' d='M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5' />
  </svg>
)

const ChevronDownIcon = ({ className = 'size-4' }) => (
  <svg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' strokeWidth={2} stroke='currentColor' className={className}>
    <path strokeLinecap='round' strokeLinejoin='round' d='m19.5 8.25-7.5 7.5-7.5-7.5' />
  </svg>
)

const ChevronRightIcon = ({ className = 'size-4' }) => (
  <svg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' strokeWidth={2} stroke='currentColor' className={className}>
    <path strokeLinecap='round' strokeLinejoin='round' d='m8.25 4.5 7.5 7.5-7.5 7.5' />
  </svg>
)

const ALLOWED_GROUPS_FOR_OTHERS = ['General', 'Social Media']

const Sidebar = ({ isOpen = true, onToggle }) => {
  const navigate = useNavigate()
  const location = useLocation()
  const { logout, hasFullAccess, canViewProjects, isHRManager } = useAuth()
  const [expandedGroup, setExpandedGroup] = useState('General')

  const toggleGroup = (title) => {
    setExpandedGroup((prev) => (prev === title ? null : title))
  }

  const allGroups = [
    {
      title: 'Admin',
      items: [
        { id: 'admin-dashboard', label: isHRManager() ? 'HR Dashboard' : 'Admin Dashboard', icon: <DashboardIcon />, path: '/admin-dashboard' },
        { id: 'clients', label: 'Clients', icon: <BookIcon />, path: '/clients' },
        { id: 'company', label: 'Company', icon: <SettingsIcon />, path: '/companies' },
        { id: 'collaborators', label: 'Collaborators', icon: <UsersIcon />, path: '/collaborators' },
      ],
    },
    {
      title: 'HR Management',
      items: [
        { id: 'employees', label: 'Employees', icon: <UsersIcon />, path: '/employees' },
        { id: 'salaries', label: 'Salaries', icon: <Salaries />, path: '/salaries' },
        { id: 'billings', label: 'Billings', icon: <BillingIcon />, path: '/billings' },
        { id: 'expenses', label: 'Expenses', icon: <BillingIcon />, path: '/expenses' },
        { id: 'revenue', label: 'Revenue', icon: <BillingIcon />, path: '/revenue' },
      ],
    },
    {
      title: 'General',
      items: [
        { id: 'home', label: 'Home', icon: <HomeIcon />, path: '/dashboard' },
        { id: 'projects', label: 'Projects', icon: <ProjectsIcon />, path: '/projects' },
        { id: 'my-projects', label: 'My Projects', icon: <ProjectsIcon />, path: '/my-projects' },
        { id: 'tasks', label: 'Tasks', icon: <TasksIcon />, path: '/tasks', showWhen: 'hasFullAccess' },
        { id: 'my-tasks', label: 'My Tasks', icon: <TasksIcon />, path: '/my-tasks' },
        { id: 'attendance', label: 'Attendance', icon: <AttendanceIcon />, path: '/attendance' },
        { id: 'leave', label: 'Leave', icon: <CalendarAltIcon />, path: '/leave' },
        { id: 'lead-management', label: 'Lead Management', icon: <LeadIcon />, path: '/lead-management' },
      ],
    },
    {
      title: 'Social Media',
      items: [{ id: 'social-calendar', label: 'Social Media Calendar', icon: <CalendarAltIcon />, path: '/social-calendar' }],
    },
  ]

  const groups = hasFullAccess()
    ? allGroups
    : allGroups.filter((g) => ALLOWED_GROUPS_FOR_OTHERS.includes(g.title))

  const filterItemsByProjectAccess = (items) => {
    if (canViewProjects()) return items
    return items.filter((item) => item.id !== 'projects')
  }

  const filterItemsByTaskAccess = (items) => {
    return items.filter((item) => {
      if (item.id === 'tasks' && item.showWhen === 'hasFullAccess') return hasFullAccess()
      return true
    })
  }

  const groupsWithFilteredItems = groups.map((g) => ({
    ...g,
    items: filterItemsByTaskAccess(filterItemsByProjectAccess(g.items)),
  }))

  return (
    <aside className={`bg-gray-900 text-white text-sm h-screen flex flex-col shadow-2xl border-r border-gray-800 transition-all duration-200 flex-shrink-0 ${isOpen ? 'w-64' : 'w-16'}`}>
      {/* Toggle & Logo Section */}
      <div className='px-3 py-4 border-b border-gray-800 flex items-center justify-center'>
        {isOpen ? (
          <div className='w-full flex items-center justify-between px-2'>
            <button
              type='button'
              onClick={() => navigate('/admin-dashboard')}
              className='flex cursor-pointer items-center gap-3 min-w-0 rounded-lg focus:outline-none focus-visible:ring-2 focus-visible:ring-cyan-400'
              title='Go to Admin Dashboard'
            >
              <div className='h-10 rounded-lg flex-shrink-0 overflow-hidden'>
                <img src={Logo} alt='Digital Buddiess' className='w-full h-full object-cover' />
              </div>
              {/* <p className='text-sm text-gray-400 truncate'>Gamotech Software</p> */}
            </button>
            <button
              onClick={onToggle}
              className='p-2 rounded-lg hover:bg-gray-800 text-gray-300 hover:text-white transition-colors flex-shrink-0'
              title='Hide menu'
            >
              <MenuToggleIcon />
            </button>
          </div>
        ) : (
          <button
            onClick={onToggle}
            className='p-2 rounded-lg hover:bg-gray-800 text-gray-300 hover:text-white transition-colors'
            title='Show menu'
          >
            <MenuToggleIcon />
          </button>
        )}
      </div>

      {/* Navigation Items */}
      <nav className={`flex-1 py-4 space-y-2 overflow-y-auto overflow-x-hidden ${isOpen ? 'px-4' : 'px-0'}`}>
        {groupsWithFilteredItems.map((group) => {
          const isExpanded = expandedGroup === group.title
          return (
            <div key={group.title} className='space-y-1'>
              {isOpen ? (
                <>
                  <button
                    type='button'
                    onClick={() => toggleGroup(group.title)}
                    className='w-full flex items-center justify-between gap-2 py-2 px-2 rounded-lg text-sm text-gray-400 hover:bg-gray-800 hover:text-white transition-colors'
                  >
                    <span className='truncate'>{group.title}</span>
                    <span className='flex-shrink-0 text-gray-500'>
                      {isExpanded ? <ChevronDownIcon /> : <ChevronRightIcon />}
                    </span>
                  </button>
                  {isExpanded && (
                    <div className='space-y-1'>
                      {group.items.map((item) => {
                        const path = item.path || `/${item.id}`
                        const isActive = location.pathname === path
                        return (
                          <button
                            key={item.id}
                            onClick={() => navigate(path)}
                            className={`w-full flex items-center gap-3 py-2.5 rounded-lg transition-all duration-150 text-gray-300 hover:bg-gray-800 hover:text-white ${
                              isActive ? 'bg-gray-800 text-white' : ''
                            } pl-4 pr-4`}
                          >
                            <span className='h-5 w-5 flex items-center justify-center flex-shrink-0'>{item.icon}</span>
                            <span className='text-sm truncate'>{item.label}</span>
                          </button>
                        )
                      })}
                    </div>
                  )}
                </>
              ) : (
                <div className='space-y-1'>
                  {group.items.map((item) => {
                    const path = item.path || `/${item.id}`
                    const isActive = location.pathname === path
                    return (
                      <button
                        key={item.id}
                        onClick={() => navigate(path)}
                        className={`w-full flex items-center gap-3 py-2.5 rounded-lg transition-all duration-150 text-gray-300 hover:bg-gray-800 hover:text-white ${
                          isActive ? 'bg-gray-800 text-white' : ''
                        } px-3 justify-center`}
                        title={item.label}
                      >
                        <span className='h-5 w-5 flex items-center justify-center flex-shrink-0'>{item.icon}</span>
                      </button>
                    )
                  })}
                </div>
              )}
            </div>
          )
        })}
      </nav>

      {/* Footer Section */}
      <div className={`border-t border-gray-800 py-2 ${isOpen ? 'px-4' : 'px-2'}`}>
        <div className='mt-2 space-y-2'>
          <button
            onClick={() => navigate('/settings')}
            className={`w-full flex items-center gap-3 py-2.5 rounded-lg transition-all duration-200 ${isOpen ? 'px-4' : 'px-3 justify-center'} ${
              location.pathname === '/settings' ? 'bg-gray-800 text-white' : 'text-gray-300 hover:bg-gray-800 hover:text-white'
            }`}
            title={!isOpen ? 'Settings' : undefined}
          >
            <span className='text-xl'><SettingsIcon /></span>
            {isOpen && <span className='font-medium'>Settings</span>}
          </button>
          <button
            onClick={() => { logout(); navigate('/login') }}
            className={`w-full flex items-center gap-3 py-2.5 text-gray-300 hover:bg-red-900 hover:text-red-200 rounded-lg transition-all duration-200 ${isOpen ? 'px-4' : 'px-3 justify-center'}`}
            title={!isOpen ? 'Logout' : undefined}
          >
            <span className='text-xl'><LogoutIcon /></span>
            {isOpen && <span className='font-medium'>Logout</span>}
          </button>
        </div>
      </div>
    </aside>
  )
}

export default Sidebar
