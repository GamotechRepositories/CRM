import mongoose from 'mongoose';
import { getQuotationFields } from '../../utils/quotationFields.js';

const quotationSchema = new mongoose.Schema(getQuotationFields('mahaProperties'), { timestamps: true });

const Quotation = mongoose.model('mahaProperties_Quotation', quotationSchema);
export default Quotation;
