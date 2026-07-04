import { isLateCheckIn } from './attendanceLate.js';

export const buildEmployeeProfile = async ({ employeeId, models }) => {
  const { Employee, Project, Task, Attendance, Leave, Salary } = models;

  const employee = await Employee.findById(employeeId)
    .populate('designation')
    .populate('reportingManager', 'name email designation employeeCode')
    .lean();

  if (!employee) return null;

  const [managedProjects, teamProjects, tasks, attendance, leaves, salaries] = await Promise.all([
    Project.find({ projectManager: employeeId })
      .populate('client', 'name companyName')
      .select('projectName status priority progress startDate endDate deadline client department')
      .lean(),
    Project.find({ teamMembers: employeeId })
      .populate('client', 'name companyName')
      .select('projectName status priority progress startDate endDate deadline client department projectManager')
      .lean(),
    Task.find({ assignedTo: employeeId, isRecurringTemplate: { $ne: true } })
      .populate('project', 'projectName')
      .populate('rating.ratedBy', 'name designation')
      .select('title status priority dueDate completedAt project estimatedDurationMinutes rating createdAt')
      .sort({ updatedAt: -1 })
      .lean(),
    Attendance.find({ employee: employeeId }).sort({ date: -1 }).limit(60).lean(),
    Leave.find({ employee: employeeId }).sort({ startDate: -1 }).lean(),
    Salary.find({ employee: employeeId }).sort({ year: -1, month: -1 }).lean(),
  ]);

  const presentDays = attendance.filter((a) => ['Full Day', 'Half Day'].includes(a.status)).length;
  const absentDays = attendance.filter((a) => a.status === 'Absent').length;
  const lateMarks = attendance.filter((a) => isLateCheckIn(a.checkIn)).length;

  const leaveBalance = {
    sick: 12 - leaves.filter((l) => l.leaveType === 'Sick' && l.status === 'Approved').reduce((s, l) => s + (l.numberOfDays || 1), 0),
    casual: 12 - leaves.filter((l) => l.leaveType === 'Casual' && l.status === 'Approved').reduce((s, l) => s + (l.numberOfDays || 1), 0),
    annual: 15 - leaves.filter((l) => l.leaveType === 'Annual' && l.status === 'Approved').reduce((s, l) => s + (l.numberOfDays || 1), 0),
  };

  const assignedProjects = [
    ...managedProjects.map((p) => ({ ...p, role: 'Project Manager' })),
    ...teamProjects
      .filter((p) => !managedProjects.some((m) => String(m._id) === String(p._id)))
      .map((p) => ({ ...p, role: 'Team Member' })),
  ];

  const ratedTasks = tasks.filter((t) => t.rating?.score);
  const taskRatingScores = ratedTasks
    .map((t) => Number(t.rating.score))
    .filter((score) => Number.isFinite(score) && score > 0);
  const taskRatingAverage = taskRatingScores.length
    ? Math.round((taskRatingScores.reduce((sum, score) => sum + score, 0) / taskRatingScores.length) * 10) / 10
    : null;

  const taskRatingPerformance = {
    averageRating: taskRatingAverage,
    ratedTaskCount: ratedTasks.length,
    totalAssignedTasks: tasks.length,
    assignedTasks: tasks.map((t) => ({
      taskId: t._id,
      title: t.title,
      projectName: t.project?.projectName || '',
      status: t.status,
      priority: t.priority,
      dueDate: t.dueDate,
      completedAt: t.completedAt,
      createdAt: t.createdAt,
      estimatedDurationMinutes: t.estimatedDurationMinutes,
      ratingScore: t.rating?.score ?? null,
      ratingComments: t.rating?.comments || '',
      ratedAt: t.rating?.ratedAt || null,
      ratedByName: t.rating?.ratedBy?.name || '',
    })),
    ratings: ratedTasks
      .map((t) => ({
        taskId: t._id,
        title: t.title,
        projectName: t.project?.projectName || '',
        score: t.rating.score,
        comments: t.rating.comments || '',
        ratedAt: t.rating.ratedAt,
        ratedByName: t.rating.ratedBy?.name || '',
        status: t.status,
        completedAt: t.completedAt,
      }))
      .sort((a, b) => new Date(b.ratedAt || 0) - new Date(a.ratedAt || 0)),
  };

  return {
    employee,
    assignedProjects,
    tasks,
    taskRatingPerformance,
    attendance: {
      summary: { presentDays, absentDays, lateMarks, totalRecords: attendance.length },
      records: attendance,
      leaveBalance,
      leaveHistory: leaves,
    },
    salaries,
    performance: employee.performance || {},
    skills: employee.skills || {},
    assets: employee.assets || {},
    documents: employee.documents || {},
    access: {
      ...(employee.access || {}),
      crmRole: employee.access?.crmRole || employee.designation?.title || '',
      accountStatus: employee.access?.accountStatus || employee.employmentStatus || employee.status || 'Active',
    },
    notes: employee.notes || {},
  };
};
