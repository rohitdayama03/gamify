import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/notifications/push_notifications.dart';
import '../../models/chat_model.dart';
import '../../models/connection_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/squad_provider.dart';
import '../../providers/tournament_provider.dart';
import '../squads/squad_info_screen.dart';
import '../tournaments/tournament_detail_screen.dart';
import '../../widgets/player_avatar.dart';

enum _ChatKind { friend, squad, tournament }

/// A chat with one friend, a squad ([ChatScreen.squad]) or a tournament's announcements
/// ([ChatScreen.tournament]), where only the organizer can write.
class ChatScreen extends StatefulWidget {
  final PlayerSummary? friend;
  final int? squadId;
  final int? tournamentId;
  // Squad or tournament name
  final String? groupName;
  // Tournament chats: false hides the input bar for participants
  final bool canPost;

  const ChatScreen({super.key, required PlayerSummary this.friend})
      : squadId = null,
        tournamentId = null,
        groupName = null,
        canPost = true;

  const ChatScreen.squad({super.key, required int this.squadId, required String squadName})
      : friend = null,
        tournamentId = null,
        groupName = squadName,
        canPost = true;

  const ChatScreen.tournament({
    super.key,
    required int this.tournamentId,
    required String tournamentName,
    required bool isOrganizer,
  })  : friend = null,
        squadId = null,
        groupName = tournamentName,
        canPost = isOrganizer;

