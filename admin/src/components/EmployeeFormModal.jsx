import React, { useEffect, useState } from 'react'
import api from '../api/axios'

const emptyForm = {
  name: '',
  email: '',
  password: '',
  designation: '',
  department: '',
  dateOfJoining: '',
  salary: '',
  workingHours: '9 AM - 6 PM',
  status: 'Active',
  reportingManager: '',
}

const inputClass =
  'w-full rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'

const toDateInput = (value) => {
  if (!value) return ''
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return ''
  return d.toISOString().slice(0, 10)
}

const EmployeeFormModal = ({
  open,
  mode = 'create',
  tenantId,
  employee,
  employees = [],
  onClose,
  onSaved,
}) => {
  const [form, setForm] = useState(emptyForm)
  const [designations, setDesignations] = useState([])
  const [loadingMeta, setLoadingMeta] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    if (!open || !tenantId) return
    let cancelled = false
    const load = async () => {
      try {
        setLoadingMeta(true)
        setError('')
        const res = await api.get(`/companies/${tenantId}/designations`)
        if (!cancelled) setDesignations(res.data?.designations || [])
      } catch (err) {
        if (!cancelled) {
          setError(err.response?.data?.message || err.message || 'Failed to load designations')
        }
      } finally {
        if (!cancelled) setLoadingMeta(false)
      }
    }
    load()
    return () => {
      cancelled = true
    }
  }, [open, tenantId])

  useEffect(() => {
    if (!open) return
    setError('')
    if (mode === 'edit' && employee) {
      setForm({
        name: employee.name || '',
        email: employee.email || '',
        password: '',
        designation: employee.designation?._id || employee.designation || '',
        department: employee.department || '',
        dateOfJoining: toDateInput(employee.dateOfJoining),
        salary: employee.salary ?? '',
        workingHours: employee.workingHours || '9 AM - 6 PM',
        status: employee.status || 'Active',
        reportingManager: employee.reportingManager?._id || employee.reportingManager || '',
      })
      return
    }
    setForm(emptyForm)
  }, [open, mode, employee])

  if (!open) return null

  const setField = (key, value) => setForm((prev) => ({ ...prev, [key]: value }))

  const handleSubmit = async (event) => {
    event.preventDefault()
    if (mode === 'create' && (!form.password || form.password.length < 6)) {
      setError('Password is required and must be at least 6 characters')
      return
    }
    if (form.password && form.password.length > 0 && form.password.length < 6) {
      setError('Password must be at least 6 characters when provided')
      return
    }

    const payload = {
      name: form.name.trim(),
      email: form.email.trim(),
      designation: form.designation,
      department: form.department.trim(),
      dateOfJoining: form.dateOfJoining,
      salary: Number(form.salary) || 0,
      workingHours: form.workingHours.trim() || '9 AM - 6 PM',
      status: form.status,
      reportingManager: form.reportingManager || null,
    }
    if (form.password) payload.password = form.password

    try {
      setSaving(true)
      setError('')
      const res =
        mode === 'edit' && employee?._id
          ? await api.put(`/companies/${tenantId}/employees/${employee._id}`, payload)
          : await api.post(`/companies/${tenantId}/employees`, payload)
      onSaved?.(res.data?.employee)
      onClose?.()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to save employee')
    } finally {
      setSaving(false)
    }
  }

  const managerOptions = employees.filter((row) => row._id !== employee?._id)

  return (
    <div className='fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40'>
      <div className='w-full max-w-2xl max-h-[90vh] overflow-y-auto rounded-2xl bg-white shadow-xl border border-gray-100'>
        <div className='sticky top-0 bg-white border-b border-gray-100 px-5 py-4 flex items-center justify-between gap-3'>
          <div>
            <h2 className='text-lg font-bold text-gray-900'>
              {mode === 'edit' ? 'Edit employee' : 'Add employee'}
            </h2>
            <p className='text-xs text-gray-500 mt-0.5'>Create or update team members across this company CRM</p>
          </div>
          <button
            type='button'
            onClick={onClose}
            className='rounded-lg border border-gray-200 px-3 py-1.5 text-sm text-gray-600 hover:bg-gray-50'
          >
            Close
          </button>
        </div>

        <form onSubmit={handleSubmit} className='p-5 space-y-4'>
          {error && (
            <div className='rounded-xl bg-red-50 border border-red-100 px-3 py-2 text-sm text-red-600'>
              {error}
            </div>
          )}

          <div className='grid grid-cols-1 sm:grid-cols-2 gap-4'>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Full name *</label>
              <input
                type='text'
                value={form.name}
                onChange={(e) => setField('name', e.target.value)}
                className={inputClass}
                required
              />
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Email *</label>
              <input
                type='email'
                value={form.email}
                onChange={(e) => setField('email', e.target.value)}
                className={inputClass}
                required
              />
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>
                {mode === 'edit' ? 'New password (optional)' : 'Password *'}
              </label>
              <input
                type='password'
                value={form.password}
                onChange={(e) => setField('password', e.target.value)}
                className={inputClass}
                placeholder={mode === 'edit' ? 'Leave blank to keep current' : 'Minimum 6 characters'}
                required={mode === 'create'}
              />
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Designation *</label>
              <select
                value={form.designation}
                onChange={(e) => setField('designation', e.target.value)}
                className={inputClass}
                required
                disabled={loadingMeta}
              >
                <option value=''>Select designation</option>
                {designations.map((d) => (
                  <option key={d._id} value={d._id}>
                    {d.title}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Department *</label>
              <input
                type='text'
                value={form.department}
                onChange={(e) => setField('department', e.target.value)}
                className={inputClass}
                required
              />
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Date of joining *</label>
              <input
                type='date'
                value={form.dateOfJoining}
                onChange={(e) => setField('dateOfJoining', e.target.value)}
                className={inputClass}
                required
              />
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Monthly salary (INR) *</label>
              <input
                type='number'
                min='0'
                value={form.salary}
                onChange={(e) => setField('salary', e.target.value)}
                className={inputClass}
                required
              />
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Working hours *</label>
              <input
                type='text'
                value={form.workingHours}
                onChange={(e) => setField('workingHours', e.target.value)}
                className={inputClass}
                required
              />
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Status</label>
              <select
                value={form.status}
                onChange={(e) => setField('status', e.target.value)}
                className={inputClass}
              >
                <option value='Active'>Active</option>
                <option value='Inactive'>Inactive</option>
                <option value='On Leave'>On Leave</option>
              </select>
            </div>
            <div>
              <label className='block text-xs font-semibold text-gray-500 mb-1'>Reporting manager</label>
              <select
                value={form.reportingManager}
                onChange={(e) => setField('reportingManager', e.target.value)}
                className={inputClass}
              >
                <option value=''>None</option>
                {managerOptions.map((row) => (
                  <option key={row._id} value={row._id}>
                    {row.name}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <div className='flex items-center justify-end gap-2 pt-2'>
            <button
              type='button'
              onClick={onClose}
              className='rounded-xl border border-gray-200 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50'
            >
              Cancel
            </button>
            <button
              type='submit'
              disabled={saving || loadingMeta}
              className='rounded-xl bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-700 disabled:opacity-50'
            >
              {saving ? 'Saving…' : mode === 'edit' ? 'Update employee' : 'Create employee'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default EmployeeFormModal
