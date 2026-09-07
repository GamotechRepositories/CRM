import React, { useEffect, useState } from 'react'
import api from '../api/axios'

const emptyForm = {
  clientName: '',
  clientNumber: '',
  mailId: '',
  businessType: '',
  clientType: 'Recurring',
  clientCategory: 'Marketing',
  city: '',
  status: 'Active',
}

const inputClass =
  'w-full rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'

const ClientFormModal = ({ open, mode = 'create', tenantId, client, onClose, onSaved }) => {
  const [form, setForm] = useState(emptyForm)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    if (!open) return
    setError('')
    if (mode === 'edit' && client) {
      setForm({
        clientName: client.clientName || '',
        clientNumber: client.clientNumber || '',
        mailId: client.mailId || '',
        businessType: client.businessType || '',
        clientType: client.clientType || 'Recurring',
        clientCategory: client.clientCategory || 'Marketing',
        city: client.city || '',
        status: client.status || 'Active',
      })
    } else {
      setForm(emptyForm)
    }
  }, [open, mode, client])

  if (!open) return null

  const setField = (key, value) => setForm((prev) => ({ ...prev, [key]: value }))

  const handleSubmit = async (event) => {
    event.preventDefault()
    try {
      setSaving(true)
      setError('')
      const res =
        mode === 'edit' && client?._id
          ? await api.put(`/companies/${tenantId}/clients/${client._id}`, form)
          : await api.post(`/companies/${tenantId}/clients`, form)
      onSaved?.(res.data?.client)
      onClose?.()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to save client')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className='fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40'>
      <div className='w-full max-w-xl max-h-[90vh] overflow-y-auto rounded-2xl bg-white shadow-xl border border-gray-100'>
        <div className='sticky top-0 bg-white border-b border-gray-100 px-5 py-4 flex items-center justify-between'>
          <h2 className='text-lg font-bold text-gray-900'>{mode === 'edit' ? 'Edit client' : 'Add client'}</h2>
          <button type='button' onClick={onClose} className='text-sm text-gray-500 hover:text-gray-800'>Close</button>
        </div>
        <form onSubmit={handleSubmit} className='p-5 space-y-4'>
          {error && <div className='rounded-xl bg-red-50 border border-red-100 px-3 py-2 text-sm text-red-600'>{error}</div>}
          <div className='grid grid-cols-1 sm:grid-cols-2 gap-4'>
            <div className='sm:col-span-2'>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Client name *</label>
              <input value={form.clientName} onChange={(e) => setField('clientName', e.target.value)} className={inputClass} required />
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Phone</label>
              <input value={form.clientNumber} onChange={(e) => setField('clientNumber', e.target.value)} className={inputClass} />
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Email</label>
              <input type='email' value={form.mailId} onChange={(e) => setField('mailId', e.target.value)} className={inputClass} />
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Business type</label>
              <input value={form.businessType} onChange={(e) => setField('businessType', e.target.value)} className={inputClass} />
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>City</label>
              <input value={form.city} onChange={(e) => setField('city', e.target.value)} className={inputClass} />
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Client type</label>
              <select value={form.clientType} onChange={(e) => setField('clientType', e.target.value)} className={inputClass}>
                <option value='Recurring'>Recurring</option>
                <option value='Non Recurring'>Non Recurring</option>
              </select>
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Status</label>
              <select value={form.status} onChange={(e) => setField('status', e.target.value)} className={inputClass}>
                <option value='Active'>Active</option>
                <option value='Inactive'>Inactive</option>
              </select>
            </div>
          </div>
          <div className='flex justify-end gap-2'>
            <button type='button' onClick={onClose} className='rounded-xl border border-gray-200 px-4 py-2 text-sm'>Cancel</button>
            <button type='submit' disabled={saving} className='rounded-xl bg-blue-600 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50'>
              {saving ? 'Saving…' : mode === 'edit' ? 'Update client' : 'Create client'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default ClientFormModal
