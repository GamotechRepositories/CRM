import mongoose from 'mongoose';
import { getQuotationFields } from '../../utils/quotationFields.js';

const quotationSchema = new mongoose.Schema(getQuotationFields('bangarProperties'), { timestamps: true });

const Quotation = mongoose.model('bangarProperties_Quotation', quotationSchema);
export default Quotation;
