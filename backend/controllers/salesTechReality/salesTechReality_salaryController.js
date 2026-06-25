import Salary from '../../models/salesTechReality/salesTechReality_salary.js';

// Create a new salary record
export const createSalary = async (req, res) => {
  try {
    const { employee, amount, month, year, status } = req.body;

    const newSalary = new Salary({
      employee,
      amount,
      month,
      year,
      status: status || 'Unpaid',
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

// Get all salary records
export const getSalaries = async (req, res) => {
  try {
    const salaries = await Salary.find().populate('employee');
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
    const updated = await Salary.findByIdAndUpdate(req.params.id, req.body, {
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
