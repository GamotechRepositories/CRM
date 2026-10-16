const TASK_NOTIFY_AUDIO_SRC = '/butty_notify.mp3'
const TASK_APPROVAL_AUDIO_SRC = '/task_approval.mp3'
const TASK_SUCCEED_AUDIO_SRC = '/task_succeed.mp3'
const TASK_REJECTED_AUDIO_SRC = '/task_rejected.mp3'

let audioInstance = null
let approvalAudioInstance = null
let succeedAudioInstance = null
let rejectedAudioInstance = null
let notificationPermissionRequested = false

export const initTaskAssignmentAudio = () => {
  if (!audioInstance) {
    audioInstance = new Audio(TASK_NOTIFY_AUDIO_SRC)
    audioInstance.preload = 'auto'
  }
  return audioInstance
}

export const initTaskApprovalAudio = () => {
  if (!approvalAudioInstance) {
    approvalAudioInstance = new Audio(TASK_APPROVAL_AUDIO_SRC)
    approvalAudioInstance.preload = 'auto'
  }
  return approvalAudioInstance
}

export const initTaskSucceedAudio = () => {
  if (!succeedAudioInstance) {
    succeedAudioInstance = new Audio(TASK_SUCCEED_AUDIO_SRC)
    succeedAudioInstance.preload = 'auto'
  }
  return succeedAudioInstance
}

export const initTaskRejectedAudio = () => {
  if (!rejectedAudioInstance) {
    rejectedAudioInstance = new Audio(TASK_REJECTED_AUDIO_SRC)
    rejectedAudioInstance.preload = 'auto'
  }
  return rejectedAudioInstance
}

const playAudioSafe = (audio) => {
  if (!audio) return
  try {
    audio.currentTime = 0
    audio.play().catch(() => {})
  } catch {
    // Ignore audio errors silently.
  }
}

export const enableTaskAssignmentAlerts = async () => {
  const audios = [
    initTaskAssignmentAudio(),
    initTaskApprovalAudio(),
    initTaskSucceedAudio(),
    initTaskRejectedAudio(),
  ]

  for (const audio of audios) {
    if (!audio) continue
    try {
      audio.volume = 0.01
      audio.currentTime = 0
      await audio.play()
      audio.pause()
      audio.currentTime = 0
      audio.volume = 1
    } catch {
      // Browser may still block until a later user gesture.
    }
  }

  if (!notificationPermissionRequested && typeof window !== 'undefined' && 'Notification' in window) {
    notificationPermissionRequested = true
    if (Notification.permission === 'default') {
      try {
        await Notification.requestPermission()
      } catch {
        // Ignore permission errors.
      }
    }
  }
}

export const notifyNewTaskAssigned = ({
  pendingCount = 1,
  navigate,
} = {}) => {
  const audio = initTaskAssignmentAudio()
  playAudioSafe(audio)

  if (typeof window === 'undefined' || !('Notification' in window)) return
  if (Notification.permission !== 'granted') return

  const body = pendingCount === 1
    ? 'You have a new pending task. Open My Tasks to accept it.'
    : `You have ${pendingCount} pending tasks waiting for you.`

  try {
    const notification = new Notification('New task assigned', {
      body,
      icon: '/chat-bot.svg',
      tag: 'crm-new-task-assigned',
      requireInteraction: false,
      silent: false,
    })

    notification.onclick = () => {
      window.focus()
      if (typeof navigate === 'function') navigate('/my-tasks')
      notification.close()
    }
  } catch {
    // Ignore notification errors silently.
  }
}

export const notifyTaskWaitingApproval = ({
  title = '',
  navigate,
} = {}) => {
  const audio = initTaskApprovalAudio()
  playAudioSafe(audio)

  if (typeof window === 'undefined' || !('Notification' in window)) return
  if (Notification.permission !== 'granted') return

  const body = title
    ? `Task "${title}" is waiting for your review & approval.`
    : 'A new task is waiting for your review & approval.'

  try {
    const notification = new Notification('Task Waiting for Approval', {
      body,
      icon: '/chat-bot.svg',
      tag: 'crm-task-waiting-approval',
      requireInteraction: false,
      silent: false,
    })

    notification.onclick = () => {
      window.focus()
      if (typeof navigate === 'function') navigate('/task-approvals')
      notification.close()
    }
  } catch {
    // Ignore notification errors silently.
  }
}

export const notifyTaskApproved = ({
  title = '',
  navigate,
} = {}) => {
  const audio = initTaskSucceedAudio()
  playAudioSafe(audio)

  if (typeof window === 'undefined' || !('Notification' in window)) return
  if (Notification.permission !== 'granted') return

  const body = title
    ? `Your task "${title}" has been approved! Please accept the task to start the timer.`
    : 'Your task has been approved! Please accept the task to start the timer.'

  try {
    const notification = new Notification('Task Approved', {
      body,
      icon: '/chat-bot.svg',
      tag: 'crm-task-approved',
      requireInteraction: false,
      silent: false,
    })

    notification.onclick = () => {
      window.focus()
      if (typeof navigate === 'function') navigate('/my-tasks')
      notification.close()
    }
  } catch {
    // Ignore notification errors silently.
  }
}

export const notifyTaskRejected = ({
  title = '',
  reason = '',
  navigate,
} = {}) => {
  const audio = initTaskRejectedAudio()
  playAudioSafe(audio)

  if (typeof window === 'undefined' || !('Notification' in window)) return
  if (Notification.permission !== 'granted') return

  const reasonSuffix = reason ? ` Reason: ${reason}` : ''
  const body = title
    ? `Your task "${title}" was rejected.${reasonSuffix}`
    : `Your task was rejected.${reasonSuffix}`

  try {
    const notification = new Notification('Task Rejected', {
      body,
      icon: '/chat-bot.svg',
      tag: 'crm-task-rejected',
      requireInteraction: false,
      silent: false,
    })

    notification.onclick = () => {
      window.focus()
      if (typeof navigate === 'function') navigate('/my-tasks')
      notification.close()
    }
  } catch {
    // Ignore notification errors silently.
  }
}
