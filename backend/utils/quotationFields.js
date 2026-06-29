import mongoose from 'mongoose';

/** Shared quotation schema fields for all company CRM instances. */
export const getQuotationFields = (companyRef) => ({
  quotationNumber: {
    type: String,
    trim: true,
    unique: true,
    sparse: true,
  },
  subject: {
    type: String,
    required: true,
    trim: true,
  },
  client: {
    type: mongoose.Schema.Types.ObjectId,
    ref: `${companyRef}_Client`,
    required: true,
  },
  lead: {
    type: mongoose.Schema.Types.ObjectId,
    ref: `${companyRef}_Lead`,
    default: null,
  },
  project: {
    type: mongoose.Schema.Types.ObjectId,
    ref: `${companyRef}_Project`,
    default: null,
  },
  preparedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: `${companyRef}_Employee`,
    required: true,
  },
  quotationDate: {
    type: Date,
    required: true,
  },
  validUntil: {
    type: Date,
    required: true,
  },
  status: {
    type: String,
    enum: ['Draft', 'Sent', 'Accepted', 'Rejected', 'Expired', 'Revised'],
    default: 'Draft',
  },
  currency: {
    type: String,
    default: 'INR',
    trim: true,
  },
  lineItems: [{
    description: { type: String, required: true, trim: true },
    quantity: { type: Number, required: true, min: 0, default: 1 },
    unit: { type: String, default: 'Nos', trim: true },
    unitPrice: { type: Number, required: true, min: 0, default: 0 },
    discount: { type: Number, default: 0, min: 0 },
    taxRate: { type: Number, default: 0, min: 0 },
    amount: { type: Number, default: 0, min: 0 },
  }],
  subtotal: { type: Number, default: 0, min: 0 },
  discountTotal: { type: Number, default: 0, min: 0 },
  taxTotal: { type: Number, default: 0, min: 0 },
  grandTotal: { type: Number, default: 0, min: 0 },
  termsAndConditions: { type: String, default: '' },
  notes: { type: String, default: '' },
  clientContact: {
    name: { type: String, default: '', trim: true },
    email: { type: String, default: '', trim: true },
    phone: { type: String, default: '', trim: true },
  },
  billingAddress: { type: String, default: '' },
});
