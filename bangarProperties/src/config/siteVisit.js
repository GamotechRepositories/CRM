export const SITE_VISIT_STATUSES = [
  'Scheduled',
  'Confirmed',
  'Completed',
  'Cancelled',
  'No Show',
  'Rescheduled',
]

export const SITE_VISIT_TYPES = [
  'First Visit',
  'Follow-up',
  'Inspection',
  'Negotiation',
  'Handover',
  'Other',
]

export const SITE_VISIT_STATUS_STYLES = {
  Scheduled: 'bg-amber-50 text-amber-700 border-amber-200',
  Confirmed: 'bg-blue-50 text-blue-700 border-blue-200',
  Completed: 'bg-emerald-50 text-emerald-700 border-emerald-200',
  Cancelled: 'bg-red-50 text-red-700 border-red-200',
  'No Show': 'bg-gray-100 text-gray-600 border-gray-200',
  Rescheduled: 'bg-purple-50 text-purple-700 border-purple-200',
}

export const emptySiteVisitForm = () => ({
  property: '',
  lead: '',
  visitorName: '',
  visitorPhone: '',
  visitorEmail: '',
  visitType: 'First Visit',
  status: 'Scheduled',
  scheduledDate: '',
  scheduledTime: '10:00',
  durationMinutes: '60',
  assignedTo: '',
  meetingPoint: '',
  address: '',
  city: '',
  notes: '',
  outcome: '',
  interested: '',
  feedback: '',
})

export const siteVisitToForm = (v = {}) => {
  const scheduled = v.scheduledAt ? new Date(v.scheduledAt) : null
  const pad = (n) => String(n).padStart(2, '0')
  return {
    property: v.property?._id || v.property || '',
    lead: v.lead?._id || v.lead || '',
    visitorName: v.visitorName || '',
    visitorPhone: v.visitorPhone || '',
    visitorEmail: v.visitorEmail || '',
    visitType: v.visitType || 'First Visit',
    status: v.status || 'Scheduled',
    scheduledDate: scheduled ? `${scheduled.getFullYear()}-${pad(scheduled.getMonth() + 1)}-${pad(scheduled.getDate())}` : '',
    scheduledTime: scheduled ? `${pad(scheduled.getHours())}:${pad(scheduled.getMinutes())}` : '10:00',
    durationMinutes: String(v.durationMinutes || 60),
    assignedTo: v.assignedTo?._id || v.assignedTo || '',
    meetingPoint: v.meetingPoint || '',
    address: v.address || '',
    city: v.city || '',
    notes: v.notes || '',
    outcome: v.outcome || '',
    interested: v.interested === true ? 'yes' : v.interested === false ? 'no' : '',
    feedback: v.feedback || '',
  }
}

export const formToSiteVisitPayload = (form, createdBy) => {
  const scheduledAt = form.scheduledDate && form.scheduledTime
    ? new Date(`${form.scheduledDate}T${form.scheduledTime}:00`)
    : null
  return {
    property: form.property || null,
    lead: form.lead || null,
    visitorName: form.visitorName,
    visitorPhone: form.visitorPhone,
    visitorEmail: form.visitorEmail,
    visitType: form.visitType,
    status: form.status,
    scheduledAt: scheduledAt && !Number.isNaN(scheduledAt.getTime()) ? scheduledAt.toISOString() : null,
    durationMinutes: Number(form.durationMinutes) || 60,
    assignedTo: form.assignedTo || null,
    meetingPoint: form.meetingPoint,
    address: form.address,
    city: form.city,
    notes: form.notes,
    outcome: form.outcome,
    interested: form.interested === 'yes' ? true : form.interested === 'no' ? false : null,
    feedback: form.feedback,
    createdBy: createdBy || null,
  }
}

export const formatVisitDateTime = (value) => {
  if (!value) return '—'
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleString('en-IN', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  })
}
