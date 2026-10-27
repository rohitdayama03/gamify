import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/chat_model.dart';
import '../../models/connection_model.dart';
import '../../providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  final PlayerSummary friend;

  const ChatScreen({super.key, required this.friend});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const Duration _pollInterval = Duration(seconds: 3);
  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  late final ChatProvider _chatProvider;

  // Oldest first
  List<ChatMessage> _messages = [];
  bool _loading = true;
  String? _loadError;
  bool _loadingOlder = false;
  bool _hasOlder = false;
  bool _sending = false;
  bool _polling = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _scrollController.addListener(_onScroll);
    _textController.addListener(() => setState(() {})); // toggles the send button
    _loadInitial();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollNewer());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    // Opening the chat marked messages as read; refresh the list so unread badges clear
    _chatProvider.fetchConversations();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final messages = await _chatProvider.fetchMessages(widget.friend.playerId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (messages == null) {
        _loadError = _chatProvider.errorMessage;
      } else {
        _messages = messages;
        _hasOlder = messages.length >= ChatProvider.pageSize;
      }
    });
  }

  Future<void> _pollNewer() async {
    if (_loading || _polling || _loadError != null) return;
    _polling = true;
    final afterId = _messages.isEmpty ? 0 : _messages.last.id;
    final newer = await _chatProvider.fetchMessages(widget.friend.playerId, afterId: afterId);
    _polling = false;
    if (newer != null && newer.isNotEmpty && mounted) {
      setState(() => _appendUnique(newer));
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasOlder || _messages.isEmpty) return;
    setState(() => _loadingOlder = true);
    final older = await _chatProvider.fetchMessages(widget.friend.playerId, beforeId: _messages.first.id);
    if (!mounted) return;
    setState(() {
      _loadingOlder = false;
      if (older != null) {
        _messages = [...older, ..._messages];
        _hasOlder = older.length >= ChatProvider.pageSize;
      }
    });
  }

  // The list is reversed, so the top (older messages) is the max scroll extent
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadOlder();
    }
  }

  // A sent message can also come back from a poll; skip ids we already have
  void _appendUnique(List<ChatMessage> incoming) {
    final known = _messages.map((m) => m.id).toSet();
    _messages = [..._messages, ...incoming.where((m) => !known.contains(m.id))];
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final sent = await _chatProvider.sendMessage(widget.friend.playerId, text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (sent != null) {
        _appendUnique([sent]);
        _textController.clear();
      }
    });
    if (sent == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_chatProvider.errorMessage ?? 'Message not sent')));
    } else if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friend = widget.friend;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary,
              child: Text(
                friend.username.isEmpty ? '?' : friend.username[0].toUpperCase(),
                style: const TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(friend.username, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Text('Say hi to ${widget.friend.username} 👋', style: const TextStyle(color: AppColors.textSecondary)),
      );
    }

    // Reversed so the newest message sits at the bottom and the list opens scrolled there
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length + (_loadingOlder ? 1 : 0),
      itemBuilder: (_, index) {
        if (index == _messages.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final position = _messages.length - 1 - index;
        final message = _messages[position];
        final previous = position > 0 ? _messages[position - 1] : null;
        final showDate = previous == null || !_sameDay(previous.createdAt, message.createdAt);
        return Column(
          children: [
            if (showDate) _DateChip(label: _dayLabel(message.createdAt)),
            _MessageBubble(message: message, time: _timeLabel(message.createdAt)),
          ],
        );
      },
    );
  }

  Widget _buildInputBar() {
    final canSend = _textController.text.trim().isNotEmpty && !_sending && _loadError == null;
    return SafeArea(
      top: false,
      child: Container(
        color: AppColors.cardBackground,
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Write a message…',
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: canSend ? _send : null,
              icon: _sending
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.send, color: canSend ? AppColors.primary : AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dayLabel(DateTime date) {
    final now = DateTime.now();
    if (_sameDay(date, now)) return 'Today';
    if (_sameDay(date, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  static String _timeLabel(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String time;

  const _MessageBubble({required this.message, required this.time});

  @override
  Widget build(BuildContext context) {
    final mine = message.fromMe;
    // Dark text on the mint bubble, light text on the dark one
    final textColor = mine ? AppColors.onPrimary : AppColors.textPrimary;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.card),
            topRight: const Radius.circular(AppRadius.card),
            bottomLeft: Radius.circular(mine ? AppRadius.card : 0),
            bottomRight: Radius.circular(mine ? 0 : AppRadius.card),
          ),
          border: mine ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SelectableText(message.content, style: TextStyle(color: textColor, fontSize: 15)),
            const SizedBox(height: 2),
            Text(time, style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;

  const _DateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ),
    );
  }
}
