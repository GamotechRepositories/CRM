import { Router } from 'express';
import {
  createExpense,
  getExpenses,
  getExpenseById,
  updateExpense,
  deleteExpense,
} from '../../controllers/bangarProperties/bangarProperties_expenseController.js';

const router = Router();

router.get('/expenses', getExpenses);
router.post('/expenses', createExpense);
router.get('/expenses/:id', getExpenseById);
router.put('/expenses/:id', updateExpense);
router.delete('/expenses/:id', deleteExpense);

export default router;
