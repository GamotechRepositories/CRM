import React, { useEffect, useState } from 'react'
import { useNavigate, useParams, useSearchParams } from 'react-router-dom'
import api from '../api/axios'
import { useAuth } from '../context/AuthContext'
import {
  emptySiteVisitForm,
  formToSiteVisitPayload,
  SITE_VISIT_STATUSES,
  SITE_VISIT_TYPES,
  siteVisitToForm,
} from '../config/siteVisit'

const Section = ({ title, children }) => (
  <div className='bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden'>
    <div className='px-5 py-3 border-b border-gray-100 bg-gray-50'>
      <h2 className='text-sm font-semibold text-gray-900'>{title}</h2>
    </div>
    <div className='p-5 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4'>{children}</div>
  </div>
)

const Field = ({ label, children, className = '' }) => (
  <div className={className}>
    <label className='block text-sm font-medium text-gray-700 mb-1'>{label}</label>
    {children}
  </div>
)

const ScheduleSiteVisit = () => {
  const { id } = useParams()
  const isEdit = Boolean(id)
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const { user } = useAuth()
  const [form, setForm] = useState(emptySiteVisitForm())
  const [properties, setProperties] = useState([])
  const [employees, setEmployees] = useState([])
  const [leads, setLeads] = useState([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  useEffect(() => {
    Promise.all([
      api.get('/properties').catch(() => ({ data: [] })),
      api.get('/employees').catch(() => ({ data: [] })),
      api.get('/leads', { params: { viewerId: user?._id } }).catch(() => ({ data: [] })),
    ]).then(([propRes, empRes, leadRes]) => {
      const propList = Array.isArray(propRes.data) ? propRes.data : []
      const empList = Array.isArray(empRes.data) ? empRes.data : []
      const leadList = Array.isArray(leadRes.data) ? leadRes.data : []
      setProperties(propList)
      setEmployees(empList.filter((e) => e.status !== 'Inactive'))
      setLeads(leadList)
    })
  }, [])

  useEffect(() => {
    if (!isEdit || !id) {
      const propertyId = searchParams.get('propertyId')
      if (propertyId) {
        setForm((f) => ({ ...f, property: propertyId }))
      }
      return
    }
    api
      .get(`/site-visits/${id}`)
      .then((res) => setForm(siteVisitToForm(res.data)))
      .catch((err) => setError(err.response?.data?.message || 'Failed to load site visit'))
  }, [id, isEdit, searchParams])

  useEffect(() => {
    if (!form.property || isEdit) return
    const selected = properties.find((p) => String(p._id) === String(form.property))
    if (!selected) return
    setForm((f) => ({
      ...f,
      address: f.address || selected.address || '',
      city: f.city || selected.city || '',
      meetingPoint: f.meetingPoint || selected.locality || selected.title || '',
    }))
  }, [form.property, properties, isEdit])

  const handleChange = (e) => {
    const { name, value } = e.target
    setForm((f) => ({ ...f, [name]: value }))
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!form.visitorName?.trim()) {
      setError('Visitor name is required')
      return
    }
    if (!form.scheduledDate || !form.scheduledTime) {
      setError('Schedule date and time are required')
      return
    }
    setLoading(true)
    setError(null)
    try {
      const payload = formToSiteVisitPayload(form, user?._id)
      if (isEdit) {
        await api.put(`/site-visits/${id}`, payload)
      } else {
        await api.post('/site-visits', payload)
      }
      navigate('/site-visits')
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Error saving site visit')
    } finally {
      setLoading(false)
    }
  }

  const inputClass =
    'w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'

  return (
    <div className='p-6 md:p-8 w-full bg-[#f4f6f9] min-h-full'>
      <div className='flex items-center justify-between mb-6'>
        <div>
          <h1 className='text-2xl font-bold text-gray-900'>{isEdit ? 'Edit Site Visit' : 'Schedule Site Visit'}</h1>
          <p className='text-sm text-gray-500 mt-1'>Plan a property visit with visitor and agent details</p>
        </div>
        <button
          type='button'
          onClick={() => navigate('/site-visits')}
          className='rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-white'
        >
          Back to Visits
        </button>
      </div>

      {error && (
        <div className='mb-4 rounded-lg bg-red-50 border border-red-100 px-3 py-2'>
          <p className='text-red-600 text-sm'>{error}</p>
        </div>
      )}

      <form onSubmit={handleSubmit} className='space-y-5'>
        <Section title='Visit Schedule'>
          <Field label='Date *'>
            <input name='scheduledDate' type='date' value={form.scheduledDate} onChange={handleChange} required className={inputClass} />
          </Field>
          <Field label='Time *'>
            <input name='scheduledTime' type='time' value={form.scheduledTime} onChange={handleChange} required className={inputClass} />
          </Field>
          <Field label='Duration (minutes)'>
            <select name='durationMinutes' value={form.durationMinutes} onChange={handleChange} className={inputClass}>
              {[30, 45, 60, 90, 120].map((m) => (
                <option key={m} value={String(m)}>{m} mins</option>
              ))}
            </select>
          </Field>
          <Field label='Visit Type'>
            <select name='visitType' value={form.visitType} onChange={handleChange} className={inputClass}>
              {SITE_VISIT_TYPES.map((t) => <option key={t} value={t}>{t}</option>)}
            </select>
          </Field>
          <Field label='Status'>
            <select name='status' value={form.status} onChange={handleChange} className={inputClass}>
              {SITE_VISIT_STATUSES.map((t) => <option key={t} value={t}>{t}</option>)}
            </select>
          </Field>
          <Field label='Assigned Agent'>
            <select name='assignedTo' value={form.assignedTo} onChange={handleChange} className={inputClass}>
              <option value=''>Select employee</option>
              {employees.map((emp) => (
                <option key={emp._id} value={emp._id}>{emp.name}</option>
              ))}
            </select>
          </Field>
        </Section>

        <Section title='Visitor Details'>
          <Field label='Visitor Name *'>
            <input name='visitorName' value={form.visitorName} onChange={handleChange} required className={inputClass} />
          </Field>
          <Field label='Phone'>
            <input name='visitorPhone' value={form.visitorPhone} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Email'>
            <input name='visitorEmail' type='email' value={form.visitorEmail} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Linked Lead' className='sm:col-span-2 lg:col-span-3'>
            <select name='lead' value={form.lead} onChange={handleChange} className={inputClass}>
              <option value=''>No linked lead</option>
              {leads.map((lead) => (
                <option key={lead._id} value={lead._id}>
                  {lead.businessName || lead.name || 'Lead'}{lead.contactNumber ? ` · ${lead.contactNumber}` : ''}
                </option>
              ))}
            </select>
          </Field>
        </Section>

        <Section title='Property & Location'>
          <Field label='Property' className='sm:col-span-2 lg:col-span-3'>
            <select name='property' value={form.property} onChange={handleChange} className={inputClass}>
              <option value=''>Select property</option>
              {properties.map((p) => (
                <option key={p._id} value={p._id}>
                  {p.title}{p.propertyCode ? ` (${p.propertyCode})` : ''}{p.city ? ` · ${p.city}` : ''}
                </option>
              ))}
            </select>
          </Field>
          <Field label='Meeting Point'>
            <input name='meetingPoint' value={form.meetingPoint} onChange={handleChange} className={inputClass} placeholder='Gate / Society entrance' />
          </Field>
          <Field label='City'>
            <input name='city' value={form.city} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Address' className='sm:col-span-2 lg:col-span-3'>
            <input name='address' value={form.address} onChange={handleChange} className={inputClass} />
          </Field>
        </Section>

        <Section title='Notes & Outcome'>
          <Field label='Notes' className='sm:col-span-2 lg:col-span-3'>
            <textarea name='notes' value={form.notes} onChange={handleChange} rows={3} className={inputClass} placeholder='Instructions for the agent or visitor' />
          </Field>
          <Field label='Outcome'>
            <input name='outcome' value={form.outcome} onChange={handleChange} className={inputClass} placeholder='After visit summary' />
          </Field>
          <Field label='Interested'>
            <select name='interested' value={form.interested} onChange={handleChange} className={inputClass}>
              <option value=''>Not marked</option>
              <option value='yes'>Yes</option>
              <option value='no'>No</option>
            </select>
          </Field>
          <Field label='Feedback' className='sm:col-span-2 lg:col-span-3'>
            <textarea name='feedback' value={form.feedback} onChange={handleChange} rows={2} className={inputClass} />
          </Field>
        </Section>

        <div className='flex gap-3'>
          <button
            type='submit'
            disabled={loading}
            className='bg-blue-600 text-white px-6 py-2.5 rounded-lg text-sm font-medium hover:bg-blue-700 disabled:opacity-50'
          >
            {loading ? 'Saving…' : isEdit ? 'Update Visit' : 'Schedule Visit'}
          </button>
          <button
            type='button'
            onClick={() => navigate('/site-visits')}
            className='border border-gray-300 px-6 py-2.5 rounded-lg text-sm font-medium hover:bg-white'
          >
            Cancel
          </button>
        </div>
      </form>
    </div>
  )
}

export default ScheduleSiteVisit
