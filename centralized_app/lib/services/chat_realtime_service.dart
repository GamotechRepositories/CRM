import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

/// Real-time chat via Socket.IO — mirrors web `realtimeSocket.js`.
class ChatRealtimeService {
  ChatRealtimeService._();
  static final ChatRealtimeService instance = ChatRealtimeService._();

  io.Socket? _socket;
  String? _userId;
  String? _tenantId;

  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _messageUpdates = StreamController<Map<String, dynamic>>.broadcast();
  final _conversationUpdates = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messages.stream;
  Stream<Map<String, dynamic>> get messageUpdates => _messageUpdates.stream;
  Stream<Map<String, dynamic>> get conversationUpdates => _conversationUpdates.stream;

  bool get isConnected => _socket?.connected == true;

  void connect({
    required String socketOrigin,
    required String userId,
    required String tenantId,
  }) {
    final id = userId.trim();
    final tenant = tenantId.trim();
    if (id.isEmpty || tenant.isEmpty) return;
    if (_userId == id && _tenantId == tenant && isConnected) return;

    disconnect();

    _userId = id;
    _tenantId = tenant;

    final socket = io.io(
      socketOrigin,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setPath('/socket.io')
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(50)
          .setReconnectionDelay(1200)
          .setAuth({'userId': id, 'tenantId': tenant})
          .setQuery({'userId': id, 'tenantId': tenant})
          .enableForceNew()
          .build(),
    );

    void emitMap(String event, dynamic payload) {
      if (payload is! Map) return;
      final map = Map<String, dynamic>.from(
        payload.map((k, v) => MapEntry(k.toString(), v)),
      );
      switch (event) {
        case 'chat:message':
          _messages.add(map);
        case 'chat:message:updated':
          _messageUpdates.add(map);
        case 'chat:conversation:updated':
          _conversationUpdates.add(map);
      }
    }

    socket.on('chat:message', (payload) => emitMap('chat:message', payload));
    socket.on('chat:message:updated', (payload) => emitMap('chat:message:updated', payload));
    socket.on('chat:conversation:updated', (payload) => emitMap('chat:conversation:updated', payload));

    _socket = socket;
    socket.connect();
  }

  void joinConversation(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty || _socket == null) return;
    _socket!.emit('chat:join', id);
  }

  void leaveConversation(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty || _socket == null) return;
    _socket!.emit('chat:leave', id);
  }

  void disconnect() {
    _userId = null;
    _tenantId = null;
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
  }
}
