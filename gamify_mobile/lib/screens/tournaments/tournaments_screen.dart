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

/// Browse open tournaments by game, or see the ones you organize and joined.
class TournamentsScreen extends StatefulWidget {
  final Game? initialGame;

  const TournamentsScreen({super.key, this.initialGame});

  static Future<void> open(BuildContext context, {Game? game}) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentsScreen(initialGame: game)));

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  late Game? _game = widget.initialGame;
  bool _showMine = false;
  List<TournamentSummary>? _tournaments;
  bool _loading = true;
  String? _error;
  // Ignores answers to an earlier filter that arrive after a newer one
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    setState(() {
      _loading = true;
      _error = null;
    });
    final provider = Provider.of<TournamentProvider>(context, listen: false);
    final result = _showMine ? await provider.fetchMine() : await provider.fetchOpen(game: _game);
    if (!mounted || token != _loadToken) return;
    setState(() {
      _loading = false;
      _tournaments = result ?? _tournaments;
      _error = result == null ? provider.errorMessage : null;
    });
  }

  void _select({Game? game, bool? mine}) {
    setState(() {
      if (mine != null) _showMine = mine;
      if (mine == null) _game = game;
    });
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
          // Game filter only applies to Browse; Mine shows every game
          if (!_showMine)
            SizedBox(
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
            )
          else
            const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading && _tournaments == null
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? _buildEmpty()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, 88),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                          itemBuilder: (_, index) => TournamentCard(
                            tournament: items[index],
                            onTap: () => _openTournament(items[index]),
                          ),
                        ),
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
    } else {
      title = _game == null ? 'No open tournaments' : 'No open ${_game!.shortLabel} tournaments';
      body = 'Be the first: tap Organize to set one up.';
    }
    // ListView so pull-to-refresh still works when there is nothing to show
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.emoji_events_outlined, size: 64, color: AppColors.textSecondary),
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
