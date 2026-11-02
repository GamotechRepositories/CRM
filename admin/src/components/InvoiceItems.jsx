import React from 'react'
import InvoiceTaxSummary from './InvoiceTaxSummary'

// Service codes supplied in the invoice reference; users can override them.
export const servicePresets = [
  { name: 'Software development', description: '', hsnSac: '998314' },
  { name: 'IT consulting', description: '', hsnSac: '998313' },
  { name: 'Advertising services', description: '', hsnSac: '998361' },
  { name: 'Management consulting', description: '', hsnSac: '998311' },
  { name: 'Business support services', description: '', hsnSac: '998599' },
  { name: 'Website Development', description: '', hsnSac: '998314' },
  ...['Facebook Account Setup', 'Instagram Account Setup', 'LinkedIn Account Setup', 'X (Twitter) Account Setup', 'YouTube Channel Setup'].map((description) => ({ name: 'Social Media Setup', description, hsnSac: '998313' })),
  ...['Brochure Content Writing', 'Brochure Design', 'Graphics Design', 'ID Card Design', 'Visiting Card Design', 'Logo Design', 'Envelope Design', 'Letter Head Design'].map((description) => ({ name: 'Print Media', description, hsnSac: '998391' })),
  { name: 'Tracking Setup', description: 'Meta Pixel Create & Install', hsnSac: '998313' },
]

const serviceLabel = (service) => service.description ? `${service.name} — ${service.description}` : service.name

export const emptyItem = () => ({ name: '', description: '', hsnSac: '', serviceName: '', quantity: 1, unit: 'Nos', price: 0, gstRate: 18 })
const round = (n) => Math.round((n + Number.EPSILON) * 100) / 100
export const itemAmounts = (item, isGst) => {
  const base = round(Number(item.quantity || 0) * Number(item.price || 0))
  const tax = isGst ? round(base * Number(item.gstRate || 0) / 100) : 0
  return { base, tax, total: round(base + tax) }
}
export const itemTotals = (items, isGst) => items.reduce((sum, item) => {
  const amounts = itemAmounts(item, isGst)
  return { base: round(sum.base + amounts.base), tax: round(sum.tax + amounts.tax), total: round(sum.total + amounts.total) }
}, { base: 0, tax: 0, total: 0 })
const money = (n) => new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR' }).format(n)

export default function InvoiceItems({ items, isGst, onChange, received = 0 }) {
  const editable = Boolean(onChange)
  const totals = itemTotals(items, isGst)
  const update = (index, field, value) => onChange(items.map((item, i) => i === index ? { ...item, [field]: value } : item))
  const applyService = (index, value) => {
    if (value === '') return
    const preset = servicePresets[Number(value)]
    if (preset) onChange(items.map((item, i) => i === index ? { ...item, hsnSac: preset.hsnSac, serviceName: serviceLabel(preset) } : item))
  }
  const input = (item, index, field, label, numeric = false) => <input aria-label={`${label}, item ${index + 1}`} type={numeric ? 'number' : 'text'} min={numeric ? (field === 'quantity' ? '0.001' : '0') : undefined} max={field === 'gstRate' ? 100 : undefined} step={numeric ? 'any' : undefined} required={field === 'name' || numeric} value={item[field] ?? ''} onChange={(e) => update(index, field, e.target.value)} style={{ width: '100%', minWidth: field === 'name' ? 150 : 65, padding: '8px', border: '1px solid #cbd5e1', borderRadius: 4, color: '#334155', background: '#fff' }} />
  const cell = { border: '1px solid #646779', padding: '8px 6px', verticalAlign: 'middle' }
  return <section aria-label='Invoice items'>
    <div style={{ overflowX: 'auto' }} tabIndex={0} aria-label='Invoice items table'>
      <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 12, color: '#404359' }}>
        <thead><tr style={{ background: '#f4f4f5' }}>{['#', 'Item name', 'HSN / SAC', 'Quantity', 'Unit', 'Price / Unit(₹)', ...(isGst ? ['GST(₹)'] : []), 'Amount(₹)', ...(editable ? [''] : [])].map((label, i) => <th key={i} scope='col' style={{ ...cell, textAlign: i < 3 ? 'left' : 'right' }}>{label}</th>)}</tr></thead>
        <tbody>{items.map((item, index) => {
          const amounts = itemAmounts(item, isGst)
          const serviceIndex = servicePresets.findIndex((service) => serviceLabel(service) === item.serviceName)
          return <tr key={index} style={{ breakInside: 'avoid' }}>
            <td style={cell}>{index + 1}</td>
            <td style={{ ...cell, width: '28%' }}>{editable ? <>{input(item, index, 'name', 'Item name')}<textarea aria-label={`Description, item ${index + 1}`} placeholder='Description (optional)' value={item.description} onChange={(e) => update(index, 'description', e.target.value)} style={{ width: '100%', minWidth: 150, marginTop: 6, padding: 8, border: '1px solid #cbd5e1', borderRadius: 4 }} /></> : <><strong>{item.name}</strong>{item.description && <div style={{ fontSize: 11, marginTop: 4, whiteSpace: 'pre-wrap' }}>{item.description}</div>}</>}</td>
            <td style={cell}>{editable ? <><select aria-label={`Choose HSN or SAC code, item ${index + 1}`} value={serviceIndex < 0 ? '' : String(serviceIndex)} onChange={(e) => applyService(index, e.target.value)} style={{ width: '100%', minWidth: 150, marginBottom: 6, padding: 8, border: '1px solid #cbd5e1', borderRadius: 4, background: '#fff', color: '#334155' }}>
              <option value=''>Choose service / auto-fill code</option>
              {servicePresets.map((service, i) => <option key={i} value={i}>{service.name}{service.description ? ` — ${service.description}` : ''} ({service.hsnSac})</option>)}
            </select>{input(item, index, 'hsnSac', 'HSN or SAC')}</> : <>{item.serviceName && <div style={{ fontSize: 11, marginBottom: 4 }}>{item.serviceName}</div>}{item.hsnSac || '—'}</>}</td>
            <td style={{ ...cell, textAlign: 'right' }}>{editable ? input(item, index, 'quantity', 'Quantity', true) : item.quantity}</td>
            <td style={{ ...cell, textAlign: 'right' }}>{editable ? input(item, index, 'unit', 'Unit') : item.unit}</td>
            <td style={{ ...cell, textAlign: 'right' }}>{editable ? input(item, index, 'price', 'Price per unit', true) : money(item.price)}</td>
            {isGst && <td style={{ ...cell, textAlign: 'right' }}>{editable && <label>GST % {input(item, index, 'gstRate', 'GST rate', true)}</label>}<div>{money(amounts.tax)}{!editable && <div>({item.gstRate}%)</div>}</div></td>}
            <td style={{ ...cell, textAlign: 'right', whiteSpace: 'nowrap' }}>{money(amounts.total)}</td>
            {editable && <td style={cell}><button type='button' aria-label={`Remove item ${index + 1}`} onClick={() => onChange(items.filter((_, i) => i !== index))} style={{ color: '#b91c1c', padding: 8 }}>Remove</button></td>}
          </tr>
        })}</tbody>
      </table>
    </div>
    {editable && <button type='button' onClick={() => onChange([...items, emptyItem()])} className='mt-3 rounded-lg border border-blue-300 px-4 py-2 text-sm font-medium text-blue-700'>+ Add item</button>}
    <InvoiceTaxSummary rows={items.map((item) => ({ ...item, ...itemAmounts(item, isGst) }))} totals={totals} isGst={isGst} received={received} />
  </section>
}
