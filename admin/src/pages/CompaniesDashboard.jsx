import React, { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../api/axios'
import { useAuth } from '../context/AuthContext'
import { TENANT_IDS, TENANT_LOGOS, TENANT_NAMES } from '../config/tenants'

const CompanyLogo = ({ logo, name }) => {
  const [failed, setFailed] = useState(false)
  const initials = (name || '?').trim().slice(0, 2).toUpperCase() || '?'

  if (!logo || failed) {
    return (
      <div className='w-24 h-24 rounded-2xl bg-indigo-50 text-indigo-700 flex items-center justify-center text-2xl font-bold border border-indigo-100'>
        {initials}
      </div>
    )
  }

  return (
    <img
      src={logo}
      alt={name || 'Company logo'}
      onError={() => setFailed(true)}
      className='w-24 h-24 rounded-2xl object-contain bg-white border border-gray-100 p-2'
    />
  )
}

const CompaniesDashboard = () => {
  const { user, logout } = useAuth()
  const navigate = useNavigate()
  const [companies, setCompanies] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')

  const fetchCompanies = async () => {
    try {
      setLoading(true)
      setError('')
      const res = await api.get('/companies')
      setCompanies(Array.isArray(res.data) ? res.data : [])
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to load companies')
      setCompanies([])
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchCompanies()
  }, [])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return companies
    return companies.filter((row) =>
      [row.tenantLabel, row.tenantId, row.companyName, row.email]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(q))
    )
  }, [companies, search])

  const displayCompanies = useMemo(() => {
    const byTenant = new Map()

    for (const row of filtered) {
      const existing = byTenant.get(row.tenantId)
      if (!existing || (existing.isEmpty && !row.isEmpty)) {
        byTenant.set(row.tenantId, row)
      }
    }

    return TENANT_IDS.map((tenantId) => {
      const row = byTenant.get(tenantId)
      return {
        tenantId,
        name: TENANT_NAMES[tenantId],
        logo: TENANT_LOGOS[tenantId],
        companyName: row && !row.isEmpty ? row.companyName : TENANT_NAMES[tenantId],
      }
    }).filter((item) => {
      const q = search.trim().toLowerCase()
      if (!q) return true
      return [item.name, item.companyName, item.tenantId]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(q))
    })
  }, [filtered, search])

  const handleLogout = () => {
    logout()
    navigate('/login')
  }

  return (
    <div className='min-h-screen bg-[#f8f9fa]'>
      <header className='bg-white border-b border-gray-200'>
        <div className='max-w-7xl mx-auto px-4 sm:px-6 py-4 flex flex-wrap items-center justify-between gap-3'>
          <div>
            <h1 className='text-xl font-bold text-gray-900'>Central Admin</h1>
            <p className='text-sm text-gray-500 mt-0.5'>
              All companies · Signed in as {user?.email || 'root'}
            </p>
          </div>
          <div className='flex items-center gap-2'>
            <button
              type='button'
              onClick={() => navigate('/create-team')}
              className='px-4 py-2 rounded-lg bg-indigo-600 text-white text-sm font-medium hover:bg-indigo-700'
            >
              Create Team
            </button>
            <button
              type='button'
              onClick={fetchCompanies}
              className='px-4 py-2 rounded-lg border border-gray-200 text-sm font-medium text-gray-700 hover:bg-gray-50'
            >
              Refresh
            </button>
            <button
              type='button'
              onClick={handleLogout}
              className='px-4 py-2 rounded-lg bg-slate-900 text-white text-sm font-medium hover:bg-slate-800'
            >
              Logout
            </button>
          </div>
        </div>
      </header>

      <main className='max-w-7xl mx-auto px-4 sm:px-6 py-8'>
        <div className='flex flex-wrap items-center justify-between gap-3 mb-6'>
          <div>
            <h2 className='text-lg font-semibold text-gray-900'>Companies</h2>
            <p className='text-sm text-gray-500'>{displayCompanies.length} company{displayCompanies.length === 1 ? '' : 'ies'}</p>
          </div>
          <input
            type='search'
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder='Search company…'
            className='w-full sm:w-72 border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white'
          />
        </div>

        {error && (
          <div className='mb-4 rounded-lg bg-red-50 border border-red-100 px-3 py-2'>
            <p className='text-red-600 text-sm'>{error}</p>
          </div>
        )}

        {loading ? (
          <div className='bg-white rounded-xl border border-gray-200 shadow-sm p-10 text-center text-sm text-gray-500'>
            Loading companies…
          </div>
        ) : displayCompanies.length === 0 ? (
          <div className='bg-white rounded-xl border border-gray-200 shadow-sm p-10 text-center text-sm text-gray-500'>
            No companies found.
          </div>
        ) : (
          <div className='grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5'>
            {displayCompanies.map((row) => (
              <button
                key={row.tenantId}
                type='button'
                onClick={() => navigate(`/company/${row.tenantId}`)}
                className='bg-white rounded-2xl border border-gray-200 shadow-sm p-6 flex flex-col items-center text-center hover:shadow-md hover:border-indigo-200 transition-all'
              >
                <CompanyLogo logo={row.logo} name={row.name} />
                <h3 className='mt-4 text-base font-semibold leading-snug text-gray-900'>
                  {row.name}
                </h3>
                <p className='mt-2 text-xs font-medium text-indigo-600'>Open dashboard →</p>
              </button>
            ))}
          </div>
        )}
      </main>
    </div>
  )
}

export default CompaniesDashboard
