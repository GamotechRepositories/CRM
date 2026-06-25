import { Router } from 'express'
import {
  createEmployee,
  getEmployees,
  getEmployeeById,
  updateEmployee,
  deleteEmployee,
  getEmployeeProfile,
} from '../../controllers/salesTechReality/salesTechReality_employeeController.js'

const router = Router()

router.get('/employees', getEmployees)
router.post('/employees', createEmployee)
router.get('/employees/:id/profile', getEmployeeProfile)
router.get('/employees/:id', getEmployeeById)
router.put('/employees/:id', updateEmployee)
router.delete('/employees/:id', deleteEmployee)

export default router
