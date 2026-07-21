/**
 * System notification push template.
 * @param {object} params
 * @param {string} params.title
 * @param {string} params.body
 * @param {object} [params.extraData]
 * @returns {{ title: string, body: string, data: object, image: string, priority: string }}
 */
export function systemNotificationTemplate({ title, body, extraData = {} }) {
  return {
    title: title || 'System Notification',
    body: body || '',
    data: {
      type: 'system',
      screen: 'notifications',
      meetingId: '',
      companyId: String(extraData.companyId || ''),
      priority: String(extraData.priority || 'normal'),
      action: 'open_notifications',
      ...extraData,
    },
    image: String(extraData.image || ''),
    priority: String(extraData.priority || 'normal'),
  };
}
