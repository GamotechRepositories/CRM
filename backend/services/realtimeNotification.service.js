/**
 * Real-time notification layer — Socket.IO ready (not yet wired in index.js).
 * When Socket.IO is added, call `bindSocketServer(io)` at startup.
 * Online users receive socket events; offline users receive FCM only.
 * @module services/realtimeNotification.service
 */
import logger from '../utils/logger.js';

/** @type {import('socket.io').Server | null} */
let io = null;

/** @type {Set<string>} */
const onlineUsers = new Set();

/**
 * Bind Socket.IO server instance (call once at app startup when available).
 * @param {import('socket.io').Server} socketServer
 */
export function bindSocketServer(socketServer) {
  io = socketServer;

  io.on('connection', (socket) => {
    const userId = socket.handshake.auth?.userId || socket.handshake.query?.userId;
    if (userId) {
      const room = userRoom(userId);
      socket.join(room);
      onlineUsers.add(String(userId));
      logger.info('SocketConnect', 'User connected to notification socket', { userId });
    }

    socket.on('disconnect', () => {
      if (userId) {
        onlineUsers.delete(String(userId));
        logger.info('SocketDisconnect', 'User disconnected', { userId });
      }
    });
  });

  logger.info('SocketInit', 'Real-time notification socket bound');
}

/** @param {string} userId */
export function userRoom(userId) {
  return `user:${userId}`;
}

/** @returns {boolean} */
export function isRealtimeEnabled() {
  return io != null;
}

/** @param {string} userId */
export function isUserOnline(userId) {
  return onlineUsers.has(String(userId));
}

/**
 * Emit notification to connected user via Socket.IO.
 * @returns {boolean} true if delivered via socket
 */
export function emitToUser(userId, payload) {
  if (!io) return false;
  io.to(userRoom(userId)).emit('notification', payload);
  logger.info('SocketDelivered', 'Real-time notification emitted', { userId });
  return true;
}

/**
 * Emit meeting list change event to user(s).
 * @param {string[]} userIds
 * @param {{ action: string, meetingId?: string }} payload
 */
export function emitMeetingChange(userIds = [], payload = {}) {
  if (!io || !Array.isArray(userIds) || !userIds.length) return 0;
  const eventPayload = {
    action: String(payload.action || 'updated'),
    meetingId: payload.meetingId ? String(payload.meetingId) : undefined,
    ts: new Date().toISOString(),
  };
  const uniqueIds = [...new Set(userIds.map((id) => String(id)).filter(Boolean))];
  uniqueIds.forEach((userId) => {
    io.to(userRoom(userId)).emit('meetings:changed', eventPayload);
  });
  return uniqueIds.length;
}

/**
 * Split user ids into online (socket) vs offline (FCM).
 * @param {string[]} userIds
 */
export function partitionByOnlineStatus(userIds = []) {
  const online = [];
  const offline = [];
  for (const id of userIds) {
    if (isUserOnline(id)) online.push(id);
    else offline.push(id);
  }
  return { online, offline };
}

export default {
  bindSocketServer,
  isRealtimeEnabled,
  isUserOnline,
  emitToUser,
  emitMeetingChange,
  partitionByOnlineStatus,
};
