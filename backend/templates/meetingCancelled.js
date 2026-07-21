/**
 * Meeting cancelled push template.
 * @param {object} params
 * @param {object} params.meeting
 * @returns {{ title: string, body: string, data: object, image: string, priority: string }}
 */
export function meetingCancelledTemplate({ meeting }) {
  const meetingId = String(meeting?._id || meeting?.id || '');
  return {
    title: 'Meeting Cancelled',
    body: meeting?.title
      ? `"${meeting.title}" has been cancelled.`
      : 'A meeting has been cancelled.',
    data: {
      type: 'meeting',
      screen: 'meeting_details',
      meetingId,
      companyId: String(meeting?.companyId || ''),
      priority: 'normal',
      action: 'open_meeting',
    },
    image: '',
    priority: 'normal',
  };
}
