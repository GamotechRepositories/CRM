/**
 * Meeting reminder push template (15 minutes before start).
 * @param {object} params
 * @param {object} params.meeting
 * @returns {{ title: string, body: string, data: object, image: string, priority: string }}
 */
export function meetingReminderTemplate({ meeting }) {
  const meetingId = String(meeting?._id || meeting?.id || '');
  return {
    title: 'Meeting Reminder',
    body: meeting?.title
      ? `"${meeting.title}" starts in 15 minutes.`
      : 'Your meeting starts in 15 minutes.',
    data: {
      type: 'meeting',
      screen: 'meeting_details',
      meetingId,
      companyId: String(meeting?.companyId || ''),
      priority: 'high',
      action: 'open_meeting',
    },
    image: '',
    priority: 'high',
  };
}
