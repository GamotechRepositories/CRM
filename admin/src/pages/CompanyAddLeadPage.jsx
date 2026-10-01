import React, { useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import api from '../api/axios'
import AdminCompanyShell from '../components/AdminCompanyShell'
import SearchableSelect from '../components/SearchableSelect'
import { uploadFile } from '../utils/uploadFile'
import { TENANT_NAMES } from '../config/tenants'
import { leadStatusesForTenant } from './ModulePage.shared'

const normalizeFollowUps = (arr) =>
  (Array.isArray(arr) ? arr : []).map((fu) => ({
    _id: fu._id,
    date: fu.date
      ? new Date(fu.date).toISOString().slice(0, 10)
      : new Date().toISOString().slice(0, 10),
    comments: fu.comments ?? fu.text ?? '',
  }))

const followUpDateToDisplay = (dateVal) => {
  if (!dateVal) return '—'
  const s = typeof dateVal === 'string' ? dateVal : ''
  const d =
    s && /^\d{4}-\d{2}-\d{2}$/.test(s) ? new Date(`${s}T12:00:00`) : new Date(dateVal)
  return Number.isNaN(d.getTime()) ? '—' : d.toLocaleDateString()
}

const inputClass =
  'mt-1.5 block w-full border border-gray-300 rounded-xl px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white disabled:bg-gray-50 disabled:text-gray-500'

export default function CompanyAddLeadPage({ readOnly = false }) {
  const { tenantId, leadId, id } = useParams()
  const currentLeadId = leadId || id
  const isEdit = Boolean(currentLeadId) && !readOnly
  const navigate = useNavigate()
  const companyName = TENANT_NAMES[tenantId] || tenantId

  const statusOptions = useMemo(() => leadStatusesForTenant(tenantId), [tenantId])

  const [form, setForm] = useState({
    name: '',
    businessName: '',
    contactNumber: '',
    address: '',
    city: '',
    state: '',
    businessType: '',
    leadSource: '',
    description: '',
    status: statusOptions[0] || 'Call not Received',
    meetingType: '',
    meetingPersonName: '',
    meetingTime: '',
    meetingInfoSent: false,
    followUps: [],
    generatedBy: '',
    assignedTo: '',
    siteCoordinator: '',
    siteVisitEvidence: { fileName: '', mimeType: '', dataUrl: '', uploadedAt: null },
  })

  const [employees, setEmployees] = useState([])
  const [employeeSearch, setEmployeeSearch] = useState('')
  const [employeeOpen, setEmployeeOpen] = useState(false)
  const [meetingPersonSearch, setMeetingPersonSearch] = useState('')
  const [meetingPersonOpen, setMeetingPersonOpen] = useState(false)
  const [followUpDate, setFollowUpDate] = useState(() => new Date().toISOString().slice(0, 10))
  const [followUpComments, setFollowUpComments] = useState('')
  const [loading, setLoading] = useState(false)
  const [fetchingLead, setFetchingLead] = useState(Boolean(currentLeadId))
  const [error, setError] = useState(null)
  const [states, setStates] = useState([])
  const [cities, setCities] = useState([])

  const employeeRef = useRef(null)
  const meetingPersonRef = useRef(null)
  const evidenceInputRef = useRef(null)

  const fetchCitiesByStateCode = async (stateCode) => {
    if (!stateCode) {
      setCities([])
      return
    }
    try {
      const res = await api.get('/locations/cities', { params: { stateCode } })
      setCities(Array.isArray(res.data) ? res.data : [])
    } catch {
      setCities([])
    }
  }

  // Load initial employees and states
  useEffect(() => {
    if (!tenantId) return
    const fetchInitialData = async () => {
      try {
        const [empRes, statesRes] = await Promise.all([
          api.get(`/companies/${tenantId}/employees`),
          api.get('/locations/states'),
        ])
        const empPayload = empRes.data
        const empList = Array.isArray(empPayload?.employees)
          ? empPayload.employees
          : Array.isArray(empPayload)
            ? empPayload
            : empPayload?.data || []
        setEmployees(empList)
        setStates(Array.isArray(statesRes.data) ? statesRes.data : [])
      } catch (err) {
        console.error('Failed to load initial data:', err)
      }
    }
    fetchInitialData()
  }, [tenantId])

  // Load lead data if editing or viewing
  useEffect(() => {
    if (!tenantId || !currentLeadId) return
    const fetchLead = async () => {
      try {
        setFetchingLead(true)
        const res = await api.get(`/companies/${tenantId}/leads/${currentLeadId}`)
        const l = res.data?.lead || res.data
        const genId = l.generatedBy?._id ?? l.generatedBy ?? ''
        const genName = l.generatedBy?.name ?? ''
        const assigneeId = l.assignedTo?._id ?? l.assignedTo ?? ''
        const siteCoordinatorId = l.siteCoordinator?._id ?? l.siteCoordinator ?? ''

        setForm({
          name: l.name ?? '',
          businessName: l.businessName ?? '',
          contactNumber: l.contactNumber ?? '',
          address: l.address ?? '',
          city: l.city ?? '',
          state: l.state ?? '',
          businessType: l.businessType ?? '',
          leadSource: l.leadSource ?? '',
          description: l.description ?? '',
          status: l.status ?? statusOptions[0] ?? 'Call not Received',
          meetingType: l.meetingType ?? '',
          meetingPersonName: l.meetingPersonName ?? '',
          meetingTime: l.meetingTime ? new Date(l.meetingTime).toISOString().slice(0, 16) : '',
          meetingInfoSent: Boolean(l.meetingInfoSent),
          followUps: normalizeFollowUps(l.followUps),
          generatedBy: genId,
          assignedTo: assigneeId,
          siteCoordinator: siteCoordinatorId,
          siteVisitEvidence: {
            fileName: l.siteVisitEvidence?.fileName || '',
            mimeType: l.siteVisitEvidence?.mimeType || '',
            dataUrl: l.siteVisitEvidence?.dataUrl || '',
            uploadedAt: l.siteVisitEvidence?.uploadedAt || null,
          },
        })
        setEmployeeSearch(genName)
        setMeetingPersonSearch(l.meetingPersonName ?? '')
      } catch (err) {
        setError(err.response?.data?.message || err.message || 'Error loading lead details')
      } finally {
        setFetchingLead(false)
      }
    }
    fetchLead()
  }, [tenantId, currentLeadId])

  // Auto-populate employee name if generatedBy set
  useEffect(() => {
    if (employeeSearch || !form.generatedBy || employees.length === 0) return
    const matched = employees.find((e) => String(e._id) === String(form.generatedBy))
    if (matched?.name) setEmployeeSearch(matched.name)
  }, [employeeSearch, form.generatedBy, employees])

  // Fetch cities when state changes
  useEffect(() => {
    if (!form.state || states.length === 0) return
    const matched = states.find((s) => s.name === form.state)
    if (matched?.iso2) fetchCitiesByStateCode(matched.iso2)
  }, [form.state, states])

  // Click outside listener for dropdowns
  useEffect(() => {
    const handleClickOutside = (e) => {
      if (employeeRef.current && !employeeRef.current.contains(e.target)) setEmployeeOpen(false)
      if (meetingPersonRef.current && !meetingPersonRef.current.contains(e.target))
        setMeetingPersonOpen(false)
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  const getDesignationTitle = (emp) =>
    emp?.designation?.title ||
    emp?.designation?.name ||
    (typeof emp?.designation === 'string' ? emp.designation : '')

  const filteredEmployees = useMemo(
    () =>
      employees.filter((e) =>
        (e.name || '').toLowerCase().includes(employeeSearch.toLowerCase())
      ),
    [employees, employeeSearch]
  )

  const MEETING_PERSON_DESIGNATIONS = [
    'Sales Manager',
    'Social Media Manager',
    'Product Manager',
    'Senior Software Engineer',
    'Software Engineer',
    'Team Lead',
  ]

  const meetingPersonEmployees = useMemo(
    () =>
      employees.filter((e) => {
        const title = getDesignationTitle(e)
        return MEETING_PERSON_DESIGNATIONS.some((d) =>
          (title || '').toLowerCase().includes(d.toLowerCase())
        )
      }),
    [employees]
  )

  const filteredMeetingPersonEmployees = useMemo(
    () =>
      meetingPersonEmployees.filter((e) =>
        (e.name || '').toLowerCase().includes(meetingPersonSearch.toLowerCase())
      ),
    [meetingPersonEmployees, meetingPersonSearch]
  )

  const siteCoordinatorEmployees = useMemo(() => {
    const normalizeKey = (value = '') =>
      String(value || '')
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '')
    const isSiteVisitAssignee = (emp) => {
      const title = getDesignationTitle(emp)
      const key = normalizeKey(title)
      const isCoordinator =
        key.includes('sitecoordinator') ||
        key.includes('sitereliabilityengineer') ||
        (key.includes('sitereliability') && key.includes('engineer'))
      const dept = String(emp?.department || emp?.designation?.department || '')
      return isCoordinator || /sales/i.test(dept)
    }
    return employees
      .filter((e) => {
        if (e.status === 'Inactive') return false
        return isSiteVisitAssignee(e)
      })
      .slice()
      .sort((a, b) => String(a.name || '').localeCompare(String(b.name || '')))
  }, [employees])

  // When status becomes Site Visit, keep a coordinator selected
  useEffect(() => {
    if (form.status !== 'Site Visit') return
    if (!siteCoordinatorEmployees.length) return
    const currentIsCoordinator = siteCoordinatorEmployees.some(
      (e) => String(e._id) === String(form.siteCoordinator)
    )
    if (currentIsCoordinator) return
    setForm((f) => ({ ...f, siteCoordinator: siteCoordinatorEmployees[0]._id }))
  }, [form.status, form.siteCoordinator, siteCoordinatorEmployees])

  const stateOptions = useMemo(
    () => states.map((s) => ({ value: s.name, label: s.name })),
    [states]
  )

  const cityOptions = useMemo(
    () => cities.map((c) => ({ value: c.name, label: c.name })),
    [cities]
  )

  const handleEmployeeSelect = (emp) => {
    setForm((f) => ({ ...f, generatedBy: emp._id }))
    setEmployeeSearch(emp.name || '')
    setEmployeeOpen(false)
  }

  const handleMeetingPersonSelect = (emp) => {
    setForm((f) => ({ ...f, meetingPersonName: emp.name || '' }))
    setMeetingPersonSearch(emp.name || '')
    setMeetingPersonOpen(false)
  }

  const handleChange = (e) => {
    const { name, value, type, checked } = e.target
    setForm((f) => ({ ...f, [name]: type === 'checkbox' ? checked : value }))
  }

  const handleSiteVisitEvidence = async (e) => {
    const file = e.target.files?.[0]
    if (!file) return
    const allowed =
      /^(image\/|application\/pdf)/i.test(file.type) ||
      /\.(jpe?g|png|gif|webp|pdf)$/i.test(file.name)
    if (!allowed) {
      setError('Please upload an image or PDF as site visit evidence.')
      e.target.value = ''
      return
    }
    try {
      setError(null)
      const uploaded = await uploadFile(file, { folder: 'evidence', tenantId })
      setForm((f) => ({
        ...f,
        siteVisitEvidence: {
          fileName: uploaded.fileName || file.name,
          mimeType: uploaded.mimeType || file.type || '',
          dataUrl: uploaded.url,
          uploadedAt: new Date().toISOString(),
        },
      }))
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to upload evidence file')
      e.target.value = ''
    }
  }

  const clearSiteVisitEvidence = () => {
    setForm((f) => ({
      ...f,
      siteVisitEvidence: { fileName: '', mimeType: '', dataUrl: '', uploadedAt: null },
    }))
    if (evidenceInputRef.current) evidenceInputRef.current.value = ''
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (readOnly) return

    if (!form.name.trim() || !form.businessName.trim() || !form.contactNumber.trim()) {
      setError('Please fill in Name, Business Name, and Contact Number')
      return
    }

    if (!form.generatedBy) {
      setError('Please select Lead Generated By')
      return
    }

    if (form.status === 'Site Visit' && !form.siteCoordinator) {
      setError('Please select a Sales or Site Co-ordinator employee when status is Site Visit')
      return
    }

    setLoading(true)
    setError(null)
    try {
      const pendingFollowUpComment = followUpComments.trim()
      const pendingFollowUp =
        pendingFollowUpComment && followUpDate
          ? [{ date: followUpDate, comments: pendingFollowUpComment }]
          : []

      const payload = {
        ...form,
        meetingType: form.meetingType || undefined,
        meetingTime: form.meetingTime ? new Date(form.meetingTime) : undefined,
        siteCoordinator:
          form.status === 'Site Visit'
            ? form.siteCoordinator || null
            : form.siteCoordinator || undefined,
        siteVisitEvidence:
          form.status === 'Site Visit'
            ? {
                fileName: form.siteVisitEvidence?.fileName || '',
                mimeType: form.siteVisitEvidence?.mimeType || '',
                dataUrl: form.siteVisitEvidence?.dataUrl || '',
                uploadedAt: form.siteVisitEvidence?.dataUrl
                  ? form.siteVisitEvidence?.uploadedAt || new Date()
                  : null,
              }
            : undefined,
        followUps: [...form.followUps, ...pendingFollowUp].map((fu) => ({
          comments: (fu.comments ?? fu.text ?? '').trim(),
          date:
            typeof fu.date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(fu.date)
              ? new Date(`${fu.date}T12:00:00`)
              : fu.date
                ? new Date(fu.date)
                : new Date(),
          ...(fu._id ? { _id: fu._id } : {}),
        })),
      }

      if (form.status !== 'Site Visit') {
        delete payload.siteCoordinator
        delete payload.siteVisitEvidence
      }

      if (currentLeadId) {
        await api.put(`/companies/${tenantId}/leads/${currentLeadId}`, payload)
      } else {
        await api.post(`/companies/${tenantId}/leads`, payload)
      }
      navigate(`/company/${tenantId}/leads`)
    } catch (err) {
      setError(
        err.response?.data?.message ||
          err.message ||
          (currentLeadId ? 'Error updating lead' : 'Error creating lead')
      )
    } finally {
      setLoading(false)
    }
  }

  const pageTitle = readOnly ? 'View Lead' : isEdit ? 'Edit Lead' : 'Add Lead'

  return (
    <AdminCompanyShell activeNav='leads'>
      <div className='w-full p-4 md:p-8'>
        {/* Header Breadcrumb */}
        <div className='mb-6 flex flex-wrap items-center justify-between gap-3'>
          <div>
            <div className='flex items-center gap-2 text-sm text-gray-500 mb-1'>
              <button
                type='button'
                onClick={() => navigate(`/company/${tenantId}/leads`)}
                className='hover:text-blue-600 transition-colors cursor-pointer'
              >
                Lead Management
              </button>
              <span>/</span>
              <span className='text-gray-900 font-medium'>{pageTitle}</span>
            </div>
            <h1 className='text-2xl md:text-3xl font-bold text-gray-900 tracking-tight'>
              {pageTitle}
            </h1>
          </div>
          <button
            type='button'
            onClick={() => navigate(`/company/${tenantId}/leads`)}
            className='px-4 py-2 rounded-xl border border-gray-300 text-sm font-medium text-gray-700 hover:bg-gray-100 transition-colors cursor-pointer'
          >
            ← Back to Leads
          </button>
        </div>

        {fetchingLead ? (
          <div className='bg-white rounded-xl shadow p-12 text-center text-gray-500'>
            <div className='inline-flex items-center gap-2'>
              <svg
                className='animate-spin h-5 w-5 text-blue-600'
                xmlns='http://www.w3.org/2000/svg'
                fill='none'
                viewBox='0 0 24 24'
              >
                <circle
                  className='opacity-25'
                  cx='12'
                  cy='12'
                  r='10'
                  stroke='currentColor'
                  strokeWidth='4'
                ></circle>
                <path
                  className='opacity-75'
                  fill='currentColor'
                  d='M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z'
                ></path>
              </svg>
              <span>Loading lead details…</span>
            </div>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className='w-full'>
            <div className='bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden'>
              {/* Blue Header Banner mirroring company app */}
              <div className='px-5 py-4 border-b border-blue-700 bg-blue-600'>
                <h2 className='text-lg font-semibold text-white'>Lead details</h2>
                <p className='text-sm text-blue-100 mt-0.5'>
                  Track lead source, status, meeting details and follow-ups.
                </p>
              </div>

              <div className='p-5 md:p-7 space-y-6 md:space-y-7'>
                <fieldset disabled={readOnly} className='contents'>
                  {/* Grid 1: Basic Information */}
                  <div className='grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4'>
                    <div>
                      <label className='block text-xs font-semibold text-gray-700 uppercase tracking-wider'>
                        Name <span className='text-red-500'>*</span>
                      </label>
                      <input
                        name='name'
                        value={form.name}
                        onChange={handleChange}
                        required
                        className={inputClass}
                        placeholder='Full name'
                      />
                    </div>
                    <div>
                      <label className='block text-xs font-semibold text-gray-700 uppercase tracking-wider'>
                        Business Name <span className='text-red-500'>*</span>
                      </label>
                      <input
                        name='businessName'
                        value={form.businessName}
                        onChange={handleChange}
                        required
                        className={inputClass}
                        placeholder='Company or Brand name'
                      />
                    </div>
                    <div>
                      <label className='block text-xs font-semibold text-gray-700 uppercase tracking-wider'>
                        Contact Number <span className='text-red-500'>*</span>
                      </label>
                      <input
                        name='contactNumber'
                        value={form.contactNumber}
                        onChange={handleChange}
                        required
                        className={inputClass}
                        placeholder='+91 98765 43210'
                      />
                    </div>
                    <div>
                      <label className='block text-xs font-semibold text-gray-700 uppercase tracking-wider'>
                        Business Type
                      </label>
                      <input
                        name='businessType'
                        value={form.businessType}
                        onChange={handleChange}
                        className={inputClass}
                        placeholder='e.g. Real Estate, Retail, IT'
                      />
                    </div>
                  </div>

                  {/* Grid 2: Location Information */}
                  <div className='grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4'>
                    <div>
                      <SearchableSelect
                        id='lead-state'
                        label='State'
                        value={form.state}
                        onChange={(stateName) => {
                          const selected = states.find((s) => s.name === stateName)
                          setForm((f) => ({ ...f, state: stateName || '', city: '' }))
                          fetchCitiesByStateCode(selected?.iso2 || '')
                        }}
                        options={stateOptions}
                        disabled={readOnly}
                        placeholder='Select state'
                        searchPlaceholder='Search state…'
                        emptyText='No states match'
                        inputClassName={inputClass}
                      />
                    </div>
                    <div>
                      <SearchableSelect
                        id='lead-city'
                        label='City'
                        value={form.city}
                        onChange={(cityName) => setForm((f) => ({ ...f, city: cityName || '' }))}
                        options={cityOptions}
                        disabled={readOnly || !form.state}
                        placeholder={form.state ? 'Select city' : 'Select state first'}
                        searchPlaceholder='Search city…'
                        emptyText='No cities match'
                        inputClassName={inputClass}
                      />
                    </div>
                    <div className='lg:col-span-2'>
                      <label className='block text-xs font-semibold text-gray-700 uppercase tracking-wider'>
                        Address
                      </label>
                      <input
                        name='address'
                        value={form.address}
                        onChange={handleChange}
                        className={inputClass}
                        placeholder='Street address, landmark'
                      />
                    </div>
                  </div>

                  {/* Grid 3: Lead Qualification & Generator */}
                  <div className='grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4'>
                    <div>
                      <label className='block text-xs font-semibold text-gray-700 uppercase tracking-wider'>
                        Lead Source
                      </label>
                      <input
                        name='leadSource'
                        value={form.leadSource}
                        onChange={handleChange}
                        className={inputClass}
                        placeholder='e.g. Website, Referral, Ads'
                      />
                    </div>
                    <div>
                      <label className='block text-xs font-semibold text-gray-700 uppercase tracking-wider'>
                        Status
                      </label>
                      <select
                        name='status'
                        value={form.status}
                        onChange={handleChange}
                        className={inputClass}
                      >
                        {statusOptions.map((s) => (
                          <option key={s} value={s}>
                            {s}
                          </option>
                        ))}
                      </select>
                    </div>

                    <div className='relative lg:col-span-2' ref={employeeRef}>
                      <label className='block text-xs font-semibold text-gray-700 uppercase tracking-wider'>
                        Lead Generated By <span className='text-red-500'>*</span>
                      </label>
                      <input
                        type='text'
                        value={employeeSearch}
                        onChange={(e) => {
                          setEmployeeSearch(e.target.value)
                          setEmployeeOpen(true)
                          if (!e.target.value) setForm((f) => ({ ...f, generatedBy: '' }))
                        }}
                        onFocus={() => !readOnly && setEmployeeOpen(true)}
                        placeholder='Search employee…'
                        className={inputClass}
                        autoComplete='off'
                        disabled={readOnly}
                      />
                      {employeeOpen && !readOnly && (
                        <ul className='absolute z-20 top-full left-0 right-0 mt-1 max-h-48 overflow-auto bg-white border border-gray-300 rounded-xl shadow-xl py-1'>
                          {filteredEmployees.map((emp) => (
                            <li
                              key={emp._id}
                              onClick={() => handleEmployeeSelect(emp)}
                              className={`px-3 py-2 text-sm cursor-pointer hover:bg-blue-50 ${
                                form.generatedBy === emp._id
                                  ? 'bg-blue-100 font-medium text-blue-800'
                                  : 'text-gray-800'
                              }`}
                            >
                              <div className='flex items-center justify-between'>
                                <span>{emp.name}</span>
                                {emp.department && (
                                  <span className='text-xs text-gray-400'>{emp.department}</span>
                                )}
                              </div>
                            </li>
                          ))}
                        </ul>
                      )}
                    </div>
                  </div>

                  {/* Description */}
                  <div>
                    <label className='block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1'>
                      Description
                    </label>
                    <textarea
                      name='description'
                      value={form.description}
                      onChange={handleChange}
                      rows={3}
                      className={inputClass}
                      placeholder='Add relevant notes or qualification details…'
                    />
                  </div>

                  {/* Conditional: Meeting Schedule */}
                  {form.status === 'Meeting Schedule' && (
                    <div className='rounded-xl border border-amber-200 bg-amber-50/50 p-4 space-y-4'>
                      <h3 className='text-sm font-bold text-amber-900 flex items-center gap-1.5'>
                        <span>📅</span> Meeting Details
                      </h3>
                      <div className='grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4'>
                        <div>
                          <label className='block text-xs font-semibold text-gray-700 uppercase tracking-wider'>
                            Meeting Type
                          </label>
                          <select
                            name='meetingType'
                            value={form.meetingType}
                            onChange={handleChange}
                            className={inputClass}
                          >
                            <option value=''>Select type</option>
                            <option value='Online'>Online</option>
                            <option value='Offline'>Offline</option>
                          </select>
                        </div>

                        <div className='relative lg:col-span-2' ref={meetingPersonRef}>
                          <label className='block text-xs font-semibold text-gray-700 uppercase tracking-wider'>
                            Meeting Person Name
                          </label>
                          <input
                            type='text'
                            value={meetingPersonSearch}
                            onChange={(e) => {
                              setMeetingPersonSearch(e.target.value)
                              setMeetingPersonOpen(true)
                              if (!e.target.value) setForm((f) => ({ ...f, meetingPersonName: '' }))
                            }}
                            onFocus={() => !readOnly && setMeetingPersonOpen(true)}
                            placeholder='Select meeting person (Sales Manager, etc.)'
                            className={inputClass}
                            autoComplete='off'
                            disabled={readOnly}
                          />
                          {meetingPersonOpen && !readOnly && (
                            <ul className='absolute z-20 top-full left-0 right-0 mt-1 max-h-48 overflow-auto bg-white border border-gray-300 rounded-xl shadow-xl py-1'>
                              {filteredMeetingPersonEmployees.length === 0 ? (
                                <li className='px-3 py-2 text-sm text-gray-500'>
                                  No employees with matching designation
                                </li>
                              ) : (
                                filteredMeetingPersonEmployees.map((emp) => (
                                  <li
                                    key={emp._id}
                                    onClick={() => handleMeetingPersonSelect(emp)}
                                    className={`px-3 py-2 text-sm cursor-pointer hover:bg-blue-50 ${
                                      form.meetingPersonName === emp.name
                                        ? 'bg-blue-100 font-medium text-blue-800'
                                        : 'text-gray-800'
                                    }`}
                                  >
                                    <div className='flex items-center justify-between'>
                                      <span>{emp.name}</span>
                                      {getDesignationTitle(emp) && (
                                        <span className='text-xs text-gray-400'>
                                          ({getDesignationTitle(emp)})
                                        </span>
                                      )}
                                    </div>
                                  </li>
                                ))
                              )}
                            </ul>
                          )}
                        </div>

                        <div>
                          <label className='block text-xs font-semibold text-gray-700 uppercase tracking-wider'>
                            Meeting Time
                          </label>
                          <input
                            name='meetingTime'
                            type='datetime-local'
                            value={form.meetingTime}
                            onChange={handleChange}
                            className={inputClass}
                          />
                        </div>

                        <div className='sm:col-span-2 lg:col-span-4'>
                          <label className='flex items-center gap-2 cursor-pointer mt-1'>
                            <input
                              type='checkbox'
                              name='meetingInfoSent'
                              checked={form.meetingInfoSent}
                              onChange={handleChange}
                              className='rounded text-blue-600 focus:ring-blue-500'
                              disabled={readOnly}
                            />
                            <span className='text-sm text-gray-700'>
                              Info sent to meeting person
                            </span>
                          </label>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* Conditional: Site Visit */}
                  {form.status === 'Site Visit' && (
                    <div className='rounded-xl border border-indigo-200 bg-indigo-50/50 p-4 space-y-4'>
                      <h3 className='text-sm font-bold text-indigo-900 flex items-center gap-1.5'>
                        <span>📍</span> Site Visit Assignment & Evidence
                      </h3>
                      <div className='grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4'>
                        <div className='lg:col-span-2'>
                          <label className='block text-xs font-semibold text-gray-700 uppercase tracking-wider'>
                            Site visit assignee <span className='text-red-500'>*</span>
                          </label>
                          <select
                            name='siteCoordinator'
                            value={form.siteCoordinator || ''}
                            onChange={handleChange}
                            className={inputClass}
                            required={form.status === 'Site Visit'}
                            disabled={readOnly}
                          >
                            <option value=''>
                              {siteCoordinatorEmployees.length
                                ? 'Select employee…'
                                : 'No Sales / Site Co-ordinator employees found'}
                            </option>
                            {siteCoordinatorEmployees.map((emp) => (
                              <option key={emp._id} value={emp._id}>
                                {emp.name}
                                {getDesignationTitle(emp) ? ` (${getDesignationTitle(emp)})` : ''}
                              </option>
                            ))}
                          </select>
                          <p className='mt-1 text-xs text-gray-500'>
                            Assign a sales executive or site co-ordinator for the in-person visit.
                          </p>
                        </div>

                        <div className='lg:col-span-2'>
                          <label className='block text-xs font-semibold text-gray-700 uppercase tracking-wider'>
                            Site visit evidence
                          </label>
                          <input
                            ref={evidenceInputRef}
                            type='file'
                            accept='image/*,.pdf,application/pdf'
                            onChange={handleSiteVisitEvidence}
                            disabled={readOnly}
                            className={`${inputClass} file:mr-3 file:rounded-lg file:border-0 file:bg-blue-50 file:px-3 file:py-1.5 file:text-xs file:font-semibold file:text-blue-700`}
                          />
                          <p className='mt-1 text-xs text-gray-500'>
                            Upload a photo or PDF proving the visitor attended the site.
                          </p>

                          {form.siteVisitEvidence?.dataUrl ? (
                            <div className='mt-3 rounded-xl border border-gray-200 bg-white p-3 shadow-xs'>
                              <div className='flex flex-wrap items-center justify-between gap-2'>
                                <a
                                  href={form.siteVisitEvidence.dataUrl}
                                  target='_blank'
                                  rel='noopener noreferrer'
                                  className='text-sm font-medium text-indigo-600 hover:underline break-all'
                                >
                                  {form.siteVisitEvidence.fileName || 'View uploaded evidence'}
                                </a>
                                {!readOnly && (
                                  <button
                                    type='button'
                                    onClick={clearSiteVisitEvidence}
                                    className='text-xs text-rose-600 hover:underline font-medium cursor-pointer'
                                  >
                                    Remove
                                  </button>
                                )}
                              </div>
                              {/image\//i.test(form.siteVisitEvidence.mimeType || '') && (
                                <a
                                  href={form.siteVisitEvidence.dataUrl}
                                  target='_blank'
                                  rel='noopener noreferrer'
                                >
                                  <img
                                    src={form.siteVisitEvidence.dataUrl}
                                    alt={form.siteVisitEvidence.fileName || 'Site visit evidence'}
                                    className='mt-3 max-h-48 rounded-lg border border-gray-200 object-contain'
                                  />
                                </a>
                              )}
                            </div>
                          ) : null}
                        </div>
                      </div>
                    </div>
                  )}

                  {/* Follow-up Section */}
                  <div>
                    <label className='block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-2'>
                      Follow Up History
                    </label>
                    <div className='border border-gray-200 rounded-xl overflow-hidden shadow-xs'>
                      <div className='overflow-x-auto'>
                        <table className='w-full text-sm min-w-[480px]'>
                          <thead>
                            <tr className='bg-blue-600 text-white font-bold text-sm'>
                              <th className='text-left px-4 py-3 font-semibold whitespace-nowrap'>
                                Follow-up date
                              </th>
                              <th className='text-left px-4 py-3 font-semibold'>
                                Comments (what was discussed)
                              </th>
                            </tr>
                          </thead>
                          <tbody className='bg-white divide-y divide-gray-100'>
                            {form.followUps.length === 0 ? (
                              <tr>
                                <td colSpan={2} className='px-4 py-8 text-center text-gray-500'>
                                  {readOnly
                                    ? 'No follow-ups recorded.'
                                    : 'No follow-ups yet. Add one below.'}
                                </td>
                              </tr>
                            ) : (
                              form.followUps.map((fu, idx) => (
                                <tr key={fu._id || `fu-${idx}`} className='hover:bg-gray-50/80'>
                                  <td className='px-4 py-3 text-gray-900 whitespace-nowrap align-top font-medium'>
                                    {followUpDateToDisplay(fu.date)}
                                  </td>
                                  <td className='px-4 py-3 text-gray-800 align-top whitespace-pre-wrap break-words'>
                                    {fu.comments ?? fu.text ?? '—'}
                                  </td>
                                </tr>
                              ))
                            )}
                          </tbody>
                        </table>
                      </div>

                      {!readOnly && (
                        <div className='p-4 bg-gray-50 border-t border-gray-200 space-y-3'>
                          <p className='text-xs font-semibold text-gray-600 uppercase tracking-wider'>
                            + Add New Follow-up
                          </p>
                          <div className='grid grid-cols-1 sm:grid-cols-12 gap-3 items-end'>
                            <div className='sm:col-span-4'>
                              <label
                                htmlFor='follow-up-date'
                                className='block text-xs font-medium text-gray-600 mb-1'
                              >
                                Follow-up date
                              </label>
                              <input
                                id='follow-up-date'
                                type='date'
                                value={followUpDate}
                                onChange={(e) => setFollowUpDate(e.target.value)}
                                className={inputClass}
                              />
                            </div>
                            <div className='sm:col-span-8'>
                              <label
                                htmlFor='follow-up-comments'
                                className='block text-xs font-medium text-gray-600 mb-1'
                              >
                                Comments (what was discussed)
                              </label>
                              <textarea
                                id='follow-up-comments'
                                value={followUpComments}
                                onChange={(e) => setFollowUpComments(e.target.value)}
                                placeholder='Summarize what was discussed on this follow-up…'
                                rows={2}
                                className={inputClass}
                              />
                            </div>
                          </div>
                        </div>
                      )}
                    </div>
                  </div>

                  {error && (
                    <div className='rounded-xl bg-red-50 border border-red-200 p-4 text-sm text-red-700'>
                      {error}
                    </div>
                  )}
                </fieldset>
              </div>

              {/* Form Bottom Actions */}
              <div className='px-5 py-4 border-t border-gray-200 bg-gray-50/70 flex items-center gap-3'>
                {!readOnly && (
                  <button
                    type='submit'
                    disabled={loading}
                    className='bg-green-600 text-white px-6 py-2.5 rounded-xl hover:bg-green-700 active:bg-green-800 text-sm font-semibold shadow-sm transition-all disabled:opacity-50 cursor-pointer'
                  >
                    {loading ? 'Saving…' : isEdit ? 'Update Lead' : 'Save Lead'}
                  </button>
                )}
                <button
                  type='button'
                  onClick={() => navigate(`/company/${tenantId}/leads`)}
                  className='px-5 py-2.5 rounded-xl border border-gray-300 text-sm font-medium text-gray-700 hover:bg-gray-100 transition-colors cursor-pointer'
                >
                  {readOnly ? 'Back to Leads' : 'Cancel'}
                </button>
              </div>
            </div>
          </form>
        )}
      </div>
    </AdminCompanyShell>
  )
}
