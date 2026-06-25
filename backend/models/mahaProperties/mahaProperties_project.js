import mongoose from 'mongoose';

const projectSchema = new mongoose.Schema({
  projectName: {
    type: String,
    required: true,
  },
  department: {
    type: String,
    enum: ['IT', 'Marketing'],
    default: 'IT',
  },
  client: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'mahaProperties_Client',
    required: true,
  },
  description: {
    type: String,
  },
  status: {
    type: String,
    enum: ['Not Started', 'In Progress', 'On Hold', 'Completed', 'Cancelled'],
    default: 'Not Started',
  },
  priority: {
    type: String,
    enum: ['Low', 'Medium', 'High', 'Urgent'],
    default: 'Medium',
  },
  startDate: {
    type: Date,
    required: true,
  },
  endDate: {
    type: Date,
  },
  deadline: {
    type: Date,
  },
  budget: {
    type: Number,
  },
  progress: {
    type: Number,
    min: 0,
    max: 100,
    default: 0,
  },
  projectManager: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'mahaProperties_Employee',
  },
  teamMembers: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'mahaProperties_Employee',
  }],
  services: [{
    type: String,
  }],
  notes: {
    type: String,
  },
}, { timestamps: true });

const Project = mongoose.model('mahaProperties_Project', projectSchema);
export default Project;
