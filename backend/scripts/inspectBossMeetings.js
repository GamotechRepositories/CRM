import dotenv from 'dotenv';
import mongoose from 'mongoose';

dotenv.config();

const swapDb = (uri, dbName) => uri.replace(/\/([^/?]+)(\?|$)/, `/${dbName}$2`);

async function inspect(dbName) {
  const conn = await mongoose.createConnection(swapDb(process.env.MONGO_URI, dbName)).asPromise();
  const cols = await conn.db.listCollections().toArray();
  const meetingCols = cols.map((c) => c.name).filter((n) => /meeting/i.test(n));

  console.log(`=== ${dbName} ===`);
  if (!meetingCols.length) {
    console.log('(no meeting collections)');
  }

  for (const col of meetingCols) {
    const count = await conn.db.collection(col).countDocuments();
    const sample = await conn.db
      .collection(col)
      .find({})
      .sort({ createdAt: -1 })
      .limit(5)
      .project({
        title: 1,
        subject: 1,
        startAt: 1,
        endAt: 1,
        status: 1,
        location: 1,
        createdByName: 1,
        createdBy: 1,
        companyTenant: 1,
        createdAt: 1,
      })
      .toArray();
    console.log(`${col}: count=${count}`);
    console.log(JSON.stringify(sample, null, 2));
  }

  await conn.close();
}

async function main() {
  for (const db of ['BangalorePropertiesCRM', 'BangalorePropertiesCRMPROD']) {
    await inspect(db);
  }
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
