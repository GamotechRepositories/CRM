import React, { useEffect, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { AppIcon } from './Icons'
import { TENANT_IDS, TENANT_LOGOS, TENANT_NAMES } from '../config/tenants'
import centralLogo from '../assets/logo.jpg'

const NAV_ITEMS = [
  { id: 'dashboard', label: 'Dashboard', icon: 'dashboard', path: '' },
  { id: 'employees', label: 'Employees', icon: 'employees', path: 'employees' },
  { id: 'clients', label: 'Clients', icon: 'clients', path: 'clients' },
  { id: 'projects', label: 'Projects', icon: 'projects', path: 'projects' },
  { id: 'leads', label: 'Leads', icon: 'leads', path: 'leads' },
  { id: 'tasks', label: 'Tasks', icon: 'tasks', path: 'tasks' },
  { id: 'invoices', label: 'Invoices', icon: 'invoices', path: 'invoices' },
  { id: 'leaves', label: 'Leaves', icon: 'leaves', path: 'leaves' },
  { id: 'reports', label: 'Reports', icon: 'reports', path: 'reports' },
  { id: 'settings', label: 'Settings', icon: 'settings', path: 'settings' },
]

const getInitials = (name = '') =>
  name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() || '')
    .join('') || 'NA'

const AdminCompanyShell = ({ activeNav = 'dashboard', children }) => {
  const { tenantId: paramTenantId } = useParams()
  const navigate = useNavigate()
  const { user, logout } = useAuth()
  const [sidebarOpen, setSidebarOpen] = useState(true)
  const [showHeaderCompanyMenu, setShowHeaderCompanyMenu] = useState(false)
  const [showSidebarCompanyMenu, setShowSidebarCompanyMenu] = useState(false)
  const headerMenuRef = useRef(null)
  const sidebarMenuRef = useRef(null)

  const hasCompanyContext = Boolean(paramTenantId)
  const logo = hasCompanyContext ? TENANT_LOGOS[paramTenantId] : centralLogo
  const name = hasCompanyContext
    ? (TENANT_NAMES[paramTenantId] || paramTenantId)
    : 'Central Admin'

  const switchCompany = (nextTenantId) => {
    if (!nextTenantId) {
      setShowHeaderCompanyMenu(false)
      setShowSidebarCompanyMenu(false)
      return
    }
    setShowHeaderCompanyMenu(false)
    setShowSidebarCompanyMenu(false)
    const current = NAV_ITEMS.find((item) => item.id === activeNav)
    if (current?.absolutePath) {
      navigate(current.absolutePath)
      return
    }
    const suffix = current?.path ? `/${current.path}` : ''
    navigate(`/company/${nextTenantId}${suffix}`)
  }

  useEffect(() => {
    const onClickOutside = (event) => {
      if (headerMenuRef.current && !headerMenuRef.current.contains(event.target)) {
        setShowHeaderCompanyMenu(false)
      }
      if (sidebarMenuRef.current && !sidebarMenuRef.current.contains(event.target)) {
        setShowSidebarCompanyMenu(false)
      }
    }
    document.addEventListener('mousedown', onClickOutside)
    return () => document.removeEventListener('mousedown', onClickOutside)
  }, [])

  const handleNav = (item) => {
    if (item.absolutePath) {
      navigate(item.absolutePath)
      return
    }
    if (item.path === null) return
    const targetTenant = paramTenantId || TENANT_IDS[0]
    navigate(item.path ? `/company/${targetTenant}/${item.path}` : `/company/${targetTenant}`)
  }

  const CompanySwitcherMenu = ({ className = '' }) => (
    <div className={`absolute z-50 mt-2 w-72 rounded-xl border border-gray-200 bg-white shadow-xl overflow-hidden ${className}`}>
      <div className='px-3 py-2 border-b border-gray-100'>
        <p className='text-xs font-semibold uppercase tracking-wide text-gray-400'>Switch company</p>
      </div>
      {TENANT_IDS.map((id) => {
        const selected = hasCompanyContext && id === paramTenantId
        return (
          <button
            key={id}
            type='button'
            onClick={() => {
              setShowHeaderCompanyMenu(false)
              setShowSidebarCompanyMenu(false)
              switchCompany(id)
            }}
            className={`w-full flex items-center gap-3 px-3 py-2.5 text-left hover:bg-indigo-50 transition-colors ${
              selected ? 'bg-indigo-50' : 'bg-white'
            }`}
          >
            <img
              src={TENANT_LOGOS[id]}
              alt={TENANT_NAMES[id]}
              className='w-8 h-8 rounded-lg object-contain border border-gray-100 bg-white'
            />
            <div className='min-w-0 flex-1'>
              <p className={`text-sm font-medium truncate ${selected ? 'text-indigo-700' : 'text-gray-900'}`}>
                {TENANT_NAMES[id]}
              </p>
            </div>
            {selected && <span className='text-xs font-semibold text-indigo-600'>Active</span>}
          </button>
        )
      })}
    </div>
  )

  return (
    <div className='h-screen overflow-hidden bg-[#F5F7FB] flex'>
      <aside
        className={`${
          sidebarOpen ? 'w-64' : 'w-20'
        } h-full bg-[#0F172A] text-white flex flex-col shrink-0 transition-all duration-200`}
      >
        <div className='px-4 py-5 border-b border-white/10'>
          <div className='flex items-center gap-3'>
            {logo ? (
              <img src={logo} alt={name} className='w-10 h-10 rounded-xl object-contain bg-white p-1' />
            ) : (
              <div className='w-10 h-10 rounded-xl bg-blue-600 flex items-center justify-center font-bold'>
                {getInitials(name)}
              </div>
            )}
            {sidebarOpen && (
              <div className='min-w-0'>
                <p className='font-semibold text-sm truncate'>{name}</p>
              </div>
            )}
          </div>
        </div>

        <nav className='flex-1 px-3 py-4 space-y-1 overflow-y-auto'>
          {NAV_ITEMS.map((item) => {
            const active = activeNav === item.id
            return (
              <button
                key={item.id}
                type='button'
                onClick={() => handleNav(item)}
                className={`w-full flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm transition-colors ${
                  active
                    ? 'bg-blue-600 text-white'
                    : 'text-slate-300 hover:bg-white/5 hover:text-white'
                }`}
                title={!sidebarOpen ? item.label : undefined}
              >
                <AppIcon id={item.icon} className='size-5 shrink-0' />
                {sidebarOpen && <span className='font-medium'>{item.label}</span>}
              </button>
            )
          })}
        </nav>

        <div className='p-3 border-t border-white/10' ref={sidebarMenuRef}>
          <button
            type='button'
            onClick={() => {
              setShowSidebarCompanyMenu((v) => !v)
              setShowHeaderCompanyMenu(false)
            }}
            className='w-full flex items-center gap-3 rounded-xl px-3 py-2.5 bg-white/5 hover:bg-white/10 transition-colors'
          >
            {logo ? (
              <img src={logo} alt={name} className='w-9 h-9 rounded-full object-contain bg-white p-0.5' />
            ) : (
              <div className='w-9 h-9 rounded-full bg-blue-600 flex items-center justify-center text-xs font-bold'>
                AD
              </div>
            )}
            {sidebarOpen && (
              <>
                <div className='min-w-0 flex-1 text-left'>
                  <p className='text-sm font-medium truncate'>{name}</p>
                  <p className='text-[11px] text-slate-400'>Switch company</p>
                </div>
                <span className='text-slate-400 text-xs'>▾</span>
              </>
            )}
          </button>
          {showSidebarCompanyMenu && (
            <div className='relative'>
              <CompanySwitcherMenu className='left-0 right-0 w-full' />
            </div>
          )}
        </div>
      </aside>

      <div className='flex-1 min-w-0 min-h-0 flex flex-col'>
        <header className='bg-white border-b border-gray-200 px-4 sm:px-6 py-3 flex items-center gap-3 shrink-0'>
          <button
            type='button'
            onClick={() => setSidebarOpen((v) => !v)}
            className='p-2 rounded-lg text-gray-500 hover:bg-gray-100'
            title='Toggle menu'
          >
            ☰
          </button>

          <div className='relative' ref={headerMenuRef}>
            <button
              type='button'
              onClick={() => {
                setShowHeaderCompanyMenu((v) => !v)
                setShowSidebarCompanyMenu(false)
              }}
              className='flex items-center gap-2 px-3 py-2 rounded-xl border border-gray-200 text-sm font-medium text-gray-700 hover:bg-gray-50'
            >
              {logo && <img src={logo} alt='' className='w-5 h-5 rounded object-contain' />}
              <span className='hidden sm:inline'>{name}</span>
              <span className='text-gray-400'>▾</span>
            </button>
            {showHeaderCompanyMenu && <CompanySwitcherMenu />}
          </div>

          <div className='ml-auto flex items-center gap-2 sm:gap-3'>
            <div className='flex items-center gap-2 pl-2 border-l border-gray-200'>
              <div className='w-9 h-9 rounded-full bg-blue-600 text-white flex items-center justify-center text-sm font-bold'>
                {getInitials(user?.name || 'CEO')}
              </div>
              <div className='hidden sm:block leading-tight'>
                <p className='text-sm font-medium text-gray-900'>{user?.name || 'CEO'}</p>
                <p className='text-[11px] text-gray-400'>{user?.role || 'CEO'} · {user?.email || ''}</p>
              </div>
              <button
                type='button'
                onClick={() => { logout(); navigate('/login') }}
                className='ml-1 rounded-lg border border-gray-200 px-3 py-1.5 text-xs font-medium text-gray-600 hover:bg-gray-50 hover:text-gray-900'
              >
                Logout
              </button>
            </div>
          </div>
        </header>

        <main className='flex-1 min-h-0 overflow-y-auto p-4 sm:p-6'>{children}</main>
      </div>
    </div>
  )
}

export default AdminCompanyShell
export { getInitials }
