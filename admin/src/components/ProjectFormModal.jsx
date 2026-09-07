import React, { useEffect, useState } from 'react'
import api from '../api/axios'

const emptyForm = {
  projectName: '',
  department: 'IT',
  client: '',
  status: 'Not Started',
  priority: 'Medium',
  startDate: '',
  deadline: '',
  budget: '',
  progress: '0',
  description: '',
}

const inputClass =
  'w-full rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'

const toDateInput = (value) => {
  if (!value) return ''
  const d = new Date(value)
  return Number.isNaN(d.getTime()) ? '' : d.toISOString().slice(0, 10)
}

const ProjectFormModal = ({ open, mode = 'create', tenantId, project, clients = [], onClose, onSaved }) => {
  const [form, setForm] = useState(emptyForm)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    if (!open) return
    setError('')
    if (mode === 'edit' && project) {
      setForm({
        projectName: project.projectName || '',
        department: project.department || 'IT',
        client: project.client?._id || project.client || '',
        status: project.status || 'Not Started',
        priority: project.priority || 'Medium',
        startDate: toDateInput(project.startDate),
        deadline: toDateInput(project.deadline || project.endDate),
        budget: project.budget ?? '',
        progress: String(project.progress ?? 0),
        description: project.description || '',
      })
    } else {
      setForm(emptyForm)
    }
  }, [open, mode, project])

  if (!open) return null

  const setField = (key, value) => setForm((prev) => ({ ...prev, [key]: value }))

  const handleSubmit = async (event) => {
    event.preventDefault()
    const payload = {
      ...form,
      budget: Number(form.budget) || 0,
      progress: Number(form.progress) || 0,
      client: form.client || null,
    }
    try {
      setSaving(true)
      setError('')
      const res =
        mode === 'edit' && project?._id
          ? await api.put(`/companies/${tenantId}/projects/${project._id}`, payload)
          : await api.post(`/companies/${tenantId}/projects`, payload)
      onSaved?.(res.data?.project)
      onClose?.()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to save project')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className='fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40'>
      <div className='w-full max-w-xl max-h-[90vh] overflow-y-auto rounded-2xl bg-white shadow-xl border border-gray-100'>
        <div className='sticky top-0 bg-white border-b border-gray-100 px-5 py-4 flex items-center justify-between'>
          <h2 className='text-lg font-bold text-gray-900'>{mode === 'edit' ? 'Edit project' : 'Add project'}</h2>
          <button type='button' onClick={onClose} className='text-sm text-gray-500 hover:text-gray-800'>Close</button>
        </div>
        <form onSubmit={handleSubmit} className='p-5 space-y-4'>
          {error && <div className='rounded-xl bg-red-50 border border-red-100 px-3 py-2 text-sm text-red-600'>{error}</div>}
          <div className='grid grid-cols-1 sm:grid-cols-2 gap-4'>
            <div className='sm:col-span-2'>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Project name *</label>
              <input value={form.projectName} onChange={(e) => setField('projectName', e.target.value)} className={inputClass} required />
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Department</label>
              <select value={form.department} onChange={(e) => setField('department', e.target.value)} className={inputClass}>
                <option value='IT'>IT</option>
                <option value='Marketing'>Marketing</option>
                <option value='Sales'>Sales</option>
                <option value='Operations'>Operations</option>
              </select>
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Client</label>
              <select value={form.client} onChange={(e) => setField('client', e.target.value)} className={inputClass}>
                <option value=''>None</option>
                {clients.map((c) => (
                  <option key={c._id} value={c._id}>{c.clientName || c.name}</option>
                ))}
              </select>
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Status</label>
              <select value={form.status} onChange={(e) => setField('status', e.target.value)} className={inputClass}>
                <option value='Not Started'>Not Started</option>
                <option value='In Progress'>In Progress</option>
                <option value='Completed'>Completed</option>
                <option value='On Hold'>On Hold</option>
              </select>
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Priority</label>
              <select value={form.priority} onChange={(e) => setField('priority', e.target.value)} className={inputClass}>
                <option value='Low'>Low</option>
                <option value='Medium'>Medium</option>
                <option value='High'>High</option>
              </select>
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Start date</label>
              <input type='date' value={form.startDate} onChange={(e) => setField('startDate', e.target.value)} className={inputClass} />
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Deadline</label>
              <input type='date' value={form.deadline} onChange={(e) => setField('deadline', e.target.value)} className={inputClass} />
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Budget (INR)</label>
              <input type='number' min='0' value={form.budget} onChange={(e) => setField('budget', e.target.value)} className={inputClass} />
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Progress %</label>
              <input type='number' min='0' max='100' value={form.progress} onChange={(e) => setField('progress', e.target.value)} className={inputClass} />
            </div>
            <div className='sm:col-span-2'>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Description</label>
              <textarea value={form.description} onChange={(e) => setField('description', e.target.value)} className={`${inputClass} min-h-[80px]`} />
            </div>
          </div>
          <div className='flex justify-end gap-2'>
            <button type='button' onClick={onClose} className='rounded-xl border border-gray-200 px-4 py-2 text-sm'>Cancel</button>
            <button type='submit' disabled={saving} className='rounded-xl bg-blue-600 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50'>
              {saving ? 'Saving…' : mode === 'edit' ? 'Update project' : 'Create project'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default ProjectFormModal