  _ChatKind get _kind => squadId != null
      ? _ChatKind.squad
      : tournamentId != null
          ? _ChatKind.tournament
          : _ChatKind.friend;
  bool get isSquad => _kind == _ChatKind.squad;
  bool get isTournament => _kind == _ChatKind.tournament;
  bool get isGroup => !isFriend;
  bool get isFriend => _kind == _ChatKind.friend;
  String get title => friend?.username ?? groupName!;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const Duration _pollInterval = Duration(seconds: 3);
  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  late final ChatProvider _chatProvider;
  late final SquadProvider _squadProvider;
  late final TournamentProvider _tournamentProvider;

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
    _squadProvider = Provider.of<SquadProvider>(context, listen: false);
    _tournamentProvider = Provider.of<TournamentProvider>(context, listen: false);
    _scrollController.addListener(_onScroll);
    _textController.addListener(() => setState(() {})); // toggles the send button
    _loadInitial();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollNewer());
    // This chat is on screen: don't pop up its messages, and clear any notification already showing
    switch (widget._kind) {
      case _ChatKind.friend:
        PushNotifications.openChatPlayerId = widget.friend!.playerId;
        PushNotifications.instance.clearChat(widget.friend!.playerId);
      case _ChatKind.squad:
        PushNotifications.openSquadId = widget.squadId;
        PushNotifications.instance.clearSquad(widget.squadId!);
      case _ChatKind.tournament:
        PushNotifications.openTournamentId = widget.tournamentId;
        PushNotifications.instance.clearTournament(widget.tournamentId!);
    }
  }

  @override
  void dispose() {
    switch (widget._kind) {
      case _ChatKind.friend:
        if (PushNotifications.openChatPlayerId == widget.friend!.playerId) PushNotifications.openChatPlayerId = null;
        // Opening the chat marked messages as read; refresh the list so unread badges clear
        _chatProvider.fetchConversations();
      case _ChatKind.squad:
        if (PushNotifications.openSquadId == widget.squadId) PushNotifications.openSquadId = null;
        _squadProvider.refresh();
      case _ChatKind.tournament:
        if (PushNotifications.openTournamentId == widget.tournamentId) PushNotifications.openTournamentId = null;
        _tournamentProvider.refresh();
    }
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String? get _providerError => switch (widget._kind) {
        _ChatKind.friend => _chatProvider.errorMessage,
        _ChatKind.squad => _squadProvider.errorMessage,
        _ChatKind.tournament => _tournamentProvider.errorMessage,
      };

  Future<List<ChatMessage>?> _fetch({int? afterId, int? beforeId}) => switch (widget._kind) {
        _ChatKind.friend => _chatProvider.fetchMessages(widget.friend!.playerId, afterId: afterId, beforeId: beforeId),
        _ChatKind.squad => _squadProvider.fetchMessages(widget.squadId!, afterId: afterId, beforeId: beforeId),
        _ChatKind.tournament =>
          _tournamentProvider.fetchMessages(widget.tournamentId!, afterId: afterId, beforeId: beforeId),
      };

  Future<void> _loadInitial() async {
    final messages = await _fetch();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (messages == null) {
        _loadError = _providerError;
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
    final newer = await _fetch(afterId: afterId);
    _polling = false;
    if (newer != null && newer.isNotEmpty && mounted) {
      setState(() => _appendUnique(newer));
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasOlder || _messages.isEmpty) return;
    setState(() => _loadingOlder = true);
    final older = await _fetch(beforeId: _messages.first.id);
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
    final sent = await switch (widget._kind) {
      _ChatKind.friend => _chatProvider.sendMessage(widget.friend!.playerId, text),
      _ChatKind.squad => _squadProvider.sendMessage(widget.squadId!, text),
      _ChatKind.tournament => _tournamentProvider.sendMessage(widget.tournamentId!, text),
    };
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (sent != null) {
        _appendUnique([sent]);
        _textController.clear();
      }
    });
    if (sent == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_providerError ?? 'Message not sent')));
    } else if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  // Squad: members, invites and Leave live on its info page, and leaving closes this chat too.
  // Tournament: its page has the details, participants and result.
  Future<void> _openInfo() async {
    if (widget.isTournament) {
      TournamentDetailScreen.open(context, widget.tournamentId!, name: widget.title);
      return;
    }
    final left = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SquadInfoScreen(squadId: widget.squadId!, squadName: widget.title)),
    );
    if (left == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final header = Row(
      children: [
        if (widget.isGroup)
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            child: Icon(widget.isSquad ? Icons.groups : Icons.emoji_events, size: 20, color: AppColors.onPrimary),
          )
        else
          PlayerAvatar(
            name: title,
            url: widget.friend?.avatarUrl,
            radius: 18,
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
          ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, overflow: TextOverflow.ellipsis)),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: widget.isGroup
            ? Semantics(button: true, label: _infoLabel, child: InkWell(onTap: _openInfo, child: header))
            : header,
        actions: [
          if (widget.isGroup)
            IconButton(tooltip: _infoLabel, icon: const Icon(Icons.info_outline), onPressed: _openInfo),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages()),
          widget.canPost ? _buildInputBar() : _buildReadOnlyNotice(),
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
        child: Text(
          switch (widget._kind) {
            _ChatKind.friend => 'Say hi to ${widget.title} 👋',
            _ChatKind.squad => 'Say hi to the squad 👋',
            _ChatKind.tournament =>
              widget.canPost ? 'Post updates for your participants here' : 'Announcements from the organizer appear here',
          },
          style: const TextStyle(color: AppColors.textSecondary),
        ),
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
        // In a squad, name the sender at the start of each run of their messages
        final showSender = widget.isSquad &&
            !message.fromMe &&
            (showDate || previous.senderId != message.senderId);
        return Column(
          children: [
            if (showDate) _DateChip(label: _dayLabel(message.createdAt)),
            _MessageBubble(
              message: message,
              time: _timeLabel(message.createdAt),
              senderName: showSender ? message.senderName : null,
            ),
          ],
        );
      },
    );
  }

  String get _infoLabel => widget.isTournament ? 'Tournament details' : 'Squad info';

  Widget _buildReadOnlyNotice() {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        color: AppColors.cardBackground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined, size: 18, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Flexible(
              child: Text('Only the organizer can send messages', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
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
  // Shown above the text in squad chats
  final String? senderName;

  const _MessageBubble({required this.message, required this.time, this.senderName});

  @override
  Widget build(BuildContext context) {
    final mine = message.fromMe;
    // Dark text on the mint bubble, light text on the dark one
    final textColor = mine ? AppColors.onPrimary : AppColors.textPrimary;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: EdgeInsets.only(top: senderName != null ? 8 : 3, bottom: 3),
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
        child: _fitToContent(Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (senderName != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    senderName!,
                    style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            SelectableText(message.content, style: TextStyle(color: textColor, fontSize: 15)),
            const SizedBox(height: 2),
            Text(time, style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 11)),
          ],
        )),
      ),
    );
  }

  // Keeps the bubble as narrow as its text when the sender's name is left-aligned above it
  Widget _fitToContent(Widget child) => senderName == null ? child : IntrinsicWidth(child: child);
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
