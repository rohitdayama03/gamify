import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/game.dart';
import '../../providers/connection_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/game_tile.dart';
import '../../widgets/primary_button.dart';
import '../profile/edit_game_profiles_screen.dart';

/// Home: greeting → game picker → Find players → quick links (PRD §3 composition).
class HomeScreen extends StatelessWidget {
  final ValueChanged<Game> onFindPlayers;
  final void Function({bool sent}) onOpenRequests;

  const HomeScreen({
    super.key,
    required this.onFindPlayers,
    required this.onOpenRequests,
  });

  @override
  Widget build(BuildContext context) {
    final players = Provider.of<PlayerProvider>(context);
    final me = players.currentPlayer;
    final connections = Provider.of<ConnectionProvider>(context);
    final pending = connections.pendingInvites.length;
    final sentPending = connections.pendingSentCount;
    final selected = me?.preferredGame ?? Game.values.first;
    // Interested games first so the player's own games are easiest to reach
    final games = [
      ...?me?.interestedGames,
      ...Game.values.where((g) => !(me?.interestedGames.contains(g) ?? false)),
    ];
    final hasProfile = me?.hasProfileFor(selected) ?? false;

    return RefreshIndicator(
      onRefresh: () => Future.wait([
        players.fetchMyProfile(),
        Provider.of<ConnectionProvider>(
          context,
          listen: false,
        ).fetchConnections(),
      ]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.xs,
          AppSpacing.gutter,
          AppSpacing.lg,
        ),
        children: [
          Text(
            'Hey ${me?.username ?? 'player'}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'What are we playing today?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final game in games) ...[
                if (game != games.first) const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: GameTile(
                    game: game,
                    compact: true,
                    showTagline: false,
                    selected: game == selected,
                    onTap: () => players.setLastGame(game),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            selected.tagline,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: 'Find ${selected.shortLabel} players',
            icon: Icons.search,
            onPressed: () => onFindPlayers(selected),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Quick links', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _QuickLink(
            icon: Icons.mail_outline,
            title: 'Requests',
            subtitle: [
              pending == 0
                  ? 'No new requests'
                  : '$pending waiting for your reply',
              if (sentPending > 0) '$sentPending sent, awaiting reply',
            ].join(' · '),
            badge: pending,
            // Jump straight to Sent when that's the only thing waiting
            onTap: () => onOpenRequests(sent: pending == 0 && sentPending > 0),
          ),
          const SizedBox(height: AppSpacing.xs),
          _QuickLink(
            icon: Icons.badge_outlined,
            title: hasProfile
                ? 'Edit ${selected.shortLabel} profile'
                : 'Add ${selected.shortLabel} profile',
            subtitle: hasProfile
                ? 'Keep your details current so players can find you'
                : 'Players can only find you once you add one',
            onTap: () => EditGameProfilesScreen.open(context, selected),
          ),
        ],
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int badge;
  // Null renders the link disabled; the subtitle explains why
  final VoidCallback? onTap;

  const _QuickLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        enabled: enabled,
        onTap: onTap,
        minTileHeight: 64,
        leading: Icon(
          icon,
          color: enabled ? AppColors.secondary : AppColors.textSecondary,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge > 0) Badge(label: Text('$badge')),
            if (enabled)
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
