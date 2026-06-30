export const TASK_STATUSES = ['Pending', 'In Progress', 'Completed', 'Cancelled'];

export const normalizeTaskStatus = (status) => {
  if (status == null || status === '') return '';
  const value = String(status).trim();
  if (value === 'InProgress' || value.toLowerCase() === 'in progress') return 'In Progress';
  if (TASK_STATUSES.includes(value)) return value;
  return value;
};

export const socialStatusToTaskStatus = (status) => {
  if (status === 'Published') return 'Completed';
  if (status === 'Cancelled') return 'Cancelled';
  if (status === 'Draft') return 'In Progress';
  return 'Pending';
};

export const taskStatusToSocialStatus = (status) => {
  const normalized = normalizeTaskStatus(status);
  if (normalized === 'Completed') return 'Published';
  if (normalized === 'Cancelled') return 'Cancelled';
  if (normalized === 'In Progress') return 'Draft';
  return 'Scheduled';
};
