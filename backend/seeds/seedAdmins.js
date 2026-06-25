import dotenv from 'dotenv';
import bcrypt from 'bcryptjs';
import connectDB from '../config/db.js';
import { getDefaultDesignationMeta } from '../utils/designationFields.js';

dotenv.config();

const companies = ['adsResearchGlobal', 'bangarProperties', 'mahaProperties', 'salesTechReality'];

const ADMIN = {
  name: 'Admin',
  email: 'admin@gmail.com',
  password: 'admin@2026',
  designationTitle: 'Admin',
  department: 'Administration',
  salary: 0,
  workingHours: '9-6',
  status: 'Active',
};

const seedCompanyAdmin = async (company) => {
  const { default: Designation } = await import(`../models/${company}/${company}_designation.js`);
  const { default: Employee } = await import(`../models/${company}/${company}_employee.js`);

  const adminMeta = getDefaultDesignationMeta(ADMIN.designationTitle);
  const designation = await Designation.findOneAndUpdate(
    { title: ADMIN.designationTitle },
    { title: ADMIN.designationTitle, ...adminMeta },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );

  const hashedPassword = await bcrypt.hash(ADMIN.password, 10);

  const employee = await Employee.findOneAndUpdate(
    { email: ADMIN.email },
    {
      name: ADMIN.name,
      email: ADMIN.email,
      password: hashedPassword,
      designation: designation._id,
      department: ADMIN.department,
      dateOfJoining: new Date(),
      salary: ADMIN.salary,
      workingHours: ADMIN.workingHours,
      status: ADMIN.status,
    },
    { upsert: true, new: true }
  );

  console.log(`[${company}] Admin seeded: ${employee.email}`);
};

const seed = async () => {
  try {
    await connectDB();

    for (const company of companies) {
      await seedCompanyAdmin(company);
    }

    console.log('All company admins seeded successfully');
    process.exit(0);
  } catch (error) {
    console.error('Admin seeding error:', error);
    process.exit(1);
  }
};

seed();
