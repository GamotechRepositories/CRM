export const PROPERTY_LEAD_STATUSES = [
  'Call not Received',
  'Call You After Sometime',
  'Interested',
  'Not Interested',
  'Meeting Schedule',
  'Site Visit',
  'Meeting Revisit',
  'Booking Token',
  'Incentive Earned',
  'Pending',
]

export const STR_LEAD_STATUSES = [
  'Call not Received',
  'Call You After Sometime',
  'Interested',
  'Not Interested',
  'Meeting Schedule',
  'Site Visit',
  'Zoom Meeting',
  'Booking Done',
  'Token Done',
  'Pending',
]

export const ADS_LEAD_STATUSES = [
  'Call not Received',
  'Call You After Sometime',
  'Interested',
  'Not Interested',
  'Meeting Schedule',
]

export const leadStatusesForTenant = (tenantId) => {
  if (tenantId === 'adsResearchGlobal') return ADS_LEAD_STATUSES
  if (tenantId === 'salesTechReality') return STR_LEAD_STATUSES
  return PROPERTY_LEAD_STATUSES
}

export const MODULE_TITLES = {
  clients: 'Clients',
  projects: 'Projects',
  leads: 'Leads',
  tasks: 'Tasks',
  invoices: 'Invoices',
  leaves: 'Leaves',
  reports: 'Reports',
  settings: 'Settings',
  expenses: 'Expenses',
  salaries: 'Payroll',
  attendance: 'Attendance',
  properties: 'Properties',
  quotations: 'Quotations',
}
