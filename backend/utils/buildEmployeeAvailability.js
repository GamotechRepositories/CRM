import { getTaskRemainingMinutes } from './taskTiming.js';
import {
  buildWorkingTimeline,
  getTaskScheduledRange,
  parseWorkingHours,
} from './workingHoursTimeline.js';

const startOfDay = (value) => {
  const d = value ? new Date(value) : new Date();
  d.setHours(0, 0, 0, 0);
  return d;
};

const formatDurationLabel = (minutes) => {
  const mins = Number(minutes);
  if (!Number.isFinite(mins) || mins <= 0) return null;
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  if (h && m) return `${h}h ${m}m`;
  if (h) return `${h}h`;
  return `${m}m`;
};

const isOnApprovedLeave = (leave, dayStart, dayEnd) => {
  const start = new Date(leave.startDate);
  const end = new Date(leave.endDate);
  start.setHours(0, 0, 0, 0);
  end.setHours(23, 59, 59, 999);
  return leave.status === 'Approved' && start < dayEnd && end >= dayStart;
};

const isTaskScheduledOnDay = (task, dayStart) => {
  const range = getTaskScheduledRange(task);
  if (range) {
    const taskDay = new Date(range.start);
    taskDay.setHours(0, 0, 0, 0);
    return taskDay.getTime() === dayStart.getTime();
  }
  if (!task?.dueDate) return false;
  const dueDay = new Date(task.dueDate);
  dueDay.setHours(0, 0, 0, 0);
  return dueDay.getTime() === dayStart.getTime();
};

