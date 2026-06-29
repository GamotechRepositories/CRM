import Quotation from '../../models/bangarProperties/bangarProperties_quotation.js';
import { createQuotationController } from '../../utils/createQuotationController.js';

export const {
  createQuotation,
  getQuotations,
  getQuotationById,
  updateQuotation,
  deleteQuotation,
} = createQuotationController(Quotation);
