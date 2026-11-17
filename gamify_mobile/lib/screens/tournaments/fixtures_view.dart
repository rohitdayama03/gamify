import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tournament_format_model.dart';
import 'tournament_widgets.dart';

/// Every fixture, stage by stage: league stages by group and round, knockouts as a bracket. Before a player
/// is known their side shows where they come from ("Group A · 1st"). The organizer taps an [editable] match to
/// enter its result.
class FixturesView extends StatelessWidget {
  final TournamentFixtures fixtures;
  final ValueChanged<TournamentMatch>? onEditMatch;
  final Future<void> Function() onRefresh;

  const FixturesView({super.key, required this.fixtures, required this.onRefresh, this.onEditMatch});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, AppSpacing.lg),
        children: [
          for (final stage in fixtures.stages) ...[
            _StageHeader(stage: stage),
            const SizedBox(height: AppSpacing.xs),
            if (stage.type == StageType.knockout)
              _Bracket(stage: stage, onEditMatch: onEditMatch)
            else
              ..._leagueRounds(stage),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }

  List<Widget> _leagueRounds(StageFixtures stage) {
    final widgets = <Widget>[];
    String? heading;
    for (final match in stage.matches) {
      final next = [?match.groupName, match.roundName].join(' · ');
      if (next != heading) {
        heading = next;
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: 4),
          child: Text(next, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        ));
      }
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: MatchCard(match: match, onTap: match.editable && onEditMatch != null ? () => onEditMatch!(match) : null),
      ));
    }
    return widgets;
  }
}

class _StageHeader extends StatelessWidget {
  final StageFixtures stage;

  const _StageHeader({required this.stage});

  @override
  Widget build(BuildContext context) {
    final done = stage.matches.where((m) => m.completed).length;
    final (String status, Color color) = stage.finished
        ? ('FINISHED', AppColors.textSecondary)
        : stage.current
            ? ('LIVE · $done/${stage.matches.length}', AppColors.primary)
            : ('UPCOMING', AppColors.textSecondary);
    return Row(
      children: [
        Expanded(
          child: Text(
            'STAGE ${stage.seq} · ${stage.type.label.toUpperCase()}',
            overflow: TextOverflow.ellipsis,
            style: AppFonts.label(color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(status, style: AppFonts.label(color: color)),
      ],
    );
  }
}

/// Knockout rounds side by side, scrolling sideways; the third-place match sits under the final.
class _Bracket extends StatelessWidget {
  final StageFixtures stage;
  final ValueChanged<TournamentMatch>? onEditMatch;

  const _Bracket({required this.stage, this.onEditMatch});

  @override
  Widget build(BuildContext context) {
    final rounds = <int, List<TournamentMatch>>{};
    for (final m in stage.matches) {
      rounds.putIfAbsent(m.roundNo, () => []).add(m);
    }
    final roundNos = rounds.keys.toList()..sort();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in roundNos)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: SizedBox(
                width: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, m) in rounds[r]!.indexed) ...[
                      if (i == 0 || m.roundName != rounds[r]![i - 1].roundName)
                        Padding(
                          padding: EdgeInsets.only(bottom: 4, top: i == 0 ? 0 : AppSpacing.sm),
                          child: Text(m.roundName,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: MatchCard(match: m, onTap: m.editable && onEditMatch != null ? () => onEditMatch!(m) : null),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A fixture: both sides with their scores (and penalties), the winner in bold. Shows an edit hint when [onTap]
/// lets the organizer enter the result.
class MatchCard extends StatelessWidget {
  final TournamentMatch match;
  final VoidCallback? onTap;

  const MatchCard({super.key, required this.match, this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = match;
    return Semantics(
      button: onTap != null,
      label: onTap == null ? null : (m.completed ? 'Edit result of ${m.home.name} vs ${m.away.name}' : 'Enter result of ${m.home.name} vs ${m.away.name}'),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: OutlineCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          borderColor: onTap != null && !m.completed ? AppColors.primary.withValues(alpha: 0.5) : null,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _SideRow(side: m.home, pens: m.homePens, won: m.winnerId != null && m.winnerId == m.home.participantId),
                    const SizedBox(height: 4),
                    _SideRow(side: m.away, pens: m.awayPens, won: m.winnerId != null && m.winnerId == m.away.participantId),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(m.completed ? Icons.edit_outlined : Icons.add_circle_outline, size: 20, color: AppColors.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SideRow extends StatelessWidget {
  final MatchSide side;
  final int? pens;
  final bool won;

  const _SideRow({required this.side, required this.pens, required this.won});

  @override
  Widget build(BuildContext context) {
    final known = side.player != null;
    return Row(
      children: [
        Expanded(
          child: Text(
            side.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: known ? AppColors.textPrimary : AppColors.textSecondary,
              fontStyle: known ? FontStyle.normal : FontStyle.italic,
              fontWeight: won ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        if (pens != null)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text('($pens)', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
        SizedBox(
          width: 22,
          child: Text(
            side.score?.toString() ?? '–',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontWeight: won ? FontWeight.w700 : FontWeight.w500,
              color: side.score == null ? AppColors.textSecondary : (won ? AppColors.primary : AppColors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}

/// A section shown when there's nothing to list yet.
class EmptyNote extends StatelessWidget {
  final String text;

  const EmptyNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(text, style: const TextStyle(color: AppColors.textSecondary)),
      );
}
