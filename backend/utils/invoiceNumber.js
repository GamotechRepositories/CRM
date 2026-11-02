import InvoiceSequence from '../models/invoiceSequence.js';

export const invoiceYearRange = (date = new Date()) => {
  const year = Number(new Intl.DateTimeFormat('en', {
    timeZone: 'Asia/Kolkata', year: 'numeric',
  }).format(date));
  return `${year}-${String(year + 1).slice(-2)}`;
};

export const nextInvoiceNumber = async (companyPrefix, date = new Date()) => {
  const prefix = `${companyPrefix}-${invoiceYearRange(date)}`;
  const counter = await InvoiceSequence.findOneAndUpdate(
    { _id: prefix },
    { $inc: { sequence: 1 } },
    { upsert: true, new: true },
  );
  return `${prefix}-${counter.sequence}`;
};
