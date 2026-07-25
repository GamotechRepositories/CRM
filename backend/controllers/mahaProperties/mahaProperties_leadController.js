import Lead from '../../models/mahaProperties/mahaProperties_lead.js';
import Employee from '../../models/mahaProperties/mahaProperties_employee.js';
import { createLeadDistributionHandlers } from '../../utils/createLeadDistributionHandlers.js';
import { createScopedLeadHandlers } from '../../utils/createScopedLeadHandlers.js';
import { applySiteVisitAssignment } from '../../utils/leadAccess.js';

export const createLead = async (req, res) => {
  try {
    const body = await applySiteVisitAssignment(Employee, req.body);
    const lead = new Lead(body);
    await lead.save();
    const populated = await Lead.findById(lead._id)
      .populate('generatedBy')
      .populate({
        path: 'assignedTo',
        select: 'name email department designation',
        populate: { path: 'designation', select: 'title accessRole' },
      })
      .populate('assignedTeamLeader', 'name email');
    res.status(201).json({ message: 'Lead created successfully', lead: populated });
  } catch (error) {
    const status = error.statusCode || 500;
    res.status(status).json({ message: error.message || 'Error creating lead', error: status === 500 ? error : undefined });
  }
};

export const { getLeads, getLeadById, updateLead, addFollowUp } = createScopedLeadHandlers({
  Lead,
  Employee,
});

export const deleteLead = async (req, res) => {
  try {
    const deleted = await Lead.findByIdAndDelete(req.params.id);
    if (!deleted) return res.status(404).json({ message: 'Lead not found' });
    res.status(200).json({ message: 'Lead deleted successfully' });
  } catch (error) {
    res.status(500).json({ message: 'Error deleting lead', error });
  }
};

export const { previewDistribution, distributeLeads } = createLeadDistributionHandlers({
  Lead,
  Employee,
});
