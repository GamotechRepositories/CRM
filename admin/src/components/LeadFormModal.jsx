import React, { useEffect, useState } from 'react'
import api from '../api/axios'
import { leadStatusesForTenant } from '../pages/ModulePage.shared'

const emptyForm = {
  businessName: '',
  name: '',
  contactNumber: '',
  status: 'Pending',
  leadSource: '',
  city: '',
  description: '',
}

const inputClass =
  'w-full rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'

const LeadFormModal = ({ open, mode = 'create', tenantId, lead, onClose, onSaved }) => {
  const [form, setForm] = useState(emptyForm)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const statusOptions = leadStatusesForTenant(tenantId)

  useEffect(() => {
    if (!open) return
    setError('')
    if (mode === 'edit' && lead) {
      setForm({
        businessName: lead.businessName || '',
        name: lead.name || '',
        contactNumber: lead.contactNumber || '',
        status: lead.status || 'Pending',
        leadSource: lead.leadSource || '',
        city: lead.city || '',
        description: lead.description || '',
      })
    } else {
      setForm(emptyForm)
    }
  }, [open, mode, lead])

  if (!open) return null

  const setField = (key, value) => setForm((prev) => ({ ...prev, [key]: value }))

  const handleSubmit = async (event) => {
    event.preventDefault()
    try {
      setSaving(true)
      setError('')
      const res =
        mode === 'edit' && lead?._id
          ? await api.put(`/companies/${tenantId}/leads/${lead._id}`, form)
          : await api.post(`/companies/${tenantId}/leads`, form)
      onSaved?.(res.data?.lead)
      onClose?.()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to save lead')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className='fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40'>
      <div className='w-full max-w-xl max-h-[90vh] overflow-y-auto rounded-2xl bg-white shadow-xl border border-gray-100'>
        <div className='sticky top-0 bg-white border-b border-gray-100 px-5 py-4 flex items-center justify-between'>
          <h2 className='text-lg font-bold text-gray-900'>{mode === 'edit' ? 'Edit lead' : 'Add lead'}</h2>
          <button type='button' onClick={onClose} className='text-sm text-gray-500 hover:text-gray-800'>Close</button>
        </div>
        <form onSubmit={handleSubmit} className='p-5 space-y-4'>
          {error && <div className='rounded-xl bg-red-50 border border-red-100 px-3 py-2 text-sm text-red-600'>{error}</div>}
          <div className='grid grid-cols-1 sm:grid-cols-2 gap-4'>
            <div className='sm:col-span-2'>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Business name *</label>
              <input value={form.businessName} onChange={(e) => setField('businessName', e.target.value)} className={inputClass} required />
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Contact name</label>
              <input value={form.name} onChange={(e) => setField('name', e.target.value)} className={inputClass} />
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Phone</label>
              <input value={form.contactNumber} onChange={(e) => setField('contactNumber', e.target.value)} className={inputClass} />
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Status</label>
              <select value={form.status} onChange={(e) => setField('status', e.target.value)} className={inputClass}>
                {statusOptions.map((s) => <option key={s} value={s}>{s}</option>)}
              </select>
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Lead source</label>
              <input value={form.leadSource} onChange={(e) => setField('leadSource', e.target.value)} className={inputClass} />
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>City</label>
              <input value={form.city} onChange={(e) => setField('city', e.target.value)} className={inputClass} />
            </div>
            <div className='sm:col-span-2'>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Description</label>
              <textarea value={form.description} onChange={(e) => setField('description', e.target.value)} className={`${inputClass} min-h-[80px]`} />
            </div>
          </div>
          <div className='flex justify-end gap-2'>
            <button type='button' onClick={onClose} className='rounded-xl border border-gray-200 px-4 py-2 text-sm'>Cancel</button>
            <button type='submit' disabled={saving} className='rounded-xl bg-blue-600 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50'>
              {saving ? 'Saving…' : mode === 'edit' ? 'Update lead' : 'Create lead'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default LeadFormModal
