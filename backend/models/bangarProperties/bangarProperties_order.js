import mongoose from 'mongoose';

const orderSchema = new mongoose.Schema({
  billType: {
    type: String,
    enum: ['GST', 'Non-GST'],
    required: true,
  },
  companyLogo: {
    type: String,
    default: '',
  },
  orderDate: { type: Date, default: null },
  placeOfSupply: { type: String, default: '' },
  items: [{
    name: { type: String, required: true, trim: true },
    description: { type: String, default: '' },
    hsnSac: { type: String, default: '' },
    serviceName: { type: String, default: '' },
    quantity: { type: Number, required: true, min: 0.001 },
    unit: { type: String, default: 'Nos' },
    price: { type: Number, required: true, min: 0 },
    gstRate: { type: Number, default: 18, min: 0, max: 100 },
  }],
  orderNumber: { type: String, default: '' },
  company: {
    name: { type: String, default: '' },
    address: { type: String, default: '' },
    email: { type: String, default: '' },
    phone: { type: String, default: '' },
    pan: { type: String, default: '' },
    website: { type: String, default: '' },
  },
  termsAndConditions: { type: String, default: '' },
  authorizedSignature: { type: String, default: '' },
  // GST fields for company (when billType === 'GST')
  companyGst: {
    gstin: { type: String, default: '' },
    state: { type: String, default: '' },
    stateCode: { type: String, default: '' },
  },
  client: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'bangarProperties_Client',
    required: true,
  },
  // GST fields for client (when billType === 'GST')
  clientGst: {
    gstin: { type: String, default: '' },
    state: { type: String, default: '' },
    orderAddress: { type: String, default: '' },
  },
  projects: [{
    project: { type: mongoose.Schema.Types.ObjectId, ref: 'bangarProperties_Project' },
    projectCost: { type: Number, default: 0 },
    remainingCost: { type: Number, default: 0 },
  }],
  // Common payment details
  paymentDetails: {
    amount: { type: Number, default: null },
    paymentDate: { type: Date, default: null },
    receiverName: { type: String, default: '' },
    receiverBankAccount: { type: String, default: '' },
    receiverBankName: { type: String, default: '' },
    modeOfTransaction: { type: String, default: '' },
  },
}, { timestamps: true });

const Order = mongoose.model('bangarProperties_Order', orderSchema);
export default Order;
