import React, { useEffect, useState, useRef } from 'react'
import api from '../api/axios'
import { uploadFile } from '../utils/uploadFile'
import { useNavigate, useParams } from 'react-router-dom'

import InvoiceItems, { emptyItem } from '../components/InvoiceItems'

const MODES = ['Bank Transfer', 'UPI', 'Cheque', 'Cash', 'Other']

const AddBilling = ({ isOrder = false }) => {
  const resource = isOrder ? '/order' : '/billing'
  const listPath = isOrder ? '/orders' : '/billings'
  const documentLabel = isOrder ? 'Order' : 'Invoice'
  const { id } = useParams()
  const isEdit = Boolean(id)
  const [items, setItems] = useState(() => id ? [] : [emptyItem()])
  const [itemMode, setItemMode] = useState(!id)
  const [invoiceDate, setInvoiceDate] = useState(() => new Date().toLocaleDateString('en-CA'))
  const [placeOfSupply, setPlaceOfSupply] = useState('')
  const [billType, setBillType] = useState('Non-GST')
  const [companyLogo, setCompanyLogo] = useState('')
  const [signatureUploading, setSignatureUploading] = useState(false)
  const [signatureError, setSignatureError] = useState('')
  const [authorizedSignature, setAuthorizedSignature] = useState('')
  const [company, setCompany] = useState({ name: '', address: '', email: '', phone: '', pan: '', website: '' })
  const [termsAndConditions, setTermsAndConditions] = useState('')
  const [companyGst, setCompanyGst] = useState({ gstin: '', state: '', stateCode: '' })
  const [clientId, setClientId] = useState('')
  const [clientGst, setClientGst] = useState({ gstin: '', state: '', billingAddress: '' })
  const [projects, setProjects] = useState([])
  const [paymentDetails, setPaymentDetails] = useState({
    amount: '',
    paymentDate: '',
    receiverName: '',
    receiverBankAccount: '',
    receiverBankName: '',
    modeOfTransaction: '',
  })
  const [clients, setClients] = useState([])
  const [companies, setCompanies] = useState([])
  const [selectedCompanyId, setSelectedCompanyId] = useState('')
  const [companyPersonalAccounts, setCompanyPersonalAccounts] = useState([])
  const [selectedPersonalAccountIndex, setSelectedPersonalAccountIndex] = useState(0)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const fileInputRef = useRef(null)
  const signatureInputRef = useRef(null)
  const skipClientGstRef = useRef(false)

  const navigate = useNavigate()

  useEffect(() => {
    const fetchClients = async () => {
      try {
        const res = await api.get('/clients')
        const list = Array.isArray(res.data) ? res.data : res.data?.data || []
        setClients(list)
      } catch (err) {
        console.error('Failed to fetch clients:', err)
      }
    }
    fetchClients()
  }, [])

  useEffect(() => {
    let active = true
    const fetchCompanies = async () => {
      try {
        const [res, profile] = await Promise.all([
          api.get('/companies'),
          isEdit ? Promise.resolve(null) : api.get('/company-profile').catch(() => null),
        ])
        if (!active) return
        const list = Array.isArray(res.data) ? res.data : res.data?.data || []
        setCompanies(list)
        if (!isEdit) {
          // Use the same primary company as Company Profile settings.
          const defaultId = profile?.data?._id || (list.length === 1 ? list[0]._id : '')
          setSelectedCompanyId((current) => current || defaultId)
        }
      } catch (err) {
        console.error('Failed to fetch companies:', err)
      }
    }
    fetchCompanies()
    return () => { active = false }
  }, [isEdit])

  useEffect(() => {
    if (!selectedCompanyId) return
    const applyCompany = async () => {
      try {
        const res = await api.get(`/companies/${selectedCompanyId}`)
        const c = res.data
        setCompanyLogo(c.companyLogo || '')
        setCompany({
          name: c.companyName ?? '',
          address: c.address ?? '',
          email: c.email ?? '',
          phone: c.phone ?? '',
          pan: c.pan ?? '',
          website: c.website ?? '',
        })
        setCompanyGst({
          gstin: c.gstin ?? '',
          state: c.state ?? '',
          stateCode: c.gstCode ?? '',
        })
        const personalAccounts = Array.isArray(c.personalAccounts) ? c.personalAccounts : (c.personalReceiverName || c.personalBankName || c.personalBankAccountNumber ? [{ receiverName: c.personalReceiverName ?? '', bankName: c.personalBankName ?? '', bankAccountNumber: c.personalBankAccountNumber ?? '' }] : [])
        setCompanyPersonalAccounts(personalAccounts)
        if (billType === 'GST') {
          setPaymentDetails((prev) => ({
            ...prev,
            receiverName: c.companyName ?? '',
            receiverBankAccount: c.bankAccountNumber ?? '',
            receiverBankName: c.bankName ?? '',
          }))
        } else if (personalAccounts.length > 0) {
          setSelectedPersonalAccountIndex(0)
          const acc = personalAccounts[0]
          setPaymentDetails((prev) => ({
            ...prev,
            receiverName: acc.receiverName ?? '',
            receiverBankAccount: acc.bankAccountNumber ?? '',
            receiverBankName: acc.bankName ?? '',
          }))
        }
      } catch (err) {
        console.error('Failed to fetch company details:', err)
      }
    }
    applyCompany()
  }, [selectedCompanyId, billType])

  useEffect(() => {
    if (!clientId) return
    if (skipClientGstRef.current) {
      skipClientGstRef.current = false
      return
    }
    const fetchClientAndFillGst = async () => {
      try {
        const res = await api.get(`/clients/${clientId}`)
        const c = res.data
        setClientGst({
          gstin: c.gstin ?? '',
          state: c.gstCode ?? '',
          billingAddress: c.address ?? '',
        })
      } catch (err) {
        console.error('Failed to fetch client for GST:', err)
      }
    }
    fetchClientAndFillGst()
  }, [clientId])

  useEffect(() => {
    if (!id) return
    const fetchBilling = async () => {
      try {
        const res = await api.get(`${resource}/${id}`)
        const b = isOrder ? { ...res.data, invoiceDate: res.data.orderDate } : res.data
        setItems(b.items || [])
        setItemMode(Boolean(b.items?.length))
        setInvoiceDate((b.invoiceDate || b.createdAt || '').slice(0, 10))
        setPlaceOfSupply(b.placeOfSupply || '')
        setBillType(b.billType || 'Non-GST')
        setCompanyLogo(b.companyLogo || '')
        setAuthorizedSignature(b.authorizedSignature || '')
        setCompany({
          name: b.company?.name ?? '',
          address: b.company?.address ?? '',
          email: b.company?.email ?? '',
          phone: b.company?.phone ?? '',
          pan: b.company?.pan ?? '',
          website: b.company?.website ?? '',
        })
        setTermsAndConditions(b.termsAndConditions ?? '')
        setCompanyGst({
          gstin: b.companyGst?.gstin ?? '',
          state: b.companyGst?.state ?? '',
          stateCode: b.companyGst?.stateCode ?? '',
        })
        skipClientGstRef.current = true
        setClientId(b.client?._id ?? b.client ?? '')
        setClientGst({
          gstin: b.clientGst?.gstin ?? '',
          state: b.clientGst?.state ?? '',
          billingAddress: b.clientGst?.billingAddress ?? '',
        })
        if (Array.isArray(b.projects)) {
          setProjects(b.projects.map((p) => {
            const cost = Number(p.projectCost) || 0
            const rem = Number(p.remainingCost) || 0
            return {
              project: p.project?._id ?? p.project,
              projectCost: cost,
              amountPaid: Math.max(0, cost - rem),
            }
          }))
        }
        setPaymentDetails({
          amount: b.paymentDetails?.amount ?? '',
          paymentDate: b.paymentDetails?.paymentDate ? (typeof b.paymentDetails.paymentDate === 'string' ? b.paymentDetails.paymentDate.slice(0, 10) : new Date(b.paymentDetails.paymentDate).toISOString().slice(0, 10)) : '',
          receiverName: b.paymentDetails?.receiverName ?? '',
          receiverBankAccount: b.paymentDetails?.receiverBankAccount ?? '',
          receiverBankName: b.paymentDetails?.receiverBankName ?? '',
          modeOfTransaction: b.paymentDetails?.modeOfTransaction ?? '',
        })
      } catch (err) {
        setError(err.response?.data?.message || err.message || 'Error loading billing')
      }
    }
    fetchBilling()
  }, [id, resource, isOrder])

  const handleCompanyChange = (field, value) => {
    setCompany((c) => ({ ...c, [field]: value }))
  }

  const handleLogoFile = async (e) => {
    const file = e.target.files?.[0]
    if (!file) return
    try {
      setError(null)
      const uploaded = await uploadFile(file, { folder: 'logos' })
      setCompanyLogo(uploaded.url)
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to upload logo')
      e.target.value = ''
    }
  }

  const handleSignatureFile = async (e) => {
    const input = e.target
    const file = input.files?.[0]
    if (!file) return
    setSignatureError('')
    if (!['image/png', 'image/jpeg', 'image/webp'].includes(file.type)) {
      setSignatureError('Choose a PNG, JPEG, or WebP signature image.')
      input.value = ''
      return
    }
    setSignatureUploading(true)
    try {
      const uploaded = await uploadFile(file, { folder: 'signatures', proxyFallback: true })
      setAuthorizedSignature(uploaded.url)
    } catch (err) {
      setSignatureError(err.response?.data?.message || err.message || 'Failed to upload signature')
    } finally {
      setSignatureUploading(false)
      input.value = ''
    }
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (signatureUploading) return
    if (!clientId) {
      setError('Please select a client')
      return
    }
    if (itemMode && !items.length) { setError('Add at least one item'); return }
    setLoading(true)
    setError(null)
    try {
      const payload = {
        billType,
        [isOrder ? 'orderDate' : 'invoiceDate']: invoiceDate || null,
        placeOfSupply,
        items: itemMode ? items : [],
        companyLogo,
        authorizedSignature,
        company,
        termsAndConditions: termsAndConditions.trim() || undefined,
        client: clientId,
        projects: projects.filter((p) => p.project).map((p) => ({
          project: p.project,
          projectCost: Number(p.projectCost) || 0,
          remainingCost: Math.max(0, (Number(p.projectCost) || 0) - (Number(p.amountPaid) || 0)),
        })),
        paymentDetails: {
          amount: paymentDetails.amount ? Number(paymentDetails.amount) : null,
          paymentDate: paymentDetails.paymentDate ? new Date(paymentDetails.paymentDate).toISOString() : null,
          receiverName: paymentDetails.receiverName || '',
          receiverBankAccount: paymentDetails.receiverBankAccount || '',
          receiverBankName: paymentDetails.receiverBankName || '',
          modeOfTransaction: paymentDetails.modeOfTransaction || '',
        },
      }
      if (billType === 'GST') {
        payload.companyGst = companyGst
        payload.clientGst = clientGst
      }
      if (isEdit) {
        await api.put(`${resource}/${id}`, payload)
        navigate(listPath)
      } else {
        const res = await api.post(resource, payload)
        const createdId = (isOrder ? res.data?.order?._id : res.data?.billing?._id)
        if (createdId) {
          navigate(`${listPath}/${createdId}/${isOrder ? 'order' : 'invoice'}`)
        } else {
          navigate(listPath)
        }
      }
    } catch (err) {
      setError(err.response?.data?.message || err.message || (isEdit ? 'Error updating' : 'Error creating'))
    } finally {
      setLoading(false)
    }
  }

  const inputClass = 'mt-1 block w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'

  return (
    <div className='p-4 md:p-5 w-full w-full'>
      <h1 className='text-2xl font-bold text-gray-900 mb-4 md:mb-5 text-center w-full'>
        {isEdit ? `Edit ${documentLabel}` : `Create ${documentLabel}`}
      </h1>

      <form onSubmit={handleSubmit} className='w-full space-y-6'>
        <div className='bg-white rounded-xl shadow-lg border border-gray-200 p-4 md:p-5 space-y-4'>
          <h2 className='text-lg font-semibold text-gray-800 border-b pb-2'>Bill Type</h2>
          <div className='flex gap-4'>
            <label className='flex items-center gap-2 cursor-pointer'>
              <input
                type='radio'
                name='billType'
                checked={billType === 'GST'}
                onChange={() => setBillType('GST')}
                className='rounded-full border-gray-300'
              />
              <span>With GST</span>
            </label>
            <label className='flex items-center gap-2 cursor-pointer'>
              <input
                type='radio'
                name='billType'
                checked={billType === 'Non-GST'}
                onChange={() => setBillType('Non-GST')}
                className='rounded-full border-gray-300'
              />
              <span>Without GST (Non-GST)</span>
            </label>
          </div>
        </div>

        <div className='bg-white rounded-xl shadow-lg border border-gray-200 p-4 md:p-5 space-y-4'>
          <h2 className='text-lg font-semibold text-gray-800 border-b pb-2'>Company</h2>
          <div>
            <label className='block text-sm font-medium text-gray-700'>Select Company (auto-fill details)</label>
            <select
              value={selectedCompanyId || (isEdit ? companies.find((c) => c.companyName?.trim().toLowerCase() === company.name.trim().toLowerCase())?._id || '' : '')}
              onChange={(e) => setSelectedCompanyId(e.target.value)}
              className={inputClass}
            >
              <option value=''>— Select company —</option>
              {companies.map((c) => (
                <option key={c._id} value={c._id}>{c.companyName || 'Unnamed'}</option>
              ))}
            </select>
          </div>
          <div className='flex flex-col sm:flex-row gap-4'>
            <div>
              <label className='block text-sm font-medium text-gray-700'>Company Logo</label>
              <input type='file' ref={fileInputRef} accept='image/*' onChange={handleLogoFile} className='hidden' />
              <button type='button' onClick={() => fileInputRef.current?.click()} className='mt-1 border border-gray-300 rounded-lg px-3 py-2 text-sm hover:bg-gray-50'>
                Choose image
              </button>
              {companyLogo && <img src={companyLogo} alt='Logo' className='mt-2 h-16 w-16 object-contain border rounded' />}
            </div>
            <div className='flex-1 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4'>
              <div>
                <label className='block text-sm font-medium text-gray-700'>Company Name</label>
                <input value={company.name} onChange={(e) => handleCompanyChange('name', e.target.value)} className={inputClass} />
              </div>
              <div>
                <label className='block text-sm font-medium text-gray-700'>Email</label>
                <input type='email' value={company.email} onChange={(e) => handleCompanyChange('email', e.target.value)} className={inputClass} />
              </div>
              <div>
                <label className='block text-sm font-medium text-gray-700'>Phone</label>
                <input value={company.phone} onChange={(e) => handleCompanyChange('phone', e.target.value)} className={inputClass} />
              </div>
              <div>
                <label className='block text-sm font-medium text-gray-700'>PAN</label>
                <input value={company.pan || ''} onChange={(e) => handleCompanyChange('pan', e.target.value)} className={inputClass} placeholder='e.g. AABCT1234D' />
              </div>
              <div>
                <label className='block text-sm font-medium text-gray-700'>Website</label>
                <input type='url' value={company.website || ''} onChange={(e) => handleCompanyChange('website', e.target.value)} className={inputClass} placeholder='https://...' />
              </div>
              <div className='sm:col-span-2 lg:col-span-4'>
                <label className='block text-sm font-medium text-gray-700'>Address</label>
                <input value={company.address} onChange={(e) => handleCompanyChange('address', e.target.value)} className={inputClass} />
              </div>
            </div>
          </div>

          {billType === 'GST' && (
            <div className='mt-4 pt-4 border-t border-gray-200'>
              <h3 className='text-sm font-semibold text-gray-700 mb-3'>Company GST Details</h3>
              <div className='grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4'>
                <div>
                  <label className='block text-sm font-medium text-gray-700'>GSTIN</label>
                  <input value={companyGst.gstin} onChange={(e) => setCompanyGst((g) => ({ ...g, gstin: e.target.value }))} className={inputClass} placeholder='e.g. 27XXXXX1234X1ZX' />
                </div>
                <div>
                  <label className='block text-sm font-medium text-gray-700'>State</label>
                  <input value={companyGst.state} onChange={(e) => setCompanyGst((g) => ({ ...g, state: e.target.value }))} className={inputClass} />
                </div>
                <div>
                  <label className='block text-sm font-medium text-gray-700'>State Code</label>
                  <input value={companyGst.stateCode} onChange={(e) => setCompanyGst((g) => ({ ...g, stateCode: e.target.value }))} className={inputClass} placeholder='e.g. 27' />
                </div>
              </div>
            </div>
          )}
        </div>

        <div className='bg-white rounded-xl shadow-lg border border-gray-200 p-4 md:p-5 space-y-4'>
          <h2 className='text-lg font-semibold text-gray-800 border-b pb-2'>Client</h2>
          <div>
            <label className='block text-sm font-medium text-gray-700'>Select Client</label>
            <select value={clientId} onChange={(e) => { setProjects([]); setClientId(e.target.value) }} className={inputClass} required>
              <option value=''>— Select client —</option>
              {clients.map((c) => (
                <option key={c._id} value={c._id}>{c.clientName}</option>
              ))}
            </select>
          </div>

          {billType === 'GST' && (
            <div className='pt-4 border-t border-gray-200'>
              <h3 className='text-sm font-semibold text-gray-700 mb-3'>Client GST Details</h3>
              <div className='grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4'>
                <div>
                  <label className='block text-sm font-medium text-gray-700'>Client GSTIN</label>
                  <input value={clientGst.gstin} onChange={(e) => setClientGst((g) => ({ ...g, gstin: e.target.value }))} className={inputClass} />
                </div>
                <div>
                  <label className='block text-sm font-medium text-gray-700'>State</label>
                  <input value={clientGst.state} onChange={(e) => setClientGst((g) => ({ ...g, state: e.target.value }))} className={inputClass} />
                </div>
                <div className='sm:col-span-2 lg:col-span-2'>
                  <label className='block text-sm font-medium text-gray-700'>Billing Address</label>
                  <input value={clientGst.billingAddress} onChange={(e) => setClientGst((g) => ({ ...g, billingAddress: e.target.value }))} className={inputClass} />
                </div>
              </div>
            </div>
          )}
        </div>

        <div className='bg-white rounded-xl shadow-lg border border-gray-200 p-4 md:p-5 space-y-4'>
          <h2 className='text-lg font-semibold text-gray-800'>{documentLabel} details</h2>
          <div className='grid grid-cols-1 sm:grid-cols-2 gap-4'>
            <label>{documentLabel} date<input type='date' required value={invoiceDate} onChange={(e) => setInvoiceDate(e.target.value)} className={inputClass} /></label>
            <label>Place of supply<input value={placeOfSupply} onChange={(e) => setPlaceOfSupply(e.target.value)} placeholder='27-Maharashtra' className={inputClass} /></label>
          </div>
          <label className='flex items-center gap-2'><input type='checkbox' checked={itemMode} onChange={(e) => { setItemMode(e.target.checked); if (!items.length) setItems([emptyItem()]) }} />Use itemized {documentLabel.toLowerCase()}</label>
          {itemMode && <InvoiceItems items={items} isGst={billType === 'GST'} onChange={setItems} received={paymentDetails.amount} documentLabel={documentLabel} />}
        </div>

        <div className='bg-white rounded-xl shadow-lg border border-gray-200 p-4 md:p-5 space-y-4'>
          <h2 className='text-lg font-semibold text-gray-800 border-b pb-2'>
            Payment Details {billType === 'GST' ? '(GST)' : '(Non-GST)'}
          </h2>
          <p className='text-xs text-gray-500'>Enter the amount received for this {documentLabel.toLowerCase()}. The tax summary calculates the remaining balance automatically.</p>
          {billType === 'Non-GST' && companyPersonalAccounts.length > 1 && (
            <div>
              <label className='block text-sm font-medium text-gray-700'>Personal account</label>
              <select
                value={selectedPersonalAccountIndex}
                onChange={(e) => {
                  const idx = Number(e.target.value)
                  setSelectedPersonalAccountIndex(idx)
                  const acc = companyPersonalAccounts[idx]
                  if (acc) {
                    setPaymentDetails((prev) => ({
                      ...prev,
                      receiverName: acc.receiverName ?? '',
                      receiverBankAccount: acc.bankAccountNumber ?? '',
                      receiverBankName: acc.bankName ?? '',
                    }))
                  }
                }}
                className={inputClass}
              >
                {companyPersonalAccounts.map((acc, i) => (
                  <option key={i} value={i}>
                    {acc.receiverName || acc.bankName || 'Account ' + (i + 1)}
                  </option>
                ))}
              </select>
            </div>
          )}
          <div className='grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4'>
            <div>
              <label className='block text-sm font-medium text-gray-700'>Payment Date</label>
              <input type='date' value={paymentDetails.paymentDate} onChange={(e) => setPaymentDetails((p) => ({ ...p, paymentDate: e.target.value }))} className={inputClass} />
            </div>
            <div>
              <label className='block text-sm font-medium text-gray-700'>Amount</label>
              <input type='number' value={paymentDetails.amount} onChange={(e) => setPaymentDetails((p) => ({ ...p, amount: e.target.value }))} className={inputClass} />
            </div>
            <div>
              <label className='block text-sm font-medium text-gray-700'>Receiver Name</label>
              <input value={paymentDetails.receiverName} onChange={(e) => setPaymentDetails((p) => ({ ...p, receiverName: e.target.value }))} className={inputClass} />
            </div>
            <div>
              <label className='block text-sm font-medium text-gray-700'>Receiver Bank Account</label>
              <input value={paymentDetails.receiverBankAccount} onChange={(e) => setPaymentDetails((p) => ({ ...p, receiverBankAccount: e.target.value }))} className={inputClass} />
            </div>
            <div>
              <label className='block text-sm font-medium text-gray-700'>Receiver Bank Name</label>
              <input value={paymentDetails.receiverBankName} onChange={(e) => setPaymentDetails((p) => ({ ...p, receiverBankName: e.target.value }))} className={inputClass} />
            </div>
            <div>
              <label className='block text-sm font-medium text-gray-700'>Mode of Transaction</label>
              <select value={paymentDetails.modeOfTransaction} onChange={(e) => setPaymentDetails((p) => ({ ...p, modeOfTransaction: e.target.value }))} className={inputClass}>
                <option value=''>— Select —</option>
                {MODES.map((m) => (
                  <option key={m} value={m}>{m}</option>
                ))}
              </select>
            </div>
          </div>

        </div>

        <div className='bg-white rounded-xl shadow-lg border border-gray-200 p-4 md:p-5 space-y-4'>
          <h2 className='text-lg font-semibold text-gray-800 border-b pb-2'>Authorized Signature (optional)</h2>
          <div>
            <label className='block text-sm font-medium text-gray-700'>Upload signature image</label>
            <input type='file' ref={signatureInputRef} disabled={signatureUploading} accept='image/png,image/jpeg,image/webp' onChange={handleSignatureFile} className='hidden' />
            <button type='button' disabled={signatureUploading} onClick={() => signatureInputRef.current?.click()} className='mt-1 border border-gray-300 rounded-lg px-3 py-2 text-sm hover:bg-gray-50'>
              {signatureUploading ? 'Uploading signature...' : 'Choose signature image'}
            </button>
            <p role='status' className='mt-2 text-sm text-gray-600'>{signatureUploading ? 'Uploading signature. Please wait before saving.' : ''}</p>
            {signatureError && <p role='alert' className='mt-2 text-sm text-red-600'>{signatureError}</p>}
            {authorizedSignature && (
              <div className='mt-2 flex items-center gap-3'>
                <img src={authorizedSignature} alt='Signature' className='h-14 max-w-[200px] object-contain border rounded' />
                <button type='button' disabled={signatureUploading} onClick={() => setAuthorizedSignature('')} className='text-sm text-red-600 hover:underline'>Remove</button>
              </div>
            )}
          </div>
        </div>

        <div className='bg-white rounded-xl shadow-lg border border-gray-200 p-4 md:p-5 space-y-4'>
          <h2 className='text-lg font-semibold text-gray-800 border-b pb-2'>Terms & Conditions (optional)</h2>
          <textarea
            value={termsAndConditions}
            onChange={(e) => setTermsAndConditions(e.target.value)}
            className={inputClass}
            rows={4}
            placeholder='Payment terms, due date, bank details note, etc.'
          />
        </div>

        {error && <p className='text-red-600 text-sm'>{error}</p>}

        <div className='flex gap-3'>
          <button type='submit' disabled={loading || signatureUploading} className='bg-blue-600 text-white px-5 py-2.5 rounded-lg text-sm font-medium hover:bg-blue-700 disabled:opacity-50'>
            {loading ? 'Saving...' : isEdit ? `Update ${documentLabel}` : `Save ${documentLabel}`}
          </button>
          <button type='button' onClick={() => navigate(listPath)} className='px-5 py-2.5 rounded-lg border border-gray-300 text-sm font-medium hover:bg-gray-50'>
            Cancel
          </button>
        </div>
      </form>
    </div>
  )
}

export default AddBilling