export const buildEmployeeAvailability = async ({
  models,
  date,
  employeeIds,
  excludeTaskId,
  now = new Date(),
}) => {
  const { Employee, Task, Attendance, Leave, Company } = models;
  const dayStart = startOfDay(date);
  const dayEnd = new Date(dayStart.getTime() + 24 * 60 * 60 * 1000);

  const company = Company ? await Company.findOne().sort({ createdAt: 1 }).select('workingHours').lean() : null;
  const companyWorkingHours = String(company?.workingHours || '').trim() || null;

  const empFilter = { status: 'Active' };
  if (employeeIds?.length) {
    empFilter._id = { $in: employeeIds };
  }

  const employees = await Employee.find(empFilter)
    .select('name workingHours status employmentStatus')
    .populate('designation', 'title')
    .sort({ name: 1 });

  const ids = employees.map((e) => e._id);
  if (!ids.length) return [];

  const [leaves, attendances, openTasks] = await Promise.all([
    Leave.find({
      employee: { $in: ids },
      status: 'Approved',
      startDate: { $lt: dayEnd },
      endDate: { $gte: dayStart },
    }).select('employee startDate endDate status'),
    Attendance.find({
      employee: { $in: ids },
      date: { $gte: dayStart, $lt: dayEnd },
    }).select('employee status checkIn checkOut durationHours'),
    Task.find({
      assignedTo: { $in: ids },
      status: { $in: ['Pending', 'In Progress'] },
      isRecurringTemplate: { $ne: true },
    }).select(
      'assignedTo estimatedDurationMinutes dueDate status title startedAt scheduledStartAt scheduledEndAt'
    ),
  ]);

  return employees.map((emp) => {
    const id = String(emp._id);
    const empLeaves = leaves.filter((l) => String(l.employee) === id);
    const onLeave = empLeaves.some((l) => isOnApprovedLeave(l, dayStart, dayEnd));
    const attendance = attendances.find((a) => String(a.employee) === id);
    const tasks = openTasks
      .filter((t) => String(t.assignedTo) === id)
      .filter((t) => !excludeTaskId || String(t._id) !== String(excludeTaskId));
    const dayTasks = tasks.filter((t) => isTaskScheduledOnDay(t, dayStart));
    const openTaskCount = dayTasks.length;
    const scheduledMinutes = dayTasks.reduce((sum, t) => sum + (t.estimatedDurationMinutes || 0), 0);
    const inProgressTask = dayTasks.find((t) => t.status === 'In Progress') || null;
    const activeTask = inProgressTask || dayTasks[0] || null;
    const remainingMinutes = dayTasks.reduce((sum, t) => sum + (getTaskRemainingMinutes(t, now.getTime()) || 0), 0);
    const activeTaskRemainingMinutes = activeTask ? getTaskRemainingMinutes(activeTask) : null;
    const isAllocated = openTaskCount > 0;

    const occupiedRanges = dayTasks
      .map((task) => {
        const range = getTaskScheduledRange(task);
        if (!range) return null;
        const taskDay = new Date(range.start);
        taskDay.setHours(0, 0, 0, 0);
        if (taskDay.getTime() !== dayStart.getTime()) return null;
        return {
          startMinutes: range.start.getHours() * 60 + range.start.getMinutes(),
          endMinutes: range.end.getHours() * 60 + range.end.getMinutes(),
          title: task.title,
        };
      })
      .filter(Boolean);

    // Company working hours define the timeline; employee workingHours is a legacy fallback.
    const effectiveWorkingHours = companyWorkingHours || emp.workingHours;

    const timeline = buildWorkingTimeline({
      workingHours: effectiveWorkingHours,
      date: dayStart,
      occupiedRanges,
      now,
    });

    let availabilityStatus = 'available';
    let availabilityLabel = 'Available';
    let isAssignable = true;

    if (emp.employmentStatus && emp.employmentStatus !== 'Active') {
      availabilityStatus = 'inactive';
      availabilityLabel = 'Inactive';
      isAssignable = false;
    } else if (onLeave) {
      availabilityStatus = 'on_leave';
      availabilityLabel = 'On approved leave';
      isAssignable = false;
    } else if (attendance?.status === 'Absent') {
      availabilityStatus = 'absent';
      availabilityLabel = 'Absent today';
      isAssignable = false;
    } else if (attendance?.checkOut) {
      availabilityStatus = 'checked_out';
      availabilityLabel = 'Checked out';
      isAssignable = false;
    } else if (isAllocated) {
      availabilityStatus = 'allocated';
      const remainingLabel = formatDurationLabel(activeTaskRemainingMinutes ?? remainingMinutes);
      availabilityLabel = inProgressTask
        ? `On task — ${remainingLabel || 'in progress'} remaining`
        : `Allocated — ${openTaskCount} open task${openTaskCount === 1 ? '' : 's'}`;
    } else if (openTaskCount >= 6 || scheduledMinutes >= 480) {
      availabilityStatus = 'busy';
      availabilityLabel = 'Heavily loaded';
    } else if (openTaskCount >= 3 || scheduledMinutes >= 300) {
      availabilityStatus = 'moderate';
      availabilityLabel = 'Moderate load';
    }

    return {
      employeeId: emp._id,
      name: emp.name,
      designation: emp.designation?.title || '',
      workingHours: effectiveWorkingHours || '',
      workingHoursParsed: parseWorkingHours(effectiveWorkingHours),
      workingHoursSource: companyWorkingHours ? 'company' : 'employee',
      timeline,
      serverNow: now.toISOString(),
      availabilityStatus,
      availabilityLabel,
      isAssignable,
      onLeave,
      openTaskCount,
      scheduledMinutes,
      remainingMinutes,
      activeTaskRemainingMinutes,
      remainingTimeLabel: formatDurationLabel(activeTaskRemainingMinutes ?? remainingMinutes),
      activeTask: activeTask
        ? {
            _id: activeTask._id,
            title: activeTask.title,
            status: activeTask.status,
            dueDate: activeTask.dueDate,
            estimatedDurationMinutes: activeTask.estimatedDurationMinutes,
            startedAt: activeTask.startedAt,
            remainingMinutes: getTaskRemainingMinutes(activeTask),
            remainingTimeLabel: formatDurationLabel(getTaskRemainingMinutes(activeTask)),
          }
        : null,
      scheduledHours: Math.round((scheduledMinutes / 60) * 10) / 10,
      attendanceToday: attendance
        ? {
            status: attendance.status,
            checkIn: attendance.checkIn,
            checkOut: attendance.checkOut,
            durationHours: attendance.durationHours,
          }
        : null,
      openTasks: dayTasks.map((t) => ({
        _id: t._id,
        title: t.title,
        status: t.status,
        dueDate: t.dueDate,
        estimatedDurationMinutes: t.estimatedDurationMinutes,
        startedAt: t.startedAt,
        remainingMinutes: getTaskRemainingMinutes(t),
        remainingTimeLabel: formatDurationLabel(getTaskRemainingMinutes(t)),
      })),
    };
  });
};

export const createGetEmployeesAvailabilityHandler = (models) => async (req, res) => {
  try {
    const { date, employeeId, excludeTaskId } = req.query;
    const employeeIds = employeeId?.trim() ? [employeeId.trim()] : undefined;
    const now = new Date();
    const list = await buildEmployeeAvailability({
      models,
      date,
      employeeIds,
      excludeTaskId: excludeTaskId?.trim() || undefined,
      now,
    });
    if (employeeId?.trim()) {
      const match = list.find((item) => String(item.employeeId) === employeeId.trim());
      return res.status(200).json(match || null);
    }
    res.status(200).json(list);
  } catch (error) {
    res.status(500).json({
      message: 'Error fetching employee availability',
      error: error?.message || error,
    });
  }
};
