import React from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { AppIcon } from './Icons'
import centralLogo from '../assets/logo.jpg'

export const getInitials = (name = '') =>
  name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() || '')
    .join('') || 'NA'

const NAV_ITEMS = [
  { id: 'home', label: 'Home', icon: 'home', path: '/' },
  { id: 'create-team', label: 'Create Team', icon: 'createTeam', path: '/create-team' },
  { id: 'team-members', label: 'Team Members', icon: 'employees', path: '/team-members' },
]

const CentralAdminShell = ({ activeNav = 'home', children }) => {
  const navigate = useNavigate()
  const { user, logout } = useAuth()

  return (
    <div className='h-screen overflow-hidden bg-[#F5F7FB] flex'>
      <aside className='w-64 h-full bg-[#0F172A] text-white flex flex-col shrink-0'>
        <div className='px-4 py-5 border-b border-white/10'>
          <div className='flex items-center gap-3'>
            <img src={centralLogo} alt='Central Admin' className='w-10 h-10 rounded-xl object-contain bg-white p-1' />
            <div className='min-w-0'>
              <p className='font-semibold text-sm truncate'>Central Admin</p>
              <p className='text-[11px] text-slate-400 truncate'>CEO support team</p>
            </div>
          </div>
        </div>

        <nav className='flex-1 px-3 py-4 space-y-1 overflow-y-auto'>
          {NAV_ITEMS.map((item) => {
            const active = activeNav === item.id
            return (
              <button
                key={item.id}
                type='button'
                onClick={() => navigate(item.path)}
                className={`w-full flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm transition-colors ${
                  active
                    ? 'bg-blue-600 text-white'
                    : 'text-slate-300 hover:bg-white/5 hover:text-white'
                }`}
              >
                <AppIcon id={item.icon} className='size-5 shrink-0' />
                <span className='font-medium'>{item.label}</span>
              </button>
            )
          })}
        </nav>

        <div className='p-3 border-t border-white/10'>
          <div className='flex items-center gap-3 rounded-xl px-3 py-2.5 bg-white/5'>
            <div className='w-9 h-9 rounded-full bg-blue-600 flex items-center justify-center text-xs font-bold'>
              {getInitials(user?.name || 'CEO')}
            </div>
            <div className='min-w-0 flex-1'>
              <p className='text-sm font-medium truncate'>{user?.name || 'CEO'}</p>
              <p className='text-[11px] text-slate-400 truncate'>{user?.email || ''}</p>
            </div>
          </div>
        </div>
      </aside>

      <div className='flex-1 min-w-0 min-h-0 flex flex-col'>
        <header className='bg-white border-b border-gray-200 px-4 sm:px-6 py-3 flex items-center justify-between shrink-0'>
          <p className='text-sm font-medium text-gray-700'>Satish Bangar Group · Admin</p>
          <button
            type='button'
            onClick={() => { logout(); navigate('/login') }}
            className='rounded-lg border border-gray-200 px-3 py-1.5 text-xs font-medium text-gray-600 hover:bg-gray-50 hover:text-gray-900'
          >
            Logout
          </button>
        </header>
        <main className='flex-1 min-h-0 overflow-y-auto p-4 sm:p-6'>{children}</main>
      </div>
    </div>
  )
}

export default CentralAdminShell
