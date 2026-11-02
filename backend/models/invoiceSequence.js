import mongoose from 'mongoose';

// One atomic sequence per company prefix and year range.
const invoiceSequenceSchema = new mongoose.Schema({
  _id: { type: String, required: true },
  sequence: { type: Number, default: 0 },
}, { versionKey: false });

export default mongoose.model('InvoiceSequence', invoiceSequenceSchema);
