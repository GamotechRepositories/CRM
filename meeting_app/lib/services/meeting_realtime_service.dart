import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/config/env_config.dart';
import '../core/utils/logger.dart';
import 'local_notification_service.dart';

/// Live meeting-list sync via Socket.IO (`meetings:changed`).
///
/// [notifyChanged] is for rare fallbacks (FCM while socket down, app resume).
/// Do not call it on every connect — that floods the meetings API.
class MeetingRealtimeService {
  MeetingRealtimeService._();
  static final MeetingRealtimeService instance = MeetingRealtimeService._();

  io.Socket? _socket;
  String? _connectedUserId;
  bool _suppressBossTeamAlerts = false;
  bool _wasEverConnected = false;
  bool _pausedForBackground = false;
  DateTime? _lastNotifyAt;
  DateTime? _lastErrorLogAt;
  final _changes = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get changes => _changes.stream;

  bool get isConnected => _socket?.connected == true;

  /// Push a synthetic change so UI reloads meetings (client-side debounce).
  void notifyChanged({
    String action = 'updated',
    String? meetingId,
    String source = 'local',
  }) {
    final now = DateTime.now();
    if (_lastNotifyAt != null &&
        now.difference(_lastNotifyAt!) < const Duration(milliseconds: 800)) {
      return;
    }
    _lastNotifyAt = now;
    _changes.add({
      'action': action,
      if (meetingId != null && meetingId.isNotEmpty) 'meetingId': meetingId,
      'source': source,
      'ts': now.toIso8601String(),
    });
  }

  void connect({
    required String userId,
    bool suppressBossTeamAlerts = false,
  }) {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return;

    _pausedForBackground = false;
    _suppressBossTeamAlerts = suppressBossTeamAlerts;

    if (_connectedUserId == trimmed && isConnected) {
      return;
    }

    // Keep user id even while reconnecting after pause.
    _connectedUserId = trimmed;
    _openSocket(trimmed);
  }

  /// Stop reconnect spam while Android backgrounds the app (DNS often fails).
  void pauseForBackground() {
    if (_pausedForBackground) return;
    _pausedForBackground = true;
    AppLogger.info('Meetings socket paused (app background)', tag: 'Socket');
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
  }

  /// Reconnect after returning to foreground.
  void resumeFromBackground() {
    if (!_pausedForBackground) return;
    _pausedForBackground = false;
    final userId = _connectedUserId;
    if (userId == null || userId.isEmpty) return;
    AppLogger.info('Meetings socket resume (app foreground)', tag: 'Socket');
    if (isConnected) return;
    _openSocket(userId);
  }

  void _openSocket(String userId) {
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    _socket = null;

    final host = EnvConfig.apiHost.trim();
    AppLogger.info('Connecting meetings socket → $host', tag: 'Socket');

    final socket = io.io(
      host,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setPath('/socket.io')
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(12)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(15000)
          .setAuth({'userId': userId})
          .setQuery({'userId': userId})
          .enableForceNew()
          .build(),
    );

    socket.onConnect((_) {
      if (_pausedForBackground) return;
      AppLogger.info('Meetings socket connected', tag: 'Socket');
      if (_wasEverConnected) {
        notifyChanged(action: 'sync', source: 'socket-reconnect');
      } else {
        _wasEverConnected = true;
        notifyChanged(action: 'sync', source: 'socket-connect');
      }
    });
    socket.onDisconnect((_) {
      if (_pausedForBackground) return;
      AppLogger.warning('Meetings socket disconnected', tag: 'Socket');
    });
    socket.onConnectError((error) {
      if (_pausedForBackground) return;
      _logErrorThrottled('Meetings socket connect error: $error');
    });
    socket.onError((error) {
      if (_pausedForBackground) return;
      _logErrorThrottled('Meetings socket error: $error');
    });
    socket.on('meetings:changed', (payload) {
      if (_pausedForBackground) return;
      AppLogger.info('meetings:changed received · $payload', tag: 'Socket');
      if (payload is Map) {
        final map = Map<String, dynamic>.from(
          payload.map((k, v) => MapEntry(k.toString(), v)),
        );
        map['source'] = 'socket';
        _lastNotifyAt = DateTime.now();
        _changes.add(map);
      } else {
        notifyChanged(source: 'socket');
      }
    });

    socket.on('notification', (payload) {
      if (_pausedForBackground) return;
      AppLogger.info('notification received · $payload', tag: 'Socket');
      String? meetingId;
      if (payload is Map) {
        final data = Map<String, dynamic>.from(
          payload.map((k, v) => MapEntry(k.toString(), v)),
        );
        final nested = data['data'];
        if (nested is Map) {
          meetingId = nested['meetingId']?.toString();
        }
        meetingId ??= data['meetingId']?.toString();
      }
      notifyChanged(
        meetingId: meetingId,
        source: 'socket-notification',
      );
      unawaited(_showLocalFromSocket(payload));
    });

    _socket = socket;
    socket.connect();
  }

  void _logErrorThrottled(String message) {
    final now = DateTime.now();
    if (_lastErrorLogAt != null &&
        now.difference(_lastErrorLogAt!) < const Duration(seconds: 8)) {
      return;
    }
    _lastErrorLogAt = now;
    AppLogger.warning(message, tag: 'Socket');
  }

  Future<void> _showLocalFromSocket(dynamic payload) async {
    try {
      if (payload is! Map) return;
      final data = Map<String, dynamic>.from(
        payload.map((k, v) => MapEntry(k.toString(), v)),
      );
      final title = data['title']?.toString().trim();
      final body = data['body']?.toString().trim();
      if (title == null || title.isEmpty) return;

      final nested = data['data'];
      final Map<String, dynamic> extra = nested is Map
          ? Map<String, dynamic>.from(
              nested.map((k, v) => MapEntry(k.toString(), v)),
            )
          : <String, dynamic>{};
      final kind = (data['type'] ?? extra['notificationKind'] ?? extra['type'])
          ?.toString();

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

  void disconnect({bool resetSession = false}) {
    _pausedForBackground = false;
    _connectedUserId = null;
    _suppressBossTeamAlerts = false;
    if (resetSession) {
      _wasEverConnected = false;
    }
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
  }
}
