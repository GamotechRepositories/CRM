import { Router } from 'express';
import {
  createCompany,
  getCompanies,
  getCompanyById,
  updateCompany,
  deleteCompany,
} from '../../controllers/bangarProperties/bangarProperties_companyController.js';

const router = Router();

router.get('/companies', getCompanies);
router.post('/companies', createCompany);
router.get('/companies/:id', getCompanyById);
router.put('/companies/:id', updateCompany);
router.delete('/companies/:id', deleteCompany);

export default router;
