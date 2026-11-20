import React, { useEffect, useState } from 'react'
import api from '../../api/axios'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { DeleteIcon } from '../Icons'

const MONTH_NAMES = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

const SalariesView = () => {
  const navigate = useNavigate()
  const [searchParams, setSearchParams] = useSearchParams()
  const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata', year: 'numeric', month: '2-digit' }).formatToParts(new Date())
  const currentMonth = `${today.find((part) => part.type === 'year').value}-${today.find((part) => part.type === 'month').value}`
  const requestedMonth = searchParams.get('month') || ''
  const selectedMonth = /^[1-9]\d{3}-(0[1-9]|1[0-2])$/.test(requestedMonth) ? requestedMonth : currentMonth
  const [year, month] = selectedMonth.split('-').map(Number)
  const monthLabel = new Date(Date.UTC(year, month - 1, 1)).toLocaleDateString('en-IN', { month: 'long', year: 'numeric', timeZone: 'UTC' })
  const selectMonth = (value) => {
    if (!/^[1-9]\d{3}-(0[1-9]|1[0-2])$/.test(value)) return
    setSearchParams((current) => {
      const next = new URLSearchParams(current)
      next.set('month', value)
      return next
    })
  }
  const moveMonth = (offset) => {
    const date = new Date(Date.UTC(year, month - 1 + offset, 1))
    selectMonth(`${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}`)
  }
  const [salaries, setSalaries] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  const fetchSalaries = async () => {
    try {
      setLoading(true)
      setError(null)
      const res = await api.get('/salaries')
      const payload = res.data
      const list = Array.isArray(payload) ? payload : payload?.data || payload?.salaries || []
      setSalaries(Array.isArray(list) ? list : [])
    } catch (err) {
      setError(err.message || 'Error fetching salaries')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchSalaries()
  }, [])

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to delete this salary record?')) return
    try {
      await api.delete(`/salaries/${id}`)
      fetchSalaries()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Error deleting salary record')
    }
  }

  const handleStatusToggle = async (salary) => {
    const newStatus = salary.status === 'Paid' ? 'Unpaid' : 'Paid'
    try {
      await api.put(`/salaries/${salary._id}`, { ...salary, status: newStatus })
      fetchSalaries()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Error updating status')
    }
  }

  const monthlySalaries = salaries.filter((salary) => Number(salary.month) === month && Number(salary.year) === year)

  return (
    <div className='p-4 md:p-8'>
      <div className='flex flex-wrap items-center justify-between gap-4 mb-6'>
        <div>
          <h1 className='text-2xl font-bold text-gray-900'>Salaries</h1>
          <p className='text-gray-600 mt-1 text-sm'>Manage employee salary records and payment status.</p>
        </div>
        <button
          onClick={() => navigate('/add-salary')}
          className='bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 text-sm'
        >
          Add Salary
        </button>
      </div>

      <div className='mb-5 flex flex-wrap items-end justify-between gap-4 rounded-lg border border-gray-200 bg-white p-4'>
        <div className='flex flex-wrap items-end gap-2'>
          <button type='button' aria-label='Previous salary month' onClick={() => moveMonth(-1)} className='min-h-11 rounded-md border border-gray-300 px-3 text-sm hover:bg-gray-50'>Previous</button>
          <label className='text-sm font-medium text-gray-700'>Salary month
            <input type='month' min='1000-01' max='9999-12' value={selectedMonth} onChange={(e) => selectMonth(e.target.value)} className='mt-1 block min-h-11 rounded-md border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500' />
          </label>
          <button type='button' aria-label='Next salary month' onClick={() => moveMonth(1)} className='min-h-11 rounded-md border border-gray-300 px-3 text-sm hover:bg-gray-50'>Next</button>
          <button type='button' onClick={() => selectMonth(currentMonth)} className='min-h-11 rounded-md px-3 text-sm font-medium text-blue-700 hover:bg-blue-50'>This month</button>
        </div>
        <p aria-live='polite' className='text-sm text-gray-600'>{monthLabel}{!loading && !error ? ` · ${monthlySalaries.length} salary records` : ''}</p>
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
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Employee</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Gross Salary</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Net Salary</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Monthly CTC</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Month</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Year</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Status</th>
                <th className='px-4 py-3 text-left border-b bg-blue-600 text-white font-bold text-sm text-center'>Actions</th>
              </tr>
            </thead>
            <tbody>
              {monthlySalaries.length === 0 ? (
                <tr>
                  <td colSpan={8} className='px-4 py-12 text-center text-gray-500'>
                    No salary records for {monthLabel}
                  </td>
                </tr>
              ) : (
                monthlySalaries.map((s) => (
                  <tr key={s._id} className='border-b hover:bg-gray-50'>
                    <td className='px-4 py-3 font-medium'>{s.employee?.name || '—'}</td>
                    <td className='px-4 py-3 font-semibold'>₹{Number(s.grossSalary || s.amount || 0).toLocaleString('en-IN')}</td>
                    <td className='px-4 py-3 text-green-700 font-medium'>₹{Number(s.netSalary || (s.amount ? s.amount - 2000 : 0)).toLocaleString('en-IN')}</td>
                    <td className='px-4 py-3 text-blue-700 font-medium'>₹{Number(s.employee?.salaryPayroll?.monthlyCTC || s.employee?.salaryPayroll?.ctc || s.employee?.salary || s.monthlyCTC || (s.amount ? s.amount + 1800 : 0)).toLocaleString('en-IN')}</td>
                    <td className='px-4 py-3'>{s.month ? MONTH_NAMES[s.month] : '—'}</td>
                    <td className='px-4 py-3'>{s.year ?? '—'}</td>
                    <td className='px-4 py-3'>
                      <span className={`px-2 py-1 rounded-full text-xs font-semibold ${
                        (s.status || 'Unpaid') === 'Paid' ? 'bg-green-100 text-green-800' : 'bg-amber-100 text-amber-800'
                      }`}>
                        {s.status || 'Unpaid'}
                      </span>
                    </td>
                    <td className='px-4 py-3'>
                      <div className='flex items-center gap-2'>
                        <button
                          onClick={() => handleStatusToggle(s)}
                          className='px-2 py-1 rounded-lg border border-gray-300 text-xs font-medium hover:bg-gray-50'
                        >
                          Mark {s.status === 'Paid' ? 'Unpaid' : 'Paid'}
                        </button>
                        {s.status === 'Paid' && (
                          <button
                            onClick={() => {
                              const employeeId = s.employee?._id || s.employee
                              const qs = new URLSearchParams({
                                salaryId: String(s._id),
                                ...(employeeId ? { employeeId: String(employeeId) } : {}),
                              })
                              navigate(`/salary-slips?${qs.toString()}`)
                            }}
                            className='px-2 py-1 rounded-lg bg-blue-50 text-blue-600 border border-blue-200 text-xs font-medium hover:bg-blue-100'
                          >
                            View Slip
                          </button>
                        )}
                        <button
                          onClick={() => handleDelete(s._id)}
                          className='p-1.5 rounded-lg text-red-600 hover:bg-red-50 transition-colors'
                          title='Delete'
                        >
                          <DeleteIcon />
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

export default SalariesView
