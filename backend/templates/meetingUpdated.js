/**
 * Meeting updated push template.
 * @param {object} params
 * @param {object} params.meeting
 * @returns {{ title: string, body: string, data: object, image: string, priority: string }}
 */
export function meetingUpdatedTemplate({ meeting }) {
  const meetingId = String(meeting?._id || meeting?.id || '');
  return {
    title: 'Meeting Updated',
    body: meeting?.title
      ? `"${meeting.title}" has been updated.`
      : 'A meeting has been updated.',
    data: {
      type: 'meeting',
      screen: 'meeting_details',
      meetingId,
      companyId: String(meeting?.companyId || ''),
      priority: String(meeting?.priority || 'normal'),
      action: 'open_meeting',
    },
    image: '',
    priority: 'normal',
  };
}
