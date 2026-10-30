import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/time_format.dart';
import '../models/tournament_model.dart';
import '../providers/tournament_provider.dart';
import '../screens/tournaments/tournament_detail_screen.dart';
import 'game_logo.dart';

/// "Tournaments" on a profile: every tournament the player was accepted into, latest first,
/// with where they placed once the result is in.
class PlayerTournamentsSection extends StatefulWidget {
  final int playerId;
  // Wording for the empty state, e.g. "You haven't…" vs "Rohit hasn't…"
  final String emptyText;

  const PlayerTournamentsSection({super.key, required this.playerId, required this.emptyText});

  @override
  State<PlayerTournamentsSection> createState() => _PlayerTournamentsSectionState();
}

class _PlayerTournamentsSectionState extends State<PlayerTournamentsSection> {
  // Shown before "Show all"
  static const int _collapsedCount = 5;

  List<PlayerTournament>? _tournaments;
  bool _failed = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PlayerTournamentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerId != widget.playerId) _load();
  }

  Future<void> _load() async {
    final result = await Provider.of<TournamentProvider>(context, listen: false).fetchPlayerTournaments(widget.playerId);
    if (!mounted) return;
    setState(() {
      _failed = result == null;
      _tournaments = result ?? _tournaments;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tournaments = _tournaments;
    final wins = tournaments?.where((t) => t.placement == 1).length ?? 0;
    final shown = tournaments == null
        ? const <PlayerTournament>[]
        : _expanded
            ? tournaments
            : tournaments.take(_collapsedCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('TOURNAMENTS  [${tournaments?.length ?? 0}]', style: AppFonts.label())),
            if (wins > 0) Text('$wins WIN${wins == 1 ? '' : 'S'}', style: AppFonts.label(color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (tournaments == null && !_failed)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (tournaments == null)
          Row(
            children: [
              const Expanded(child: Text("Couldn't load tournaments.", style: TextStyle(color: AppColors.textSecondary))),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          )
        else if (tournaments.isEmpty)
          Text(widget.emptyText, style: const TextStyle(color: AppColors.textSecondary))
        else ...[
          for (final t in shown) ...[
            _TournamentRow(tournament: t),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (tournaments.length > _collapsedCount)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Show fewer' : 'Show all ${tournaments.length}'),
              ),
            ),
        ],
      ],
    );
  }
}

class _TournamentRow extends StatelessWidget {
  final PlayerTournament tournament;

  const _TournamentRow({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final game = t.game;
    final won = t.placement == 1;
    final String outcome;
    if (!t.completed) {
      outcome = t.startsAt.isAfter(DateTime.now()) ? 'UPCOMING' : 'IN PROGRESS';
    } else {
      outcome = t.placement == null ? 'PLAYED' : ordinal(t.placement!).toUpperCase();
    }

    return Material(
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: won ? AppColors.primary : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => TournamentDetailScreen.open(context, t.id, name: t.name),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              if (game != null) GameLogo(game: game, width: 48, height: 34),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '${formatDate(t.startsAt)} · ${t.participantCount} players',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              if (won) ...[
                const Icon(Icons.emoji_events, color: AppColors.primary, size: 18),
                const SizedBox(width: 4),
              ],
              Text(
                outcome,
                style: TextStyle(
                  color: won ? AppColors.primary : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
