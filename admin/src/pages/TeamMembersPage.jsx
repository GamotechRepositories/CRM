import React, { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../api/axios'
import CentralAdminShell, { getInitials } from '../components/CentralAdminShell'
import { TENANT_IDS, TENANT_LOGOS, TENANT_NAMES } from '../config/tenants'

const DEFAULT_ROLES = [
  'Executive Assistant',
  'Meeting Coordinator',
  'Scheduler',
  'Chief of Staff',
  'Secretary',
]

const emptyEditForm = {
  name: '',
  email: '',
  phone: '',
  role: 'Executive Assistant',
  status: 'Active',
  password: '',
  confirmPassword: '',
  tenants: [...TENANT_IDS],
}

const TeamMembersPage = () => {
  const navigate = useNavigate()
  const [team, setTeam] = useState([])
  const [roles, setRoles] = useState(DEFAULT_ROLES)
  const [teamLoading, setTeamLoading] = useState(true)
  const [deletingId, setDeletingId] = useState(null)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const [editForm, setEditForm] = useState(emptyEditForm)
  const [editingMember, setEditingMember] = useState(null)
  const [showPassword, setShowPassword] = useState(false)

  const loadTeam = async () => {
    try {
      setTeamLoading(true)
      const res = await api.get('/ceo-team')
      setTeam(res.data?.users || [])
      if (Array.isArray(res.data?.roles) && res.data.roles.length) {
        setRoles(res.data.roles)
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

  const setField = (key, value) => setEditForm((prev) => ({ ...prev, [key]: value }))

  const toggleTenant = (tenantId) => {
    setEditForm((prev) => {
      const has = prev.tenants.includes(tenantId)
      const tenants = has
        ? prev.tenants.filter((id) => id !== tenantId)
        : [...prev.tenants, tenantId]
      return { ...prev, tenants }
    })
  }

  const openEdit = (member) => {
    if (member.isRoot || member.role === 'CEO') {
      setError('Root CEO account cannot be edited here')
      return
    }
    setError('')
    setSuccess('')
    setEditingMember(member)
    setShowPassword(false)
    setEditForm({
      name: member.name || '',
      email: member.email || '',
      phone: member.phone || '',
      role: roles.includes(member.role) ? member.role : (roles[0] || 'Executive Assistant'),
      status: member.status || 'Active',
      password: '',
      confirmPassword: '',
      tenants: Array.isArray(member.tenants) && member.tenants.length ? [...member.tenants] : [...TENANT_IDS],
    })
  }

  const closeEdit = () => {
    setEditingMember(null)
    setEditForm(emptyEditForm)
    setShowPassword(false)
  }

  const handleDelete = async (member) => {
    if (member.isRoot || member.role === 'CEO') {
      setError('Root CEO account cannot be deleted')
      return
    }
    const ok = window.confirm(`Delete team member "${member.name}"? This cannot be undone.`)
    if (!ok) return

    setError('')
    setSuccess('')
    setDeletingId(member._id)
    try {
      await api.delete(`/ceo-team/${member._id}`)
      if (editingMember?._id === member._id) closeEdit()
      setSuccess(`Deleted ${member.name}`)
      await loadTeam()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to delete teammate')
    } finally {
      setDeletingId(null)
    }
  }

  const handleUpdate = async (e) => {
    e.preventDefault()
    if (!editingMember) return

    setError('')
    setSuccess('')

    if (!editForm.name.trim() || !editForm.email.trim()) {
      setError('Name and email are required')
      return
    }
    if (editForm.password || editForm.confirmPassword) {
      if (editForm.password !== editForm.confirmPassword) {
        setError('Passwords do not match')
        return
      }
      if (editForm.password.length < 6) {
        setError('Password must be at least 6 characters')
        return
      }
    }
    if (!editForm.tenants.length) {
      setError('Select at least one company')
      return
    }

    setSaving(true)
    try {
      const payload = {
        name: editForm.name.trim(),
        email: editForm.email.trim().toLowerCase(),
        phone: editForm.phone.trim(),
        role: editForm.role,
        status: editForm.status,
        tenants: editForm.tenants,
      }
      if (editForm.password) payload.password = editForm.password

      await api.put(`/ceo-team/${editingMember._id}`, payload)
      setSuccess(`Updated ${editForm.name.trim()}`)
      closeEdit()
      await loadTeam()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to update teammate')
    } finally {
      setSaving(false)
    }
  }

  return (
    <CentralAdminShell activeNav='team-members'>
      <div className='flex flex-wrap items-start justify-between gap-4 mb-6'>
        <div>
          <h1 className='text-2xl font-bold text-gray-900'>Team Members</h1>
          <p className='text-sm text-gray-500 mt-1'>
            View, update, and manage CEO support team accounts across all companies.
          </p>
        </div>
        <button
          type='button'
          onClick={() => navigate('/create-team')}
          className='px-4 py-2 rounded-xl bg-indigo-600 text-white text-sm font-semibold hover:bg-indigo-700'
        >
          + Add member
        </button>
      </div>

      {(error || success) && !editingMember ? (
        <div className='mb-4 space-y-2'>
          {error ? (
            <p className='text-red-600 text-sm bg-red-50 border border-red-100 rounded-lg px-3 py-2'>{error}</p>
          ) : null}
          {success ? (
            <p className='text-emerald-700 text-sm bg-emerald-50 border border-emerald-100 rounded-lg px-3 py-2'>{success}</p>
          ) : null}
        </div>
      ) : null}

      <div className='bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden'>
        <div className='px-5 py-4 border-b border-gray-100 flex items-center justify-between'>
          <div>
            <h2 className='text-sm font-semibold text-gray-900'>All members</h2>
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
                  <th className='px-4 py-3 font-semibold text-right'>Actions</th>
                </tr>
              </thead>
              <tbody className='divide-y divide-gray-50'>
                {team.map((member, index) => {
                  const locked = Boolean(member.isRoot || member.role === 'CEO')
                  return (
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
                            {member.phone ? (
                              <p className='text-xs text-gray-400 truncate'>{member.phone}</p>
                            ) : null}
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
                      <td className='px-4 py-3'>
                        <div className='flex items-center justify-end gap-2'>
                          <button
                            type='button'
                            disabled={locked}
                            onClick={() => openEdit(member)}
                            title={locked ? 'Root CEO cannot be edited' : 'Update'}
                            className='inline-flex items-center px-2.5 py-1.5 rounded-lg text-xs font-semibold border border-indigo-200 text-indigo-700 bg-indigo-50 hover:bg-indigo-100 disabled:opacity-40 disabled:cursor-not-allowed'
                          >
                            Update
                          </button>
                          <button
                            type='button'
                            disabled={locked || deletingId === member._id}
                            onClick={() => handleDelete(member)}
                            title={locked ? 'Root CEO cannot be deleted' : 'Delete'}
                            className='inline-flex items-center px-2.5 py-1.5 rounded-lg text-xs font-semibold border border-rose-200 text-rose-700 bg-rose-50 hover:bg-rose-100 disabled:opacity-40 disabled:cursor-not-allowed'
                          >
                            {deletingId === member._id ? 'Deleting…' : 'Delete'}
                          </button>
                        </div>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        ) : (
          <div className='p-10 text-center'>
            <p className='text-sm text-gray-500 mb-4'>No team members yet</p>
            <button
              type='button'
              onClick={() => navigate('/create-team')}
              className='px-4 py-2 rounded-xl bg-indigo-600 text-white text-sm font-semibold hover:bg-indigo-700'
            >
              Create first member
            </button>
          </div>
        )}
      </div>

      {editingMember ? (
        <div className='fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40'>
          <div className='w-full max-w-lg max-h-[90vh] overflow-y-auto bg-white rounded-2xl shadow-xl border border-gray-100'>
            <div className='px-5 py-4 border-b border-gray-100 flex items-center justify-between sticky top-0 bg-white'>
              <div>
                <h3 className='text-base font-semibold text-gray-900'>Update team member</h3>
                <p className='text-xs text-gray-500 mt-0.5'>{editingMember.email}</p>
              </div>
              <button
                type='button'
                onClick={closeEdit}
                className='text-gray-400 hover:text-gray-600 text-xl leading-none px-2'
                aria-label='Close'
              >
                ×
              </button>
            </div>

            <form onSubmit={handleUpdate} className='p-5 space-y-4'>
              <div>
                <label className='block text-sm font-semibold text-slate-800 mb-1.5'>Full name</label>
                <input
                  type='text'
                  value={editForm.name}
                  onChange={(e) => setField('name', e.target.value)}
                  required
                  className='w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500'
                />
              </div>

              <div>
                <label className='block text-sm font-semibold text-slate-800 mb-1.5'>Email</label>
                <input
                  type='email'
                  value={editForm.email}
                  onChange={(e) => setField('email', e.target.value)}
                  required
                  className='w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500'
                />
              </div>

              <div>
                <label className='block text-sm font-semibold text-slate-800 mb-1.5'>Phone</label>
                <input
                  type='tel'
                  value={editForm.phone}
                  onChange={(e) => setField('phone', e.target.value)}
                  className='w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500'
                />
              </div>

              <div>
                <label className='block text-sm font-semibold text-slate-800 mb-1.5'>Role</label>
                <select
                  value={editForm.role}
                  onChange={(e) => setField('role', e.target.value)}
                  className='w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white'
                >
                  {roles.map((role) => (
                    <option key={role} value={role}>{role}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className='block text-sm font-semibold text-slate-800 mb-1.5'>Status</label>
                <select
                  value={editForm.status}
                  onChange={(e) => setField('status', e.target.value)}
                  className='w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white'
                >
                  <option value='Active'>Active</option>
                  <option value='Inactive'>Inactive</option>
                </select>
              </div>

              <div>
                <label className='block text-sm font-semibold text-slate-800 mb-1.5'>New password (optional)</label>
                <div className='relative'>
                  <input
                    type={showPassword ? 'text' : 'password'}
                    value={editForm.password}
                    onChange={(e) => setField('password', e.target.value)}
                    autoComplete='new-password'
                    className='w-full border border-gray-200 rounded-xl px-3 py-2.5 pr-20 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500'
                    placeholder='Leave blank to keep current'
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
                <label className='block text-sm font-semibold text-slate-800 mb-1.5'>Confirm new password</label>
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={editForm.confirmPassword}
                  onChange={(e) => setField('confirmPassword', e.target.value)}
                  autoComplete='new-password'
                  className='w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500'
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
                        checked={editForm.tenants.includes(id)}
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

              {error ? (
                <p className='text-red-600 text-sm bg-red-50 border border-red-100 rounded-lg px-3 py-2'>{error}</p>
              ) : null}
              {success ? (
                <p className='text-emerald-700 text-sm bg-emerald-50 border border-emerald-100 rounded-lg px-3 py-2'>{success}</p>
              ) : null}

              <div className='flex gap-2 pt-1'>
                <button
                  type='button'
                  onClick={closeEdit}
                  className='flex-1 border border-gray-200 text-gray-700 py-2.5 rounded-xl text-sm font-semibold hover:bg-gray-50'
                >
                  Cancel
                </button>
                <button
                  type='submit'
                  disabled={saving}
                  className='flex-1 bg-indigo-600 hover:bg-indigo-700 text-white py-2.5 rounded-xl text-sm font-semibold disabled:opacity-50'
                >
                  {saving ? 'Saving…' : 'Save changes'}
                </button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </CentralAdminShell>
  )
}

export default TeamMembersPage
