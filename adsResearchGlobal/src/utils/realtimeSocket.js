import { io } from 'socket.io-client'

let socket = null
let connectedUserId = null

/** API base like https://host/api/v1/tenant → socket origin https://host */
export const getSocketOrigin = () => {
  const api = import.meta.env.VITE_API_URL || ''
  try {
    return new URL(api).origin
  } catch {
    if (typeof window !== 'undefined') return window.location.origin
    return ''
  }
}

/**
 * Shared Socket.IO connection for the logged-in employee.
 * Reuses one connection; reconnects when userId changes.
 */
export const connectRealtimeSocket = (userId) => {
  const id = userId ? String(userId) : ''
  if (!id) {
    disconnectRealtimeSocket()
    return null
  }

  if (socket && connectedUserId === id) {
    if (!socket.connected) socket.connect()
    return socket
  }

  disconnectRealtimeSocket()

  const origin = getSocketOrigin()
  if (!origin) return null

  socket = io(origin, {
    path: '/socket.io',
    transports: ['websocket', 'polling'],
    auth: { userId: id },
    query: { userId: id },
    autoConnect: true,
    reconnection: true,
    reconnectionAttempts: Infinity,
    reconnectionDelay: 1000,
    reconnectionDelayMax: 10000,
  })
  connectedUserId = id
  return socket
}

export const getRealtimeSocket = () => socket

export const disconnectRealtimeSocket = () => {
  if (socket) {
    socket.removeAllListeners()
    socket.disconnect()
    socket = null
  }
  connectedUserId = null
}

/** Subscribe to task list changes for the current user. Returns unsubscribe. */
export const onTaskChanged = (handler) => {
  if (!socket || typeof handler !== 'function') return () => {}
  socket.on('task:changed', handler)
  return () => {
    socket?.off('task:changed', handler)
  }
}
