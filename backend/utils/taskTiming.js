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

export const assertEmployeeAvailableForTask = async () => {
  // Employees may have multiple open tasks at the same time.
};
