import dotenv from 'dotenv';
import bcrypt from 'bcryptjs';
import connectDB from '../config/db.js';
import CentralAdminUser, { CENTRAL_TENANTS } from '../models/centralAdmin/centralAdmin_user.js';

dotenv.config();

const ROOT = {
  name: process.env.ADMIN_ROOT_NAME || 'Root Admin',
  email: (process.env.ADMIN_ROOT_EMAIL || 'root@gmail.com').trim().toLowerCase(),
  password: process.env.ADMIN_ROOT_PASSWORD || 'root@2026',
  role: 'CEO',
  isRoot: true,
  status: 'Active',
  tenants: [...CENTRAL_TENANTS],
};

const seed = async () => {
  try {
    await connectDB();

    const hashedPassword = await bcrypt.hash(ROOT.password, 10);

    const user = await CentralAdminUser.findOneAndUpdate(
      { email: ROOT.email },
      {
        name: ROOT.name,
        email: ROOT.email,
        password: hashedPassword,
        role: ROOT.role,
        isRoot: true,
        status: ROOT.status,
        tenants: ROOT.tenants,
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    console.log(`Central CEO seeded: ${user.email} (role=${user.role}, isRoot=${user.isRoot})`);
    console.log(`Tenants: ${user.tenants.join(', ')}`);
    process.exit(0);
  } catch (error) {
    console.error('Central admin seeding error:', error);
    process.exit(1);
  }
};

seed();
