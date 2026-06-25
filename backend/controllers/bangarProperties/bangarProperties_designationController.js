import Designation from '../../models/bangarProperties/bangarProperties_designation.js';
import Employee from '../../models/bangarProperties/bangarProperties_employee.js';
import { createDesignationController } from '../../utils/createDesignationController.js';

const controller = createDesignationController(Designation, Employee);

export const {
  createDesignation,
  getDesignations,
  getDesignationById,
  updateDesignation,
  deleteDesignation,
} = controller;
