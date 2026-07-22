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
  DateTime? _lastNotifyAt;
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
      // First connect: list already loaded by meetingsController — no API hit.
      // Reconnect after drop: one catch-up reload (missed events while offline).
      if (_wasEverConnected) {
        notifyChanged(action: 'sync', source: 'socket-reconnect');
      } else {
        _wasEverConnected = true;
        // Mark source so sync provider can ignore if needed.
        notifyChanged(action: 'sync', source: 'socket-connect');
      }
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

    // Local toast + backup list refresh (in case `meetings:changed` is missed).
    socket.on('notification', (payload) {
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

  void disconnect({bool resetSession = false}) {
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
