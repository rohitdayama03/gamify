import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/game.dart';
import '../../providers/connection_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/post_provider.dart';
import '../../widgets/feed_post_card.dart';
import '../../widgets/game_tile.dart';
import '../../widgets/news_card.dart';
import '../../widgets/primary_button.dart';
import '../tournaments/tournaments_screen.dart';

/// Home: greeting → game picker → Find players → the feed: friends' posts and your own, best first, with
/// gaming news worked in, loading more as you scroll.
class HomeScreen extends StatefulWidget {
  final ValueChanged<Game> onFindPlayers;

  const HomeScreen({super.key, required this.onFindPlayers});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Start fetching the next page this far before the end, so scrolling rarely waits
  static const double _loadMoreThreshold = 600;

  final _scrollController = ScrollController();
  // The player's posts as last seen; when they share or delete one, the feed reloads to match
  int? _postsVersion;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final feed = Provider.of<FeedProvider>(context, listen: false);
      if (!feed.hasLoaded) feed.refresh();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      Provider.of<FeedProvider>(context, listen: false).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final players = Provider.of<PlayerProvider>(context);
    final feed = Provider.of<FeedProvider>(context);
    final postsVersion = Provider.of<PostProvider>(context).postsVersion;
    if (_postsVersion != postsVersion) {
      if (_postsVersion != null) WidgetsBinding.instance.addPostFrameCallback((_) => feed.refresh());
      _postsVersion = postsVersion;
    }
    final items = feed.items;

    return RefreshIndicator(
      onRefresh: () => Future.wait([
        players.fetchMyProfile(),
        Provider.of<ConnectionProvider>(context, listen: false).fetchConnections(),
        feed.refresh(),
      ]),
      // Header, then one card per post or story, then a loading/end row
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.xs, AppSpacing.gutter, AppSpacing.lg),
        itemCount: items.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) return _buildHeader(context, players);
          if (index == items.length + 1) return _buildFooter(feed);
          final item = items[index - 1];
          return Padding(
            key: ValueKey(item.key),
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: item.isPost ? FeedPostCard(post: item.post!) : NewsCard(item: item.news!),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, PlayerProvider players) {
    final me = players.currentPlayer;
    final selected = me?.preferredGame ?? Game.values.first;
    // Interested games first so the player's own games are easiest to reach
    final games = [
      ...?me?.interestedGames,
      ...Game.values.where((g) => !(me?.interestedGames.contains(g) ?? false)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Hey ${me?.username ?? 'player'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        const SizedBox(height: 4),
        Text('What are we playing today?', style: Theme.of(context).textTheme.headlineSmall),
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
        Text(selected.tagline, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: 'Find ${selected.shortLabel} players',
          icon: Icons.search,
          onPressed: () => widget.onFindPlayers(selected),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => TournamentsScreen.open(context, game: selected),
            icon: const Icon(Icons.emoji_events_outlined),
            label: Text('${selected.shortLabel} tournaments'),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('YOUR FEED', style: AppFonts.label()),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _buildFooter(FeedProvider feed) {
    if (feed.errorMessage == null && feed.hasMore && feed.items.isNotEmpty) {
      // Reaching this row means the player scrolled to the end; fetch the next page if it isn't already coming
      if (!feed.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) => feed.loadMore());
      }
    }
    if (feed.isLoading || (feed.errorMessage == null && feed.hasMore && feed.items.isNotEmpty)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
      );
    }
    if (feed.errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          children: [
            Text(feed.errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              onPressed: feed.items.isEmpty ? feed.refresh : feed.loadMore,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    final message = feed.items.isEmpty ? 'Nothing here yet. Add friends or share a post.' : "You're all caught up";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(child: Text(message.toUpperCase(), style: AppFonts.label(fontWeight: FontWeight.w500))),
    );
  }
}
