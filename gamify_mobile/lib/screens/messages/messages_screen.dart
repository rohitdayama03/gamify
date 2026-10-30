import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/chat_model.dart';
import '../../models/connection_model.dart';
import '../../models/squad_model.dart';
import '../../models/tournament_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/squad_provider.dart';
import '../../providers/tournament_provider.dart';
import '../squads/create_squad_screen.dart';
import 'chat_screen.dart';
import '../../widgets/player_avatar.dart';

/// One row per friend (their chat if you've talked, otherwise a "say hi" row), one per squad you've
/// joined, and one per tournament you organize or were accepted into (its announcements). Newest activity first, where activity is the last message or the moment you became friends
/// or joined the squad, whichever is later.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  /// Opens the chat with [friend] from anywhere in the app.
  static void openChat(BuildContext context, PlayerSummary friend) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(friend: friend)));
  }

  static void openTournament(BuildContext context, TournamentChat chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen.tournament(tournamentId: chat.id, tournamentName: chat.name, isOrganizer: chat.isOrganizer),
      ),
    );
  }

  static void openSquad(BuildContext context, SquadSummary squad) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen.squad(squadId: squad.id, squadName: squad.name)));
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
  List<_ChatRow> _buildRows(
    List<Conversation> conversations,
    List<({PlayerSummary friend, DateTime? since})> friendships,
    List<SquadSummary> squads,
    List<TournamentChat> tournaments,
  ) {
    final byFriend = {for (final c in conversations) c.friend.playerId: c};
    final rows = <_ChatRow>[
      for (final f in friendships)
        _ChatRow(friend: f.friend, conversation: byFriend.remove(f.friend.playerId), friendsSince: f.since),
      for (final c in byFriend.values) _ChatRow(friend: c.friend, conversation: c),
      for (final squad in squads) _ChatRow.squad(squad),
      for (final tournament in tournaments) _ChatRow.tournament(tournament),
    ];
    rows.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final connections = Provider.of<ConnectionProvider>(context);
    final squadProvider = Provider.of<SquadProvider>(context);
    final tournamentProvider = Provider.of<TournamentProvider>(context);
    final query = _searchController.text.trim().toLowerCase();
    final allRows = _buildRows(
      chatProvider.conversations,
      connections.friendships,
      squadProvider.squads,
      tournamentProvider.chats,
    );
    // Name prefix match, like player search on Discover; the list is local so it filters from the first letter
    final rows = query.isEmpty ? allRows : allRows.where((r) => r.title.toLowerCase().startsWith(query)).toList();
    final loading =
        (chatProvider.isLoading || connections.isLoading || squadProvider.isLoading || tournamentProvider.isLoading) &&
            allRows.isEmpty;

    // Shown inside Inbox, which provides the app bar
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateSquadScreen())),
        icon: const Icon(Icons.group_add),
        label: const Text('New squad'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
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
                  hintText: 'Search friends and squads',
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
              onRefresh: () => Future.wait([
                chatProvider.fetchConversations(),
                connections.fetchConnections(),
                squadProvider.refresh(),
                tournamentProvider.refresh(),
              ]),
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : rows.isEmpty
                      ? _buildEmpty(query: query, hasFriends: allRows.isNotEmpty)
                      : ListView.separated(
                          // Room for the New squad button over the last row
                          padding: const EdgeInsets.only(bottom: 88),
                          itemCount: rows.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, indent: 76, color: AppColors.cardBackground),
                          itemBuilder: (_, index) => _ChatTile(
                            row: rows[index],
                            onTap: () {
                              final row = rows[index];
                              if (row.squad != null) {
                                MessagesScreen.openSquad(context, row.squad!);
                              } else if (row.tournament != null) {
                                MessagesScreen.openTournament(context, row.tournament!);
                              } else {
                                MessagesScreen.openChat(context, row.friend!);
                              }
                            },
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
          hasFriends ? 'Nothing matches "$query"' : 'No chats yet',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          hasFriends
              ? 'Search matches the start of a username, squad or tournament name.'
              : 'When a player accepts your request, a chat with them appears here. You can also start a squad with your friends.',
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

/// A friend chat, a squad when [squad] is set, or a tournament's announcements when [tournament] is set.
class _ChatRow {
  final PlayerSummary? friend;
  final Conversation? conversation;
  final DateTime? friendsSince;
  final SquadSummary? squad;
  final TournamentChat? tournament;

  _ChatRow({required PlayerSummary this.friend, this.conversation, this.friendsSince})
      : squad = null,
        tournament = null;

  _ChatRow.squad(SquadSummary this.squad)
      : friend = null,
        conversation = null,
        friendsSince = null,
        tournament = null;

  _ChatRow.tournament(TournamentChat this.tournament)
      : friend = null,
        conversation = null,
        friendsSince = null,
        squad = null;

  String get title => squad?.name ?? tournament?.name ?? friend!.username;

  int get unreadCount => squad?.unreadCount ?? tournament?.unreadCount ?? conversation?.unreadCount ?? 0;

  ChatMessage? get lastMessage => squad != null
      ? squad!.lastMessage
      : tournament != null
          ? tournament!.lastMessage
          : conversation?.lastMessage;

  DateTime get lastActivity {
    final messageTime = lastMessage?.createdAt;
    final since = squad?.joinedAt ?? tournament?.since ?? friendsSince;
    if (messageTime == null) return since ?? DateTime(0);
    if (since == null) return messageTime;
    return messageTime.isAfter(since) ? messageTime : since;
  }

  // The latest event is the friendship or joining the squad itself (no messages, or none since)
  // Tournaments always show their latest announcement once there is one
  bool get showsNewFriend =>
      lastMessage == null || (tournament == null && lastActivity != lastMessage!.createdAt);
}

class _ChatTile extends StatelessWidget {
  final _ChatRow row;
  final VoidCallback onTap;

  const _ChatTile({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final squad = row.squad;
    final tournament = row.tournament;
    final unreadCount = row.unreadCount;
    final unread = unreadCount > 0;
    final last = row.lastMessage;
    final String preview;
    // Earlier announcements are unread for a newly accepted player, so show the latest one if there is any
    if (tournament != null && last == null) {
      preview = tournament.isOrganizer ? 'Post updates for your players' : "You're in · announcements appear here";
    } else if (tournament != null) {
      // Only the organizer posts, so no sender name is needed
      preview = '${last!.fromMe ? 'You: ' : '📣 '}${last.content}';
    } else if (row.showsNewFriend) {
      preview = squad != null
          ? '${squad.memberCount} member${squad.memberCount == 1 ? '' : 's'} · say hi'
          : "You're now friends · say hi";
    } else if (last!.fromMe) {
      preview = 'You: ${last.content}';
    } else {
      // Squad previews name who wrote, since there are several senders
      preview = squad != null && last.senderName != null ? '${last.senderName}: ${last.content}' : last.content;
    }

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _Avatar(
        name: row.title,
        url: row.friend?.avatarUrl,
        icon: squad != null
            ? Icons.groups
            : tournament != null
                ? Icons.emoji_events
                : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              row.title,
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
  // A friend's profile picture
  final String? url;
  // Squads and tournaments show an icon instead
  final IconData? icon;

  const _Avatar({required this.name, this.url, this.icon});

  @override
  Widget build(BuildContext context) {
    if (icon == null) return PlayerAvatar(name: name, url: url, radius: 24);
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.surfaceAlt,
      child: Icon(icon, color: AppColors.primary),
    );
  }
}
