/**
 * Meeting assigned push template.
 * @param {object} params
 * @param {object} params.meeting
 * @returns {{ title: string, body: string, data: object, image: string, priority: string }}
 */
export function meetingAssignedTemplate({ meeting }) {
  const meetingId = String(meeting?._id || meeting?.id || '');
  return {
    title: 'New Meeting Assigned',
    body: meeting?.title
      ? `You have a new meeting scheduled: ${meeting.title}.`
      : 'You have a new meeting scheduled.',
    data: {
      type: 'meeting',
      screen: 'meeting_details',
      meetingId,
      companyId: String(meeting?.companyId || ''),
      priority: String(meeting?.priority || 'normal'),
      action: 'open_meeting',
    },
    image: '',
    priority: meeting?.priority === 'critical' || meeting?.priority === 'high' ? 'high' : 'normal',
  };
}
