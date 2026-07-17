import Employee from "../../models/mahaProperties/mahaProperties_employee.js";
import Designation from "../../models/mahaProperties/mahaProperties_designation.js";
import Project from "../../models/mahaProperties/mahaProperties_project.js";
import Task from "../../models/mahaProperties/mahaProperties_task.js";
import Attendance from "../../models/mahaProperties/mahaProperties_attendance.js";
import Leave from "../../models/mahaProperties/mahaProperties_leave.js";
import Salary from "../../models/mahaProperties/mahaProperties_salary.js";
import Company from "../../models/mahaProperties/mahaProperties_company.js";
import { buildEmployeeProfile } from "../../utils/buildEmployeeProfile.js";
import { createGetEmployeesAvailabilityHandler } from "../../utils/buildEmployeeAvailability.js";
import { normalizeEmployeePayload } from "../../utils/normalizeEmployeePayload.js";
import { getEmployeeApiError, validateEmployeePayload } from "../../utils/employeeApiErrors.js";
import { assignEmployeeCodeOnCreate, validateEmployeeCodeOnUpdate } from "../../utils/employeeCode.js";
import bcrypt from "bcryptjs";

const COMPANY_KEY = 'mahaProperties';

// Create a new employee
export const createEmployee = async (req, res) => {
  try {
    const { payload, password } = normalizeEmployeePayload(req.body);
    if (!password || password.length < 6) {
      return res.status(400).json({ message: "Password is required and must be at least 6 characters" });
    }
    const missing = validateEmployeePayload(payload);
    if (missing.length) {
      return res.status(400).json({ message: `Missing required fields: ${missing.join(', ')}` });
    }
    await assignEmployeeCodeOnCreate(Employee, COMPANY_KEY, payload);
    const hashedPassword = await bcrypt.hash(password, 10);
    const newEmployee = new Employee({
      ...payload,
      password: hashedPassword,
    });
    await newEmployee.save();
    res.status(201).json({
      message: "Employee created successfully",
      employee: newEmployee,
    });
  } catch (error) {
    const { status, message } = getEmployeeApiError(error, "Error creating employee");
    res.status(error.status || status).json({ message: error.message || message });
  }
};

// Get all employees
export const getEmployees = async (req, res) => {
  try {
    const employees = await Employee.find().populate('designation');
    res.status(200).json(employees);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching employees', error });
  }
};

// Get a single employee by ID
export const getEmployeeById = async (req, res) => {
  try {
    const employee = await Employee.findById(req.params.id)
      .populate('designation')
      .populate('reportingManager', 'name email');
    if (!employee) return res.status(404).json({ message: 'Employee not found' });
    res.status(200).json(employee);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching employee', error });
  }
};

// Update an employee by ID
export const updateEmployee = async (req, res) => {
  try {
    const { payload, password } = normalizeEmployeePayload(req.body);
    await validateEmployeeCodeOnUpdate(Employee, COMPANY_KEY, req.params.id, payload);
    const updates = { ...payload };
    if (password && password.length >= 6) {
      updates.password = await bcrypt.hash(password, 10);
    }
    const updated = await Employee.findByIdAndUpdate(req.params.id, updates, { new: true })
      .populate('designation')
      .populate('reportingManager', 'name email');
    if (!updated) return res.status(404).json({ message: 'Employee not found' });
    res.status(200).json({ message: 'Employee updated', employee: updated });
  } catch (error) {
    const { status, message } = getEmployeeApiError(error, "Error updating employee");
    res.status(error.status || status).json({ message: error.message || message });
  }
};

// Delete an employee by ID
export const deleteEmployee = async (req, res) => {
  try {
    const deleted = await Employee.findByIdAndDelete(req.params.id);
    if (!deleted) return res.status(404).json({ message: 'Employee not found' });
    res.status(200).json({ message: 'Employee deleted successfully' });
  } catch (error) {
    res.status(500).json({ message: 'Error deleting employee', error });
  }
};
// Get full employee profile with related data
export const getEmployeeProfile = async (req, res) => {
  try {
    const profile = await buildEmployeeProfile({
      employeeId: req.params.id,
      models: {
        Employee,
        Project,
        Task,
        Attendance,
        Leave,
        Salary,
      },
    });
    if (!profile) return res.status(404).json({ message: 'Employee not found' });
    res.status(200).json(profile);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching employee profile', error: error?.message || error });
  }
};

export const getEmployeesAvailability = createGetEmployeesAvailabilityHandler({
  Employee,
  Task,
  Attendance,
  Leave,
  Company,
});

