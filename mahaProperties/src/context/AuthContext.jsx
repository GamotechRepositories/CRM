import React, { createContext, useContext, useState, useEffect } from 'react'
import api from '../api/axios'
import { getDashboardPathForUser } from '../config/dashboardRoutes'

const AUTH_KEY = 'crm_user'

const AuthContext = createContext(null)

export const useAuth = () => {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const stored = localStorage.getItem(AUTH_KEY)
    if (stored) {
      try {
        setUser(JSON.parse(stored))
      } catch {
        localStorage.removeItem(AUTH_KEY)
      }
    }
    setLoading(false)
  }, [])

  const login = async (email, password) => {
    const res = await api.post('/auth/login', { email, password })
    const u = res.data?.user
    if (u) {
      setUser(u)
      localStorage.setItem(AUTH_KEY, JSON.stringify(u))
      return u
    }
    throw new Error(res.data?.message || 'Login failed')
  }

  const logout = () => {
    setUser(null)
    localStorage.removeItem(AUTH_KEY)
  }

  const getDesignationTitle = () => (user?.designation?.title || user?.designation?.name || '').toLowerCase()

  const isAdmin = () => getDesignationTitle() === 'admin'

  const isHRManager = () => {
    const title = getDesignationTitle()
    return title === 'admin' || title === 'hr manager'
  }

  const hasFullAccess = () => {
    const title = getDesignationTitle()
    return ['admin', 'hr manager', 'technical lead'].includes(title)
  }

  const canAddProject = () => {
    const title = getDesignationTitle()
    return ['admin', 'hr manager', 'technical lead', 'senior software engineer', 'product manager'].includes(title)
  }

  /** Any logged-in employee can add/edit posts on the social media calendar. */
  const canManageSocialCalendar = () => Boolean(user)

  const canViewProjects = () => {
    const title = getDesignationTitle()
    return [
      'admin',
      'hr manager',
      'technical lead',
      'social media manager',
      'product manager',
      'senior software engineer',
      'project manager',
      'engineering manager',
    ].includes(title)
  }

  const canAssignTask = () => {
    const title = getDesignationTitle()
    return [
      'admin',
      'social media manager',
      'hr manager',
      'technical lead',
      'product manager',
      'senior software engineer',
      'project manager',
      'engineering manager',
    ].includes(title)
  }

  const canApproveLeave = () => {
    const title = getDesignationTitle()
    return [
      'admin',
      'hr manager',
      'project manager',
      'technical lead',
      'engineering manager',
      'product manager',
      'senior software engineer',
    ].includes(title)
  }

  const getSidebarSections = () => user?.access?.sidebarSections || []

  const getDashboardPath = () => getDashboardPathForUser(user)

  return (
    <AuthContext.Provider value={{ user, loading, login, logout, isHRManager, hasFullAccess, canAddProject, canManageSocialCalendar, canViewProjects, canAssignTask, canApproveLeave, getSidebarSections, getDashboardPath, isAdmin }}>
      {children}
    </AuthContext.Provider>
  )
}
