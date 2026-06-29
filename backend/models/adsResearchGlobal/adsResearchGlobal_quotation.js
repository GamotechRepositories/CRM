import mongoose from 'mongoose';
import { getQuotationFields } from '../../utils/quotationFields.js';

const quotationSchema = new mongoose.Schema(getQuotationFields('adsResearchGlobal'), { timestamps: true });

const Quotation = mongoose.model('adsResearchGlobal_Quotation', quotationSchema);
export default Quotation;
