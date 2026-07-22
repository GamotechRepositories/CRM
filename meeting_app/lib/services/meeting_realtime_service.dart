import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/config/env_config.dart';
import '../core/utils/logger.dart';
import 'local_notification_service.dart';

/// Live meeting-list sync via Socket.IO (`meetings:changed`).
class MeetingRealtimeService {
  MeetingRealtimeService._();
  static final MeetingRealtimeService instance = MeetingRealtimeService._();

  io.Socket? _socket;
  String? _connectedUserId;
  bool _suppressBossTeamAlerts = false;
  final _changes = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get changes => _changes.stream;

  bool get isConnected => _socket?.connected == true;

  void connect({
    required String userId,
    bool suppressBossTeamAlerts = false,
  }) {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return;
    if (_connectedUserId == trimmed &&
        isConnected &&
        _suppressBossTeamAlerts == suppressBossTeamAlerts) {
      return;
    }

    disconnect();
    _connectedUserId = trimmed;
    _suppressBossTeamAlerts = suppressBossTeamAlerts;

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

    // Push-style alert while app is connected (complements FCM).
    socket.on('notification', (payload) {
      AppLogger.info('notification received · $payload', tag: 'Socket');
      unawaited(_showLocalFromSocket(payload));
    });

    _socket = socket;
    socket.connect();
  }

  Future<void> _showLocalFromSocket(dynamic payload) async {
    try {
      if (payload is! Map) return;
      final data = Map<String, dynamic>.from(payload);
      final title = data['title']?.toString().trim();
      final body = data['body']?.toString().trim();
      if (title == null || title.isEmpty) return;

      final nested = data['data'];
      final Map<String, dynamic> extra = nested is Map
          ? Map<String, dynamic>.from(nested)
          : <String, dynamic>{};
      final kind = (data['type'] ?? extra['notificationKind'] ?? extra['type'])
          ?.toString();

      // Boss should not see their own "Confirm for your team" alerts.
      if (_suppressBossTeamAlerts &&
          (kind == 'meeting_boss_response' ||
              title.toLowerCase().contains('boss will attend') ||
              title.toLowerCase().contains('boss cannot attend') ||
              title.toLowerCase().contains('boss response') ||
              title.toLowerCase().contains('boss requested reschedule'))) {
        AppLogger.info(
          'Skipped boss-team alert on Boss device · $title',
          tag: 'Socket',
        );
        return;
      }

      await LocalNotificationService.instance.showNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: (body == null || body.isEmpty) ? 'Meeting update' : body,
        payload: {
          'type':
              data['type']?.toString() ?? extra['type']?.toString() ?? 'meeting',
          'meetingId': extra['meetingId']?.toString() ??
              data['meetingId']?.toString() ??
              '',
          ...extra,
        },
      );
    } catch (error) {
      AppLogger.warning(
        'Socket local notification failed: $error',
        tag: 'Socket',
      );
    }
  }

  void disconnect() {
    _connectedUserId = null;
    _suppressBossTeamAlerts = false;
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
  }
}
