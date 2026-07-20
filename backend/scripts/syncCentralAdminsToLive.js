/**
 * Copy CentralAdminUser records from local MongoDB to live MongoDB.
 * Password hashes are copied as-is — same login works on live after sync.
 *
 * Usage:
 *   node scripts/syncCentralAdminsToLive.js "<TARGET_MONGO_URI>"
 *
 * Or set LIVE_MONGO_URI in backend/.env
 */
import dotenv from 'dotenv';
import mongoose from 'mongoose';

dotenv.config();

const SOURCE_URI = process.env.MONGO_URI;
const TARGET_URI = process.argv[2] || process.env.LIVE_MONGO_URI;

if (!SOURCE_URI) {
  console.error('Missing MONGO_URI in backend/.env');
  process.exit(1);
}
if (!TARGET_URI) {
  console.error(
    'Pass live Mongo URI:\n  node scripts/syncCentralAdminsToLive.js "<LIVE_MONGO_URI>"\nOr set LIVE_MONGO_URI in backend/.env'
  );
  process.exit(1);
}

const centralAdminUserSchema = new mongoose.Schema(
  {
    name: String,
    email: { type: String, lowercase: true, trim: true },
    password: { type: String, select: false },
    role: String,
    isRoot: Boolean,
    tenants: [String],
    status: String,
    phone: String,
  },
  { timestamps: true, strict: false }
);

async function loadUsers(uri) {
  const conn = await mongoose.createConnection(uri).asPromise();
  const Model = conn.model('CentralAdminUser', centralAdminUserSchema);
  const users = await Model.find({}).select('+password').lean();
  await conn.close();
  return users;
}

async function upsertUsers(uri, users) {
  const conn = await mongoose.createConnection(uri).asPromise();
  const Model = conn.model('CentralAdminUser', centralAdminUserSchema);
  let created = 0;
  let updated = 0;
  let skipped = 0;

  for (const user of users) {
    const email = String(user.email || '').trim().toLowerCase();
    if (!email) {
      skipped += 1;
      continue;
    }

    const existing = await Model.findOne({ email }).select('+password').lean();
    if (existing) {
      await Model.updateOne(
        { email },
        {
          $set: {
            name: user.name,
            password: user.password,
            role: user.role,
            isRoot: user.isRoot,
            tenants: user.tenants,
            status: user.status,
            phone: user.phone || '',
          },
        }
      );
      updated += 1;
      console.log(`Updated: ${email}`);
    } else {
      await Model.create({
        name: user.name,
        email,
        password: user.password,
        role: user.role,
        isRoot: Boolean(user.isRoot),
        tenants: user.tenants,
        status: user.status || 'Active',
        phone: user.phone || '',
      });
      created += 1;
      console.log(`Created: ${email}`);
    }
  }

  await conn.close();
  return { created, updated, skipped };
}

async function main() {
  console.log('Source:', SOURCE_URI.replace(/\/\/([^:]+):([^@]+)@/, '//***:***@'));
  console.log('Target:', TARGET_URI.replace(/\/\/([^:]+):([^@]+)@/, '//***:***@'));

  const users = await loadUsers(SOURCE_URI);
  console.log(`Found ${users.length} central admin user(s) in source.`);

  const result = await upsertUsers(TARGET_URI, users);
  console.log(`Done. created=${result.created} updated=${result.updated} skipped=${result.skipped}`);
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
