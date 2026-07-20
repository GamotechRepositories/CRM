/**
 * Sync CentralAdminUser from local DB → Render live DB (same Atlas cluster).
 * Copies password hashes so the same email/password works on the mobile app.
 *
 * Default:
 *   source = BangalorePropertiesCRM (local backend)
 *   target = BangalorePropertiesCRMPROD (Render live)
 *
 * Usage:
 *   node scripts/syncCentralAdminsToLive.js
 */
import dotenv from 'dotenv';
import mongoose from 'mongoose';

dotenv.config();

const SOURCE_DB = process.env.SYNC_SOURCE_DB || 'BangalorePropertiesCRM';
const TARGET_DB = process.env.SYNC_TARGET_DB || 'BangalorePropertiesCRMPROD';

const swapDb = (uri, dbName) => uri.replace(/\/([^/?]+)(\?|$)/, `/${dbName}$2`);

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
    if (!email || !user.password) {
      skipped += 1;
      continue;
    }

    const existing = await Model.findOne({ email }).select('+password').lean();
    const payload = {
      name: user.name,
      password: user.password,
      role: user.role,
      isRoot: Boolean(user.isRoot),
      tenants: user.tenants,
      status: user.status || 'Active',
      phone: user.phone || '',
    };

    if (existing) {
      await Model.updateOne({ email }, { $set: payload });
      updated += 1;
      console.log(`Updated: ${email}`);
    } else {
      await Model.create({ email, ...payload });
      created += 1;
      console.log(`Created: ${email}`);
    }
  }

  await conn.close();
  return { created, updated, skipped };
}

async function main() {
  if (!process.env.MONGO_URI) {
    console.error('Missing MONGO_URI in backend/.env');
    process.exit(1);
  }

  const sourceUri = swapDb(process.env.MONGO_URI, SOURCE_DB);
  const targetUri = swapDb(process.env.MONGO_URI, TARGET_DB);

  console.log(`Source: ${SOURCE_DB}`);
  console.log(`Target: ${TARGET_DB} (Render live)`);

  const users = await loadUsers(sourceUri);
  console.log(`Found ${users.length} user(s) in source.`);

  const result = await upsertUsers(targetUri, users);
  console.log(
    `Done. created=${result.created} updated=${result.updated} skipped=${result.skipped}`
  );

  const verify = await loadUsers(targetUri);
  console.log('Live users now:', verify.map((u) => u.email).join(', '));
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
