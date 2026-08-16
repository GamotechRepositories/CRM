import React, { useEffect, useState, useRef } from 'react'
import api from '../api/axios'
import { useAuth } from '../context/AuthContext'
import html2canvas from 'html2canvas'
import jsPDF from 'jspdf'

const MONTH_NAMES = [
  '', 'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
]

const SalarySlipPage = () => {
  const { user } = useAuth()
  const printRef = useRef(null)
  const slipRef = useRef(null)

  const [company, setCompany] = useState(null)
  const [salaries, setSalaries] = useState([])
  const [selectedSalary, setSelectedSalary] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [downloading, setDownloading] = useState(false)
  const [downloadError, setDownloadError] = useState(null)

  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true)
        // Fetch Company Profile
        const compRes = await api.get('/company-profile').catch(() => ({ data: {} }))
        setCompany(compRes.data || {})

        // Fetch Salaries for logged in employee (or all if admin)
        const empId = user?._id || user?.id
        const endpoint = empId ? `/salaries?employee=${empId}` : '/salaries'
        const salRes = await api.get(endpoint).catch(() => ({ data: [] }))
        const list = Array.isArray(salRes.data)
          ? salRes.data
          : salRes.data?.data || salRes.data?.salaries || []
        
        const sorted = (Array.isArray(list) ? list : []).sort((a, b) => {
          if (b.year !== a.year) return b.year - a.year
          return b.month - a.month
        })
        
        setSalaries(sorted)
        // Auto-select first paid salary if available
        const firstPaid = sorted.find((s) => s.status === 'Paid')
        if (firstPaid) setSelectedSalary(firstPaid)
        else if (sorted.length > 0) setSelectedSalary(sorted[0])
      } catch (err) {
        setError(err.response?.data?.message || err.message || 'Error loading salary slips')
      } finally {
        setLoading(false)
      }
    }

    fetchData()
  }, [user])

  const handlePrint = () => {
    window.print()
  }

  const stripUnsupportedColors = (cssText) => {
    if (!cssText || typeof cssText !== 'string') return cssText
    let out = cssText
    const replaceParenFunc = (name, replacement) => {
      const re = new RegExp(name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '\\s*\\(', 'gi')
      let match
      while ((match = re.exec(out)) !== null) {
        const idx = match.index
        const start = out.indexOf('(', idx)
        let depth = 1
        let end = start + 1
        while (depth > 0 && end < out.length) {
          if (out[end] === '(') depth++
          else if (out[end] === ')') depth--
          end++
        }
        out = out.slice(0, idx) + replacement + out.slice(end)
        re.lastIndex = 0
      }
    }
    replaceParenFunc('oklch', 'rgb(128,128,128)')
    replaceParenFunc('oklab', 'rgb(128,128,128)')
    replaceParenFunc('color-mix', 'rgb(128,128,128)')
    return out
  }

  const handleDownload = async () => {
    const element = slipRef.current || printRef.current
    if (!element) return
    setDownloading(true)
    setDownloadError(null)
    try {
      let strippedLinkedCss = ''
      const links = document.querySelectorAll('link[rel="stylesheet"]')
      if (links.length > 0) {
        const hrefs = Array.from(links).map((l) => l.href).filter(Boolean)
        const texts = await Promise.all(
          hrefs.map((h) => fetch(h).then((r) => r.text()).catch(() => ''))
        )
        strippedLinkedCss = texts.map(stripUnsupportedColors).join('\n')
      }

      const canvas = await html2canvas(element, {
        scale: 2,
        useCORS: true,
        allowTaint: true,
        backgroundColor: '#ffffff',
        logging: false,
        onclone: (clonedDoc, clonedElement) => {
          clonedDoc.querySelectorAll('style').forEach((style) => {
            if (style.textContent) {
              style.textContent = stripUnsupportedColors(style.textContent)
            }
          })
          clonedDoc.querySelectorAll('link[rel="stylesheet"]').forEach((l) => l.remove())
          if (strippedLinkedCss) {
            const style = clonedDoc.createElement('style')
            style.textContent = strippedLinkedCss
            clonedDoc.head.appendChild(style)
          }
          clonedElement.querySelectorAll('[style]').forEach((el) => {
            const s = el.getAttribute('style')
            if (s && /oklch/i.test(s)) {
              el.setAttribute('style', stripUnsupportedColors(s))
            }
          })
        },
      })

      const imgWidth = 210
      const pageHeight = 297
      const imgHeight = (canvas.height * imgWidth) / canvas.width
      const pdf = new jsPDF('p', 'mm', 'a4')
      const imgData = canvas.toDataURL('image/jpeg', 0.95)

      pdf.addImage(imgData, 'JPEG', 0, 0, imgWidth, Math.min(imgHeight, pageHeight))
      const empName = selectedSalary?.employee?.name || user?.name || 'Employee'
      const monthLabel = MONTH_NAMES[selectedSalary?.month] || 'Salary'
      const filename = `SalarySlip-${empName.replace(/\s+/g, '_')}-${monthLabel}_${selectedSalary?.year}.pdf`
      pdf.save(filename)
    } catch (err) {
      console.error('Salary slip PDF download failed:', err)
      setDownloadError(err?.message || 'Download failed. Try Print then Save as PDF.')
    } finally {
      setDownloading(false)
    }
  }

  const formatINR = (num) => {
    if (num == null || num === '' || isNaN(num)) return '₹0'
    const n = Number(num)
    return `₹${Math.round(n).toLocaleString('en-IN')}`
  }

  if (loading) {
    return <div className='p-8 text-sm text-gray-600'>Loading salary slips...</div>
  }

  const emp = selectedSalary?.employee || user || {}
  const isPaid = selectedSalary?.status === 'Paid'
  const totalNet = Number(selectedSalary?.amount || selectedSalary?.netSalary || 0)
  
  // Breakdown
  const basic = selectedSalary?.basicSalary || Math.round(totalNet * 0.50)
  const hra = selectedSalary?.hra || Math.round(totalNet * 0.30)
  const allowances = selectedSalary?.allowances || Math.round(totalNet * 0.20)
  const bonus = selectedSalary?.bonus || 0
  const totalEarnings = basic + hra + allowances + bonus
  const deductions = selectedSalary?.deductions || 0
  const netPayable = selectedSalary?.netSalary || (totalEarnings - deductions)

  return (
    <div className='p-4 md:p-8 bg-gray-50 min-h-full'>
      <div className='max-w-6xl mx-auto'>
        {/* Header */}
        <div className='mb-6 print:hidden'>
          <nav className='text-sm text-gray-500 mb-2'>
            <span className='text-gray-900 font-medium'>My Workspace</span>
            <span className='mx-2 text-gray-300'>›</span>
            <span className='text-gray-900 font-medium'>Salary Slips</span>
          </nav>
          <h1 className='text-2xl font-bold text-gray-900'>Salary Slips</h1>
          <p className='text-sm text-gray-500 mt-1'>
            View and download your monthly salary slips once approved and marked as paid by HR.
          </p>
        </div>

        {error && (
          <div className='mb-6 p-4 bg-red-50 border border-red-200 rounded-xl text-red-700 text-sm print:hidden'>
            {error}
          </div>
        )}

        <div className='grid grid-cols-1 lg:grid-cols-12 gap-6'>
          {/* Left Column: Month Selector List */}
          <div className='lg:col-span-4 print:hidden space-y-4'>
            <div className='bg-white rounded-xl shadow-sm border border-gray-200 p-5'>
              <h2 className='text-base font-semibold text-gray-800 mb-3'>Payment Records</h2>
              {salaries.length === 0 ? (
                <p className='text-sm text-gray-500 py-4 text-center'>No salary records found.</p>
              ) : (
                <div className='space-y-2 max-h-[500px] overflow-y-auto pr-1'>
                  {salaries.map((s) => {
                    const isSelected = selectedSalary?._id === s._id
                    const sPaid = s.status === 'Paid'
                    return (
                      <button
                        key={s._id}
                        onClick={() => setSelectedSalary(s)}
                        className={`w-full text-left p-3.5 rounded-xl border transition-all flex items-center justify-between ${
                          isSelected
                            ? 'border-blue-600 bg-blue-50/60 ring-1 ring-blue-600'
                            : 'border-gray-200 hover:border-gray-300 bg-white'
                        }`}
                      >
                        <div>
                          <p className='font-semibold text-gray-900 text-sm'>
                            {MONTH_NAMES[s.month]} {s.year}
                          </p>
                          <p className='text-xs text-gray-500 mt-0.5'>
                            {s.employee?.name || user?.name || 'Employee'}
                          </p>
                          <p className='text-sm font-bold text-gray-800 mt-1'>
                            {formatINR(s.amount)}
                          </p>
                        </div>
                        <div className='text-right'>
                          <span
                            className={`inline-block px-2.5 py-1 rounded-full text-xs font-semibold ${
                              sPaid
                                ? 'bg-green-100 text-green-800'
                                : 'bg-amber-100 text-amber-800'
                            }`}
                          >
                            {s.status || 'Unpaid'}
                          </span>
                        </div>
                      </button>
                    )
                  })}
                </div>
              )}
            </div>
          </div>

          {/* Right Column: Salary Slip Preview & Download */}
          <div className='lg:col-span-8'>
            {!selectedSalary ? (
              <div className='bg-white rounded-xl shadow-sm border border-gray-200 p-12 text-center text-gray-500 print:hidden'>
                Select a salary record to view the salary slip.
              </div>
            ) : !isPaid ? (
              <div className='bg-amber-50 border border-amber-200 rounded-xl p-8 text-center print:hidden'>
                <div className='w-12 h-12 bg-amber-100 rounded-full flex items-center justify-center mx-auto mb-3 text-amber-700 text-xl font-bold'>
                  ⏳
                </div>
                <h3 className='text-lg font-semibold text-amber-900'>Salary Payment Pending</h3>
                <p className='text-sm text-amber-700 mt-1 max-w-md mx-auto'>
                  Your salary slip for {MONTH_NAMES[selectedSalary.month]} {selectedSalary.year} will become available for view and download once HR marks the payment status as <strong>Paid</strong>.
                </p>
              </div>
            ) : (
              <div>
                {/* Actions Toolbar */}
                <div className='print:hidden bg-white border border-gray-200 rounded-xl p-4 mb-4 flex flex-wrap items-center justify-between gap-3 shadow-sm'>
                  <div>
                    <h3 className='font-semibold text-gray-900 text-sm'>
                      Salary Slip — {MONTH_NAMES[selectedSalary.month]} {selectedSalary.year}
                    </h3>
                    <p className='text-xs text-green-700 font-medium mt-0.5 flex items-center gap-1'>
                      <span>✓</span> Status: Paid
                    </p>
                  </div>
                  <div className='flex gap-2'>
                    <button
                      onClick={handlePrint}
                      className='bg-gray-700 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-gray-800 flex items-center gap-1.5'
                    >
                      <span>🖨</span> Print
                    </button>
                    <button
                      onClick={handleDownload}
                      disabled={downloading}
                      className='bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700 disabled:opacity-50 flex items-center gap-1.5'
                    >
                      <span>📥</span> {downloading ? 'Downloading...' : 'Download PDF'}
                    </button>
                  </div>
                </div>

                {downloadError && (
                  <div className='print:hidden mb-4 rounded-lg bg-amber-50 border border-amber-200 px-3 py-2 text-xs text-amber-800'>
                    {downloadError}
                  </div>
                )}

                {/* Printable Salary Slip Container */}
                <div ref={printRef} className='bg-white border border-gray-300 rounded-xl shadow-md overflow-hidden p-6 md:p-10 text-black'>
                  <div ref={slipRef} className='space-y-6'>
                    {/* Header: Company Info */}
                    <div className='border-b border-gray-300 pb-6 flex flex-wrap items-center justify-between gap-4'>
                      <div>
                        {company?.companyLogo && (
                          <img
                            src={company.companyLogo}
                            alt='Company Logo'
                            className='h-14 w-auto max-w-[180px] object-contain mb-2'
                          />
                        )}
                        <h2 className='text-xl font-bold text-black uppercase tracking-wide'>
                          {company?.companyName || 'Organization Name'}
                        </h2>
                        {company?.address && <p className='text-xs text-gray-700 mt-1 max-w-sm'>{company.address}</p>}
                        <div className='text-xs text-gray-600 mt-1 space-x-3'>
                          {company?.email && <span>Email: {company.email}</span>}
                          {company?.phone && <span>Phone: {company.phone}</span>}
                        </div>
                        {company?.gstin && <p className='text-xs text-gray-600'>GSTIN: {company.gstin}</p>}
                        {company?.pan && <p className='text-xs text-gray-600'>PAN: {company.pan}</p>}
                      </div>
                      <div className='text-right border-l-2 border-blue-600 pl-4 py-1'>
                        <span className='text-xs font-semibold text-blue-600 uppercase tracking-widest block'>Official Document</span>
                        <h3 className='text-lg font-bold text-gray-900 mt-0.5'>PAYSLIP</h3>
                        <p className='text-xs font-medium text-gray-600 mt-0.5'>
                          {MONTH_NAMES[selectedSalary.month]} {selectedSalary.year}
                        </p>
                      </div>
                    </div>

                    {/* Employee & Payment Meta Grid */}
                    <div className='bg-gray-50/80 rounded-lg p-4 border border-gray-200 text-xs grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4'>
                      <div>
                        <span className='text-gray-500 font-medium block'>Employee Name</span>
                        <span className='font-bold text-gray-900 text-sm'>{emp.name || user?.name || '—'}</span>
                      </div>
                      <div>
                        <span className='text-gray-500 font-medium block'>Employee Code / ID</span>
                        <span className='font-semibold text-gray-800'>{emp.employeeCode || emp._id || emp.id || '—'}</span>
                      </div>
                      <div>
                        <span className='text-gray-500 font-medium block'>Designation</span>
                        <span className='font-semibold text-gray-800'>{emp.designation?.title || emp.designation || '—'}</span>
                      </div>
                      <div>
                        <span className='text-gray-500 font-medium block'>Department</span>
                        <span className='font-semibold text-gray-800'>{emp.department || '—'}</span>
                      </div>
                      <div>
                        <span className='text-gray-500 font-medium block'>Date of Joining</span>
                        <span className='font-semibold text-gray-800'>
                          {emp.dateOfJoining ? new Date(emp.dateOfJoining).toLocaleDateString('en-IN') : '—'}
                        </span>
                      </div>
                      <div>
                        <span className='text-gray-500 font-medium block'>Bank Account Details</span>
                        <span className='font-semibold text-gray-800'>{emp.salaryPayroll?.bankAccountDetails || emp.bankAccountNumber || '—'}</span>
                      </div>
                      <div>
                        <span className='text-gray-500 font-medium block'>Payment Method</span>
                        <span className='font-semibold text-gray-800'>{selectedSalary.paymentMode || 'Bank Transfer'}</span>
                      </div>
                      <div>
                        <span className='text-gray-500 font-medium block'>Payment Status</span>
                        <span className='font-bold text-green-700 uppercase'>PAID</span>
                      </div>
                      <div>
                        <span className='text-gray-500 font-medium block'>Payment Date</span>
                        <span className='font-semibold text-gray-800'>
                          {selectedSalary.paymentDate
                            ? new Date(selectedSalary.paymentDate).toLocaleDateString('en-IN')
                            : new Date(selectedSalary.updatedAt || Date.now()).toLocaleDateString('en-IN')}
                        </span>
                      </div>
                    </div>

                    {/* Earnings & Deductions Table */}
                    <div>
                      <h4 className='text-xs font-bold text-gray-800 uppercase tracking-wider mb-2'>Salary Breakdown</h4>
                      <table className='w-full text-xs border border-gray-300 rounded-lg overflow-hidden'>
                        <thead>
                          <tr className='bg-gray-100 border-b border-gray-300 font-bold text-gray-800'>
                            <th className='py-2.5 px-3 text-left w-1/2 border-r border-gray-300'>EARNINGS</th>
                            <th className='py-2.5 px-3 text-right border-r border-gray-300'>AMOUNT</th>
                            <th className='py-2.5 px-3 text-left w-1/3 border-r border-gray-300'>DEDUCTIONS</th>
                            <th className='py-2.5 px-3 text-right'>AMOUNT</th>
                          </tr>
                        </thead>
                        <tbody className='divide-y divide-gray-200'>
                          <tr>
                            <td className='py-2 px-3 border-r border-gray-200'>Basic Salary (50%)</td>
                            <td className='py-2 px-3 text-right border-r border-gray-200 font-medium'>{formatINR(basic)}</td>
                            <td className='py-2 px-3 border-r border-gray-200'>Provident Fund (PF) / TDS</td>
                            <td className='py-2 px-3 text-right font-medium'>{formatINR(deductions)}</td>
                          </tr>
                          <tr>
                            <td className='py-2 px-3 border-r border-gray-200'>House Rent Allowance (HRA 30%)</td>
                            <td className='py-2 px-3 text-right border-r border-gray-200 font-medium'>{formatINR(hra)}</td>
                            <td className='py-2 px-3 border-r border-gray-200'>Other Deductions</td>
                            <td className='py-2 px-3 text-right font-medium'>₹0</td>
                          </tr>
                          <tr>
                            <td className='py-2 px-3 border-r border-gray-200'>Special / Other Allowances (20%)</td>
                            <td className='py-2 px-3 text-right border-r border-gray-200 font-medium'>{formatINR(allowances)}</td>
                            <td className='py-2 px-3 border-r border-gray-200'>—</td>
                            <td className='py-2 px-3 text-right'>—</td>
                          </tr>
                          {bonus > 0 && (
                            <tr>
                              <td className='py-2 px-3 border-r border-gray-200'>Performance Bonus / Incentives</td>
                              <td className='py-2 px-3 text-right border-r border-gray-200 font-medium'>{formatINR(bonus)}</td>
                              <td className='py-2 px-3 border-r border-gray-200'>—</td>
                              <td className='py-2 px-3 text-right'>—</td>
                            </tr>
                          )}
                          <tr className='bg-gray-50 font-bold border-t border-gray-300 text-gray-900'>
                            <td className='py-2.5 px-3 border-r border-gray-300'>GROSS EARNINGS</td>
                            <td className='py-2.5 px-3 text-right border-r border-gray-300'>{formatINR(totalEarnings)}</td>
                            <td className='py-2.5 px-3 border-r border-gray-300'>TOTAL DEDUCTIONS</td>
                            <td className='py-2.5 px-3 text-right'>{formatINR(deductions)}</td>
                          </tr>
                        </tbody>
                      </table>
                    </div>

                    {/* Net Pay Banner */}
                    <div className='bg-blue-50 border border-blue-200 rounded-lg p-4 flex items-center justify-between'>
                      <div>
                        <span className='text-xs font-bold text-blue-900 uppercase tracking-wide block'>Net Salary Payable</span>
                        <span className='text-xs text-blue-700'>Gross Earnings minus Total Deductions</span>
                      </div>
                      <div className='text-right'>
                        <span className='text-xl font-extrabold text-blue-900'>{formatINR(netPayable)}</span>
                      </div>
                    </div>

                    {/* Footer: Stamp & Authorized Signature */}
                    <div className='pt-6 border-t border-gray-200 flex items-end justify-between gap-6'>
                      {/* Stamp Column */}
                      <div className='text-center min-w-[140px]'>
                        {company?.companyStamp ? (
                          <img
                            src={company.companyStamp}
                            alt='Company Stamp'
                            className='h-16 w-auto max-w-[140px] object-contain mx-auto'
                          />
                        ) : (
                          <div className='h-16 flex items-center justify-center text-xs text-gray-400 border border-dashed rounded-lg px-2'>
                            Company Stamp
                          </div>
                        )}
                        <p className='text-xs font-semibold text-gray-700 mt-1'>Company Stamp</p>
                      </div>

                      {/* Disclaimer Note */}
                      <div className='text-center flex-1 text-[11px] text-gray-500 italic max-w-xs mx-auto'>
                        This is a computer-generated payslip issued by {company?.companyName || 'the organization'} and does not require a physical ink signature.
                      </div>

                      {/* Authorized Signature Column */}
                      <div className='text-center min-w-[140px]'>
                        {company?.authorizedSignature ? (
                          <img
                            src={company.authorizedSignature}
                            alt='Authorized Signature'
                            className='h-16 w-auto max-w-[140px] object-contain mx-auto'
                          />
                        ) : (
                          <div className='border-t-2 border-gray-800 w-32 mt-12 mb-1 mx-auto' />
                        )}
                        <p className='text-xs font-semibold text-gray-800 mt-1'>Authorized Signature</p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

export default SalarySlipPage
