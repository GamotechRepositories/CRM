import Designation from '../../models/mahaProperties/mahaProperties_designation.js';
import Employee from '../../models/mahaProperties/mahaProperties_employee.js';
import { createDesignationController } from '../../utils/createDesignationController.js';

const controller = createDesignationController(Designation, Employee);

export const {
  createDesignation,
  getDesignations,
  getDesignationById,
  updateDesignation,
  deleteDesignation,
} = controller;
