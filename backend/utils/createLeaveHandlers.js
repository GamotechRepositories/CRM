import { emitToUser } from '../services/realtimeNotification.service.js';

const STAGE_ORDER = ['hr', 'admin', 'completed'];

const getNumberOfDays = (startDate, endDate) => {
  const start = new Date(startDate);
  const end = new Date(endDate);
  start.setHours(0, 0, 0, 0);
  end.setHours(0, 0, 0, 0);
  return Math.max(1, Math.ceil((end - start) / (1000 * 60 * 60 * 24)) + 1);
};

const getRole = (employee) => {
  const designation = employee?.designation;
  const accessRole = String(designation?.accessRole || '').trim().toLowerCase();
  const title = String(designation?.title || designation?.name || '').trim().toLowerCase();
  if (
    accessRole === 'hr' ||
    accessRole === 'hr_manager' ||
    title === 'hr manager' ||
    title === 'hr' ||
    title.includes('human resource') ||
    title.includes('hr ') ||
    title.startsWith('hr')
  ) {
    return 'hr';
  }
  if (
    title === 'chief operating officer' ||
    title.includes('chief operating officer') ||
    title === 'coo' ||
    title.includes('coo')
  ) {
    return 'coo';
  }
  if (accessRole === 'admin' || title === 'admin') return 'admin';
  if (title === 'team leader' || title.includes('team lead') || accessRole === 'team_leader') return 'team_leader';
  if (title.includes('manager') || accessRole === 'manager') return 'manager';
  if (accessRole) return accessRole;
  return 'employee';
};

const getInitialStage = (employee) => {
  const role = getRole(employee);
  // If HR or COO applies for leave, escalate to admin; otherwise leave is approved by HR / COO
  if (role === 'hr' || role === 'coo') return 'admin';
  return 'hr';
};

const canActAtStage = (role, stage) => {
  // Both HR and Chief Operating Officer can approve leaves
  if (role === 'hr' || role === 'coo') return stage === 'hr' || stage === 'admin' || stage === 'team_leader';
  // Admin can act on 'admin' stage or as system administrator fallback
  if (role === 'admin') return stage === 'admin' || stage === 'hr' || stage === 'team_leader';
  return false;
};

const nextStage = (stage) => {
  const index = STAGE_ORDER.indexOf(stage);
  return index >= 0 ? STAGE_ORDER[index + 1] : 'completed';
};

const populateLeave = (Leave, id) =>
  Leave.findById(id)
    .populate({ path: 'employee', populate: { path: 'designation' } })
    .populate({ path: 'approvedBy', populate: { path: 'designation' } })
    .populate('approvalHistory.actor');

const notify = async (Notification, payload) => {
  if (!Notification) return;
  try {
    const doc = await Notification.create(payload);
    emitToUser(String(payload.recipient), doc);
  } catch {
    // A notification failure must not roll back a valid leave transition.
  }
};

const notifyStageApprovers = async ({ Employee, Notification, stage, leave, actor = null }) => {
  if (!Notification || stage === 'central_admin' || stage === 'completed') return;
  const candidates = await Employee.find({ status: 'Active' }).populate('designation').lean();
  const approvers = candidates.filter((employee) => canActAtStage(getRole(employee), stage));
  await Promise.all(approvers.map((approver) => notify(Notification, {
    recipient: approver._id,
    type: 'leave_status',
    title: 'Leave request awaiting review',
    message: `${leave.employee?.name || 'An employee'} submitted a ${leave.leaveType} leave request.`,
    link: '/leave',
    priority: 'high',
    metadata: {
      entityType: 'leave',
      entityId: leave._id,
      actor,
      extra: { stage },
    },
  })));
};

