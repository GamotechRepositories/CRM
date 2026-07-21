import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/config/env_config.dart';
import '../core/utils/logger.dart';

class MeetingRealtimeService {
  MeetingRealtimeService._();
  static final MeetingRealtimeService instance = MeetingRealtimeService._();

  io.Socket? _socket;
  String? _connectedUserId;
  final _changes = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get changes => _changes.stream;

  void connect({required String userId}) {
    if (userId.trim().isEmpty) return;
    if (_connectedUserId == userId && _socket?.connected == true) return;

    disconnect();
    _connectedUserId = userId;

    final socket = io.io(
      EnvConfig.apiHost,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(20)
          .setReconnectionDelay(1500)
          .setQuery({'userId': userId})
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
    socket.on('meetings:changed', (payload) {
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
    _socket?.dispose();
    _socket = null;
  }
}
