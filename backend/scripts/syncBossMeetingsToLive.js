/**
 * Sync boss meetings (CentralAdmin_Meeting) from local DB → Render live DB.
 *
 * Default:
 *   source = BangalorePropertiesCRM
 *   target = BangalorePropertiesCRMPROD
 *
 * Usage:
 *   node scripts/syncBossMeetingsToLive.js
 */
import dotenv from 'dotenv';
import mongoose from 'mongoose';

dotenv.config();

const SOURCE_DB = process.env.SYNC_SOURCE_DB || 'BangalorePropertiesCRM';
const TARGET_DB = process.env.SYNC_TARGET_DB || 'BangalorePropertiesCRMPROD';
const COLLECTION = 'centraladmin_meetings';

const swapDb = (uri, dbName) => uri.replace(/\/([^/?]+)(\?|$)/, `/${dbName}$2`);

async function main() {
  if (!process.env.MONGO_URI) {
    console.error('Missing MONGO_URI in backend/.env');
    process.exit(1);
  }

  const sourceUri = swapDb(process.env.MONGO_URI, SOURCE_DB);
  const targetUri = swapDb(process.env.MONGO_URI, TARGET_DB);

  const source = await mongoose.createConnection(sourceUri).asPromise();
  const target = await mongoose.createConnection(targetUri).asPromise();

  const docs = await source.db.collection(COLLECTION).find({}).toArray();
  console.log(`Source ${SOURCE_DB}: ${docs.length} meeting(s)`);

  let created = 0;
  let updated = 0;

  for (const doc of docs) {
    const { _id, ...rest } = doc;
    const result = await target.db.collection(COLLECTION).updateOne(
      { _id },
      { $set: { ...rest } },
      { upsert: true }
    );
    if (result.upsertedCount) {
      created += 1;
      console.log(`Created: ${doc.title} (${_id})`);
    } else {
      updated += 1;
      console.log(`Updated: ${doc.title} (${_id})`);
    }
  }

  const liveCount = await target.db.collection(COLLECTION).countDocuments();
  console.log(`Done. created=${created} updated=${updated}`);
  console.log(`Live ${TARGET_DB} now has ${liveCount} meeting(s)`);

  await source.close();
  await target.close();
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
