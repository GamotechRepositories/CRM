import mongoose from 'mongoose';
const designationSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    unique: true,
  },
  description: {
    type: String,
  },
});

const Designation = mongoose.model('bangarProperties_Designation', designationSchema);
export default Designation;