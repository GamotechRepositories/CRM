import dotenv from 'dotenv';
import mongoose from 'mongoose';

dotenv.config();

const dbs = [
  'BangalorePropertiesCRM',
  'BangalorePropertiesCRMPROD',
  'CRM',
  'admin',
  'local',
];

const swapDb = (uri, dbName) =>
  uri.replace(/\/([^/?]+)(\?|$)/, `/${dbName}$2`);

async function main() {
  for (const db of dbs) {
    const uri = swapDb(process.env.MONGO_URI, db);
    const conn = await mongoose.createConnection(uri).asPromise();
    const cols = await conn.db.listCollections().toArray();
    const names = cols.map((c) => c.name).filter((n) => /central|admin|user/i.test(n));
    let users = [];
    const has = names.includes('centraladminusers');
    if (has) {
      users = await conn.db
        .collection('centraladminusers')
        .find({}, { projection: { email: 1, name: 1 } })
        .toArray();
    }
    console.log(`=== ${db} ===`);
    console.log('matching cols:', names.join(', ') || '(none)');
    console.log(
      'centraladminusers:',
      users.map((u) => u.email).join(', ') || '(empty/missing)'
    );
    await conn.close();
  }
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
