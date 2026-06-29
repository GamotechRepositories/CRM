const toNumber = (value, fallback = 0) => {
  if (value === '' || value === null || value === undefined) return fallback;
  const num = Number(value);
  return Number.isNaN(num) ? fallback : num;
};

const toDate = (value) => {
  if (!value) return undefined;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? undefined : date;
};

const normalizeLineItems = (items = []) => {
  if (!Array.isArray(items)) return [];

  return items
    .map((item) => {
      const quantity = toNumber(item.quantity, 1);
      const unitPrice = toNumber(item.unitPrice, 0);
      const discount = toNumber(item.discount, 0);
      const taxRate = toNumber(item.taxRate, 0);
      const base = Math.max(0, quantity * unitPrice - discount);
      const tax = base * (taxRate / 100);
      const amount = Math.max(0, base + tax);

      return {
        description: String(item.description || '').trim(),
        quantity,
        unit: String(item.unit || 'Nos').trim() || 'Nos',
        unitPrice,
        discount,
        taxRate,
        amount,
      };
    })
    .filter((item) => item.description);
};

const computeTotals = (lineItems) => {
  const subtotal = lineItems.reduce((sum, item) => sum + item.quantity * item.unitPrice, 0);
  const discountTotal = lineItems.reduce((sum, item) => sum + item.discount, 0);
  const taxTotal = lineItems.reduce((sum, item) => {
    const base = Math.max(0, item.quantity * item.unitPrice - item.discount);
    return sum + base * (item.taxRate / 100);
  }, 0);
  const grandTotal = lineItems.reduce((sum, item) => sum + item.amount, 0);

  return { subtotal, discountTotal, taxTotal, grandTotal };
};

export const normalizeQuotationPayload = (body = {}) => {
  const lineItems = normalizeLineItems(body.lineItems);
  const totals = computeTotals(lineItems);

  return {
    subject: String(body.subject || '').trim(),
    client: body.client || undefined,
    lead: body.lead || null,
    project: body.project || null,
    preparedBy: body.preparedBy || undefined,
    quotationDate: toDate(body.quotationDate),
    validUntil: toDate(body.validUntil),
    status: body.status || 'Draft',
    currency: String(body.currency || 'INR').trim() || 'INR',
    lineItems,
    ...totals,
    termsAndConditions: body.termsAndConditions ?? '',
    notes: body.notes ?? '',
    clientContact: {
      name: body.clientContact?.name ?? body.clientName ?? '',
      email: body.clientContact?.email ?? body.clientEmail ?? '',
      phone: body.clientContact?.phone ?? body.clientPhone ?? '',
    },
    billingAddress: body.billingAddress ?? '',
    quotationNumber: body.quotationNumber?.trim() || undefined,
  };
};

export const validateQuotationPayload = (payload) => {
  const missing = [];
  if (!payload.subject) missing.push('subject');
  if (!payload.client) missing.push('client');
  if (!payload.preparedBy) missing.push('preparedBy');
  if (!payload.quotationDate) missing.push('quotationDate');
  if (!payload.validUntil) missing.push('validUntil');
  if (!payload.lineItems?.length) missing.push('lineItems');
  return missing;
};
