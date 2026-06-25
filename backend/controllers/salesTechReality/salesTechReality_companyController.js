import Company from '../../models/salesTechReality/salesTechReality_company.js';

export const createCompany = async (req, res) => {
  try {
    const company = new Company(req.body);
    await company.save();
    res.status(201).json({ message: 'Company created', company });
  } catch (error) {
    res.status(500).json({ message: 'Error creating company', error });
  }
};

export const getCompanies = async (req, res) => {
  try {
    const companies = await Company.find().sort({ createdAt: -1 });
    res.status(200).json(companies);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching companies', error });
  }
};

export const getCompanyById = async (req, res) => {
  try {
    const company = await Company.findById(req.params.id);
    if (!company) return res.status(404).json({ message: 'Company not found' });
    res.status(200).json(company);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching company', error });
  }
};

export const updateCompany = async (req, res) => {
  try {
    const company = await Company.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true,
    });
    if (!company) return res.status(404).json({ message: 'Company not found' });
    res.status(200).json({ message: 'Company updated', company });
  } catch (error) {
    res.status(500).json({ message: 'Error updating company', error });
  }
};

export const deleteCompany = async (req, res) => {
  try {
    const company = await Company.findByIdAndDelete(req.params.id);
    if (!company) return res.status(404).json({ message: 'Company not found' });
    res.status(200).json({ message: 'Company deleted' });
  } catch (error) {
    res.status(500).json({ message: 'Error deleting company', error });
  }
};
