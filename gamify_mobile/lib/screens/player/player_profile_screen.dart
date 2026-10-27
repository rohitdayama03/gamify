import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/game.dart';
import '../../models/player_model.dart';
import '../../providers/player_provider.dart';
import '../../widgets/connect_button.dart';
import '../../widgets/game_profile_card.dart';
import '../../widgets/player_header.dart';
import '../../widgets/primary_button.dart';

/// Another player's public profile: who they are, their game profiles, and the action that fits your relationship.
class PlayerProfileScreen extends StatefulWidget {
  final int playerId;
  // Shown in the app bar while the profile loads
  final String? username;

  const PlayerProfileScreen({super.key, required this.playerId, this.username});

  static Future<void> open(
    BuildContext context,
    int playerId, {
    String? username,
  }) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          PlayerProfileScreen(playerId: playerId, username: username),
    ),
  );

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  PlayerResponse? _player;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider = Provider.of<PlayerProvider>(context, listen: false);
    setState(() {
      _loading = true;
      _error = null;
    });
    final player = await provider.fetchPlayer(widget.playerId);
    if (!mounted) return;
    setState(() {
      _player = player;
      _error = player == null ? provider.errorMessage : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = Provider.of<PlayerProvider>(context).currentPlayer;
    final player = _player;

    return Scaffold(
      appBar: AppBar(
        title: Text(player?.username ?? widget.username ?? 'Player profile'),
      ),
      body: _loading && player == null
          ? const Center(child: CircularProgressIndicator())
          : player == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MessageBanner(
                      message: _error ?? 'Could not load this player.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(label: 'Try again', onPressed: _load),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                children: [
                  PlayerHeader(
                    player: player,
                    emptyBioText:
                        "${player.username} hasn't written a bio yet.",
                    action: player.playerId == me?.playerId
                        ? const MessageBanner(
                            message:
                                'This is how other players see your profile.',
                            isError: false,
                          )
                        : ConnectButton(player: player, fullWidth: true),
                  ),
                  ..._buildGameProfiles(player),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildGameProfiles(PlayerResponse player) {
    final games = Game.values.where(player.hasProfileFor).toList();
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.md,
          AppSpacing.gutter,
          AppSpacing.sm,
        ),
        child: Text(
          'GAME PROFILES  [${games.length}]',
          style: AppFonts.label(),
        ),
      ),
      if (games.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: Text(
            "${player.username} hasn't added a game profile yet.",
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      for (final game in games)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppSpacing.sm,
          ),
          child: GameProfileCard(player: player, game: game),
        ),
    ];
  }
}

/// Makes any player tile open that player's profile when tapped.
class OpenProfileOnTap extends StatelessWidget {
  final int playerId;
  final String username;
  final Widget child;

  const OpenProfileOnTap({
    super.key,
    required this.playerId,
    required this.username,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      hint: 'Open $username\'s profile',
      child: InkWell(
        onTap: () =>
            PlayerProfileScreen.open(context, playerId, username: username),
        child: child,
      ),
    );
  }
}
