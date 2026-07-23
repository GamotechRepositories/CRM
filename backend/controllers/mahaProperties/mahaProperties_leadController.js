import Lead from '../../models/mahaProperties/mahaProperties_lead.js';
import Employee from '../../models/mahaProperties/mahaProperties_employee.js';
import { createLeadDistributionHandlers } from '../../utils/createLeadDistributionHandlers.js';
import { createScopedLeadHandlers } from '../../utils/createScopedLeadHandlers.js';

export const createLead = async (req, res) => {
  try {
    const lead = new Lead(req.body);
    await lead.save();
    const populated = await Lead.findById(lead._id)
      .populate('generatedBy')
      .populate('assignedTo', 'name email department')
      .populate('assignedTeamLeader', 'name email');
    res.status(201).json({ message: 'Lead created successfully', lead: populated });
  } catch (error) {
    res.status(500).json({ message: 'Error creating lead', error });
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
