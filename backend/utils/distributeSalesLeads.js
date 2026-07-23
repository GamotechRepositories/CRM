import { endOfBusinessDay, startOfBusinessDay } from './businessTime.js';

const isSalesDepartment = (value = '') =>
  /sales/i.test(String(value || '').trim());

const isTeamLeaderDesignation = (designation) => {
  if (!designation) return false;
  if (String(designation.accessRole || '').trim() === 'team_leader') return true;
  const title = String(designation.title || '').toLowerCase();
  return title.includes('team leader') || title.includes('team lead') || title.includes('sales team lead');
};

/**
 * Split `items` into `bucketCount` arrays as evenly as possible.
 * Remainder (odd extras) go to the first buckets (+1 each).
 */
export const splitEvenly = (items = [], bucketCount = 1) => {
  const n = Math.max(1, Number(bucketCount) || 1);
  const list = Array.isArray(items) ? [...items] : [];
  const buckets = Array.from({ length: n }, () => []);
  if (!list.length) return buckets;

  const base = Math.floor(list.length / n);
  const rem = list.length % n;
  let cursor = 0;
  for (let i = 0; i < n; i += 1) {
    const size = base + (i < rem ? 1 : 0);
    buckets[i] = list.slice(cursor, cursor + size);
    cursor += size;
  }
  return buckets;
};

export const findSalesTeamLeaders = async (Employee) => {
  const employees = await Employee.find({ status: 'Active' })
    .populate('designation', 'title accessRole department')
    .select('name email department designation reportingManager status')
    .sort({ name: 1 });

  return employees.filter(
    (emp) => isSalesDepartment(emp.department) && isTeamLeaderDesignation(emp.designation)
  );
};

export const findTeamMembersForLeader = async (Employee, teamLeaderId) => {
  const members = await Employee.find({
    status: 'Active',
    reportingManager: teamLeaderId,
  })
    .populate('designation', 'title accessRole')
    .select('name email department designation reportingManager status')
    .sort({ name: 1 });

  // Prefer Sales-department reportees; if none tagged Sales, use all reportees.
  const salesMembers = members.filter((m) => isSalesDepartment(m.department));
  return salesMembers.length ? salesMembers : members;
};

export const buildLeadDistributionPlan = async ({
  Lead,
  Employee,
  date,
  leadIds,
}) => {
  const dayStart = startOfBusinessDay(date || new Date());
  const dayEnd = endOfBusinessDay(date || new Date());

  const leadFilter = {
    $or: [{ assignedTo: null }, { assignedTo: { $exists: false } }],
  };

  if (Array.isArray(leadIds) && leadIds.length) {
    leadFilter._id = { $in: leadIds };
  } else {
    leadFilter.createdAt = { $gte: dayStart, $lt: dayEnd };
  }

  const [leads, teamLeaders] = await Promise.all([
    Lead.find(leadFilter).sort({ createdAt: 1 }).select('_id name contactNumber createdAt'),
    findSalesTeamLeaders(Employee),
  ]);

  if (!teamLeaders.length) {
    const error = new Error(
      'No Sales Team Leaders found. Ensure Active employees in Sales department have Team Leader designation/access role.'
    );
    error.statusCode = 400;
    throw error;
  }

  if (!leads.length) {
    return {
      totalLeads: 0,
      teamLeaderCount: teamLeaders.length,
      dayStart,
      dayEnd,
      assignments: [],
      plan: teamLeaders.map((tl) => ({
        teamLeader: { _id: tl._id, name: tl.name, email: tl.email },
        leadCount: 0,
        members: [],
      })),
    };
  }

  const leaderBuckets = splitEvenly(leads, teamLeaders.length);
  const plan = [];
  const assignments = [];

  for (let i = 0; i < teamLeaders.length; i += 1) {
    const tl = teamLeaders[i];
    const bucket = leaderBuckets[i] || [];
    let members = await findTeamMembersForLeader(Employee, tl._id);

    // If TL has no team, assign the pool to the team leader themselves.
    if (!members.length) {
      members = [tl];
    }

    const memberBuckets = splitEvenly(bucket, members.length);
    const memberPlan = members.map((member, idx) => {
      const memberLeads = memberBuckets[idx] || [];
      for (const lead of memberLeads) {
        assignments.push({
          leadId: lead._id,
          assignedTo: member._id,
          assignedTeamLeader: tl._id,
        });
      }
      return {
        employee: { _id: member._id, name: member.name, email: member.email },
        leadCount: memberLeads.length,
        leadIds: memberLeads.map((l) => l._id),
      };
    });

    plan.push({
      teamLeader: { _id: tl._id, name: tl.name, email: tl.email },
      leadCount: bucket.length,
      members: memberPlan,
    });
  }

  return {
    totalLeads: leads.length,
    teamLeaderCount: teamLeaders.length,
    dayStart,
    dayEnd,
    plan,
    assignments,
  };
};

export const applyLeadDistribution = async ({
  Lead,
  assignments,
  distributedBy,
  now = new Date(),
}) => {
  if (!assignments?.length) return { updated: 0 };

  const ops = assignments.map((row) => ({
    updateOne: {
      filter: {
        _id: row.leadId,
        $or: [{ assignedTo: null }, { assignedTo: { $exists: false } }],
      },
      update: {
        $set: {
          assignedTo: row.assignedTo,
          assignedTeamLeader: row.assignedTeamLeader,
          assignedAt: now,
          distributedBy: distributedBy || null,
        },
      },
    },
  }));

  const result = await Lead.bulkWrite(ops, { ordered: false });
  return { updated: result.modifiedCount || 0 };
};
