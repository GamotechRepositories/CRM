import Salary from '../../models/salesTechReality/salesTechReality_salary.js';

// Create a new salary record
export const createSalary = async (req, res) => {
  try {
    const { employee, amount, month, year, status, basicSalary, hra, allowances, deductions, bonus, netSalary, paymentDate, paymentMode } = req.body;

    const newSalary = new Salary({
      employee,
      amount,
      month,
      year,
      status: status || 'Unpaid',
      basicSalary: basicSalary || 0,
      hra: hra || 0,
      allowances: allowances || 0,
      deductions: deductions || 0,
      bonus: bonus || 0,
      netSalary: netSalary || amount || 0,
      paymentDate: paymentDate || (status === 'Paid' ? new Date() : undefined),
      paymentMode: paymentMode || 'Bank Transfer',
    });

    await newSalary.save();
    const populated = await Salary.findById(newSalary._id).populate('employee');
    res.status(201).json({
      message: 'Salary record created successfully',
      salary: populated,
    });
  } catch (error) {
    res.status(500).json({ message: 'Error creating salary record', error });
  }
};

// Get all salary records (supports ?employee=ID or ?employeeId=ID filtering)
export const getSalaries = async (req, res) => {
  try {
    const filter = {};
    const empId = req.query.employee || req.query.employeeId;
    if (empId) filter.employee = empId;
    if (req.query.status) filter.status = req.query.status;

    const salaries = await Salary.find(filter).populate('employee').sort({ year: -1, month: -1 });
    res.status(200).json(salaries);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching salaries', error });
  }
};

// Get a single salary record by ID
export const getSalaryById = async (req, res) => {
  try {
    const salary = await Salary.findById(req.params.id).populate('employee');
    if (!salary) return res.status(404).json({ message: 'Salary record not found' });
    res.status(200).json(salary);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching salary', error });
  }
};

// Update a salary record by ID
export const updateSalary = async (req, res) => {
  try {
    const payload = { ...req.body };
    if (payload.status === 'Paid' && !payload.paymentDate) {
      payload.paymentDate = new Date();
    }
    const updated = await Salary.findByIdAndUpdate(req.params.id, payload, {
      new: true,
    }).populate('employee');
    if (!updated) return res.status(404).json({ message: 'Salary record not found' });
    res.status(200).json({ message: 'Salary updated', salary: updated });
  } catch (error) {
    res.status(500).json({ message: 'Error updating salary', error });
  }
};

// Delete a salary record by ID
export const deleteSalary = async (req, res) => {
  try {
    const deleted = await Salary.findByIdAndDelete(req.params.id);
    if (!deleted) return res.status(404).json({ message: 'Salary record not found' });
    res.status(200).json({ message: 'Salary record deleted successfully' });
  } catch (error) {
    res.status(500).json({ message: 'Error deleting salary', error });
  }
};
