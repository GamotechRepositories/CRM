import React, { useEffect, useState } from 'react'
import api from '../api/axios'
import AdminCompanyShell, { getInitials } from '../components/AdminCompanyShell'
import { AppIcon } from '../components/Icons'
import { TENANT_IDS, TENANT_LOGOS, TENANT_NAMES } from '../config/tenants'

const API_TARGET = import.meta.env.VITE_API_PROXY_TARGET || 'https://crm-1-foi4.onrender.com'
const apiBackendLabel = import.meta.env.VITE_API_URL
  ? import.meta.env.VITE_API_URL
  : `Live backend → MongoDB (${API_TARGET})`

const DEFAULT_ROLES = [
  'Executive Assistant',
  'Meeting Coordinator',
  'Scheduler',
  'Chief of Staff',
  'Secretary',
]

const emptyForm = {
  name: '',
  email: '',
  phone: '',
  role: 'Executive Assistant',
  password: '',
  confirmPassword: '',
  tenants: [...TENANT_IDS],
}

const CreateTeamPage = () => {
  const [form, setForm] = useState(emptyForm)
  const [roles, setRoles] = useState(DEFAULT_ROLES)
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const [team, setTeam] = useState([])
  const [teamLoading, setTeamLoading] = useState(true)

  const loadTeam = async () => {
    try {
      setTeamLoading(true)
      const res = await api.get('/ceo-team')
      setTeam(res.data?.users || [])
      if (Array.isArray(res.data?.roles) && res.data.roles.length) {
        setRoles(res.data.roles)
        setForm((prev) => ({
          ...prev,
          role: res.data.roles.includes(prev.role) ? prev.role : res.data.roles[0],
        }))
      }
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to load team')
    } finally {
      setTeamLoading(false)
    }
  }

  useEffect(() => {
    loadTeam()
  }, [])

  const setField = (key, value) => setForm((prev) => ({ ...prev, [key]: value }))

  const toggleTenant = (tenantId) => {
    setForm((prev) => {
      const has = prev.tenants.includes(tenantId)
      const tenants = has
        ? prev.tenants.filter((id) => id !== tenantId)
        : [...prev.tenants, tenantId]
      return { ...prev, tenants }
    })
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    setSuccess('')

    if (!form.name.trim() || !form.email.trim() || !form.password) {
      setError('Name, email and password are required')
      return
    }
    if (!form.role) {
      setError('Please assign a role')
      return
    }
    if (form.password !== form.confirmPassword) {
      setError('Passwords do not match')
      return
    }
    if (form.password.length < 6) {
      setError('Password must be at least 6 characters')
      return
    }
    if (!form.tenants.length) {
      setError('Select at least one company')
      return
    }

    setLoading(true)
    try {
      await api.post('/ceo-team', {
        name: form.name.trim(),
        email: form.email.trim().toLowerCase(),
        phone: form.phone.trim(),
        password: form.password,
        role: form.role,
        tenants: form.tenants,
      })
      setSuccess(`Team member saved to MongoDB as ${form.role}`)
      setForm({ ...emptyForm, role: roles[0] || 'Executive Assistant' })
      await loadTeam()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to create teammate')
    } finally {
      setLoading(false)
    }
  }

  return (
    <AdminCompanyShell activeNav='create-team'>
      <div className='flex flex-wrap items-start justify-between gap-4 mb-6'>
        <div>
          <h1 className='text-2xl font-bold text-gray-900'>Create Team</h1>
          <p className='text-sm text-gray-500 mt-1'>
            Build the CEO support team that schedules and runs meetings for the boss across companies.
          </p>
          <p className='text-xs text-indigo-700 bg-indigo-50 border border-indigo-100 rounded-lg px-3 py-2 mt-3 inline-block'>
            Saved to <span className='font-semibold'>live MongoDB</span> via{' '}
            <span className='font-semibold'>{apiBackendLabel}</span>
            {' — '}
            mobile meeting app login uses this same backend.
          </p>
        </div>
      </div>

      <div className='grid grid-cols-1 xl:grid-cols-5 gap-6'>
        <div className='xl:col-span-2'>
          <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-6 sm:p-8'>
            <div className='flex items-center gap-3 mb-6'>
              <div className='w-11 h-11 rounded-xl bg-indigo-100 text-indigo-700 flex items-center justify-center'>
                <AppIcon id='createTeam' className='size-5' />
              </div>
              <div>
                <h2 className='text-lg font-semibold text-gray-900'>Team signup</h2>
                <p className='text-xs text-gray-500'>Roles for meeting support to the CEO</p>
              </div>
            </div>

            <form onSubmit={handleSubmit} className='space-y-4'>
              <div>
                <label className='block text-sm font-semibold text-slate-800 mb-1.5'>Full name</label>
                <input
                  type='text'
                  value={form.name}
                  onChange={(e) => setField('name', e.target.value)}
                  required
                  className='w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500'
                  placeholder='e.g. Priya Sharma'
                />
              </div>

              <div>
                <label className='block text-sm font-semibold text-slate-800 mb-1.5'>Email</label>
                <input
                  type='email'
                  value={form.email}
                  onChange={(e) => setField('email', e.target.value)}
                  required
                  autoComplete='off'
                  className='w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500'
                  placeholder='teammate@company.com'
                />
              </div>

              <div>
                <label className='block text-sm font-semibold text-slate-800 mb-1.5'>Phone</label>
                <input
                  type='tel'
                  value={form.phone}
                  onChange={(e) => setField('phone', e.target.value)}
                  className='w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500'
                  placeholder='Optional'
                />
              </div>

              <div>
                <label className='block text-sm font-semibold text-slate-800 mb-1.5'>Assign role</label>
                <select
                  value={form.role}
                  onChange={(e) => setField('role', e.target.value)}
                  required
                  className='w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white'
                >
                  {roles.map((role) => (
                    <option key={role} value={role}>{role}</option>
                  ))}
                </select>
                <p className='text-[11px] text-gray-400 mt-1'>
                  CEO is the boss only — team roles organize meetings on their behalf
                </p>
              </div>

              <div>
                <label className='block text-sm font-semibold text-slate-800 mb-1.5'>Password</label>
                <div className='relative'>
                  <input
                    type={showPassword ? 'text' : 'password'}
                    value={form.password}
                    onChange={(e) => setField('password', e.target.value)}
                    required
                    autoComplete='new-password'
                    className='w-full border border-gray-200 rounded-xl px-3 py-2.5 pr-20 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500'
                    placeholder='Min 6 characters'
                  />
                  <button
                    type='button'
                    onClick={() => setShowPassword((v) => !v)}
                    className='absolute right-3 top-1/2 -translate-y-1/2 text-xs font-medium text-indigo-600'
                  >
                    {showPassword ? 'Hide' : 'Show'}
                  </button>
                </div>
              </div>

              <div>
                <label className='block text-sm font-semibold text-slate-800 mb-1.5'>Confirm password</label>
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={form.confirmPassword}
                  onChange={(e) => setField('confirmPassword', e.target.value)}
                  required
                  autoComplete='new-password'
                  className='w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500'
                  placeholder='Re-enter password'
                />
              </div>

              <div>
                <p className='block text-sm font-semibold text-slate-800 mb-2'>Companies access</p>
                <div className='space-y-2'>
                  {TENANT_IDS.map((id) => (
                    <label
                      key={id}
                      className='flex items-center gap-3 rounded-xl border border-gray-100 px-3 py-2.5 cursor-pointer hover:bg-slate-50'
                    >
                      <input
                        type='checkbox'
                        checked={form.tenants.includes(id)}
                        onChange={() => toggleTenant(id)}
                        className='rounded border-gray-300 text-indigo-600 focus:ring-indigo-500'
                      />
                      <img
                        src={TENANT_LOGOS[id]}
                        alt=''
                        className='w-7 h-7 rounded-lg object-contain border border-gray-100 bg-white'
                      />
                      <span className='text-sm text-gray-800'>{TENANT_NAMES[id]}</span>
                    </label>
                  ))}
                </div>
              </div>

              {error && (
                <p className='text-red-600 text-sm bg-red-50 border border-red-100 rounded-lg px-3 py-2'>{error}</p>
              )}
              {success && (
                <p className='text-emerald-700 text-sm bg-emerald-50 border border-emerald-100 rounded-lg px-3 py-2'>
                  {success}
                </p>
              )}

              <button
                type='submit'
                disabled={loading}
                className='w-full bg-indigo-600 hover:bg-indigo-700 text-white py-3 rounded-xl font-semibold text-sm transition-colors disabled:opacity-50 shadow-lg shadow-indigo-200'
              >
                {loading ? 'Creating…' : 'Create team member'}
              </button>
            </form>
          </div>
        </div>

        <div className='xl:col-span-3'>
          <div className='bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden'>
            <div className='px-5 py-4 border-b border-gray-100 flex items-center justify-between'>
              <div>
                <h2 className='text-sm font-semibold text-gray-900'>Team members</h2>
                <p className='text-xs text-gray-500 mt-0.5'>{team.length} member{team.length === 1 ? '' : 's'}</p>
              </div>
            </div>

            {teamLoading ? (
              <p className='p-8 text-center text-sm text-gray-500'>Loading team…</p>
            ) : team.length ? (
              <div className='overflow-x-auto'>
                <table className='min-w-full text-sm'>
                  <thead className='bg-slate-50 text-left text-xs uppercase tracking-wide text-gray-500'>
                    <tr>
                      <th className='px-4 py-3 font-semibold'>Member</th>
                      <th className='px-4 py-3 font-semibold'>Role</th>
                      <th className='px-4 py-3 font-semibold'>Companies</th>
                      <th className='px-4 py-3 font-semibold'>Status</th>
                    </tr>
                  </thead>
                  <tbody className='divide-y divide-gray-50'>
                    {team.map((member, index) => (
                      <tr key={member._id}>
                        <td className='px-4 py-3'>
                          <div className='flex items-center gap-3'>
                            <div className={`w-9 h-9 rounded-full flex items-center justify-center text-xs font-bold text-white ${
                              index % 2 === 0 ? 'bg-indigo-500' : 'bg-violet-500'
                            }`}>
                              {getInitials(member.name)}
                            </div>
                            <div className='min-w-0'>
                              <p className='font-semibold text-gray-900 truncate'>
                                {member.name}
                                {member.isRoot ? (
                                  <span className='ml-2 text-[10px] uppercase tracking-wide text-amber-700 bg-amber-50 border border-amber-100 px-1.5 py-0.5 rounded'>
                                    Root
                                  </span>
                                ) : null}
                              </p>
                              <p className='text-xs text-gray-400 truncate'>{member.email}</p>
                            </div>
                          </div>
                        </td>
                        <td className='px-4 py-3'>
                          <span className={`inline-flex px-2 py-0.5 rounded-md text-xs font-medium ${
                            member.role === 'CEO'
                              ? 'bg-amber-50 text-amber-700'
                              : 'bg-indigo-50 text-indigo-700'
                          }`}>
                            {member.role || 'Executive Assistant'}
                          </span>
                        </td>
                        <td className='px-4 py-3'>
                          <div className='flex flex-wrap gap-1.5'>
                            {(member.tenants || []).map((id) => (
                              <span
                                key={id}
                                title={TENANT_NAMES[id]}
                                className='inline-flex items-center gap-1 rounded-lg border border-gray-100 bg-white px-1.5 py-1'
                              >
                                <img
                                  src={TENANT_LOGOS[id]}
                                  alt={TENANT_NAMES[id]}
                                  className='w-5 h-5 rounded object-contain'
                                />
                              </span>
                            ))}
                          </div>
                        </td>
                        <td className='px-4 py-3'>
                          <span className={`inline-flex px-2 py-0.5 rounded-md text-xs font-medium ${
                            member.status === 'Active'
                              ? 'bg-emerald-50 text-emerald-700'
                              : 'bg-rose-50 text-rose-700'
                          }`}>
                            {member.status || 'Active'}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <p className='p-8 text-center text-sm text-gray-500'>No team members yet</p>
            )}
          </div>
        </div>
      </div>
    </AdminCompanyShell>
  )
}

export default CreateTeamPage
