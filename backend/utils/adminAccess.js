import { getDefaultDesignationMeta } from './designationFields.js';

export const ALL_SIDEBAR_SECTION_IDS = [
  'dashboard',
  'crm',
  'projects',
  'employees',
  'finance',
  'inventory',
  'sales',
  'support',
  'marketing',
  'documents',
  'company',
  'reports',
  'approvals',
  'communication',
  'administration',
  'workspace',
];

export const isAdminEmployee = (user) => {
  const title = String(user?.designation?.title || user?.designation?.name || '').trim().toLowerCase();
  const accessRole = String(user?.designation?.accessRole || '').trim().toLowerCase();
  return title === 'admin' || accessRole === 'admin';
};

export const enrichLoginUser = (user) => {
  if (!user || !isAdminEmployee(user)) return user;

  const adminMeta = getDefaultDesignationMeta('Admin');
  return {
    ...user,
    designation: {
      ...user.designation,
      title: user.designation?.title || 'Admin',
      accessRole: 'admin',
      permissions: { ...adminMeta.permissions },
    },
    access: {
      ...(user.access || {}),
      sidebarSections: ALL_SIDEBAR_SECTION_IDS,
    },
  };
};
