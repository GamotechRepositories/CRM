import React, { useEffect, useState } from 'react'
import api from '../../api/axios'
import { useNavigate } from 'react-router-dom'
import { EditIcon, ViewIcon } from '../Icons'

const STATUS_OPTIONS = [
  'Call not Received',
  'Call You After Sometime',
  'Interested',
  'Not Interested',
  'Meeting Schedule',
]

const LeadsView = () => {
  const [leads, setLeads] = useState([])
  const [employees, setEmployees] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [filters, setFilters] = useState({
    status: '',
    date: '',
    dateFrom: '',
    dateTo: '',
    employee: '',
    businessType: '',
    leadSource: '',
    city: '',
    state: '',
    search: '',
  })
  const navigate = useNavigate()

  const fetchLeads = async () => {
    try {
      setLoading(true)
      const params = new URLSearchParams()
      Object.entries(filters).forEach(([k, v]) => {
        if (v) params.append(k, v)
      })
      const res = await api.get(`/leads?${params.toString()}`)
      setLeads(Array.isArray(res.data) ? res.data : [])
    } catch (err) {
      setError(err.message || 'Error fetching leads')
    } finally {
      setLoading(false)
    }
  }

  const fetchEmployees = async () => {
    try {
      const res = await api.get('/employees')
      setEmployees(Array.isArray(res.data) ? res.data : res.data?.data || [])
    } catch (err) {
      console.error('Failed to fetch employees:', err)
    }
  }

  useEffect(() => {
    fetchEmployees()
  }, [])

  useEffect(() => {
    fetchLeads()
  }, [filters])

  const handleFilterChange = (key, value) => {
    setFilters((f) => ({ ...f, [key]: value }))
  }

  return (
    <div className='p-8'>
      <div className='flex items-center justify-between mb-6'>
        <div>
          <h1 className='text-2xl font-bold text-gray-900'>Lead Management</h1>
          <p className='text-gray-600 mt-1 text-sm'>Manage and qualify sales leads.</p>
        </div>
        <button
          onClick={() => navigate('/add-lead')}
          className='bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-md text-sm font-medium'
        >
          + Add Lead
        </button>
      </div>

      <div className='grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6'>
        <div className='bg-white rounded-lg shadow p-5 border-l-4 border-blue-500'>
          <p className='text-sm font-medium text-gray-600'>Total Leads</p>
          <p className='text-2xl font-bold text-gray-900 mt-1'>
            {loading ? '—' : leads.length}
          </p>
          <p className='text-xs text-gray-500 mt-1'>Based on current filters</p>
        </div>
        <div className='bg-white rounded-lg shadow p-5 border-l-4 border-green-500'>
          <p className='text-sm font-medium text-gray-600'>Interested</p>
          <p className='text-2xl font-bold text-gray-900 mt-1'>
            {loading ? '—' : leads.filter((l) => l.status === 'Interested').length}
          </p>
          <p className='text-xs text-gray-500 mt-1'>Based on current filters</p>
        </div>
        <div className='bg-white rounded-lg shadow p-5 border-l-4 border-amber-500'>
          <p className='text-sm font-medium text-gray-600'>Meeting Schedule</p>
          <p className='text-2xl font-bold text-gray-900 mt-1'>
            {loading ? '—' : leads.filter((l) => l.status === 'Meeting Schedule').length}
          </p>
          <p className='text-xs text-gray-500 mt-1'>Based on current filters</p>
        </div>
        <div className='bg-white rounded-lg shadow p-5 border-l-4 border-gray-400'>
          <p className='text-sm font-medium text-gray-600'>Not Interested</p>
          <p className='text-2xl font-bold text-gray-900 mt-1'>
            {loading ? '—' : leads.filter((l) => l.status === 'Not Interested').length}
          </p>
          <p className='text-xs text-gray-500 mt-1'>Based on current filters</p>
        </div>
      </div>

      <div className='bg-white rounded-lg shadow p-4 mb-6'>
        <h3 className='text-sm font-semibold text-gray-700 mb-3'>Filters</h3>
        <div className='grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4'>
          <div>
            <label className='block text-xs font-medium text-gray-600 mb-1'>Search</label>
            <input
              type='text'
              value={filters.search}
              onChange={(e) => handleFilterChange('search', e.target.value)}
              placeholder='Name, business, contact, lead source...'
              className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm'
            />
          </div>
          <div>
            <label className='block text-xs font-medium text-gray-600 mb-1'>Status</label>
            <select
              value={filters.status}
              onChange={(e) => handleFilterChange('status', e.target.value)}
              className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm'
            >
              <option value=''>All status</option>
              {STATUS_OPTIONS.map((s) => (
                <option key={s} value={s}>{s}</option>
              ))}
            </select>
          </div>
          <div>
            <label className='block text-xs font-medium text-gray-600 mb-1'>Date</label>
            <input
              type='date'
              value={filters.date}
              onChange={(e) => handleFilterChange('date', e.target.value)}
              className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm'
            />
          </div>
          <div>
            <label className='block text-xs font-medium text-gray-600 mb-1'>Date From</label>
            <input
              type='date'
              value={filters.dateFrom}
              onChange={(e) => handleFilterChange('dateFrom', e.target.value)}
              className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm'
            />
          </div>
          <div>
            <label className='block text-xs font-medium text-gray-600 mb-1'>Date To</label>
            <input
              type='date'
              value={filters.dateTo}
              onChange={(e) => handleFilterChange('dateTo', e.target.value)}
              className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm'
            />
          </div>
          <div>
            <label className='block text-xs font-medium text-gray-600 mb-1'>Employee</label>
            <select
              value={filters.employee}
              onChange={(e) => handleFilterChange('employee', e.target.value)}
              className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm'
            >
              <option value=''>All</option>
              {employees.map((e) => (
                <option key={e._id} value={e._id}>{e.name}</option>
              ))}
            </select>
          </div>
          <div>
            <label className='block text-xs font-medium text-gray-600 mb-1'>Business Type</label>
            <input
              type='text'
              value={filters.businessType}
              onChange={(e) => handleFilterChange('businessType', e.target.value)}
              placeholder='Filter by business type'
              className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm'
            />
          </div>
          <div>
            <label className='block text-xs font-medium text-gray-600 mb-1'>Lead Source</label>
            <input
              type='text'
              value={filters.leadSource}
              onChange={(e) => handleFilterChange('leadSource', e.target.value)}
              placeholder='Filter by lead source'
              className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm'
            />
          </div>
          <div>
            <label className='block text-xs font-medium text-gray-600 mb-1'>City</label>
            <input
              type='text'
              value={filters.city}
              onChange={(e) => handleFilterChange('city', e.target.value)}
              placeholder='Filter by city'
              className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm'
            />
          </div>
          <div>
            <label className='block text-xs font-medium text-gray-600 mb-1'>State</label>
            <input
              type='text'
              value={filters.state}
              onChange={(e) => handleFilterChange('state', e.target.value)}
              placeholder='Filter by state'
              className='w-full border border-gray-300 rounded-lg px-3 py-2 text-sm'
            />
          </div>
        </div>
      </div>

      {loading ? (
        <p className='text-sm'>Loading...</p>
      ) : error ? (
        <p className='text-red-600 text-sm'>{error}</p>
      ) : (
        <div className='bg-white rounded-lg shadow overflow-x-auto'>
          <table className='w-full table-auto text-sm'>
            <thead className='text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>
              <tr className='text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Name</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Business</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Contact</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Business Type</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Lead Source</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>City</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center whitespace-nowrap'>Status</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Generated By</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Actions</th>
              </tr>
            </thead>
            <tbody>
              {leads.length === 0 ? (
                <tr>
                  <td colSpan={9} className='px-4 py-12 text-center text-gray-500'>
                    No leads found
                  </td>
                </tr>
              ) : (
                leads.map((l) => (
                  <tr
                    key={l._id}
                    className='border-b hover:bg-gray-50 cursor-pointer transition-colors'
                    onClick={() => navigate(`/leads/view/${l._id}`)}
                    role='link'
                    tabIndex={0}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter' || e.key === ' ') {
                        e.preventDefault()
                        navigate(`/leads/view/${l._id}`)
                      }
                    }}
                  >
                    <td className='px-4 py-3 font-medium text-indigo-700'>{l.name}</td>
                    <td className='px-4 py-3'>{l.businessName}</td>
                    <td className='px-4 py-3'>{l.contactNumber}</td>
                    <td className='px-4 py-3'>{l.businessType || '—'}</td>
                    <td className='px-4 py-3'>{l.leadSource || '—'}</td>
                    <td className='px-4 py-3'>{l.city || '—'}</td>
                    <td className='px-4 py-3 text-left align-middle whitespace-nowrap'>
                      <span className='inline-flex items-center whitespace-nowrap px-2.5 py-1 rounded-full text-xs font-semibold bg-blue-100 text-blue-800'>
                        {l.status}
                      </span>
                    </td>
                    <td className='px-4 py-3'>{l.generatedBy?.name || '—'}</td>
                    <td className='px-4 py-3 cursor-default' onClick={(e) => e.stopPropagation()}>
                      <div className='flex items-center gap-2'>
                        <button
                          type='button'
                          onClick={() => navigate(`/leads/view/${l._id}`)}
                          className='p-1.5 rounded-lg text-gray-700 hover:bg-gray-100 transition-colors'
                          title='View details'
                        >
                          <ViewIcon />
                        </button>
                        <button
                          type='button'
                          onClick={() => navigate(`/leads/edit/${l._id}`)}
                          className='p-1.5 rounded-lg text-blue-600 hover:bg-blue-50 transition-colors'
                          title='Edit'
                        >
                          <EditIcon />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

export default LeadsView
