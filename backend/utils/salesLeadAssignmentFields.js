import mongoose from 'mongoose';

/** Assignment fields for sales-team lead distribution. */
export const getSalesLeadAssignmentFields = (employeeRef) => ({
  /** Sales employee this lead is assigned to (Sales department). */
  assignedTo: {
    type: mongoose.Schema.Types.ObjectId,
    ref: employeeRef,
    default: null,
    index: true,
  },
  /** Sales Team Leader whose pool this lead was taken from. */
  assignedTeamLeader: {
    type: mongoose.Schema.Types.ObjectId,
    ref: employeeRef,
    default: null,
    index: true,
  },
  assignedAt: {
    type: Date,
    default: null,
  },
  distributedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: employeeRef,
    default: null,
  },
});
