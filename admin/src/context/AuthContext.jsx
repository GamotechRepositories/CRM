import React, { createContext, useContext, useEffect, useMemo, useState } from 'react'
import api from '../api/axios'

const AUTH_KEY = 'central_admin_user'
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
    try {
      const raw = localStorage.getItem(AUTH_KEY)
      if (raw) {
        const parsed = JSON.parse(raw)
        const canManage =
          parsed.canManageEmployees ??
          parsed.canManageAll ??
          parsed.isCentralAdmin ??
          parsed.isRoot ??
          false
        setUser({
          ...parsed,
          canManageEmployees: canManage,
          canManageAll: canManage,
        })
      }
    } catch {
      localStorage.removeItem(AUTH_KEY)
    } finally {
      setLoading(false)
    }
  }, [])

  const login = async (email, password) => {
    const res = await api.post('/auth/login', { email, password })
    const nextUser = res.data?.user
    if (!nextUser) throw new Error(res.data?.message || 'Login failed')
    setUser(nextUser)
    localStorage.setItem(AUTH_KEY, JSON.stringify(nextUser))
    return nextUser
  }

  const logout = () => {
    setUser(null)
    localStorage.removeItem(AUTH_KEY)
  }

  const value = useMemo(
    () => ({
      user,
      loading,
      login,
      logout,
      isAuthenticated: Boolean(user),
      canManageEmployees: () => Boolean(user?.canManageEmployees ?? user?.canManageAll ?? user?.isCentralAdmin ?? user?.isRoot),
      canManageAll: () => Boolean(user?.canManageAll ?? user?.canManageEmployees ?? user?.isCentralAdmin ?? user?.isRoot),
    }),
    [user, loading]
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
