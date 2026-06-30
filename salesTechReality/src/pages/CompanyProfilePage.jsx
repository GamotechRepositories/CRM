import React, { useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../api/axios'
import { useAuth } from '../context/AuthContext'

const EMPTY_FORM = {
  companyLogo: '',
  companyName: '',
  address: '',
  website: '',
  pan: '',
  phone: '',
  gstin: '',
  gstCode: '',
  state: '',
  email: '',
  bankName: '',
  bankAccountNumber: '',
  personalAccounts: [{ receiverName: '', bankName: '', bankAccountNumber: '' }],
}

const CompanyProfilePage = () => {
  const navigate = useNavigate()
  const { getDashboardPath } = useAuth()
  const [form, setForm] = useState(EMPTY_FORM)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState(null)
  const [success, setSuccess] = useState(null)
  const fileInputRef = useRef(null)

  useEffect(() => {
    const fetchProfile = async () => {
      try {
        setLoading(true)
        const res = await api.get('/company-profile')
        const c = res.data || {}
        setForm({
          companyLogo: c.companyLogo ?? '',
          companyName: c.companyName ?? '',
          address: c.address ?? '',
          website: c.website ?? '',
          pan: c.pan ?? '',
          phone: c.phone ?? '',
          gstin: c.gstin ?? '',
          gstCode: c.gstCode ?? '',
          state: c.state ?? '',
          email: c.email ?? '',
          bankName: c.bankName ?? '',
          bankAccountNumber: c.bankAccountNumber ?? '',
          personalAccounts: Array.isArray(c.personalAccounts) && c.personalAccounts.length > 0
            ? c.personalAccounts.map((a) => ({
                receiverName: a.receiverName ?? '',
                bankName: a.bankName ?? '',
                bankAccountNumber: a.bankAccountNumber ?? '',
              }))
            : [{ receiverName: '', bankName: '', bankAccountNumber: '' }],
        })
      } catch (err) {
        setError(err.response?.data?.message || err.message || 'Error loading company profile')
      } finally {
        setLoading(false)
      }
    }
    fetchProfile()
  }, [])

  const handleChange = (e) => {
    const { name, value } = e.target
    setForm((f) => ({ ...f, [name]: value }))
    setSuccess(null)
  }

  const addPersonalAccount = () => {
    setForm((f) => ({
      ...f,
      personalAccounts: [...f.personalAccounts, { receiverName: '', bankName: '', bankAccountNumber: '' }],
    }))
  }

  const removePersonalAccount = (index) => {
    setForm((f) => ({
      ...f,
      personalAccounts: f.personalAccounts.filter((_, i) => i !== index),
    }))
  }

  const handlePersonalAccountChange = (index, field, value) => {
    setForm((f) => ({
      ...f,
      personalAccounts: f.personalAccounts.map((acc, i) =>
        i === index ? { ...acc, [field]: value } : acc
      ),
    }))
    setSuccess(null)
  }

  const handleLogoFile = (e) => {
    const file = e.target.files?.[0]
    if (!file) return
    const reader = new FileReader()
    reader.onload = () => {
      setForm((f) => ({ ...f, companyLogo: reader.result }))
      setSuccess(null)
    }
    reader.readAsDataURL(file)
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setSaving(true)
    setError(null)
    setSuccess(null)
    try {
      const payload = {
        ...form,
        personalAccounts: form.personalAccounts.filter((a) => a.receiverName || a.bankName || a.bankAccountNumber),
      }
      if (payload.personalAccounts.length === 0) payload.personalAccounts = []
      const res = await api.put('/company-profile', payload)
      const saved = res.data?.company || res.data
      if (saved?.companyName) {
        setForm((f) => ({ ...f, ...saved }))
      }
      setSuccess('Company profile saved successfully.')
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Error saving company profile')
    } finally {
      setSaving(false)
    }
  }

  const inputClass = 'mt-1 block w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white'

  if (loading) {
    return <div className='p-8 text-sm text-gray-600'>Loading company profile...</div>
  }

  return (
    <div className='p-4 md:p-8 bg-gray-50 min-h-full'>
      <div className='max-w-5xl mx-auto'>
        <div className='mb-6'>
          <nav className='text-sm text-gray-500 mb-2'>
            <span className='text-gray-900 font-medium'>Company</span>
            <span className='mx-2 text-gray-300'>›</span>
            <span className='text-gray-900 font-medium'>Company Profile</span>
          </nav>
          <h1 className='text-2xl font-bold text-gray-900'>Company Profile</h1>
          <p className='text-sm text-gray-500 mt-1'>
            Manage your organization details — logo, contact, GST, and bank information used across billing and documents.
          </p>
        </div>

        <form onSubmit={handleSubmit}>
          <div className='bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden'>
            <div className='px-5 py-4 border-b border-gray-100 bg-gray-50/80'>
              <h2 className='text-lg font-semibold text-gray-800'>Basic Information</h2>
              <p className='text-sm text-gray-500 mt-0.5'>Logo, name, address, and contact details</p>
            </div>

            <div className='p-5 space-y-5'>
              <div>
                <label className='block text-sm font-medium text-gray-700'>Company Logo</label>
                <input type='file' ref={fileInputRef} accept='image/*' onChange={handleLogoFile} className='hidden' />
                <div className='mt-2 flex items-center gap-4'>
                  <button
                    type='button'
                    onClick={() => fileInputRef.current?.click()}
                    className='border border-gray-300 rounded-lg px-3 py-2 text-sm hover:bg-gray-50'
                  >
                    Upload logo
                  </button>
                  {form.companyLogo && (
                    <img src={form.companyLogo} alt='Company logo' className='h-16 w-16 object-contain border rounded-lg bg-white p-1' />
                  )}
                </div>
              </div>

              <div className='grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4'>
                <div>
                  <label className='block text-sm font-medium text-gray-700'>Company Name *</label>
                  <input name='companyName' value={form.companyName} onChange={handleChange} required className={inputClass} />
                </div>
                <div>
                  <label className='block text-sm font-medium text-gray-700'>Email</label>
                  <input name='email' type='email' value={form.email} onChange={handleChange} className={inputClass} />
                </div>
                <div>
                  <label className='block text-sm font-medium text-gray-700'>Phone</label>
                  <input name='phone' value={form.phone} onChange={handleChange} className={inputClass} />
                </div>
                <div>
                  <label className='block text-sm font-medium text-gray-700'>Website</label>
                  <input name='website' type='url' value={form.website} onChange={handleChange} className={inputClass} placeholder='https://...' />
                </div>
                <div className='sm:col-span-2'>
                  <label className='block text-sm font-medium text-gray-700'>Address</label>
                  <input name='address' value={form.address} onChange={handleChange} className={inputClass} />
                </div>
              </div>
            </div>

            <div className='px-5 py-4 border-t border-gray-100 bg-gray-50/80'>
              <h2 className='text-lg font-semibold text-gray-800'>Tax & Registration</h2>
              <p className='text-sm text-gray-500 mt-0.5'>PAN, GSTIN, and state details for invoices</p>
            </div>

            <div className='p-5'>
              <div className='grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4'>
                <div>
                  <label className='block text-sm font-medium text-gray-700'>PAN</label>
                  <input name='pan' value={form.pan} onChange={handleChange} className={inputClass} placeholder='e.g. AABCT1234D' />
                </div>
                <div>
                  <label className='block text-sm font-medium text-gray-700'>State</label>
                  <input name='state' value={form.state} onChange={handleChange} className={inputClass} />
                </div>
                <div>
                  <label className='block text-sm font-medium text-gray-700'>GSTIN</label>
                  <input name='gstin' value={form.gstin} onChange={handleChange} className={inputClass} placeholder='e.g. 27XXXXX1234X1ZX' />
                </div>
                <div>
                  <label className='block text-sm font-medium text-gray-700'>GST Code</label>
                  <input name='gstCode' value={form.gstCode} onChange={handleChange} className={inputClass} placeholder='e.g. 27' />
                </div>
              </div>
            </div>

            <div className='px-5 py-4 border-t border-gray-100 bg-gray-50/80'>
              <h2 className='text-lg font-semibold text-gray-800'>Bank Accounts</h2>
              <p className='text-sm text-gray-500 mt-0.5'>Company and personal accounts used on bills</p>
            </div>

            <div className='p-5 space-y-5'>
              <div>
                <h3 className='text-sm font-semibold text-gray-800 mb-3'>Company account (GST bills)</h3>
                <div className='grid grid-cols-1 sm:grid-cols-2 gap-4'>
                  <div>
                    <label className='block text-sm font-medium text-gray-700'>Bank Name</label>
                    <input name='bankName' value={form.bankName} onChange={handleChange} className={inputClass} />
                  </div>
                  <div>
                    <label className='block text-sm font-medium text-gray-700'>Bank Account Number</label>
                    <input name='bankAccountNumber' value={form.bankAccountNumber} onChange={handleChange} className={inputClass} />
                  </div>
                </div>
              </div>

              <div className='border-t border-gray-100 pt-5'>
                <div className='flex items-center justify-between mb-3'>
                  <h3 className='text-sm font-semibold text-gray-800'>Personal accounts (Non-GST bills)</h3>
                  <button type='button' onClick={addPersonalAccount} className='text-sm text-blue-600 hover:text-blue-700 font-medium'>
                    + Add account
                  </button>
                </div>
                <div className='space-y-4'>
                  {form.personalAccounts.map((acc, index) => (
                    <div key={index} className='p-4 bg-gray-50 rounded-lg border border-gray-200'>
                      <div className='flex items-center justify-between mb-3'>
                        <span className='text-xs font-medium text-gray-500 uppercase tracking-wide'>Account {index + 1}</span>
                        {form.personalAccounts.length > 1 && (
                          <button type='button' onClick={() => removePersonalAccount(index)} className='text-xs text-red-600 hover:underline'>
                            Remove
                          </button>
                        )}
                      </div>
                      <div className='grid grid-cols-1 sm:grid-cols-3 gap-3'>
                        <div>
                          <label className='block text-xs font-medium text-gray-600'>Receiver / Account holder</label>
                          <input value={acc.receiverName} onChange={(e) => handlePersonalAccountChange(index, 'receiverName', e.target.value)} className={inputClass} />
                        </div>
                        <div>
                          <label className='block text-xs font-medium text-gray-600'>Bank Name</label>
                          <input value={acc.bankName} onChange={(e) => handlePersonalAccountChange(index, 'bankName', e.target.value)} className={inputClass} />
                        </div>
                        <div>
                          <label className='block text-xs font-medium text-gray-600'>Account Number</label>
                          <input value={acc.bankAccountNumber} onChange={(e) => handlePersonalAccountChange(index, 'bankAccountNumber', e.target.value)} className={inputClass} />
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            <div className='px-5 py-4 border-t border-gray-100 flex flex-wrap items-center gap-3 bg-white'>
              {error && <p className='text-red-600 text-sm flex-1'>{error}</p>}
              {success && <p className='text-green-600 text-sm flex-1'>{success}</p>}
              <button
                type='submit'
                disabled={saving}
                className='bg-blue-600 text-white px-5 py-2 rounded-lg text-sm font-medium hover:bg-blue-700 disabled:opacity-50'
              >
                {saving ? 'Saving...' : 'Save Profile'}
              </button>
              <button
                type='button'
                onClick={() => navigate(getDashboardPath())}
                className='px-5 py-2 rounded-lg border border-gray-300 text-sm font-medium hover:bg-gray-50 text-gray-700'
              >
                Back to Dashboard
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>
  )
}

export default CompanyProfilePage
