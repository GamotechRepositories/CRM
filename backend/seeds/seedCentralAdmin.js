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

const DEMO_TEAM = {
  name: process.env.ADMIN_TEAM_NAME || 'Demo Team Member',
  email: (process.env.ADMIN_TEAM_EMAIL || 'team@gmail.com').trim().toLowerCase(),
  password: process.env.ADMIN_TEAM_PASSWORD || 'team@2026',
  role: 'Executive Assistant',
  isRoot: false,
  status: 'Active',
  tenants: [...CENTRAL_TENANTS],
};

const seed = async () => {
  try {
    await connectDB();

    const rootPassword = await bcrypt.hash(ROOT.password, 10);
    const user = await CentralAdminUser.findOneAndUpdate(
      { email: ROOT.email },
      {
        name: ROOT.name,
        email: ROOT.email,
        password: rootPassword,
        role: ROOT.role,
        isRoot: true,
        status: ROOT.status,
        tenants: ROOT.tenants,
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    const teamPassword = await bcrypt.hash(DEMO_TEAM.password, 10);
    const team = await CentralAdminUser.findOneAndUpdate(
      { email: DEMO_TEAM.email },
      {
        name: DEMO_TEAM.name,
        email: DEMO_TEAM.email,
        password: teamPassword,
        role: DEMO_TEAM.role,
        isRoot: false,
        status: DEMO_TEAM.status,
        tenants: DEMO_TEAM.tenants,
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    console.log(`Central CEO seeded: ${user.email} (role=${user.role}, isRoot=${user.isRoot})`);
    console.log(`Demo team seeded: ${team.email} (role=${team.role})`);
    console.log(`Tenants: ${user.tenants.join(', ')}`);
    process.exit(0);
  } catch (error) {
    console.error('Central admin seeding error:', error);
    process.exit(1);
  }
};

seed();
