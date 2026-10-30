import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/time_format.dart';
import '../../models/connection_model.dart';
import '../../models/squad_model.dart';
import '../../models/tournament_model.dart';
import '../../providers/connection_provider.dart';
import '../../providers/squad_provider.dart';
import '../../providers/tournament_provider.dart';
import '../messages/chat_screen.dart';
import '../player/player_profile_screen.dart';
import '../tournaments/tournament_detail_screen.dart';
import '../../widgets/player_avatar.dart';

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
    final squadProvider = Provider.of<SquadProvider>(context);
    final tournamentProvider = Provider.of<TournamentProvider>(context);
    // Squad invites and tournament join requests are always pending, so they lead the list
    final squadInvites = squadProvider.invites;
    final joinRequests = tournamentProvider.requests;
    final leading = squadInvites.length + joinRequests.length;

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
              onRefresh: () => Future.wait([provider.fetchConnections(), squadProvider.refresh(), tournamentProvider.refresh()]),
              child: (provider.isLoading || squadProvider.isLoading || tournamentProvider.isLoading) &&
                      items.isEmpty &&
                      leading == 0
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty && leading == 0
                      ? _buildEmpty()
                      : ListView.separated(
                          itemCount: leading + items.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.background),
                          itemBuilder: (_, index) {
                            if (index < joinRequests.length) return _JoinRequestTile(request: joinRequests[index]);
                            if (index < leading) return _SquadInviteTile(invite: squadInvites[index - joinRequests.length]);
                            final item = items[index - leading];
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
        Center(child: Text('Requests and invites will show up here.', style: TextStyle(color: AppColors.textSecondary))),
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
          _Avatar(player: player),
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

/// Someone asked to join a tournament the signed-in player organizes.
class _JoinRequestTile extends StatelessWidget {
  final TournamentRequest request;

  const _JoinRequestTile({required this.request});

  Future<void> _respond(BuildContext context, bool accept) async {
    final provider = Provider.of<TournamentProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final name = request.player.username;
    final updated = accept ? await provider.acceptRequest(request.id) : await provider.rejectRequest(request.id);
    messenger.showSnackBar(SnackBar(
      content: Text(updated == null
          ? provider.errorMessage ?? 'Something went wrong'
          : accept
              ? '$name is in ${request.tournamentName}'
              : 'Declined $name'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final busy = Provider.of<TournamentProvider>(context).isBusy(request.id);
    final player = request.player;

    return InkWell(
      onTap: () => TournamentDetailScreen.open(context, request.tournamentId, name: request.tournamentName),
      child: Container(
        color: AppColors.cardBackground,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.emoji_events, color: AppColors.onPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: player.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const TextSpan(text: ' wants to join '),
                    TextSpan(text: request.tournamentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ])),
                  const SizedBox(height: 2),
                  Text(
                    [if (request.game != null) request.game!.shortLabel, 'Tournament', timeAgo(request.requestedAt)].join(' · '),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
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
      ),
    );
  }
}

class _SquadInviteTile extends StatelessWidget {
  final SquadInvite invite;

  const _SquadInviteTile({required this.invite});

  Future<void> _respond(BuildContext context, bool accept) async {
    final provider = Provider.of<SquadProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final name = invite.squadName;
    if (!accept) {
      final ok = await provider.declineInvite(invite.id);
      messenger.showSnackBar(SnackBar(content: Text(ok ? 'Invite to $name declined' : provider.errorMessage ?? 'Something went wrong')));
      return;
    }
    final squad = await provider.acceptInvite(invite.id);
    if (squad == null) {
      messenger.showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Something went wrong')));
      // The squad may be gone or the invite withdrawn; drop the stale tile
      await provider.refresh();
      return;
    }
    messenger.showSnackBar(SnackBar(
      content: Text('You joined ${squad.name}'),
      action: SnackBarAction(
        label: 'Open',
        onPressed: () => navigator.push(
          MaterialPageRoute(builder: (_) => ChatScreen.squad(squadId: squad.id, squadName: squad.name)),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final busy = Provider.of<SquadProvider>(context).isBusy(invite.id);
    final inviter = invite.invitedBy?.username;
    final members = invite.memberCount;

    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.groups, color: AppColors.onPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(TextSpan(children: [
                  if (inviter != null) ...[
                    TextSpan(text: inviter, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const TextSpan(text: ' invited you to join '),
                  ] else
                    const TextSpan(text: "You're invited to join "),
                  TextSpan(text: invite.squadName, style: const TextStyle(fontWeight: FontWeight.bold)),
                ])),
                const SizedBox(height: 2),
                Text(
                  'Squad · $members member${members == 1 ? '' : 's'} · ${timeAgo(invite.createdAt)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
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
                          : const Text('Join', style: TextStyle(color: AppColors.onPrimary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
          _Avatar(player: connection.otherPlayer),
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
  final PlayerSummary player;

  const _Avatar({required this.player});

  @override
  Widget build(BuildContext context) {
    return PlayerAvatar(
      name: player.username,
      url: player.avatarUrl,
      radius: 24,
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
    );
  }
}
