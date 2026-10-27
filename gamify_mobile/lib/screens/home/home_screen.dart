import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/game.dart';
import '../../providers/connection_provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/game_tile.dart';
import '../../widgets/news_card.dart';
import '../../widgets/primary_button.dart';

/// Home: greeting → game picker → Find players → gaming news feed (newest first, older as you scroll).
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final news = Provider.of<NewsProvider>(context, listen: false);
      if (!news.hasLoaded) news.refresh();
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
      Provider.of<NewsProvider>(context, listen: false).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final players = Provider.of<PlayerProvider>(context);
    final news = Provider.of<NewsProvider>(context);
    final items = news.items;

    return RefreshIndicator(
      onRefresh: () => Future.wait([
        players.fetchMyProfile(),
        Provider.of<ConnectionProvider>(context, listen: false).fetchConnections(),
        news.refresh(),
      ]),
      // Header, then one card per story, then a loading/end row
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.xs, AppSpacing.gutter, AppSpacing.lg),
        itemCount: items.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) return _buildHeader(context, players);
          if (index == items.length + 1) return _buildFooter(news);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: NewsCard(item: items[index - 1]),
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
        const SizedBox(height: AppSpacing.lg),
        Text('LATEST GAMING NEWS', style: AppFonts.label()),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _buildFooter(NewsProvider news) {
    if (news.errorMessage == null && news.hasMore && news.items.isNotEmpty) {
      // Reaching this row means the player scrolled to the end; fetch the next page if it isn't already coming
      if (!news.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) => news.loadMore());
      }
    }
    if (news.isLoading || (news.errorMessage == null && news.hasMore && news.items.isNotEmpty)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
      );
    }
    if (news.errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          children: [
            Text(news.errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              onPressed: news.items.isEmpty ? news.refresh : news.loadMore,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    final message = news.items.isEmpty ? 'No news yet. Check back soon.' : "You're all caught up";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(child: Text(message.toUpperCase(), style: AppFonts.label(fontWeight: FontWeight.w500))),
    );
  }
}
