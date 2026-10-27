import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/game_options.dart';
import '../../models/game.dart';
import '../../models/player_model.dart';
import '../../providers/player_provider.dart';
import '../../widgets/connect_button.dart';
import '../player/player_profile_screen.dart';

enum _Filter {
  game,
  gtaPlatform,
  gtaActivity,
  bgmiRole,
  efootballTier,
  country,
  language,
}

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => DiscoverScreenState();
}

class DiscoverScreenState extends State<DiscoverScreen> {
  // Shorter text is too broad: it isn't sent, and all players are shown instead
  static const int _minQueryLength = 3;
  static const Duration _debounceDelay = Duration(milliseconds: 250);

  final _searchController = TextEditingController();
  Timer? _debounce;
  // Text sent with the last search, so typing the 1st and 2nd character doesn't refetch the same list
  String? _lastQuery;

  // Selected value per filter; a missing key means the filter is not applied
  final Map<_Filter, String> _filters = {};

  static const Map<_Filter, String> _filterLabels = {
    _Filter.game: 'Game',
    _Filter.gtaPlatform: 'Platform',
    _Filter.gtaActivity: 'Activity',
    _Filter.bgmiRole: 'Role',
    _Filter.efootballTier: 'Tier',
    _Filter.country: 'Country',
    _Filter.language: 'Language',
  };

  static final Map<_Filter, List<String>> _filterOptions = {
    _Filter.game: [for (final game in Game.values) game.shortLabel],
    _Filter.gtaPlatform: GtaOptions.platforms,
    _Filter.gtaActivity: GtaOptions.activities.keys.toList(),
    _Filter.bgmiRole: [
      'IGL',
      'Assaulter',
      'Fragger',
      'Support',
      'Sniper',
      'Scout',
    ],
    _Filter.efootballTier: [
      'Div 1',
      'Div 2',
      'Div 3',
      'Div 4',
      'Div 5',
      'Div 6',
      'Div 7',
      'Div 8',
      'Div 9',
      'Div 10',
    ],
    _Filter.country: ['India', 'Bangladesh', 'Nepal', 'Pakistan', 'Sri Lanka'],
    _Filter.language: [
      'English',
      'Hindi',
      'Bengali',
      'Tamil',
      'Telugu',
      'Marathi',
    ],
  };

  // Filters that only make sense once their game is chosen (PRD §6.1: never show another game's filters)
  static const Map<Game, List<_Filter>> _gameFilters = {
    Game.gta: [_Filter.gtaPlatform, _Filter.gtaActivity],
    Game.bgmi: [_Filter.bgmiRole],
    Game.efootball: [_Filter.efootballTier],
  };

