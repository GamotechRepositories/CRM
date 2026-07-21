/**
 * Real-time Socket.IO layer for notifications + meeting list sync.
 * @module services/realtimeNotification.service
 */
import logger from '../utils/logger.js';

/** @type {import('socket.io').Server | null} */
let io = null;

/** @type {Set<string>} */
const onlineUsers = new Set();

export const MEETINGS_ROOM = 'meetings';

/**
 * Bind Socket.IO server instance (call once at app startup).
 * @param {import('socket.io').Server} socketServer
 */
export function bindSocketServer(socketServer) {
  io = socketServer;

  io.on('connection', (socket) => {
    const userId =
      socket.handshake.auth?.userId || socket.handshake.query?.userId;

    // All meeting-app clients join shared room for list sync.
    socket.join(MEETINGS_ROOM);

    if (userId) {
      const room = userRoom(userId);
      socket.join(room);
      onlineUsers.add(String(userId));
      logger.info('SocketConnect', 'User connected', {
        userId: String(userId),
        socketId: socket.id,
      });
    } else {
      logger.info('SocketConnect', 'Anonymous client connected', {
        socketId: socket.id,
      });
    }

    socket.on('disconnect', () => {
      if (userId) {
        onlineUsers.delete(String(userId));
        logger.info('SocketDisconnect', 'User disconnected', {
          userId: String(userId),
        });
      }
    });
  });

  logger.info('SocketInit', 'Real-time socket bound');
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
 * Broadcast meeting list change to all connected meeting-app clients.
 * @param {{ action: string, meetingId?: string }} payload
 * @param {string[]} [_userIds] ignored (kept for call-site compatibility)
 */
export function emitMeetingChange(_userIds = [], payload = {}) {
  if (!io) {
    logger.warn('SocketEmit', 'Socket not ready — meeting change not broadcast');
    return 0;
  }

  const eventPayload = {
    action: String(payload.action || 'updated'),
    meetingId: payload.meetingId ? String(payload.meetingId) : undefined,
    ts: new Date().toISOString(),
  };

  // Broadcast to shared room (all logged-in app clients).
  io.to(MEETINGS_ROOM).emit('meetings:changed', eventPayload);
  // Also emit globally so any client not yet in room still receives it.
  io.emit('meetings:changed', eventPayload);

  const rooms = io.sockets.adapter.rooms.get(MEETINGS_ROOM);
  const listeners = rooms?.size || 0;
  logger.info('SocketEmit', 'meetings:changed broadcast', {
    ...eventPayload,
    listeners,
  });
  return listeners;
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
