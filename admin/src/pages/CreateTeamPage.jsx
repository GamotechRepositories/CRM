import React, { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../api/axios'
import CentralAdminShell from '../components/CentralAdminShell'
import { AppIcon } from '../components/Icons'
import { TENANT_IDS, TENANT_LOGOS, TENANT_NAMES } from '../config/tenants'

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
  const navigate = useNavigate()
  const [form, setForm] = useState(emptyForm)
  const [roles, setRoles] = useState(DEFAULT_ROLES)
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  useEffect(() => {
    api.get('/ceo-team')
      .then((res) => {
        if (Array.isArray(res.data?.roles) && res.data.roles.length) {
          setRoles(res.data.roles)
          setForm((prev) => ({
            ...prev,
            role: res.data.roles.includes(prev.role) ? prev.role : res.data.roles[0],
          }))
        }
      })
      .catch(() => {})
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
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to create teammate')
    } finally {
      setLoading(false)
    }
  }

  return (
    <CentralAdminShell activeNav='create-team'>
      <div className='flex flex-wrap items-start justify-between gap-4 mb-6'>
        <div>
          <h1 className='text-2xl font-bold text-gray-900'>Create Team</h1>
          <p className='text-sm text-gray-500 mt-1'>
            Add a CEO support team member who schedules and runs meetings across companies.
          </p>
        </div>
        <button
          type='button'
          onClick={() => navigate('/team-members')}
          className='px-4 py-2 rounded-xl border border-gray-200 text-sm font-semibold text-gray-700 hover:bg-gray-50'
        >
          View team members
        </button>
      </div>

      <div className='w-full'>
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

          <form onSubmit={handleSubmit} className='space-y-6'>
            <div className='grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4'>
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
            </div>

            <div className='grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4'>
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
            </div>

            <div>
              <p className='block text-sm font-semibold text-slate-800 mb-2'>Companies access</p>
              <div className='grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-2'>
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
              className='w-full lg:w-auto lg:min-w-[220px] bg-indigo-600 hover:bg-indigo-700 text-white py-3 px-8 rounded-xl font-semibold text-sm transition-colors disabled:opacity-50 shadow-lg shadow-indigo-200'
            >
              {loading ? 'Creating…' : 'Create team member'}
            </button>
          </form>
        </div>
      </div>
    </CentralAdminShell>
  )
}

export default CreateTeamPage