  // Filters where the user may type a value not present in the preset list
  static const Set<_Filter> _customAllowed = {
    _Filter.bgmiRole,
    _Filter.efootballTier,
    _Filter.country,
    _Filter.language,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Shows [game]'s players with its filters, e.g. from Home's "Find players" button
  void selectGame(Game game) => _setFilter(_Filter.game, game.shortLabel);

  String get _typed => _searchController.text.trim();

  String? get _query => _typed.length >= _minQueryLength ? _typed : null;

  Game? get _selectedGame {
    final label = _filters[_Filter.game];
    for (final game in Game.values) {
      if (game.shortLabel == label) return game;
    }
    return null;
  }

  // Game first, then only the selected game's own filters, then the ones every game shares
  List<_Filter> get _visibleFilters => [
    _Filter.game,
    ...?_gameFilters[_selectedGame],
    _Filter.country,
    _Filter.language,
  ];

  void _search() {
    _lastQuery = _query;
    Provider.of<PlayerProvider>(context, listen: false).searchPlayers(
      query: _query,
      game: _selectedGame,
      gtaPlatform: _filters[_Filter.gtaPlatform],
      gtaActivity: _filters[_Filter.gtaActivity],
      bgmiRole: _filters[_Filter.bgmiRole],
      efootballTier: _filters[_Filter.efootballTier],
      country: _filters[_Filter.country],
      language: _filters[_Filter.language],
    );
  }

  void _onSearchChanged(String _) {
    setState(
      () {},
    ); // refresh the clear (x) button and the hint below the field
    _debounce?.cancel();
    if (_query == _lastQuery) return;
    _debounce = Timer(_debounceDelay, _search);
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _setFilter(_Filter filter, String? value) {
    setState(() {
      if (value == null || value.isEmpty) {
        _filters.remove(filter);
      } else {
        _filters[filter] = value;
      }
      // Changing game drops filters that belong to other games so no stale ones apply unseen
      if (filter == _Filter.game) {
        final keep = _gameFilters[_selectedGame] ?? const <_Filter>[];
        for (final gameFilters in _gameFilters.values) {
          for (final f in gameFilters) {
            if (!keep.contains(f)) _filters.remove(f);
          }
        }
      }
    });
    final game = _selectedGame;
    if (filter == _Filter.game && game != null) {
      Provider.of<PlayerProvider>(context, listen: false).setLastGame(game);
    }
    _search();
  }

  void _clearFilters() {
    setState(() => _filters.clear());
    _search();
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final players = playerProvider.searchResults;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            _buildSearchStatus(playerProvider),
            _buildFilterChips(),
            const Divider(height: 1),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _search(),
                child: _buildResults(
                  playerProvider,
                  players,
                  playerProvider.currentPlayer?.playerId,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _search(),
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search username or game',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          tooltip: 'Clear search',
                          onPressed: _clearSearch,
                        ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // One line under the field explaining what the results are
  Widget _buildSearchStatus(PlayerProvider provider) {
    final String? message;
    if (_typed.isNotEmpty && _query == null) {
      message = 'Keep typing: search starts at $_minQueryLength characters';
    } else if (_query != null &&
        provider.matchedGame != null &&
        !provider.isSearching) {
      message =
          'Players who play ${provider.matchedGame!.shortLabel}, plus usernames starting with "$_query"';
    } else if (_query != null && !provider.isSearching) {
      message = 'Usernames starting with "$_query"';
    } else {
      message = null;
    }
    if (message == null) return const SizedBox(height: 4);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        2,
        AppSpacing.gutter,
        0,
      ),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          textAlign: TextAlign.start,
          style: AppFonts.label(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ).copyWith(letterSpacing: 0.3),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final filter in _visibleFilters) ...[
            _buildChip(filter),
            const SizedBox(width: 8),
          ],
          if (_filters.isNotEmpty)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear all'),
            ),
        ],
      ),
    );
  }

  Widget _buildChip(_Filter filter) {
    final value = _filters[filter];
    final selected = value != null;
    return ActionChip(
      onPressed: () => _openFilterSheet(filter),
      backgroundColor: selected ? AppColors.primary : Colors.transparent,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value ?? _filterLabels[filter]!,
            style: TextStyle(
              color: selected ? AppColors.onPrimary : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: selected ? AppColors.onPrimary : AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Future<void> _openFilterSheet(_Filter filter) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (_) => _FilterSheet(
        title: _filterLabels[filter]!,
        options: _filterOptions[filter]!,
        selected: _filters[filter],
        allowCustom: _customAllowed.contains(filter),
      ),
    );
    // null means the sheet was dismissed; an empty string means "reset"
    if (result != null) _setFilter(filter, result);
  }

  Widget _buildResults(
    PlayerProvider provider,
    List<PlayerResponse> players,
    int? myId,
  ) {
    if (provider.isSearching && players.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (players.isEmpty) {
      // ListView so pull-to-refresh still works on an empty result
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          const SizedBox(height: 100),
          const Icon(
            Icons.person_search,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            _query == null
                ? 'No players match your filters'
                : 'No players found for "$_query"',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try a username or a game name like GTA, BGMI or eFootball.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.xs,
            children: [
              if (_typed.isNotEmpty)
                OutlinedButton(
                  onPressed: _clearSearch,
                  child: const Text('Clear search'),
                ),
              if (_filters.isNotEmpty)
                OutlinedButton(
                  onPressed: _clearFilters,
                  child: const Text('Reset filters'),
                ),
            ],
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: players.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) => _PlayerCard(
        player: players[index],
        isMe: players[index].playerId == myId,
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final String? selected;
  final bool allowCustom;

  const _FilterSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.allowCustom,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final TextEditingController _customController;

  @override
  void initState() {
    super.initState();
    final isCustom =
        widget.selected != null && !widget.options.contains(widget.selected);
    _customController = TextEditingController(
      text: isCustom ? widget.selected : '',
    );
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, ''),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final option in widget.options)
                    ListTile(
                      title: Text(option),
                      trailing: option == widget.selected
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.pop(context, option),
                    ),
                ],
              ),
            ),
            if (widget.allowCustom)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: TextField(
                  controller: _customController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (v) => Navigator.pop(context, v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Or type a ${widget.title.toLowerCase()}',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: () =>
                          Navigator.pop(context, _customController.text.trim()),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final PlayerResponse player;
  final bool isMe;

  const _PlayerCard({required this.player, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final location = [
      player.country,
      player.language,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Material(
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => PlayerProfileScreen.open(
            context,
            player.playerId,
            username: player.username,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(name: player.username, radius: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.username,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (player.playerBio != null &&
                          player.playerBio!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          player.playerBio!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                      ],
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          location,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (player.gtaProfile != null)
                            _GameTag(
                              label:
                                  'GTA Online · ${player.gtaProfile!.platform}',
                              color: AppColors.secondary,
                            ),
                          if (player.bgmiProfile != null)
                            _GameTag(
                              label:
                                  'BGMI${_suffix(player.bgmiProfile!.currentRole)}',
                              color: AppColors.secondary,
                            ),
                          if (player.efootballProfile != null)
                            _GameTag(
                              label:
                                  'eFootball${_suffix(player.efootballProfile!.highTier)}',
                              color: AppColors.success,
                            ),
                        ],
                      ),
                      if (!isMe) ...[
                        const SizedBox(height: 12),
                        ConnectButton(player: player),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _suffix(String? value) =>
      value == null || value.isEmpty ? '' : ' · $value';
}

class _GameTag extends StatelessWidget {
  final String label;
  final Color color;

  const _GameTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? name;
  final double radius;

  const _Avatar({required this.name, required this.radius});

  @override
  Widget build(BuildContext context) {
    final initial = (name == null || name!.isEmpty)
        ? null
        : name![0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      child: initial == null
          ? Icon(Icons.person, color: AppColors.onPrimary, size: radius)
          : Text(
              initial,
              style: TextStyle(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.8,
              ),
            ),
    );
  }
}
