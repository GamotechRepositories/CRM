import Quotation from '../../models/mahaProperties/mahaProperties_quotation.js';
import { createQuotationController } from '../../utils/createQuotationController.js';

export const {
  createQuotation,
  getQuotations,
  getQuotationById,
  updateQuotation,
  deleteQuotation,
} = createQuotationController(Quotation);
