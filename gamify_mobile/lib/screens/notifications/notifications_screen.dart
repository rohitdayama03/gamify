import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/time_format.dart';
import '../../models/connection_model.dart';
import '../../providers/connection_provider.dart';
import '../player/player_profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  /// Embedded in Inbox → Requests: no app bar and only pending invites
  final bool embedded;

  const NotificationsScreen({super.key, this.embedded = false});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const List<String> _categories = ['All', 'Invites'];
  String _selected = _categories.first;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConnectionProvider>(context);

    // Pending invites first, then "accepted your invite" updates, newest first
    final items = <ConnectionResponse>[
      ...provider.pendingInvites,
      if (_selected == 'All' && !widget.embedded)
        ...(provider.acceptedSentInvites..sort((a, b) => _sortKey(b).compareTo(_sortKey(a)))),
    ];

    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Notifications')),
      body: Column(
        children: [
          // Category chips only apply to the full notifications page
          if (!widget.embedded)
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final category = _categories[index];
                final selected = category == _selected;
                return ChoiceChip(
                  label: Text(category),
                  selected: selected,
                  onSelected: (_) => setState(() => _selected = category),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: selected ? AppColors.onPrimary : AppColors.textPrimary, fontWeight: FontWeight.w600),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                );
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: provider.fetchConnections,
              child: provider.isLoading && items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? _buildEmpty()
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.background),
                          itemBuilder: (_, index) {
                            final item = items[index];
                            return item.status == ConnectionStatus.pending
                                ? _InviteTile(invite: item)
                                : _AcceptedTile(connection: item);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  static DateTime _sortKey(ConnectionResponse c) => c.respondedAt ?? c.createdAt ?? DateTime(0);

  Widget _buildEmpty() {
    // ListView so pull-to-refresh still works when there is nothing to show
    return ListView(
      children: const [
        SizedBox(height: 120),
        Icon(Icons.notifications_none, size: 64, color: AppColors.textSecondary),
        SizedBox(height: 12),
        Center(child: Text("You're all caught up", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        SizedBox(height: 4),
        Center(child: Text('Requests from other players will show up here.', style: TextStyle(color: AppColors.textSecondary))),
      ],
    );
  }
}

class _InviteTile extends StatelessWidget {
  final ConnectionResponse invite;

  const _InviteTile({required this.invite});

  Future<void> _respond(BuildContext context, bool accept) async {
    final provider = Provider.of<ConnectionProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final name = invite.otherPlayer.username;
    final ok = accept ? await provider.acceptInvite(invite.id) : await provider.declineInvite(invite.id);
    messenger.showSnackBar(SnackBar(
      content: Text(!ok
          ? provider.errorMessage ?? 'Something went wrong'
          : accept
              ? 'You and $name are now friends'
              : 'Invite from $name declined'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final busy = Provider.of<ConnectionProvider>(context).isBusy(invite.id);
    final player = invite.otherPlayer;

    return OpenProfileOnTap(
      playerId: player.playerId,
      username: player.username,
      child: Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(name: player.username),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: player.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: ' wants to connect with you'),
                ])),
                if (player.playerBio != null && player.playerBio!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(player.playerBio!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 2),
                Text(timeAgo(invite.createdAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: busy ? null : () => _respond(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('Decline'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: busy ? null : () => _respond(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: busy
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary))
                          : const Text('Accept', style: TextStyle(color: AppColors.onPrimary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}

class _AcceptedTile extends StatelessWidget {
  final ConnectionResponse connection;

  const _AcceptedTile({required this.connection});

  @override
  Widget build(BuildContext context) {
    return OpenProfileOnTap(
      playerId: connection.otherPlayer.playerId,
      username: connection.otherPlayer.username,
      child: Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _Avatar(name: connection.otherPlayer.username),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: connection.otherPlayer.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: ' accepted your invite. You are now friends.'),
                ])),
                const SizedBox(height: 2),
                Text(timeAgo(connection.respondedAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    ));
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
      child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.bold)),
    );
  }
}