export const createLeaveHandlers = ({ Leave, Employee, Notification }) => {
  const createLeave = async (req, res) => {
    try {
      const { employee, leaveType, startDate, endDate, reason } = req.body;
      if (!employee || !leaveType || !startDate || !endDate) {
        return res.status(400).json({ message: 'Employee, leave type, start date and end date are required' });
      }
      const start = new Date(startDate);
      const end = new Date(endDate);
      if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || end < start) {
        return res.status(400).json({ message: 'End date must be on or after start date' });
      }
      const applicant = await Employee.findById(employee).populate('designation');
      if (!applicant) return res.status(404).json({ message: 'Employee not found' });

      const approvalStage = getInitialStage(applicant);
      const leave = await Leave.create({
        employee,
        leaveType,
        startDate: start,
        endDate: end,
        reason: reason || '',
        numberOfDays: getNumberOfDays(start, end),
        approvalStage,
        approvalHistory: [{
          stage: approvalStage,
          action: 'Submitted',
          actor: employee,
          actorName: applicant.name || '',
          actorRole: getRole(applicant),
          comment: reason || '',
        }],
      });
      const populated = await populateLeave(Leave, leave._id);
      await notifyStageApprovers({ Employee, Notification, stage: approvalStage, leave: populated, actor: employee });
      return res.status(201).json({ message: 'Leave application submitted', leave: populated });
    } catch (error) {
      return res.status(500).json({ message: 'Error creating leave application', error: error?.message || error });
    }
  };

  const getLeaves = async (req, res) => {
    try {
      const { employeeId, status, approvalStage } = req.query;
      const filter = {};
      if (employeeId?.trim()) filter.employee = employeeId.trim();
      if (status?.trim()) filter.status = status.trim();
      if (approvalStage?.trim()) filter.approvalStage = approvalStage.trim();
      const leaves = await Leave.find(filter)
        .populate({ path: 'employee', populate: { path: 'designation' } })
        .populate({ path: 'approvedBy', populate: { path: 'designation' } })
        .populate('approvalHistory.actor')
        .sort({ createdAt: -1 });
      return res.status(200).json(leaves);
    } catch (error) {
      return res.status(500).json({ message: 'Error fetching leaves', error: error?.message || error });
    }
  };

  const getLeaveById = async (req, res) => {
    try {
      const leave = await populateLeave(Leave, req.params.id);
      if (!leave) return res.status(404).json({ message: 'Leave not found' });
      return res.status(200).json(leave);
    } catch (error) {
      return res.status(500).json({ message: 'Error fetching leave', error: error?.message || error });
    }
  };

  const updateLeaveStatus = async (req, res) => {
    try {
      const rawAction = String(req.body?.action || req.body?.status || '').trim();
      const action = ['Approve', 'Approved'].some((a) => a.toLowerCase() === rawAction.toLowerCase())
        ? 'Approve'
        : ['Reject', 'Rejected'].some((a) => a.toLowerCase() === rawAction.toLowerCase())
        ? 'Reject'
        : rawAction.toLowerCase() === 'forward'
        ? 'Approve'
        : rawAction;
      const actorId = req.body?.actorId || req.body?.approvedBy;
      const comment = String(req.body?.comment || req.body?.rejectionReason || '').trim();
      if (!['Approve', 'Reject'].includes(action)) {
        return res.status(400).json({ message: 'Action must be Approve or Reject' });
      }
      if (!actorId) return res.status(400).json({ message: 'The acting employee is required' });

      const [leave, actor] = await Promise.all([
        Leave.findById(req.params.id),
        Employee.findById(actorId).populate('designation'),
      ]);
      if (!leave) return res.status(404).json({ message: 'Leave not found' });
      if (!actor) return res.status(404).json({ message: 'Acting employee not found' });
      if (leave.status !== 'Pending') {
        return res.status(400).json({ message: 'Leave has already received a final decision' });
      }
      const stage = leave.approvalStage || 'hr';
      if (String(leave.employee) === String(actor._id)) {
        return res.status(403).json({ message: 'You cannot process your own leave request' });
      }
      const actorRole = getRole(actor);
      if (!canActAtStage(actorRole, stage)) {
        return res.status(403).json({ message: 'Leave applications can only be approved by HR or Chief Operating Officer' });
      }

      const actedAt = new Date();
      if (action === 'Reject') {
        leave.status = 'Rejected';
        leave.approvalStage = 'completed';
        leave.rejectionReason = comment;
        leave.approvedBy = actor._id;
        leave.approvedAt = actedAt;
        leave.approvalHistory.push({
          stage,
          action: 'Rejected',
          actor: actor._id,
          actorName: actor.name || '',
          actorRole,
          comment,
          actedAt,
        });
        await leave.save();
        await notify(Notification, {
          recipient: leave.employee,
          type: 'leave_status',
          title: 'Leave request rejected',
          message: comment ? `Your leave request was rejected: ${comment}` : 'Your leave request was rejected.',
          link: '/leave',
          priority: 'high',
          metadata: { entityType: 'leave', entityId: leave._id, actor: actor._id, extra: { stage } },
        });
        const populated = await populateLeave(Leave, leave._id);
        return res.status(200).json({ message: 'Leave rejected', leave: populated });
      }

      // Approve action: HR grants direct approval
      leave.status = 'Approved';
      leave.approvalStage = 'completed';
      leave.approvedBy = actor._id;
      leave.approvedAt = actedAt;
      leave.rejectionReason = '';
      leave.approvalHistory.push({
        stage,
        action: 'Approved',
        actor: actor._id,
        actorName: actor.name || '',
        actorRole,
        comment,
        actedAt,
      });
      await leave.save();
      await notify(Notification, {
        recipient: leave.employee,
        type: 'leave_status',
        title: 'Leave request approved',
        message: comment ? `Your leave request was approved: ${comment}` : `Your ${leave.leaveType} leave request for ${leave.numberOfDays || 1} day(s) was approved.`,
        link: '/leave',
        priority: 'high',
        metadata: { entityType: 'leave', entityId: leave._id, actor: actor._id, extra: { stage } },
      });
      const populated = await populateLeave(Leave, leave._id);
      return res.status(200).json({
        message: 'Leave approved successfully',
        leave: populated,
      });
    } catch (error) {
      return res.status(500).json({ message: 'Error updating leave status', error: error?.message || error });
    }
  };

  return { createLeave, getLeaves, getLeaveById, updateLeaveStatus };
};
