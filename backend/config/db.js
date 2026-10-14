import mongoose from 'mongoose';
import dotenv from 'dotenv';

dotenv.config();

const dropLegacyTravelJourneyIndexes = async () => {
  const collections = [
    'salestechreality_traveljourneys',
    'bangarproperties_traveljourneys',
    'mahaproperties_traveljourneys',
  ];
  for (const colName of collections) {
    try {
      const collection = mongoose.connection.db.collection(colName);
      const indexes = await collection.indexes();
      const legacyUniqueIndex = indexes.find((i) => i.name === 'employee_1_date_1' && i.unique);
      if (legacyUniqueIndex) {
        await collection.dropIndex('employee_1_date_1');
        console.log(`[db] Dropped legacy unique index employee_1_date_1 from ${colName}`);
      }
    } catch (err) {
      // Ignore if collection doesn't exist or index already dropped
    }
  }
};

const connectDB = async () => {
  try {
    await mongoose.connect(process.env.MONGO_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    console.log('MongoDB connected successfully');
    await dropLegacyTravelJourneyIndexes();
  } catch (error) {
    console.error('MongoDB connection error:', error);
    process.exit(1); // Exit with failure
  }
};

export default connectDB;