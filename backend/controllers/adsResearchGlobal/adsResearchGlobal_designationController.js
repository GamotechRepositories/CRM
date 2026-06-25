import Designation from '../../models/adsResearchGlobal/adsResearchGlobal_designation.js';
import Employee from '../../models/adsResearchGlobal/adsResearchGlobal_employee.js';
import { createDesignationController } from '../../utils/createDesignationController.js';

const controller = createDesignationController(Designation, Employee);

export const {
  createDesignation,
  getDesignations,
  getDesignationById,
  updateDesignation,
  deleteDesignation,
} = controller;
