import Designation from '../../models/salesTechReality/salesTechReality_designation.js';
import Employee from '../../models/salesTechReality/salesTechReality_employee.js';
import { createDesignationController } from '../../utils/createDesignationController.js';

const controller = createDesignationController(Designation, Employee);

export const {
  createDesignation,
  getDesignations,
  getDesignationById,
  updateDesignation,
  deleteDesignation,
} = controller;
