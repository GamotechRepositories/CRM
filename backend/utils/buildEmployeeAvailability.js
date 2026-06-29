const startOfDay = (value) => {
  const d = value ? new Date(value) : new Date();
  d.setHours(0, 0, 0, 0);
  return d;
};

const isOnApprovedLeave = (leave, dayStart, dayEnd) => {
  const start = new Date(leave.startDate);
  const end = new Date(leave.endDate);
  start.setHours(0, 0, 0, 0);
  end.setHours(23, 59, 59, 999);
  return leave.status === 'Approved' && start < dayEnd && end >= dayStart;
};

export const buildEmployeeAvailability = async ({ models, date, employeeIds }) => {
  const { Employee, Task, Attendance, Leave } = models;
  const dayStart = startOfDay(date);
  const dayEnd = new Date(dayStart.getTime() + 24 * 60 * 60 * 1000);

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
    }).select('assignedTo estimatedDurationMinutes dueDate status title'),
  ]);

  return employees.map((emp) => {
    const id = String(emp._id);
    const empLeaves = leaves.filter((l) => String(l.employee) === id);
    const onLeave = empLeaves.some((l) => isOnApprovedLeave(l, dayStart, dayEnd));
    const attendance = attendances.find((a) => String(a.employee) === id);
    const tasks = openTasks.filter((t) => String(t.assignedTo) === id);
    const openTaskCount = tasks.length;
    const scheduledMinutes = tasks.reduce((sum, t) => sum + (t.estimatedDurationMinutes || 0), 0);

    let availabilityStatus = 'available';
    let availabilityLabel = 'Available';

    if (emp.employmentStatus && emp.employmentStatus !== 'Active') {
      availabilityStatus = 'inactive';
      availabilityLabel = 'Inactive';
    } else if (onLeave) {
      availabilityStatus = 'on_leave';
      availabilityLabel = 'On approved leave';
    } else if (attendance?.status === 'Absent') {
      availabilityStatus = 'absent';
      availabilityLabel = 'Absent today';
    } else if (attendance?.checkOut) {
      availabilityStatus = 'checked_out';
      availabilityLabel = 'Checked out';
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
      workingHours: emp.workingHours || '',
      availabilityStatus,
      availabilityLabel,
      onLeave,
      openTaskCount,
      scheduledMinutes,
      scheduledHours: Math.round((scheduledMinutes / 60) * 10) / 10,
      attendanceToday: attendance
        ? {
            status: attendance.status,
            checkIn: attendance.checkIn,
            checkOut: attendance.checkOut,
            durationHours: attendance.durationHours,
          }
        : null,
      openTasks: tasks.map((t) => ({
        _id: t._id,
        title: t.title,
        status: t.status,
        dueDate: t.dueDate,
        estimatedDurationMinutes: t.estimatedDurationMinutes,
      })),
    };
  });
};

export const createGetEmployeesAvailabilityHandler = (models) => async (req, res) => {
  try {
    const { date, employeeId } = req.query;
    const employeeIds = employeeId?.trim() ? [employeeId.trim()] : undefined;
    const list = await buildEmployeeAvailability({ models, date, employeeIds });
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
