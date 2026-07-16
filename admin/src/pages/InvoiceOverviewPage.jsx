import React, { useEffect, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import html2canvas from 'html2canvas'
import jsPDF from 'jspdf'
import api from '../api/axios'

const formatINR = (num) => {
  if (num == null || num === '' || isNaN(num)) return '—'
  const n = Number(num)
  const s = Math.round(Math.abs(n)).toString()
  const len = s.length
  if (len <= 3) return `₹${n < 0 ? '-' : ''}${s}`
  const last = s.slice(-3)
  const rest = s.slice(0, -3)
  const withCommas = rest.replace(/\B(?=(\d{2})+(?!\d))/g, ',') + ',' + last
  return `₹${n < 0 ? '-' : ''}${withCommas}`
}

const getFYDisplay = (dateStr) => {
  const d = dateStr ? new Date(dateStr) : new Date()
  const y = d.getFullYear()
  const m = d.getMonth()
  const endYear = m >= 3 ? y + 1 : y
  const startYear = endYear - 1
  return `${startYear}-${String(endYear).slice(-2)}`
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

const InvoiceOverviewPage = () => {
  const { tenantId, invoiceId } = useParams()
  const navigate = useNavigate()
  const printRef = useRef(null)
  const invoiceRef = useRef(null)
  const [billing, setBilling] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [downloading, setDownloading] = useState(false)
  const [downloadError, setDownloadError] = useState(null)

  const invoicesPath = `/company/${tenantId}/invoices`

  useEffect(() => {
    const load = async () => {
      if (!tenantId || !invoiceId) return
      try {
        setLoading(true)
        setError('')
        const res = await api.get(`/companies/${tenantId}/invoices/${invoiceId}`)
        setBilling(res.data?.invoice || null)
      } catch (err) {
        setError(err.response?.data?.message || err.message || 'Failed to load invoice')
        setBilling(null)
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [tenantId, invoiceId])

  const handlePrint = () => window.print()

  const handleDownload = async () => {
    const element = invoiceRef.current || printRef.current
    if (!element) return
    setDownloading(true)
    setDownloadError(null)
    try {
      let strippedLinkedCss = ''
      const links = document.querySelectorAll('link[rel="stylesheet"]')
      if (links.length > 0) {
        const hrefs = Array.from(links).map((l) => l.href).filter(Boolean)
        const texts = await Promise.all(hrefs.map((h) => fetch(h).then((r) => r.text()).catch(() => '')))
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
            if (style.textContent) style.textContent = stripUnsupportedColors(style.textContent)
          })
          clonedDoc.querySelectorAll('link[rel="stylesheet"]').forEach((l) => l.remove())
          if (strippedLinkedCss) {
            const style = clonedDoc.createElement('style')
            style.textContent = strippedLinkedCss
            clonedDoc.head.appendChild(style)
          }
          clonedElement.querySelectorAll('[style]').forEach((el) => {
            const s = el.getAttribute('style')
            if (s && /oklch/i.test(s)) el.setAttribute('style', stripUnsupportedColors(s))
          })
        },
      })

      const imgWidth = 210
      const pageHeight = 297
      const imgHeight = (canvas.height * imgWidth) / canvas.width
      let heightLeft = imgHeight
      let position = 0
      const pdf = new jsPDF('p', 'mm', 'a4')
      const imgData = canvas.toDataURL('image/jpeg', 0.95)
      if (heightLeft <= pageHeight) {
        pdf.addImage(imgData, 'JPEG', 0, position, imgWidth, imgHeight)
      } else {
        while (heightLeft > 0) {
          pdf.addImage(imgData, 'JPEG', 0, position, imgWidth, imgHeight)
          heightLeft -= pageHeight
          position = heightLeft - imgHeight
          if (heightLeft > 0) pdf.addPage()
        }
      }
      const filename = `invoice-${(billing?.company?.name || 'bill').replace(/\s+/g, '-')}-${invoiceId}.pdf`
      pdf.save(filename)
    } catch (err) {
      setDownloadError(err?.message || 'Download failed. Try Print then Save as PDF.')
    } finally {
      setDownloading(false)
    }
  }

  if (loading) {
    return <div className='min-h-screen bg-white p-8 text-center text-gray-600'>Loading invoice…</div>
  }

  if (error || !billing) {
    return (
      <div className='min-h-screen bg-white p-8 text-center'>
        <p className='text-red-600'>{error || 'Invoice not found'}</p>
        <button
          type='button'
          onClick={() => navigate(invoicesPath)}
          className='mt-4 text-blue-600 text-sm font-medium'
        >
          Back to Invoices
        </button>
      </div>
    )
  }

  const isGst = billing.billType === 'GST'
  const company = billing.company || {}
  const client = billing.client || {}
  const payment = billing.paymentDetails || {}
  const projects = billing.projects || []
  const invoiceAmount = payment.amount != null ? Number(payment.amount) : null
  const taxableValue = invoiceAmount != null && isGst ? invoiceAmount / 1.18 : null
  const cgstAmount = taxableValue != null ? taxableValue * 0.09 : null
  const sgstAmount = taxableValue != null ? taxableValue * 0.09 : null

  return (
    <div className='min-h-screen bg-white'>
      <div className='print:hidden sticky top-0 z-10 bg-gray-100 border-b border-gray-200 px-4 py-3 flex items-center justify-between'>
        <button
          type='button'
          onClick={() => navigate(invoicesPath)}
          className='text-gray-700 hover:text-gray-900 text-sm font-medium'
        >
          ← Back to Invoices
        </button>
        <div className='flex gap-2'>
          <button
            type='button'
            onClick={handlePrint}
            className='bg-gray-700 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-gray-800 inline-flex items-center gap-2'
          >
            Print
          </button>
          <button
            type='button'
            onClick={handleDownload}
            disabled={downloading}
            className='bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700 disabled:opacity-50 inline-flex items-center gap-2'
          >
            {downloading ? 'Downloading...' : 'Download PDF'}
          </button>
        </div>
      </div>

      {downloadError && (
        <div className='print:hidden mx-4 mt-2 rounded-lg bg-amber-50 border border-amber-200 px-3 py-2'>
          <p className='text-amber-800 text-sm'>{downloadError}</p>
        </div>
      )}

      <div ref={printRef} className='p-6 md:p-10 w-full'>
        <div ref={invoiceRef} className='border border-gray-200 rounded-lg overflow-hidden bg-white'>
          {billing.companyLogo && (
            <div className='flex justify-center pt-6 pb-2'>
              <img
                src={billing.companyLogo}
                alt='Company logo'
                className='h-20 w-auto max-w-[200px] object-contain'
              />
            </div>
          )}

          <div className='px-6 py-4 border-b border-gray-200'>
            <div className='flex flex-wrap items-baseline justify-between gap-4'>
              <div>
                <h1 className='text-2xl font-bold text-black'>INVOICE</h1>
                <p className='text-sm text-black mt-1'>
                  {isGst ? 'Tax Invoice (GST)' : 'Bill (Non-GST)'} •{' '}
                  {billing.createdAt ? new Date(billing.createdAt).toLocaleDateString() : '—'}
                </p>
              </div>
              <div className='text-right'>
                <p className='text-sm text-black'>
                  <span className='font-semibold'>Invoice No:</span>{' '}
                  {billing.invoiceNumber || `Gamo-${getFYDisplay(billing.createdAt)}-001`}
                </p>
                <p className='text-sm text-black mt-0.5'>
                  <span className='font-semibold'>Financial Year:</span> {getFYDisplay(billing.createdAt)}
                </p>
              </div>
            </div>
          </div>

          <div className='p-6 grid grid-cols-1 md:grid-cols-2 gap-8'>
            <div>
              <h2 className='text-xs font-semibold text-black uppercase tracking-wider mb-2'>From</h2>
              <p className='font-semibold text-black'>{company.name || '—'}</p>
              {company.address && <p className='text-sm text-black mt-1'>{company.address}</p>}
              {company.email && <p className='text-sm text-black'>{company.email}</p>}
              {company.phone && <p className='text-sm text-black'>{company.phone}</p>}
              {company.pan && <p className='text-sm text-black'>PAN: {company.pan}</p>}
              {company.website && <p className='text-sm text-black'>Website: {company.website}</p>}
              {isGst && billing.companyGst?.gstin && (
                <p className='text-sm text-black mt-2'>
                  GSTIN: {billing.companyGst.gstin}
                  {billing.companyGst.state &&
                    ` • State: ${billing.companyGst.state} (${billing.companyGst.stateCode || ''})`}
                </p>
              )}
            </div>

            <div>
              <h2 className='text-xs font-semibold text-black uppercase tracking-wider mb-2'>Bill To</h2>
              <p className='font-semibold text-black'>{client.clientName || '—'}</p>
              {client.address && <p className='text-sm text-black mt-1'>{client.address}</p>}
              {client.mailId && <p className='text-sm text-black'>{client.mailId}</p>}
              {client.clientNumber && <p className='text-sm text-black'>{client.clientNumber}</p>}
              {isGst && (billing.clientGst?.gstin || billing.clientGst?.billingAddress) && (
                <div className='mt-2 text-sm text-black'>
                  {billing.clientGst.gstin && <p>GSTIN: {billing.clientGst.gstin}</p>}
                  {billing.clientGst.state && <p>State: {billing.clientGst.state}</p>}
                  {billing.clientGst.billingAddress && <p>{billing.clientGst.billingAddress}</p>}
                </div>
              )}
            </div>
          </div>

          <div className='px-6 pb-6'>
            <h2 className='text-xs font-semibold text-black uppercase tracking-wider mb-3'>Project Details</h2>
            <table className='w-full text-sm border border-gray-400'>
              <thead>
                <tr className='border-b border-gray-400'>
                  <th className='text-left py-2 px-3 font-semibold text-black'>#</th>
                  <th className='text-left py-2 px-3 font-semibold text-black'>Project</th>
                  <th className='text-right py-2 px-3 font-semibold text-black'>Project Cost</th>
                  <th className='text-right py-2 px-3 font-semibold text-black'>Amount Paid</th>
                </tr>
              </thead>
              <tbody>
                {projects.length === 0 ? (
                  <tr>
                    <td colSpan={4} className='py-4 px-3 text-center text-black'>
                      No projects
                    </td>
                  </tr>
                ) : (
                  projects.map((item, i) => {
                    const cost = Number(item.projectCost) || 0
                    const rem = Number(item.remainingCost) || 0
                    const paid = cost - rem
                    return (
                      <tr key={i} className='border-b border-gray-300'>
                        <td className='py-2 px-3 text-black'>{i + 1}</td>
                        <td className='py-2 px-3 text-black'>{item.project?.projectName || '—'}</td>
                        <td className='py-2 px-3 text-right text-black'>{formatINR(item.projectCost)}</td>
                        <td className='py-2 px-3 text-right text-black'>{formatINR(paid)}</td>
                      </tr>
                    )
                  })
                )}
              </tbody>
            </table>

            {projects.length > 0 &&
              (() => {
                const totalProjectCost = projects.reduce((s, p) => s + (Number(p.projectCost) || 0), 0)
                const totalRemaining = projects.reduce((s, p) => s + (Number(p.remainingCost) || 0), 0)
                const amountPaid = totalProjectCost - totalRemaining
                return (
                  <div className='mt-3 pt-3 border-t border-gray-400 flex flex-wrap gap-6 text-sm'>
                    <span className='text-black'>
                      <span className='font-semibold'>Total Project Cost:</span> {formatINR(totalProjectCost)}
                    </span>
                    <span className='text-black'>
                      <span className='font-semibold'>Amount (this payment):</span> {formatINR(amountPaid)}
                    </span>
                  </div>
                )
              })()}

            {billing.tracking && billing.tracking.length > 0 && (
              <div className='mt-4 pt-4 border-t border-gray-400'>
                <h3 className='text-xs font-semibold text-black uppercase tracking-wider mb-2'>
                  Payment tracking (all bills for this client)
                </h3>
                <table className='w-full text-sm border border-gray-400'>
                  <thead>
                    <tr className='border-b border-gray-400'>
                      <th className='text-left py-2 px-3 font-semibold text-black'>Project</th>
                      <th className='text-right py-2 px-3 font-semibold text-black'>Project Cost</th>
                      <th className='text-right py-2 px-3 font-semibold text-black'>Total Paid</th>
                      <th className='text-right py-2 px-3 font-semibold text-black'>Remaining</th>
                    </tr>
                  </thead>
                  <tbody>
                    {billing.tracking.map((t, i) => (
                      <tr key={i} className='border-b border-gray-300'>
                        <td className='py-2 px-3 text-black'>{t.project?.projectName || '—'}</td>
                        <td className='py-2 px-3 text-right text-black'>{formatINR(t.projectCost)}</td>
                        <td className='py-2 px-3 text-right text-black'>{formatINR(t.totalPaid)}</td>
                        <td className='py-2 px-3 text-right text-black font-medium'>{formatINR(t.remaining)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>

          {isGst && (taxableValue != null || invoiceAmount != null) && (
            <div className='px-6 pb-4'>
              <h2 className='text-xs font-semibold text-black uppercase tracking-wider mb-2'>GST Breakdown</h2>
              <table className='w-full max-w-xs text-sm border border-gray-400'>
                <tbody>
                  {taxableValue != null && (
                    <tr className='border-b border-gray-300'>
                      <td className='py-1.5 px-3 text-black'>Taxable Value</td>
                      <td className='py-1.5 px-3 text-right text-black'>
                        {formatINR(taxableValue).replace('₹', '')}
                      </td>
                    </tr>
                  )}
                  {cgstAmount != null && (
                    <tr className='border-b border-gray-300'>
                      <td className='py-1.5 px-3 text-black'>CGST @ 9%</td>
                      <td className='py-1.5 px-3 text-right text-black'>
                        {formatINR(cgstAmount).replace('₹', '')}
                      </td>
                    </tr>
                  )}
                  {sgstAmount != null && (
                    <tr className='border-b border-gray-300'>
                      <td className='py-1.5 px-3 text-black'>SGST @ 9%</td>
                      <td className='py-1.5 px-3 text-right text-black'>
                        {formatINR(sgstAmount).replace('₹', '')}
                      </td>
                    </tr>
                  )}
                  {invoiceAmount != null && (
                    <tr>
                      <td className='py-1.5 px-3 text-black font-semibold'>Total</td>
                      <td className='py-1.5 px-3 text-right text-black font-semibold'>
                        {formatINR(invoiceAmount).replace('₹', '')}
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          )}

          <div className='px-6 pb-6'>
            <h2 className='text-xs font-semibold text-black uppercase tracking-wider mb-3'>Payment Details</h2>
            <div className='space-y-1 text-sm'>
              {payment.paymentDate && (
                <p className='text-black'>
                  <span className='font-medium'>Payment Date:</span>{' '}
                  {new Date(payment.paymentDate).toLocaleDateString('en-IN', {
                    day: 'numeric',
                    month: 'short',
                    year: 'numeric',
                  })}
                </p>
              )}
              {payment.amount != null && (
                <p className='text-lg font-bold text-black'>Amount: {formatINR(payment.amount)}</p>
              )}
              {payment.receiverName && (
                <p className='text-black'>
                  <span className='font-medium'>Receiver:</span> {payment.receiverName}
                </p>
              )}
              {payment.receiverBankName && (
                <p className='text-black'>
                  <span className='font-medium'>Bank:</span> {payment.receiverBankName}
                </p>
              )}
              {payment.receiverBankAccount && (
                <p className='text-black'>
                  <span className='font-medium'>Account:</span> {payment.receiverBankAccount}
                </p>
              )}
              {payment.modeOfTransaction && (
                <p className='text-black'>
                  <span className='font-medium'>Mode:</span> {payment.modeOfTransaction}
                </p>
              )}
            </div>
          </div>

          {billing.termsAndConditions && (
            <div className='px-6 pb-4'>
              <h2 className='text-xs font-semibold text-black uppercase tracking-wider mb-2'>
                Terms & Conditions
              </h2>
              <p className='text-sm text-black whitespace-pre-wrap'>{billing.termsAndConditions}</p>
            </div>
          )}

          <div className='px-6 pb-6 flex justify-end'>
            <div className='text-center'>
              {billing.authorizedSignature ? (
                <>
                  <img
                    src={billing.authorizedSignature}
                    alt='Authorized Signature'
                    className='h-16 max-w-[220px] object-contain mx-auto'
                  />
                  <p className='text-sm font-semibold text-black mt-1'>Authorized Signature</p>
                </>
              ) : (
                <>
                  <div className='border-t-2 border-black w-40 mt-8 mb-1' />
                  <p className='text-sm font-semibold text-black'>Authorized Signature</p>
                </>
              )}
            </div>
          </div>

          <div className='px-6 py-4 border-t border-gray-300 text-center text-sm text-black font-medium'>
            Thank you for your business.
          </div>
        </div>
      </div>
    </div>
  )
}

export default InvoiceOverviewPage
