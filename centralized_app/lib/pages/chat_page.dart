import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../services/chat_realtime_service.dart';
import '../utils/chat_helpers.dart';

/// `/module/chat` — team + direct messages (mirrors web `ChatPortalView.jsx`).
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<Map<String, dynamic>> _conversations = [];
  String? _activeConversationId;
  List<Map<String, dynamic>> _messages = [];
  String? _oldestLoadedDay;
  bool _hasOlderDays = false;

  bool _loadingConversations = true;
  bool _loadingMessages = false;
  bool _loadingOlder = false;
  bool _sending = false;
  String? _error;

  final _draftCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();

  StreamSubscription<Map<String, dynamic>>? _msgSub;
  StreamSubscription<Map<String, dynamic>>? _msgUpdateSub;
  StreamSubscription<Map<String, dynamic>>? _convSub;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectSocket();
      _loadConversations();
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _msgUpdateSub?.cancel();
    _convSub?.cancel();
    if (_activeConversationId != null) {
      ChatRealtimeService.instance.leaveConversation(_activeConversationId!);
    }
    _draftCtrl.dispose();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _employeeId => context.read<AuthSession>().userId;

  void _connectSocket() {
    final session = context.read<AuthSession>();
    final api = session.api;
    if (api == null || session.userId.isEmpty) return;

    final origin = Uri.parse(api.company.apiBaseUrl).origin;
    ChatRealtimeService.instance.connect(
      socketOrigin: origin,
      userId: session.userId,
      tenantId: api.company.key,
    );

    _msgSub?.cancel();
    _msgUpdateSub?.cancel();
    _convSub?.cancel();

    _msgSub = ChatRealtimeService.instance.messages.listen(_onRealtimeMessage);
    _msgUpdateSub = ChatRealtimeService.instance.messageUpdates.listen(_onRealtimeMessageUpdated);
    _convSub = ChatRealtimeService.instance.conversationUpdates.listen(_onConversationUpdated);
  }

  void _onRealtimeMessage(Map<String, dynamic> payload) {
    final conversationId = '${payload['conversationId'] ?? ''}';
    final msg = payload['message'];
    if (msg is! Map || conversationId.isEmpty) return;
    final message = Map<String, dynamic>.from(msg);

    if (_activeConversationId != null && conversationId == _activeConversationId) {
      setState(() {
        if (!_messages.any((m) => '${m['_id']}' == '${message['_id']}')) {
          _messages = [..._messages, message];
        }
      });
      _markRead(conversationId);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
    _loadConversations(silent: true);
  }

  void _onRealtimeMessageUpdated(Map<String, dynamic> payload) {
    final conversationId = '${payload['conversationId'] ?? ''}';
    final msg = payload['message'];
    if (msg is! Map || conversationId != _activeConversationId) return;
    final message = Map<String, dynamic>.from(msg);
    setState(() {
      _messages = _messages.map((m) => '${m['_id']}' == '${message['_id']}' ? message : m).toList();
    });
  }

  void _onConversationUpdated(Map<String, dynamic> payload) {
    final conversationId = '${payload['conversationId'] ?? ''}';
    if (conversationId.isEmpty) return;
    setState(() {
      final idx = _conversations.indexWhere((c) => '${c['_id']}' == conversationId);
      if (idx < 0) return;
      final current = _conversations[idx];
      _conversations[idx] = {
        ...current,
        if (payload['lastMessageAt'] != null) 'lastMessageAt': payload['lastMessageAt'],
        if (payload['lastMessagePreview'] != null) 'lastMessagePreview': payload['lastMessagePreview'],
        if (payload['lastMessageSender'] != null) 'lastMessageSender': payload['lastMessageSender'],
      };
      _conversations.sort((a, b) {
        final da = DateTime.tryParse('${a['lastMessageAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = DateTime.tryParse('${b['lastMessageAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
    });
  }

  Future<void> _loadConversations({bool silent = false}) async {
    final api = context.read<AuthSession>().api;
    if (api == null || _employeeId.isEmpty) return;
    if (!silent) setState(() => _loadingConversations = true);
    try {
      final list = await api.fetchChatConversations(_employeeId);
      if (!mounted) return;
      setState(() {
        _conversations = list;
        _loadingConversations = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingConversations = false;
        if (!silent) _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openConversation(String conversationId) async {
    if (_activeConversationId != null) {
      ChatRealtimeService.instance.leaveConversation(_activeConversationId!);
    }
    setState(() {
      _activeConversationId = conversationId;
      _messages = [];
      _oldestLoadedDay = null;
      _hasOlderDays = false;
      _error = null;
    });
    ChatRealtimeService.instance.joinConversation(conversationId);
    await _loadTodayMessages(conversationId);
  }

  void _closeConversation() {
    if (_activeConversationId != null) {
      ChatRealtimeService.instance.leaveConversation(_activeConversationId!);
    }
    setState(() {
      _activeConversationId = null;
      _messages = [];
      _draftCtrl.clear();
    });
  }

  Future<void> _loadTodayMessages(String conversationId, {bool silent = false}) async {
    final api = context.read<AuthSession>().api;
    if (api == null) return;
    if (!silent) setState(() => _loadingMessages = true);
    try {
      final page = await api.fetchChatMessages(
        conversationId: conversationId,
        employeeId: _employeeId,
        day: 'today',
      );
      if (!mounted) return;
      setState(() {
        _messages = page.messages;
        _oldestLoadedDay = page.day ?? ChatHelpers.toDateKey();
        _hasOlderDays = page.hasOlder;
        _loadingMessages = false;
      });
      await _markRead(conversationId);
      _loadConversations(silent: true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMessages = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadOlderMessages() async {
    final api = context.read<AuthSession>().api;
    final roomId = _activeConversationId;
    if (api == null || roomId == null || _oldestLoadedDay == null || !_hasOlderDays || _loadingOlder) return;

    final previousDay = ChatHelpers.previousDayKey(_oldestLoadedDay!);
    setState(() => _loadingOlder = true);
    try {
      final page = await api.fetchChatMessages(
        conversationId: roomId,
        employeeId: _employeeId,
        day: previousDay,
      );
      if (!mounted) return;
      setState(() {
        _messages = ChatHelpers.mergeMessages(page.messages, _messages);
        _oldestLoadedDay = page.day ?? previousDay;
        _hasOlderDays = page.hasOlder;
        _loadingOlder = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingOlder = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _markRead(String conversationId) async {
    final api = context.read<AuthSession>().api;
    if (api == null) return;
    try {
      await api.markChatRead(conversationId: conversationId, employeeId: _employeeId);
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final api = context.read<AuthSession>().api;
    final roomId = _activeConversationId;
    final body = _draftCtrl.text.trim();
    if (api == null || roomId == null || body.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final msg = await api.sendChatMessage(
        conversationId: roomId,
        employeeId: _employeeId,
        body: body,
      );
      if (!mounted) return;
      setState(() {
        if (!_messages.any((m) => '${m['_id']}' == '${msg['_id']}')) {
          _messages = [..._messages, msg];
        }
        _draftCtrl.clear();
        _sending = false;
      });
      _loadConversations(silent: true);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _votePoll(String messageId, int optionIndex) async {
    final api = context.read<AuthSession>().api;
    if (api == null) return;
    try {
      final updated = await api.voteChatPoll(
        messageId: messageId,
        employeeId: _employeeId,
        optionIndex: optionIndex,
      );
      if (!mounted) return;
      setState(() {
        _messages = _messages.map((m) => '${m['_id']}' == '$messageId' ? updated : m).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _loadingOlder || !_hasOlderDays) return;
    if (_scrollCtrl.position.pixels <= 80) _loadOlderMessages();
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  List<Map<String, dynamic>> get _filteredConversations {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _conversations;
    return _conversations.where((c) {
      final title = ChatHelpers.conversationTitle(c).toLowerCase();
      final preview = '${c['lastMessagePreview'] ?? ''}'.toLowerCase();
      return title.contains(q) || preview.contains(q);
    }).toList();
  }

  Map<String, dynamic>? get _activeConversation {
    if (_activeConversationId == null) return null;
    for (final c in _conversations) {
      if ('${c['_id']}' == _activeConversationId) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _activeConversationId == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _activeConversationId != null) _closeConversation();
      },
      child: _activeConversationId != null
          ? _ChatThread(
              conversation: _activeConversation,
              messages: _messages,
              loading: _loadingMessages,
              loadingOlder: _loadingOlder,
              sending: _sending,
              error: _error,
              employeeId: _employeeId,
              draftCtrl: _draftCtrl,
              scrollCtrl: _scrollCtrl,
              onBack: _closeConversation,
              onSend: _sendMessage,
              onVote: _votePoll,
              onRefresh: () => _loadTodayMessages(_activeConversationId!, silent: true),
            )
          : _ChatList(
              conversations: _filteredConversations,
              loading: _loadingConversations,
              error: _error,
              searchCtrl: _searchCtrl,
              onSearchChanged: (_) => setState(() {}),
              onRefresh: _loadConversations,
              onSelect: _openConversation,
              onNewChat: _showNewChatSheet,
            ),
    );
  }

  Future<void> _showNewChatSheet() async {
    final peerId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewChatSheet(employeeId: _employeeId),
    );
    if (peerId == null || peerId.isEmpty || !mounted) return;

    final api = context.read<AuthSession>().api;
    if (api == null) return;

    try {
      final conv = await api.createDirectChat(employeeId: _employeeId, peerId: peerId);
      await _loadConversations(silent: true);
      final id = '${conv['_id']}';
      if (id.isNotEmpty) await _openConversation(id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }
}

class _ChatList extends StatelessWidget {
  const _ChatList({
    required this.conversations,
    required this.loading,
    required this.error,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onSelect,
    required this.onNewChat,
  });

  final List<Map<String, dynamic>> conversations;
  final bool loading;
  final String? error;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function({bool silent}) onRefresh;
  final ValueChanged<String> onSelect;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    if (loading && conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search chats...',
                    hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: const Color(0xFF128C7E),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: onNewChat,
                  borderRadius: BorderRadius.circular(8),
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(error!, style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C))),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => onRefresh(),
            child: conversations.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 80),
                      Center(child: Text('No conversations yet', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
                    itemCount: conversations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, i) {
                      final c = conversations[i];
                      return _ConversationTile(conversation: c, onTap: () => onSelect('${c['_id']}'));
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final Map<String, dynamic> conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = ChatHelpers.conversationTitle(conversation);
    final isTeam = conversation['type'] == 'team';
    final unread = (conversation['unreadCount'] is num) ? (conversation['unreadCount'] as num).toInt() : 0;
    final preview = '${conversation['lastMessagePreview'] ?? 'No messages yet'}';
    final time = ChatHelpers.formatListTime(conversation['lastMessageAt']);
    final color = isTeam ? const Color(0xFF128C7E) : ChatHelpers.avatarColor(title);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(
                  isTeam ? Icons.groups_rounded : Icons.person_rounded,
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (time.isNotEmpty) Text(time, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(preview, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (unread > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF128C7E), borderRadius: BorderRadius.circular(10)),
                  child: Text('$unread', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatThread extends StatelessWidget {
  const _ChatThread({
    required this.conversation,
    required this.messages,
    required this.loading,
    required this.loadingOlder,
    required this.sending,
    required this.error,
    required this.employeeId,
    required this.draftCtrl,
    required this.scrollCtrl,
    required this.onBack,
    required this.onSend,
    required this.onVote,
    required this.onRefresh,
  });

  final Map<String, dynamic>? conversation;
  final List<Map<String, dynamic>> messages;
  final bool loading;
  final bool loadingOlder;
  final bool sending;
  final String? error;
  final String employeeId;
  final TextEditingController draftCtrl;
  final ScrollController scrollCtrl;
  final VoidCallback onBack;
  final VoidCallback onSend;
  final Future<void> Function(String messageId, int optionIndex) onVote;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final title = conversation != null ? ChatHelpers.conversationTitle(conversation!) : 'Chat';
    final subtitle = conversation != null ? ChatHelpers.conversationSubtitle(conversation!) : '';
    final items = ChatHelpers.buildChatItems(messages);

    return Column(
      children: [
        Container(
          color: const Color(0xFF128C7E),
          padding: const EdgeInsets.fromLTRB(4, 6, 10, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                onPressed: onBack,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, style: const TextStyle(fontSize: 9, color: Color(0xFFD1FAE5)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                onPressed: onRefresh,
              ),
            ],
          ),
        ),
        if (error != null)
          Container(
            width: double.infinity,
            color: const Color(0xFFFEF2F2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(error!, style: const TextStyle(fontSize: 10, color: Color(0xFFB91C1C))),
          ),
        Expanded(
          child: Container(
            color: const Color(0xFFECE5DD),
            child: loading && messages.isEmpty
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : RefreshIndicator(
                    onRefresh: onRefresh,
                    child: ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      itemCount: items.length + (loadingOlder ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (loadingOlder && i == 0) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                          );
                        }
                        final idx = loadingOlder ? i - 1 : i;
                        final item = items[idx];
                        if (item.type == 'date') {
                          return Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('${item.data}', style: const TextStyle(fontSize: 10, color: Color(0xFF54656F), fontWeight: FontWeight.w500)),
                            ),
                          );
                        }
                        final msg = item.data as Map<String, dynamic>;
                        final mine = ChatHelpers.senderId(msg) == employeeId;
                        return _MessageBubble(
                          message: msg,
                          mine: mine,
                          employeeId: employeeId,
                          onVote: onVote,
                        );
                      },
                    ),
                  ),
          ),
        ),
        _MessageComposer(
          controller: draftCtrl,
          sending: sending,
          onSend: onSend,
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.employeeId,
    required this.onVote,
  });

  final Map<String, dynamic> message;
  final bool mine;
  final String employeeId;
  final Future<void> Function(String messageId, int optionIndex) onVote;

  @override
  Widget build(BuildContext context) {
    final type = message['messageType']?.toString() ?? 'text';
    final time = ChatHelpers.formatTime(message['createdAt']);
    final sender = ChatHelpers.senderName(message);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFFD9FDD3) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(10),
            topRight: const Radius.circular(10),
            bottomLeft: Radius.circular(mine ? 10 : 2),
            bottomRight: Radius.circular(mine ? 2 : 10),
          ),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine && type != 'system')
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(sender, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF128C7E))),
              ),
            if (type == 'poll') _PollContent(message: message, employeeId: employeeId, onVote: onVote) else _TextContent(message: message),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(time, style: const TextStyle(fontSize: 8, color: Color(0xFF667781))),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextContent extends StatelessWidget {
  const _TextContent({required this.message});

  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final body = '${message['body'] ?? ''}';
    final attachments = message['attachments'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (body.isNotEmpty) Text(body, style: const TextStyle(fontSize: 12, color: Color(0xFF111B21), height: 1.35)),
        if (attachments is List)
          ...attachments.whereType<Map>().map((a) {
            final name = (a['fileName'] ?? 'Attachment').toString();
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.attach_file, size: 12, color: Color(0xFF128C7E)),
                  const SizedBox(width: 4),
                  Flexible(child: Text(name, style: const TextStyle(fontSize: 10, color: Color(0xFF128C7E)), overflow: TextOverflow.ellipsis)),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _PollContent extends StatelessWidget {
  const _PollContent({
    required this.message,
    required this.employeeId,
    required this.onVote,
  });

  final Map<String, dynamic> message;
  final String employeeId;
  final Future<void> Function(String messageId, int optionIndex) onVote;

  @override
  Widget build(BuildContext context) {
    final poll = message['poll'];
    if (poll is! Map) return Text('${message['body']}', style: const TextStyle(fontSize: 12));
    final question = (poll['question'] ?? message['body'] ?? 'Poll').toString();
    final options = poll['options'];
    final opts = options is List ? options.whereType<Map>().toList() : <Map<String, dynamic>>[];
    var totalVotes = 0;
    for (final opt in opts) {
      final votes = opt['votes'];
      if (votes is List) totalVotes += votes.length;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111B21))),
        const SizedBox(height: 6),
        ...List.generate(opts.length, (idx) {
          final opt = opts[idx];
          final text = (opt['text'] ?? 'Option').toString();
          final votes = opt['votes'];
          final count = votes is List ? votes.length : 0;
          final pct = totalVotes == 0 ? 0 : ((count / totalVotes) * 100).round();
          final selected = votes is List &&
              votes.any((v) {
                if (v is Map) {
                  final emp = v['employee'];
                  if (emp is Map) return '${emp['_id']}' == employeeId;
                  return '$emp' == employeeId;
                }
                return false;
              });
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: InkWell(
              onTap: () => onVote('${message['_id']}', idx),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: selected ? const Color(0xFF128C7E) : const Color(0xFFD1D7DB)),
                  color: selected ? const Color(0xFFE7F8F3) : Colors.white,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(text, style: const TextStyle(fontSize: 10))),
                    Text('$count · $pct%', style: const TextStyle(fontSize: 9, color: Color(0xFF667781))),
                  ],
                ),
              ),
            ),
          );
        }),
        Text('$totalVotes votes', style: const TextStyle(fontSize: 9, color: Color(0xFF667781))),
      ],
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F2F5),
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Type a message',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
              style: const TextStyle(fontSize: 12),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: const Color(0xFF128C7E),
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: sending ? null : onSend,
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                width: 44,
                height: 44,
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewChatSheet extends StatefulWidget {
  const _NewChatSheet({required this.employeeId});

  final String employeeId;

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _employees = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final api = context.read<AuthSession>().api;
      if (api == null) return;
      setState(() => _loading = true);
      try {
        final list = await api.searchChatEmployees(query);
        if (!mounted) return;
        setState(() {
          _employees = list.where((e) => '${e['_id']}' != widget.employeeId).toList();
          _loading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _employees = [];
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2))),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('New chat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: 'Search employees...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _employees.length,
                  itemBuilder: (context, i) {
                    final emp = _employees[i];
                    final name = (emp['name'] ?? 'Employee').toString();
                    final dept = (emp['department'] ?? '').toString();
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: ChatHelpers.avatarColor(name).withValues(alpha: 0.15),
                        child: Text(ChatHelpers.initials(name), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ChatHelpers.avatarColor(name))),
                      ),
                      title: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      subtitle: dept.isNotEmpty ? Text(dept, style: const TextStyle(fontSize: 10)) : null,
                      onTap: () => Navigator.pop(context, '${emp['_id']}'),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
