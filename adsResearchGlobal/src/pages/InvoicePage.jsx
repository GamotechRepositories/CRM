import React, { useEffect, useState, useRef } from 'react'
import api from '../api/axios'
import { useParams, useNavigate } from 'react-router-dom'
import html2canvas from 'html2canvas'
import jsPDF from 'jspdf'
import companyLogoFallback from '../assets/logo.jpg'

const InvoicePage = () => {
  const { id } = useParams()
  const navigate = useNavigate()
  const printRef = useRef(null)
  const invoiceRef = useRef(null)
  const [billing, setBilling] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [downloading, setDownloading] = useState(false)
  const [downloadError, setDownloadError] = useState(null)
  const [logoSrc, setLogoSrc] = useState(companyLogoFallback)

  const getBackendOrigin = () => {
    const base = api.defaults.baseURL || import.meta.env.VITE_API_URL || 'http://localhost:5014'
    try {
      const u = new URL(base)
      return `${u.protocol}//${u.host}`
    } catch {
      return 'http://localhost:5014'
    }
  }

  useEffect(() => {
    if (!id) return
    const fetchBilling = async () => {
      try {
        const res = await api.get(`/billing/${id}`)
        setBilling(res.data)
      } catch (err) {
        setError(err.response?.data?.message || err.message || 'Failed to load billing')
      } finally {
        setLoading(false)
      }
    }
    fetchBilling()
  }, [id])

  useEffect(() => {
    let isMounted = true

    const loadLogo = async () => {
      const raw = billing?.companyLogo || billing?.company?.companyLogo || companyLogoFallback
      if (!raw) return

      if (typeof raw === 'string' && raw.startsWith('data:image')) {
        if (isMounted) setLogoSrc(raw)
        return
      }

      // If remote URL, fetch via backend proxy to guarantee CORS headers
      let targetUrl = raw
      if (typeof raw === 'string' && raw.startsWith('http')) {
        targetUrl = `${getBackendOrigin()}/api/proxy-image?url=${encodeURIComponent(raw)}`
      }

      try {
        const res = await fetch(targetUrl)
        if (res.ok) {
          const blob = await res.blob()
          const reader = new FileReader()
          reader.onloadend = () => {
            if (isMounted && reader.result) {
              setLogoSrc(reader.result)
            }
          }
          reader.readAsDataURL(blob)
          return
        }
      } catch (err) {
        console.warn('Failed to load logo via proxy, trying fallback:', err)
      }

      // Try local fallback logo as base64
      try {
        const res = await fetch(companyLogoFallback)
        if (res.ok) {
          const blob = await res.blob()
          const reader = new FileReader()
          reader.onloadend = () => {
            if (isMounted && reader.result) {
              setLogoSrc(reader.result)
            }
          }
          reader.readAsDataURL(blob)
        }
      } catch (e) {
        if (isMounted) setLogoSrc(companyLogoFallback)
      }
    }

    loadLogo()
    return () => {
      isMounted = false
    }
  }, [billing])

  const handlePrint = () => {
    window.print()
  }

  /** Replace oklch() and other unsupported color functions so html2canvas can parse CSS */
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
    replaceParenFunc('oklch', 'inherit')
    replaceParenFunc('oklab', 'inherit')
    replaceParenFunc('color-mix', 'inherit')
    return out
  }

  const handleDownload = async () => {
    const element = invoiceRef.current || printRef.current
    if (!element) return
    setDownloading(true)
    setDownloadError(null)
    try {
      // Ensure logo is base64 before capturing so html2canvas never drops it
      let activeLogo = logoSrc
      if (!activeLogo || !activeLogo.startsWith('data:image')) {
        const raw = billing?.companyLogo || billing?.company?.companyLogo || companyLogoFallback
        if (raw && typeof raw === 'string' && raw.startsWith('http')) {
          try {
            const res = await fetch(`${getBackendOrigin()}/api/proxy-image?url=${encodeURIComponent(raw)}`)
            if (res.ok) {
              const blob = await res.blob()
              activeLogo = await new Promise((resolve) => {
                const r = new FileReader()
                r.onloadend = () => resolve(r.result)
                r.readAsDataURL(blob)
              })
            }
          } catch {}
        }
        if (!activeLogo || !activeLogo.startsWith('data:image')) {
          try {
            const res = await fetch(companyLogoFallback)
            if (res.ok) {
              const blob = await res.blob()
              activeLogo = await new Promise((resolve) => {
                const r = new FileReader()
                r.onloadend = () => resolve(r.result)
                r.readAsDataURL(blob)
              })
            }
          } catch {}
        }
      }

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

          // Configure exact A4 sheet proportions for clone (794px x 1123px = 210mm x 297mm at 96 DPI)
          clonedElement.style.width = '794px'
          clonedElement.style.maxWidth = '794px'
          clonedElement.style.minHeight = '1123px'
          clonedElement.style.boxSizing = 'border-box'
          clonedElement.style.display = 'flex'
          clonedElement.style.flexDirection = 'column'
          clonedElement.style.justifyContent = 'space-between'
          clonedElement.style.margin = '0 auto'
          clonedElement.style.boxShadow = 'none'
          clonedElement.style.borderRadius = '0px'
          clonedElement.style.border = 'none'
          clonedElement.style.padding = '36px 44px'
          clonedElement.style.backgroundColor = '#ffffff'

          // Ensure logo uses base64 data url
          const logoEl = clonedElement.querySelector('.company-logo-img')
          if (logoEl && activeLogo) {
            logoEl.src = activeLogo
          }

          // Ensure all text elements have opaque non-transparent color
          clonedElement.querySelectorAll('*').forEach((node) => {
            if (node.style && (!node.style.color || node.style.color === 'transparent')) {
              try {
                const comp = (clonedDoc.defaultView || window).getComputedStyle(node)
                if (comp.color && comp.color.startsWith('rgb') && comp.color !== 'rgba(0, 0, 0, 0)') {
                  node.style.color = comp.color
                } else {
                  node.style.color = '#000000'
                }
              } catch {
                node.style.color = '#000000'
              }
            }
          })
        },
      })

      // Standard A4 dimensions in mm: 210 x 297
      const pageWidth = 210
      const pageHeight = 297

      const pdf = new jsPDF({
        orientation: 'portrait',
        unit: 'mm',
        format: 'a4',
      })
      const imgData = canvas.toDataURL('image/jpeg', 0.98)

      // Calculate rendered content height in mm for a 210mm width
      const contentHeight = (canvas.height * pageWidth) / canvas.width

      if (contentHeight <= pageHeight + 5) {
        // Fits on a single A4 page: fill exact 210mm x 297mm A4 sheet
        pdf.addImage(imgData, 'JPEG', 0, 0, pageWidth, pageHeight)
      } else {
        // Multi-page handling with full A4 width
        let heightLeft = contentHeight
        let position = 0

        pdf.addImage(imgData, 'JPEG', 0, position, pageWidth, contentHeight)
        heightLeft -= pageHeight

        while (heightLeft > 0) {
          position = -(contentHeight - heightLeft)
          pdf.addPage()
          pdf.addImage(imgData, 'JPEG', 0, position, pageWidth, contentHeight)
          heightLeft -= pageHeight
        }
      }

      const filename = `invoice-${(billing?.company?.name || 'bill').replace(/\s+/g, '-')}-${id}.pdf`
      pdf.save(filename)
    } catch (err) {
      console.error('PDF download failed:', err)
      setDownloadError(err?.message || 'Download failed. Try Print then Save as PDF.')
    } finally {
      setDownloading(false)
    }
  }

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

  if (loading) return <div className='p-8 text-center text-gray-600'>Loading invoice...</div>
  if (error) return <div className='p-8 text-center text-red-600'>{error}</div>
  if (!billing) return null

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
    <div className='min-h-screen bg-slate-100/80 print:bg-white print:min-h-0'>
      <style>{`
        @media print {
          @page {
            size: A4 portrait;
            margin: 10mm;
          }
          aside, nav, header, [role="navigation"], .sidebar, .print\\:hidden {
            display: none !important;
            visibility: hidden !important;
            width: 0 !important;
            height: 0 !important;
          }
          body, html, #root, main {
            background: #ffffff !important;
            margin: 0 !important;
            padding: 0 !important;
            width: 100% !important;
            height: auto !important;
            min-height: 100% !important;
            overflow: visible !important;
          }
          .invoice-sheet-container {
            padding: 0 !important;
            margin: 0 !important;
            background: transparent !important;
            display: block !important;
            width: 100% !important;
          }
          .invoice-a4-sheet {
            width: 100% !important;
            max-width: 100% !important;
            min-height: auto !important;
            box-shadow: none !important;
            border: 1px solid #d1d5db !important;
            margin: 0 !important;
            padding: 8mm 10mm !important;
            background: #ffffff !important;
          }
        }
      `}</style>

      {/* Non-printable header with actions */}
      <div className='print:hidden sticky top-0 z-20 bg-white/95 backdrop-blur border-b border-gray-200 px-4 sm:px-8 py-3 flex items-center justify-between shadow-xs'>
        <button
          onClick={() => navigate('/billings')}
          className='inline-flex items-center gap-1.5 text-gray-700 hover:text-gray-900 text-sm font-medium transition-colors'
        >
          <svg className='w-4 h-4' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path strokeLinecap='round' strokeLinejoin='round' strokeWidth={2} d='M10 19l-7-7m0 0l7-7m-7 7h18' /></svg>
          Back to Billing
        </button>
        <div className='flex items-center gap-3'>
          <span className='hidden sm:inline-block text-xs font-medium text-gray-500 bg-gray-100 px-2.5 py-1 rounded-md border border-gray-200'>
            A4 Standard Page (210 × 297 mm)
          </span>
          <button
            onClick={handlePrint}
            className='bg-white text-gray-700 border border-gray-300 px-4 py-2 rounded-lg text-sm font-medium hover:bg-gray-50 transition-colors inline-flex items-center gap-2 shadow-xs'
          >
            <svg className='w-4 h-4 text-gray-500' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path strokeLinecap='round' strokeLinejoin='round' strokeWidth={2} d='M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z' /></svg>
            Print
          </button>
          <button
            onClick={handleDownload}
            disabled={downloading}
            className='bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700 disabled:opacity-50 transition-colors inline-flex items-center gap-2 shadow-sm'
          >
            <svg className='w-4 h-4' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path strokeLinecap='round' strokeLinejoin='round' strokeWidth={2} d='M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4' /></svg>
            {downloading ? 'Downloading...' : 'Download PDF'}
          </button>
        </div>
      </div>

      {downloadError && (
        <div className='print:hidden mx-auto max-w-4xl mt-3 px-4'>
          <div className='rounded-lg bg-amber-50 border border-amber-200 px-4 py-2.5'>
            <p className='text-amber-800 text-sm font-medium'>{downloadError}</p>
          </div>
        </div>
      )}

      {/* A4 Sheet Desk Container */}
      <div ref={printRef} className='invoice-sheet-container py-8 px-4 sm:px-6 w-full flex justify-center print:p-0 print:block'>
        {/* Invoice content - exact A4 sheet proportions on screen */}
        <div
          ref={invoiceRef}
          className='invoice-a4-sheet bg-white border border-gray-200 shadow-xl rounded-sm w-[210mm] max-w-full min-h-[297mm] p-8 sm:p-12 mx-auto text-black flex flex-col justify-between'
          style={{ boxSizing: 'border-box' }}
        >
          <div className='invoice-main-content flex-1'>
            {/* Company logo at top center */}
            <div className='flex justify-center pt-2 pb-4 border-b' style={{ borderColor: '#e5e7eb' }}>
              <img
                src={logoSrc}
                alt={company.name || 'Company logo'}
                crossOrigin='anonymous'
                className='company-logo-img h-16 sm:h-20 w-auto max-w-[220px] object-contain'
              />
            </div>

            {/* Header: Title and Invoice No */}
            <div className='py-4 border-b' style={{ borderColor: '#e5e7eb' }}>
              <div className='flex flex-wrap items-baseline justify-between gap-4'>
                <div>
                  <h1 className='text-2xl font-bold tracking-tight' style={{ color: '#000000' }}>INVOICE</h1>
                  <p className='text-sm mt-1 font-medium' style={{ color: '#374151' }}>
                    {isGst ? 'Tax Invoice (GST)' : 'Bill (Non-GST)'} • {billing.createdAt ? new Date(billing.createdAt).toLocaleDateString() : '—'}
                  </p>
                </div>
                <div className='text-right'>
                  <p className='text-sm' style={{ color: '#000000' }}>
                    <span className='font-semibold' style={{ color: '#000000' }}>Invoice No:</span>{' '}
                    {billing.invoiceNumber ? billing.invoiceNumber.replace(/^Gamo-/, 'ARG-') : `ARG-${getFYDisplay(billing.createdAt)}-001`}
                  </p>
                  <p className='text-sm mt-1' style={{ color: '#000000' }}>
                    <span className='font-semibold' style={{ color: '#000000' }}>Financial Year:</span>{' '}
                    <span className='font-semibold' style={{ color: '#000000' }}>{getFYDisplay(billing.createdAt)}</span>
                  </p>
                </div>
              </div>
            </div>

          {/* From & Bill To */}
          <div className='py-6 grid grid-cols-1 md:grid-cols-2 gap-8 border-b border-gray-200'>
            {/* From / Company */}
            <div>
              <h2 className='text-xs font-semibold text-black uppercase tracking-wider mb-2'>From</h2>
              <div>
                <p className='font-semibold text-black'>{company.name || '—'}</p>
                {company.address && <p className='text-sm text-black mt-1'>{company.address}</p>}
                {company.email && <p className='text-sm text-black'>{company.email}</p>}
                {company.phone && <p className='text-sm text-black'>{company.phone}</p>}
                {company.pan && <p className='text-sm text-black'>PAN: {company.pan}</p>}
                {company.website && <p className='text-sm text-black'>Website: {company.website}</p>}
                {isGst && billing.companyGst?.gstin && (
                  <p className='text-sm text-black mt-2'>
                    GSTIN: {billing.companyGst.gstin}
                    {billing.companyGst.state && ` • State: ${billing.companyGst.state} (${billing.companyGst.stateCode || ''})`}
                  </p>
                )}
              </div>
            </div>

            {/* Bill To / Client */}
            <div>
              <h2 className='text-xs font-semibold text-black uppercase tracking-wider mb-2'>Bill To</h2>
              <p className='font-semibold text-black'>{client.clientName || '—'}</p>
              {client.address && <p className='text-sm text-black mt-1'>{client.address}</p>}
              {client.mailId && <p className='text-sm text-black'>{client.mailId}</p>}
              {client.clientNumber && <p className='text-sm text-black'>{client.clientNumber}</p>}
              {isGst && (billing.clientGst?.gstin || billing.clientGst?.billingAddress) && (
                <p className='text-sm text-black mt-2'>
                  {billing.clientGst.gstin && `GSTIN: ${billing.clientGst.gstin}`}
                  {billing.clientGst.billingAddress && ` • ${billing.clientGst.billingAddress}`}
                </p>
              )}
              {payment.method && (
                <p className='text-sm text-black mt-2'>
                  <span className='font-semibold'>Payment Mode:</span> {payment.method}
                </p>
              )}
            </div>
          </div>

          {/* Projects / Items table */}
          <div className='py-6'>
            <h2 className='text-xs font-semibold text-black uppercase tracking-wider mb-3'>Invoice Items</h2>
            <table className='w-full text-sm border' style={{ borderColor: '#d1d5db' }}>
              <thead>
                <tr className='border-b' style={{ backgroundColor: '#f8fafc', borderColor: '#d1d5db' }}>
                  <th className='text-left py-2 px-3 font-semibold text-black'>#</th>
                  <th className='text-left py-2 px-3 font-semibold text-black'>Project / Description</th>
                  <th className='text-right py-2 px-3 font-semibold text-black'>Project Cost</th>
                  <th className='text-right py-2 px-3 font-semibold text-black'>Amount (INR)</th>
                </tr>
              </thead>
              <tbody>
                {projects.length === 0 ? (
                  <tr>
                    <td colSpan={4} className='py-4 px-3 text-center text-black'>No projects</td>
                  </tr>
                ) : (
                  projects.map((item, i) => {
                    const cost = Number(item.projectCost) || 0
                    const rem = Number(item.remainingCost) || 0
                    const paid = cost - rem
                    return (
                      <tr key={i} className='border-b' style={{ borderColor: '#e5e7eb' }}>
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
            {projects.length > 0 && (() => {
              const totalProjectCost = projects.reduce((s, p) => s + (Number(p.projectCost) || 0), 0)
              const totalRemaining = projects.reduce((s, p) => s + (Number(p.remainingCost) || 0), 0)
              const amountPaid = totalProjectCost - totalRemaining
              return (
                <div className='mt-3 pt-3 border-t border-gray-300 flex flex-wrap gap-6 text-sm'>
                  <span className='text-black'><span className='font-semibold'>Total Project Cost:</span> {formatINR(totalProjectCost)}</span>
                  <span className='text-black'><span className='font-semibold'>Amount (this payment):</span> {formatINR(amountPaid)}</span>
                </div>
              )
            })()}
            {billing.tracking && billing.tracking.length > 0 && (
              <div className='mt-6 pt-4 border-t border-gray-300'>
                <h3 className='text-xs font-semibold text-black uppercase tracking-wider mb-2'>Payment tracking (all bills for this client)</h3>
                <table className='w-full text-sm border' style={{ borderColor: '#d1d5db' }}>
                  <thead>
                    <tr className='border-b' style={{ backgroundColor: '#f8fafc', borderColor: '#d1d5db' }}>
                      <th className='text-left py-2 px-3 font-semibold text-black'>Project</th>
                      <th className='text-right py-2 px-3 font-semibold text-black'>Project Cost</th>
                      <th className='text-right py-2 px-3 font-semibold text-black'>Total Paid</th>
                      <th className='text-right py-2 px-3 font-semibold text-black'>Remaining</th>
                    </tr>
                  </thead>
                  <tbody>
                    {billing.tracking.map((t, i) => (
                      <tr key={i} className='border-b' style={{ borderColor: '#e5e7eb' }}>
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

          {/* GST breakdown (when GST bill) */}
          {isGst && (taxableValue != null || invoiceAmount != null) && (
            <div className='py-4'>
              <h2 className='text-xs font-semibold text-black uppercase tracking-wider mb-2'>GST Breakdown</h2>
              <table className='w-full max-w-xs text-sm border' style={{ borderColor: '#d1d5db' }}>
                <tbody>
                  {taxableValue != null && (
                    <tr className='border-b' style={{ borderColor: '#e5e7eb' }}><td className='py-1.5 px-3 text-black'>Taxable Value</td><td className='py-1.5 px-3 text-right text-black'>{formatINR(taxableValue).replace('₹', '')}</td></tr>
                  )}
                  {cgstAmount != null && (
                    <tr className='border-b' style={{ borderColor: '#e5e7eb' }}><td className='py-1.5 px-3 text-black'>CGST @ 9%</td><td className='py-1.5 px-3 text-right text-black'>{formatINR(cgstAmount).replace('₹', '')}</td></tr>
                  )}
                  {sgstAmount != null && (
                    <tr className='border-b' style={{ borderColor: '#e5e7eb' }}><td className='py-1.5 px-3 text-black'>SGST @ 9%</td><td className='py-1.5 px-3 text-right text-black'>{formatINR(sgstAmount).replace('₹', '')}</td></tr>
                  )}
                  {invoiceAmount != null && (
                    <tr style={{ backgroundColor: '#f8fafc' }}><td className='py-1.5 px-3 text-black font-semibold'>Total</td><td className='py-1.5 px-3 text-right text-black font-semibold'>{formatINR(invoiceAmount).replace('₹', '')}</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          )}

          {billing.termsAndConditions && (
            <div className='py-4'>
              <h2 className='text-xs font-semibold text-black uppercase tracking-wider mb-2'>Terms & Conditions</h2>
              <p className='text-sm text-black whitespace-pre-wrap'>{billing.termsAndConditions}</p>
            </div>
          )}

          </div>

          {/* Bottom aligned signature and footer */}
          <div className='invoice-footer-content mt-auto pt-6'>
            {/* Authorized Signature */}
            <div className='flex justify-end'>
              <div className='text-center'>
                {billing.authorizedSignature ? (
                  <>
                    <img src={billing.authorizedSignature} alt='Authorized Signature' crossOrigin='anonymous' className='h-16 max-w-[220px] object-contain mx-auto' />
                    <p className='text-sm font-semibold text-black mt-1'>Authorized Signature</p>
                  </>
                ) : (
                  <>
                    <div className='border-t-2 border-black w-44 mt-6 mb-1 mx-auto' />
                    <p className='text-sm font-semibold text-black'>Authorized Signature</p>
                  </>
                )}
              </div>
            </div>

            {/* Footer */}
            <div className='mt-6 pt-4 border-t border-gray-200 text-center text-sm font-medium' style={{ color: '#374151' }}>
              Thank you for your business.
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

export default InvoicePage
