import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/chat_model.dart';
import '../../models/connection_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connection_provider.dart';
import 'chat_screen.dart';

/// One row per friend: their chat if you've talked, otherwise a "say hi" row. Newest activity first,
/// where activity is the last message or the moment you became friends, whichever is later.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  /// Opens the chat with [friend] from anywhere in the app.
  static void openChat(BuildContext context, PlayerSummary friend) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(friend: friend)));
  }

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
  }

  // Every friend gets a row; conversations with someone no longer in the friend list keep theirs too
  List<_ChatRow> _buildRows(List<Conversation> conversations, List<({PlayerSummary friend, DateTime? since})> friendships) {
    final byFriend = {for (final c in conversations) c.friend.playerId: c};
    final rows = <_ChatRow>[
      for (final f in friendships)
        _ChatRow(friend: f.friend, conversation: byFriend.remove(f.friend.playerId), friendsSince: f.since),
      for (final c in byFriend.values) _ChatRow(friend: c.friend, conversation: c),
    ];
    rows.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final connections = Provider.of<ConnectionProvider>(context);
    final query = _searchController.text.trim().toLowerCase();
    final allRows = _buildRows(chatProvider.conversations, connections.friendships);
    // Username prefix match, like player search on Discover; the list is local so it filters from the first letter
    final rows = query.isEmpty ? allRows : allRows.where((r) => r.friend.username.toLowerCase().startsWith(query)).toList();
    final loading = (chatProvider.isLoading || connections.isLoading) && allRows.isEmpty;

    // Shown inside Inbox, which provides the app bar
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SizedBox(
              height: 48,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search users',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                          tooltip: 'Clear search',
                          onPressed: _clearSearch,
                        ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => Future.wait([chatProvider.fetchConversations(), connections.fetchConnections()]),
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : rows.isEmpty
                      ? _buildEmpty(query: query, hasFriends: allRows.isNotEmpty)
                      : ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, indent: 76, color: AppColors.cardBackground),
                          itemBuilder: (_, index) => _ChatTile(
                            row: rows[index],
                            onTap: () => MessagesScreen.openChat(context, rows[index].friend),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty({required String query, required bool hasFriends}) {
    // ListView so pull-to-refresh still works when there is nothing to show
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        const SizedBox(height: 100),
        Icon(hasFriends ? Icons.person_search : Icons.chat_bubble_outline, size: 64, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Text(
          hasFriends ? 'No friends match "$query"' : 'No friends yet',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          hasFriends
              ? 'Search matches the start of a username.'
              : 'When a player accepts your request, a chat with them appears here.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (hasFriends) ...[
          const SizedBox(height: 12),
          Center(child: OutlinedButton(onPressed: _clearSearch, child: const Text('Clear search'))),
        ],
      ],
    );
  }
}

class _ChatRow {
  final PlayerSummary friend;
  final Conversation? conversation;
  final DateTime? friendsSince;

  _ChatRow({required this.friend, this.conversation, this.friendsSince});

  DateTime get lastActivity {
    final messageTime = conversation?.lastMessage.createdAt;
    final since = friendsSince;
    if (messageTime == null) return since ?? DateTime(0);
    if (since == null) return messageTime;
    return messageTime.isAfter(since) ? messageTime : since;
  }

  // The latest event is the friendship itself (no messages, or none since becoming friends again)
  bool get showsNewFriend => conversation == null || lastActivity != conversation!.lastMessage.createdAt;
}

class _ChatTile extends StatelessWidget {
  final _ChatRow row;
  final VoidCallback onTap;

  const _ChatTile({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final conversation = row.conversation;
    final unreadCount = conversation?.unreadCount ?? 0;
    final unread = unreadCount > 0;
    final last = conversation?.lastMessage;
    final String preview;
    if (row.showsNewFriend) {
      preview = "You're now friends · say hi";
    } else {
      preview = '${last!.fromMe ? 'You: ' : ''}${last.content}';
    }

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _Avatar(name: row.friend.username),
      title: Row(
        children: [
          Expanded(
            child: Text(
              row.friend.username,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: unread ? FontWeight.bold : FontWeight.w600),
            ),
          ),
          if (row.lastActivity.year > 1)
            Text(
              _shortTime(row.lastActivity),
              style: TextStyle(fontSize: 12, color: unread ? AppColors.primary : AppColors.textSecondary),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unread || row.showsNewFriend ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
                fontStyle: row.showsNewFriend ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          if (unread) ...[
            const SizedBox(width: 8),
            Badge(label: Text('$unreadCount'), backgroundColor: AppColors.primary),
          ],
        ],
      ),
    );
  }

  static String _shortTime(DateTime time) {
    final now = DateTime.now();
    if (time.year == now.year && time.month == now.month && time.day == now.day) {
      final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
      return '$hour:${time.minute.toString().padLeft(2, '0')} ${time.hour < 12 ? 'AM' : 'PM'}';
    }
    final days = now.difference(time).inDays;
    if (days < 7) return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][time.weekday - 1];
    return '${time.day}/${time.month}/${time.year % 100}';
  }
}

class _Avatar extends StatelessWidget {
  final String name;

  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.surfaceAlt,
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      ),
    );
  }
}
