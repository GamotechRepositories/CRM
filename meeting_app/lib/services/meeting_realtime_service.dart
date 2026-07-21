import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/config/env_config.dart';
import '../core/utils/logger.dart';

/// Live meeting-list sync via Socket.IO (`meetings:changed`).
class MeetingRealtimeService {
  MeetingRealtimeService._();
  static final MeetingRealtimeService instance = MeetingRealtimeService._();

  io.Socket? _socket;
  String? _connectedUserId;
  final _changes = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get changes => _changes.stream;

  bool get isConnected => _socket?.connected == true;

  void connect({required String userId}) {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return;
    if (_connectedUserId == trimmed && isConnected) return;

    disconnect();
    _connectedUserId = trimmed;

    final host = EnvConfig.apiHost.trim();
    AppLogger.info('Connecting meetings socket → $host', tag: 'Socket');

    final socket = io.io(
      host,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setPath('/socket.io')
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(50)
          .setReconnectionDelay(1200)
          .setAuth({'userId': trimmed})
          .setQuery({'userId': trimmed})
          .enableForceNew()
          .build(),
    );

    socket.onConnect((_) {
      AppLogger.info('Meetings socket connected', tag: 'Socket');
    });
    socket.onDisconnect((_) {
      AppLogger.warning('Meetings socket disconnected', tag: 'Socket');
    });
    socket.onConnectError((error) {
      AppLogger.warning('Meetings socket connect error: $error', tag: 'Socket');
    });
    socket.onError((error) {
      AppLogger.warning('Meetings socket error: $error', tag: 'Socket');
    });
    socket.onReconnect((_) {
      AppLogger.info('Meetings socket reconnected', tag: 'Socket');
    });
    socket.on('meetings:changed', (payload) {
      AppLogger.info('meetings:changed received · $payload', tag: 'Socket');
      if (payload is Map) {
        _changes.add(Map<String, dynamic>.from(payload));
      } else {
        _changes.add({'action': 'updated'});
      }
    });

    _socket = socket;
    socket.connect();
  }

  void disconnect() {
    _connectedUserId = null;
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
  }
}
