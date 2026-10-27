import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/connection_model.dart';
import '../../models/game.dart';
import '../../models/player_model.dart';
import '../../providers/connection_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/game_profile_card.dart';
import '../../widgets/player_header.dart';
import '../messages/messages_screen.dart';
import '../settings/edit_interests_screen.dart';
import 'edit_game_profiles_screen.dart';
import 'edit_profile_screen.dart';
import '../../core/theme/app_theme.dart';

/// Profile hub: account header, a card per game profile, then friends (PRD §5).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PlayerProvider>(context, listen: false).fetchMyProfile();
    });
  }

  void _editProfile() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
  );

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final player = playerProvider.currentPlayer;
    final friends = Provider.of<ConnectionProvider>(context).friends;

    // Shown inside the main shell, which provides the app bar (Settings holds sign out)
    return Scaffold(
      // Only show the full-page spinner on first load, so refreshes keep the page visible
      body: player == null
          ? playerProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : const Center(child: Text('No Profile Found'))
          : RefreshIndicator(
              onRefresh: () => Future.wait([
                playerProvider.fetchMyProfile(),
                Provider.of<ConnectionProvider>(
                  context,
                  listen: false,
                ).fetchConnections(),
              ]),
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                children: [
                  // Full-width identity header; the game cards below keep the side gutters
                  PlayerHeader(
                    player: player,
                    emptyBioText:
                        'No bio yet. A short bio helps players decide to accept your request.',
                    action: SizedBox(
                      height: 44,
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _editProfile,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit profile'),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.gutter,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        ..._buildGameProfiles(player),
                        const SizedBox(height: AppSpacing.lg),
                        _FriendsCard(friends: friends),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildGameProfiles(PlayerResponse player) {
    // The player's chosen games, plus any game they still have a profile for
    final games = [
      ...player.interestedGames,
      ...Game.values.where(
        (g) => !player.interestedGames.contains(g) && player.hasProfileFor(g),
      ),
    ];
    final added = games.where(player.hasProfileFor).length;

    return [
      Row(
        children: [
          Expanded(child: Text('GAME PROFILES', style: AppFonts.label())),
          Text(
            '$added OF ${games.length} ADDED',
            style: AppFonts.label(fontWeight: FontWeight.w500),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      for (final game in games) ...[
        player.hasProfileFor(game)
            ? GameProfileCard(
                player: player,
                game: game,
                actionLabel: 'Edit ${game.shortLabel} profile',
                onAction: () => EditGameProfilesScreen.open(context, game),
              )
            : AddGameProfileCard(
                game: game,
                onAdd: () => EditGameProfilesScreen.open(context, game),
              ),
        const SizedBox(height: AppSpacing.sm),
      ],
      if (games.length < Game.values.length)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditInterestsScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add another game'),
          ),
        ),
    ];
  }
}

class _FriendsCard extends StatelessWidget {
  final List<PlayerSummary> friends;

  const _FriendsCard({required this.friends});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Text(
              'Friends (${friends.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (friends.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Text(
                'No friends yet. Find players on Discover and send them a request.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            for (final friend in friends)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.surfaceAlt,
                  child: Text(
                    friend.username.isEmpty
                        ? '?'
                        : friend.username[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  friend.username,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  [
                    friend.country,
                    friend.language,
                  ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.secondary,
                  ),
                  tooltip: 'Message ${friend.username}',
                  onPressed: () => MessagesScreen.openChat(context, friend),
                ),
                onTap: () => MessagesScreen.openChat(context, friend),
              ),
        ],
      ),
    );
  }
}
