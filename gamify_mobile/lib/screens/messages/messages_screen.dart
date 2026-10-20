import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/chat_model.dart';
import '../../models/connection_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connection_provider.dart';
import 'chat_screen.dart';

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

  void _openNewMessageSheet() {
    final friends = Provider.of<ConnectionProvider>(context, listen: false).friends;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('New message', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            if (friends.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Text('You can only message friends. Find players on Home and send them an invite.',
                    style: TextStyle(color: AppColors.textSecondary)),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final friend in friends)
                      ListTile(
                        leading: _Avatar(name: friend.username),
                        title: Text(friend.username),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          MessagesScreen.openChat(context, friend);
                        },
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final query = _searchController.text.trim().toLowerCase();
    final conversations = chatProvider.conversations
        .where((c) => query.isEmpty || c.friend.username.toLowerCase().contains(query))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewMessageSheet,
        backgroundColor: AppColors.primary,
        tooltip: 'New message',
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search messages',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: chatProvider.fetchConversations,
              child: chatProvider.isLoading && chatProvider.conversations.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : conversations.isEmpty
                      ? _buildEmpty(searching: query.isNotEmpty)
                      : ListView.separated(
                          itemCount: conversations.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, indent: 76, color: AppColors.cardBackground),
                          itemBuilder: (_, index) => _ConversationTile(
                            conversation: conversations[index],
                            onTap: () => MessagesScreen.openChat(context, conversations[index].friend),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty({required bool searching}) {
    // ListView so pull-to-refresh still works when there is nothing to show
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        const SizedBox(height: 100),
        const Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Center(
          child: Text(searching ? 'No matching conversations' : 'No conversations yet',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        if (!searching) ...[
          const SizedBox(height: 4),
          const Text('Tap ✎ to message one of your friends.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
        ],
      ],
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const _ConversationTile({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = conversation.unreadCount > 0;
    final last = conversation.lastMessage;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _Avatar(name: conversation.friend.username),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversation.friend.username,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: unread ? FontWeight.bold : FontWeight.w600),
            ),
          ),
          Text(
            _shortTime(last.createdAt),
            style: TextStyle(fontSize: 12, color: unread ? AppColors.primary : AppColors.textSecondary),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              '${last.fromMe ? 'You: ' : ''}${last.content}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unread ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (unread) ...[
            const SizedBox(width: 8),
            Badge(label: Text('${conversation.unreadCount}'), backgroundColor: AppColors.primary),
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
      backgroundColor: AppColors.primary,
      child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}
