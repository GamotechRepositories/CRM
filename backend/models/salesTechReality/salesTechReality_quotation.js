import mongoose from 'mongoose';
import { getQuotationFields } from '../../utils/quotationFields.js';

const quotationSchema = new mongoose.Schema(getQuotationFields('salesTechReality'), { timestamps: true });

const Quotation = mongoose.model('salesTechReality_Quotation', quotationSchema);
export default Quotation;
