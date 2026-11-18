import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/game.dart';
import '../../models/tournament_model.dart';
import '../../providers/tournament_provider.dart';
import 'create_tournament_screen.dart';
import 'tournament_card.dart';
import 'tournament_detail_screen.dart';

/// Browse open tournaments by game, search every tournament by name or organizer, or see the ones you
/// organize and joined.
class TournamentsScreen extends StatefulWidget {
  final Game? initialGame;

  const TournamentsScreen({super.key, this.initialGame});

  static Future<void> open(BuildContext context, {Game? game}) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentsScreen(initialGame: game)));

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  static const Duration _debounceDelay = Duration(milliseconds: 300);
  static const int _pageSize = 20;

  late Game? _game = widget.initialGame;
  bool _showMine = false;
  final _searchController = TextEditingController();
  Timer? _debounce;
  // The search being shown; null lists open tournaments instead
  String? _query;
  TournamentStatusFilter _status = TournamentStatusFilter.any;
  TournamentSearchSort _sort = TournamentSearchSort.relevance;

  List<TournamentSummary>? _tournaments;
  bool _loading = true;
  String? _error;
  // Search results come a page at a time
  int _page = 0;
  bool _hasMore = false;
  bool _loadingMore = false;
  // Ignores answers to an earlier filter or search that arrive after a newer one
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool get _searching => !_showMine && _query != null;

  Future<void> _load() async {
    final token = ++_loadToken;
    setState(() {
      _loading = true;
      _error = null;
    });
    final provider = Provider.of<TournamentProvider>(context, listen: false);
    final searching = _searching;
    final result = _showMine
        ? await provider.fetchMine()
        : searching
            ? await _fetchPage(provider, 0)
            : await provider.fetchOpen(game: _game);
    if (!mounted || token != _loadToken) return;
    setState(() {
      _loading = false;
      _tournaments = result ?? _tournaments;
      _error = result == null ? provider.errorMessage : null;
      _page = 0;
      _hasMore = searching && result != null && result.length == _pageSize;
      _loadingMore = false;
    });
  }

  Future<List<TournamentSummary>?> _fetchPage(TournamentProvider provider, int page) => provider.searchTournaments(
        query: _query!,
        game: _game,
        status: _status,
        sort: _sort,
        page: page,
        pageSize: _pageSize,
      );

  Future<void> _loadMore() async {
    if (!_searching || !_hasMore || _loadingMore || _loading) return;
    final token = _loadToken;
    setState(() => _loadingMore = true);
    final provider = Provider.of<TournamentProvider>(context, listen: false);
    final next = await _fetchPage(provider, _page + 1);
    if (!mounted || token != _loadToken) return;
    setState(() {
      _loadingMore = false;
      if (next == null) {
        // Stop asking until the next search; pull to refresh starts over
        _hasMore = false;
        return;
      }
      // A tournament created meanwhile can shift a page; don't list one twice
      final seen = {for (final t in _tournaments ?? const <TournamentSummary>[]) t.id};
      _tournaments = [...?_tournaments, ...next.where((t) => !seen.contains(t.id))];
      _page++;
      _hasMore = next.length == _pageSize;
    });
  }

  void _select({Game? game, bool? mine}) {
    setState(() {
      if (mine != null) _showMine = mine;
      if (mine == null) _game = game;
    });
    _load();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    final trimmed = text.trim();
    final next = trimmed.length >= TournamentProvider.minSearchLength ? trimmed : null;
    // Redraws the clear button and the "keep typing" hint straight away
    setState(() {});
    if (next == _query) return;
    _debounce = Timer(_debounceDelay, () {
      setState(() => _query = next);
      _load();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _setStatus(TournamentStatusFilter status) {
    if (status == _status) return;
    setState(() => _status = status);
    _load();
  }

  void _setSort(TournamentSearchSort sort) {
    if (sort == _sort) return;
    setState(() => _sort = sort);
    _load();
  }

  Future<void> _openTournament(TournamentSummary t) async {
    await TournamentDetailScreen.open(context, t.id, name: t.name);
    // Joining, withdrawing or cancelling changes what this list should show
    if (mounted) _load();
  }

  Future<void> _organize() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTournamentScreen(initialGame: _game)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _tournaments ?? const <TournamentSummary>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Tournaments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _organize,
        icon: const Icon(Icons.add),
        label: const Text('Organize'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Browse'), icon: Icon(Icons.explore_outlined)),
                ButtonSegment(value: true, label: Text('Mine'), icon: Icon(Icons.emoji_events_outlined)),
              ],
              selected: {_showMine},
              showSelectedIcon: false,
              onSelectionChanged: (value) => _select(mine: value.first),
            ),
          ),
          // Search and the game filter only apply to Browse; Mine shows every game
          if (!_showMine) ...[
            _buildSearchBar(),
            _buildGameChips(),
            if (_searching) _buildSearchOptions(),
          ] else
            const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading && _tournaments == null
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? _buildEmpty()
                      : NotificationListener<ScrollNotification>(
                          // Fetch the next page of search results before reaching the bottom
                          onNotification: (n) {
                            if (n.metrics.extentAfter < 400) _loadMore();
                            return false;
                          },
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, 88),
                            itemCount: items.length + (_loadingMore ? 1 : 0),
                            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                            itemBuilder: (_, index) => index == items.length
                                ? const Padding(
                                    padding: EdgeInsets.all(AppSpacing.md),
                                    child: Center(child: CircularProgressIndicator()),
                                  )
                                : TournamentCard(
                                    tournament: items[index],
                                    onTap: () => _openTournament(items[index]),
                                  ),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final typed = _searchController.text.trim();
    final tooShort = typed.isNotEmpty && typed.length < TournamentProvider.minSearchLength;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 48,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search tournament or organizer',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                suffixIcon: _searchController.text.isEmpty
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
          if (tooShort)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Keep typing: search starts at ${TournamentProvider.minSearchLength} characters',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGameChips() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.xs),
        children: [
          for (final game in <Game?>[null, ...Game.values]) ...[
            ChoiceChip(
              label: Text(game?.shortLabel ?? 'All games'),
              selected: _game == game,
              onSelected: (_) => _select(game: game),
              showCheckmark: false,
              selectedColor: AppColors.primary,
              labelStyle: AppTheme.chipLabel(_game == game),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }

  // Which tournaments the search covers and how they're ordered
  Widget _buildSearchOptions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.xs),
      child: Row(
        children: [
          Flexible(
            child: _OptionMenu<TournamentStatusFilter>(
              icon: Icons.filter_list,
              tooltip: 'Status',
              value: _status,
              values: TournamentStatusFilter.values,
              label: (s) => s.label,
              onSelected: _setStatus,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: _OptionMenu<TournamentSearchSort>(
              icon: Icons.sort,
              tooltip: 'Sort by',
              value: _sort,
              values: TournamentSearchSort.values,
              label: (s) => s.label,
              onSelected: _setSort,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final String title;
    final String body;
    if (_error != null) {
      title = "Couldn't load tournaments";
      body = _error!;
    } else if (_showMine) {
      title = 'No tournaments yet';
      body = 'Tournaments you organize or ask to join show up here.';
    } else if (_searching) {
      title = 'No tournaments found';
      final filters = [
        if (_game != null) _game!.shortLabel,
        if (_status != TournamentStatusFilter.any) _status.label.toLowerCase(),
      ];
      body = filters.isEmpty
          ? 'Nothing matches "$_query". Try part of the tournament name or the organizer\'s username.'
          : 'No ${filters.join(', ')} tournaments match "$_query". Try another game or status.';
    } else {
      title = _game == null ? 'No open tournaments' : 'No open ${_game!.shortLabel} tournaments';
      body = 'Be the first: tap Organize to set one up.';
    }
    // ListView so pull-to-refresh still works when there is nothing to show
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        const SizedBox(height: 80),
        Icon(_searching ? Icons.search_off : Icons.emoji_events_outlined, size: 64, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(body, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Center(child: OutlinedButton(onPressed: _load, child: const Text('Try again'))),
        ],
      ],
    );
  }
}

/// A compact button showing the chosen option; tapping it lists the others.
class _OptionMenu<T> extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final T value;
  final List<T> values;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  const _OptionMenu({
    required this.icon,
    required this.tooltip,
    required this.value,
    required this.values,
    required this.label,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (_) => [for (final v in values) CheckedPopupMenuItem(value: v, checked: v == value, child: Text(label(v)))],
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
