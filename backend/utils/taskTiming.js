export const getTaskRemainingMinutes = (task, nowMs = Date.now()) => {
  const estimated = Number(task?.estimatedDurationMinutes);
  if (!Number.isFinite(estimated) || estimated <= 0) return null;

  const status = String(task?.status || '').trim();
  if (status === 'In Progress' && task?.startedAt) {
    const startedMs = new Date(task.startedAt).getTime();
    if (!Number.isNaN(startedMs)) {
      const elapsed = Math.floor((nowMs - startedMs) / 60000);
      return Math.max(0, estimated - elapsed);
    }
  }

  return estimated;
};

export const applyTaskStatusTiming = ({ existingStatus, nextStatus, payload = {} }) => {
  const result = { ...payload };

  if (nextStatus === 'In Progress' && existingStatus !== 'In Progress') {
    result.startedAt = result.startedAt || new Date();
  } else if (nextStatus !== 'In Progress') {
    result.startedAt = null;
  }

  return result;
};

export const assertEmployeeAvailableForTask = async (Task, employeeId, excludeTaskId = null) => {
  if (!employeeId) return;

  const filter = {
    assignedTo: employeeId,
    status: { $in: ['Pending', 'In Progress'] },
    isRecurringTemplate: { $ne: true },
  };
  if (excludeTaskId) filter._id = { $ne: excludeTaskId };

  const openCount = await Task.countDocuments(filter);
  if (openCount > 0) {
    const error = new Error('This employee already has an open task and is not available for another assignment');
    error.statusCode = 409;
    throw error;
  }
};
