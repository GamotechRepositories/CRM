import React from 'react'

const round = (value) => Math.round((value + Number.EPSILON) * 100) / 100
const number = (value) => Number(value).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const small = ['Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen']
const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety']
function words(value) {
  if (value < 20) return small[value]
  if (value < 100) return tens[Math.floor(value / 10)] + (value % 10 ? ` ${small[value % 10]}` : '')
  for (const [scale, label] of [[10000000, 'Crore'], [100000, 'Lakh'], [1000, 'Thousand'], [100, 'Hundred']]) {
    if (value >= scale) return `${words(Math.floor(value / scale))} ${label}${value % scale ? ` ${words(value % scale)}` : ''}`
  }
}
export function amountInWords(amount) {
  const paise = Math.round(Math.abs(amount) * 100)
  return `${amount < 0 ? 'Minus ' : ''}${words(Math.floor(paise / 100))} Rupees${paise % 100 ? ` and ${words(paise % 100)} Paise` : ''} only`
}
export function groupTaxes(rows) {
  const groups = new Map()
  for (const row of rows) {
    const code = row.hsnSac?.trim() || '—'
    const rate = Number(row.gstRate) || 0
    const key = code
    const group = groups.get(key) || { code, rates: [], base: 0, tax: 0 }
    if (!group.rates.includes(rate)) group.rates.push(rate)
    group.base = round(group.base + row.base)
    group.tax = round(group.tax + row.tax)
    groups.set(key, group)
  }
  return Array.from(groups.values(), (group) => {
    const cgst = round(group.tax / 2)
    return { ...group, rates: group.rates.sort((a, b) => a - b), cgst, sgst: round(group.tax - cgst) }
  })
}

export default function InvoiceTaxSummary({ rows, totals, isGst, received = 0, documentLabel = 'Invoice' }) {
  const groups = groupTaxes(rows)
  const cgst = round(groups.reduce((sum, group) => sum + group.cgst, 0))
  const sgst = round(groups.reduce((sum, group) => sum + group.sgst, 0))
  const paid = Number(received) || 0
  const balance = round(totals.total - paid)
  const cell = { border: '1px solid #646779', padding: '6px 5px', textAlign: 'right', verticalAlign: 'middle' }
  const heading = { ...cell, textAlign: 'center', fontWeight: 700 }
  return <div className='invoice-tax-summary' style={{ display: 'block', width: '100%', marginTop: 16, color: '#404359', fontSize: 12, breakInside: 'avoid' }}>
    {isGst && <div style={{ width: '100%', overflowX: 'auto' }} tabIndex={0} aria-label='Tax summary by HSN or SAC'>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <caption style={{ textAlign: 'left', fontWeight: 700, paddingBottom: 6 }}>Tax Summary</caption>
        <thead><tr>
          <th rowSpan={2} scope='col' style={heading}>HSN/ SAC</th><th rowSpan={2} scope='col' style={heading}>Taxable amount (₹)</th>
          <th colSpan={2} scope='colgroup' style={heading}>CGST</th><th colSpan={2} scope='colgroup' style={heading}>SGST</th><th rowSpan={2} scope='col' style={heading}>Total Tax (₹)</th>
        </tr><tr>{['Rate (%)', 'Amt (₹)', 'Rate (%)', 'Amt (₹)'].map((label, index) => <th key={index} scope='col' style={heading}>{label}</th>)}</tr></thead>
        <tbody>{groups.map((group) => <tr key={group.code}>
          <td style={{ ...cell, textAlign: 'left' }}>{group.code}</td><td style={cell}>{number(group.base)}</td>
          <td style={cell}>{group.rates.map((rate) => rate / 2).join(', ')}</td><td style={cell}>{number(group.cgst)}</td><td style={cell}>{group.rates.map((rate) => rate / 2).join(', ')}</td><td style={cell}>{number(group.sgst)}</td><td style={cell}>{number(group.tax)}</td>
        </tr>)}</tbody>
        <tfoot><tr style={{ fontWeight: 700, background: '#f4f4f5' }}><th scope='row' style={{ ...cell, textAlign: 'left' }}>TOTAL</th><td style={cell}>{number(totals.base)}</td><td style={cell} /><td style={cell}>{number(cgst)}</td><td style={cell} /><td style={cell}>{number(sgst)}</td><td style={cell}>{number(totals.tax)}</td></tr></tfoot>
      </table>
    </div>}
    <section aria-label='Invoice totals and balance' style={{ width: '100%', marginTop: 12, border: '1px solid #646779' }}>
      <dl><div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 12, flexWrap: 'wrap', padding: 6, fontWeight: 700 }}><dt style={{ textAlign: 'left' }}>Total</dt><dd style={{ flex: '1 1 180px', textAlign: 'right' }}>₹ {number(totals.total)}</dd></div></dl>
      <div style={{ borderTop: '1px solid #646779', padding: 6, lineHeight: 1.6, display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 12, flexWrap: 'wrap' }}><strong style={{ textAlign: 'left' }}>{documentLabel} Amount in Words:</strong><span style={{ flex: '1 1 180px', textAlign: 'right' }}>{amountInWords(totals.total)}</span></div>
      <dl style={{ borderTop: '1px solid #646779', padding: 6 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}><dt>Received</dt><dd>₹ {number(paid)}</dd></div>
        <div style={{ display: 'flex', justifyContent: 'space-between' }}><dt>{balance < 0 ? 'Credit' : 'Balance'}</dt><dd>₹ {number(Math.abs(balance))}</dd></div>
      </dl>
    </section>
  </div>
}
