import React, { createContext, useContext, useEffect, useMemo, useState } from 'react'
import axios from 'axios'
import api from '../api/axios'
import { TENANT_IDS } from '../config/tenants'

const AUTH_KEY = 'central_admin_user'
const TOKEN_KEY = 'central_admin_token'
const COMPANY_SESSIONS_KEY = 'central_operation_company_sessions'
const AuthContext = createContext(null)

const getApiRoot = () => {
  const adminBase = import.meta.env.VITE_API_URL || '/api/v1/admin'
  return String(adminBase).replace(/\/admin\/?$/, '')
}

const normalizeAdminUser = (parsed) => {
  if (!parsed) return null
  const role = String(parsed.role || '').toUpperCase()
  const canManage =
    parsed.canManageEmployees ??
    parsed.canManageAll ??
    parsed.accessEquivalentToCeo ??
    parsed.isOperationLogin ??
    parsed.isCentralAdmin ??
    parsed.isRoot ??
    (role === 'COO' || role === 'CEO')
  return {
    ...parsed,
    canManageEmployees: Boolean(canManage),
    canManageAll: Boolean(canManage),
  }
}

export const useAuth = () => {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)

  const mergeOperationSession = (parsedUser, sessions = {}) => {
    if (!parsedUser) return null
    const mergedSessions = {
      ...(typeof sessions === 'object' && sessions ? sessions : {}),
      ...(parsedUser.companySessions || {}),
    }
    const mergedTenants = [
      ...new Set([
        ...(Array.isArray(parsedUser.tenants) ? parsedUser.tenants : []),
        ...Object.keys(mergedSessions),
      ]),
    ].filter((id) => TENANT_IDS.includes(id))

    return normalizeAdminUser({
      ...parsedUser,
      companySessions: mergedSessions,
      tenants: mergedTenants.length ? mergedTenants : parsedUser.tenants,
    })
  }

  useEffect(() => {
    try {
      const raw = localStorage.getItem(AUTH_KEY)
      let sessions = {}
      try {
        const sessionsRaw = localStorage.getItem(COMPANY_SESSIONS_KEY)
        sessions = sessionsRaw ? JSON.parse(sessionsRaw) : {}
      } catch {
        sessions = {}
      }
      if (raw) {
        setUser(mergeOperationSession(JSON.parse(raw), sessions))
      }
    } catch {
      localStorage.removeItem(AUTH_KEY)
    } finally {
      setLoading(false)
    }
  }, [])

  const persistSession = (nextUser, token = null, companySessions = null) => {
    const normalized = mergeOperationSession(nextUser, companySessions || nextUser?.companySessions)
    setUser(normalized)
    localStorage.setItem(AUTH_KEY, JSON.stringify(normalized))
    if (token) localStorage.setItem(TOKEN_KEY, token)
    if (normalized?.companySessions) {
      localStorage.setItem(COMPANY_SESSIONS_KEY, JSON.stringify(normalized.companySessions))
    }
    return normalized
  }

  const login = async (email, password) => {
    const res = await api.post('/auth/login', { email, password })
    const nextUser = res.data?.user
    if (!nextUser) throw new Error(res.data?.message || 'Login failed')
    return persistSession(nextUser, res.data?.token || null)
  }

  /**
   * COO operations login:
   * 1) Call each company CRM login API with the same payload
   * 2) Finalize via admin /auth/login/operation (CEO-equivalent session)
   */
  const loginOperation = async (email, password) => {
    const payload = { email, password }
    const apiRoot = getApiRoot()

    const companyResults = await Promise.all(
      TENANT_IDS.map(async (tenantId) => {
        try {
          const res = await axios.post(`${apiRoot}/${tenantId}/auth/login`, payload)
          return { tenantId, ok: true, user: res.data?.user || null }
        } catch {
          return { tenantId, ok: false, user: null }
        }
      })
    )

    const clientSessions = {}
    for (const row of companyResults) {
      if (row.ok && row.user) clientSessions[row.tenantId] = row.user
    }

    const res = await api.post('/auth/login/operation', payload)
    const nextUser = res.data?.user
    if (!nextUser) throw new Error(res.data?.message || 'Operations login failed')

    const serverSessions = res.data?.companySessions || nextUser.companySessions || {}
    const companySessions = { ...clientSessions, ...serverSessions }
    const tenantIds = [
      ...new Set([
        ...(Array.isArray(res.data?.tenants) ? res.data.tenants : []),
        ...(Array.isArray(nextUser.tenants) ? nextUser.tenants : []),
        ...Object.keys(companySessions),
      ]),
    ].filter((id) => TENANT_IDS.includes(id))

    return persistSession(
      {
        ...nextUser,
        tenants: tenantIds,
        companySessions,
        isOperationLogin: true,
        loginVia: 'operation',
        canManageEmployees: true,
        canManageAll: true,
        accessEquivalentToCeo: true,
      },
      res.data?.token || null,
      companySessions
    )
  }

  const logout = () => {
    setUser(null)
    localStorage.removeItem(AUTH_KEY)
    localStorage.removeItem(TOKEN_KEY)
    localStorage.removeItem(COMPANY_SESSIONS_KEY)
  }

  const companySessions = useMemo(() => {
    const fromUser =
      user?.companySessions && typeof user.companySessions === 'object'
        ? user.companySessions
        : {}
    try {
      const raw = localStorage.getItem(COMPANY_SESSIONS_KEY)
      const fromStorage = raw ? JSON.parse(raw) : {}
      return { ...fromStorage, ...fromUser }
    } catch {
      return fromUser
    }
  }, [user])

  const isOperationUser = Boolean(
    user?.isOperationLogin ||
      user?.loginVia === 'operation' ||
      String(user?.role || '').toUpperCase() === 'COO'
  )

  const allowedTenants = useMemo(() => {
    if (!user) return []

    const sessionTenantIds = Object.keys(companySessions || {}).filter((id) =>
      TENANT_IDS.includes(id)
    )
    const declaredTenantIds = Array.isArray(user.tenants)
      ? user.tenants.filter((id) => TENANT_IDS.includes(id))
      : []

    if (isOperationUser) {
      const merged = [...new Set([...declaredTenantIds, ...sessionTenantIds])]
      return merged.length ? merged : [...TENANT_IDS]
    }

    if (user.isRoot) return [...TENANT_IDS]

    const scoped = declaredTenantIds.length ? declaredTenantIds : sessionTenantIds
    return scoped.length ? scoped : [...TENANT_IDS]
  }, [user, companySessions, isOperationUser])

  const value = useMemo(
    () => ({
      user,
      loading,
      login,
      loginOperation,
      logout,
      allowedTenants,
      companySessions,
      isOperationUser,
      isAuthenticated: Boolean(user),
      canManageEmployees: () =>
        Boolean(
          user?.canManageEmployees ??
            user?.canManageAll ??
            user?.accessEquivalentToCeo ??
            user?.isOperationLogin ??
            user?.isCentralAdmin ??
            user?.isRoot
        ),
      canManageAll: () =>
        Boolean(
          user?.canManageAll ??
            user?.canManageEmployees ??
            user?.accessEquivalentToCeo ??
            user?.isOperationLogin ??
            user?.isCentralAdmin ??
            user?.isRoot
        ),
    }),
    [user, loading, allowedTenants, companySessions, isOperationUser]
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
