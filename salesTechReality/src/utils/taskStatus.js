export const TASK_STATUSES = ['Pending', 'In Progress', 'Completed', 'Cancelled'];

export const normalizeTaskStatus = (status) => {
  if (status == null || status === '') return '';
  const value = String(status).trim();
  if (value === 'InProgress' || value.toLowerCase() === 'in progress') return 'In Progress';
  if (TASK_STATUSES.includes(value)) return value;
  return value;
};

export const getTaskStatusColor = (status) => {
  switch (normalizeTaskStatus(status)) {
    case 'Completed':
      return 'bg-green-100 text-green-800';
    case 'In Progress':
      return 'bg-blue-100 text-blue-800';
    case 'Pending':
      return 'bg-amber-100 text-amber-800';
    case 'Cancelled':
      return 'bg-gray-100 text-gray-600';
    default:
      return 'bg-gray-100 text-gray-800';
  }
};

export const getTaskRemainingMinutes = (task, nowMs = Date.now()) => {
  const estimated = Number(task?.estimatedDurationMinutes);
  if (!Number.isFinite(estimated) || estimated <= 0) return null;

  if (normalizeTaskStatus(task?.status) === 'In Progress' && task?.startedAt) {
    const startedMs = new Date(task.startedAt).getTime();
    if (!Number.isNaN(startedMs)) {
      const elapsed = Math.floor((nowMs - startedMs) / 60000);
      return Math.max(0, estimated - elapsed);
    }
  }

  return estimated;
};

export const taskStatusToSocialStatus = (status) => {
  const normalized = normalizeTaskStatus(status);
  if (normalized === 'Completed') return 'Published';
  if (normalized === 'Cancelled') return 'Cancelled';
  if (normalized === 'In Progress') return 'Draft';
  return 'Scheduled';
};

export const formatTaskDuration = (minutes) => {
  const mins = Number(minutes);
  if (!Number.isFinite(mins) || mins <= 0) return null;
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  if (h && m) return `${h}h ${m}m`;
  if (h) return `${h}h`;
  return `${m}m`;
};
