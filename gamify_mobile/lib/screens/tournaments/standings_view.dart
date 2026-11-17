import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tournament_format_model.dart';
import '../../models/tournament_model.dart';
import '../player/player_profile_screen.dart';
import 'fixtures_view.dart';
import 'tournament_widgets.dart';

/// The table of every league group, stage by stage. Players going through are marked; players level on every
/// tiebreaker show "=" until the organizer settles their order.
class StandingsView extends StatelessWidget {
  final TournamentLeaderboard leaderboard;
  final Future<void> Function() onRefresh;

  const StandingsView({super.key, required this.leaderboard, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, AppSpacing.lg),
        children: [
          if (leaderboard.stages.isEmpty) const EmptyNote('This tournament is a straight knockout. See the bracket in Fixtures.'),
          for (final stage in leaderboard.stages) ...[
            SectionLabel('STAGE ${stage.seq}${stage.finished ? ' · FINISHED' : ''}'),
            if (stage.groups.isEmpty)
              EmptyNote('The table fills in once stage ${stage.seq - 1} is finished.')
            else
              for (final group in stage.groups) ...[
                GroupTableCard(group: group),
                const SizedBox(height: AppSpacing.sm),
              ],
            const SizedBox(height: AppSpacing.md),
          ],
          const _Legend(),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => const Text(
        'Win 2 pts · Draw 1 pt · Loss 0. Ranked by points, then goal difference, goals scored, and head-to-head.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      );
}

class GroupTableCard extends StatelessWidget {
  final GroupTable group;

  const GroupTableCard({super.key, required this.group});

  static const _numbers = ['P', 'W', 'D', 'L', 'GD', 'Pts'];

  @override
  Widget build(BuildContext context) {
    return OutlineCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.advancing > 0 ? '${group.name} · top ${group.advancing} go through' : group.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                for (final h in _numbers) _Cell(h, header: true, wide: h == 'Pts' || h == 'GD'),
              ],
            ),
          ),
          for (final (i, row) in group.rows.indexed) _StandingTile(position: i + 1, row: row),
        ],
      ),
    );
  }
}

class _StandingTile extends StatelessWidget {
  final int position;
  final StandingRow row;

  const _StandingTile({required this.position, required this.row});

  @override
  Widget build(BuildContext context) {
    final r = row.record;
    return OpenProfileOnTap(
      playerId: row.player.playerId,
      username: row.player.username,
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm - 3, 6, AppSpacing.sm, 6),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: row.qualified ? AppColors.primary : Colors.transparent, width: 3)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                row.tied ? '=' : '$position',
                style: TextStyle(fontFamily: AppFonts.mono, color: row.qualified ? AppColors.primary : AppColors.textSecondary),
              ),
            ),
            Expanded(child: Text(row.player.username, maxLines: 1, overflow: TextOverflow.ellipsis)),
            _Cell('${r.played}'),
            _Cell('${r.won}'),
            _Cell('${r.drawn}'),
            _Cell('${r.lost}'),
            _Cell(r.goalDifference > 0 ? '+${r.goalDifference}' : '${r.goalDifference}', wide: true),
            _Cell('${r.points}', wide: true, bold: true),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final bool header;
  final bool wide;
  final bool bold;

  const _Cell(this.text, {this.header = false, this.wide = false, this.bold = false});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: wide ? 34 : 24,
        child: Text(
          text,
          textAlign: TextAlign.end,
          style: header
              ? AppFonts.label(fontSize: 10.5)
              : TextStyle(fontFamily: AppFonts.mono, fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w400),
        ),
      );
}

/// Every player across all matches with the tournament's stats. Tap a column to sort by it.
class LeaderboardView extends StatefulWidget {
  final TournamentLeaderboard leaderboard;
  final bool completed;
  final Future<void> Function() onRefresh;

  const LeaderboardView({super.key, required this.leaderboard, required this.completed, required this.onRefresh});

  @override
  State<LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends State<LeaderboardView> {
  // Null keeps the server's order (points, goal difference, goals scored)
  int? _sortColumn;
  bool _ascending = false;

  List<_Column> get _columns => [
        _Column('P', (r) => r.record.played),
        _Column('W', (r) => r.record.won),
        _Column('D', (r) => r.record.drawn),
        _Column('L', (r) => r.record.lost),
        _Column('GF', (r) => r.record.goalsFor),
        _Column('GD', (r) => r.record.goalDifference),
        _Column('Pts', (r) => r.record.points),
        for (final stat in widget.leaderboard.stats) _Column(stat.label, (r) => r.statValue(stat.id), stat: stat),
        if (widget.completed) _Column('Place', (r) => r.placement, ascendingFirst: true),
      ];

  @override
  Widget build(BuildContext context) {
    final columns = _columns;
    final rows = List.of(widget.leaderboard.overall);
    final sortColumn = _sortColumn;
    if (sortColumn != null && sortColumn < columns.length) {
      final value = columns[sortColumn].value;
      rows.sort((a, b) {
        final va = value(a);
        final vb = value(b);
        // Missing values always go last
        if (va == null || vb == null) return va == null ? (vb == null ? 0 : 1) : -1;
        return _ascending ? va.compareTo(vb) : vb.compareTo(va);
      });
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          if (rows.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter), child: EmptyNote('No players yet.'))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: DataTable(
                sortColumnIndex: sortColumn == null ? null : sortColumn + 2,
                sortAscending: _ascending,
                columnSpacing: 18,
                horizontalMargin: 4,
                headingRowHeight: 36,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 44,
                headingTextStyle: AppFonts.label(fontSize: 10.5),
                columns: [
                  const DataColumn(label: Text('#')),
                  const DataColumn(label: Text('PLAYER')),
                  for (final (i, c) in columns.indexed)
                    DataColumn(
                      numeric: true,
                      label: Text(c.label.toUpperCase()),
                      tooltip: c.stat == null ? null : (c.stat!.aggregation == StatAggregation.avg ? 'Average per match' : 'Total'),
                      onSort: (_, _) => setState(() {
                        if (_sortColumn == i) {
                          _ascending = !_ascending;
                        } else {
                          _sortColumn = i;
                          _ascending = c.ascendingFirst;
                        }
                      }),
                    ),
                ],
                rows: [
                  for (final (i, row) in rows.indexed)
                    DataRow(cells: [
                      DataCell(Text('${i + 1}', style: const TextStyle(color: AppColors.textSecondary))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (row.placement == 1) ...[
                              const Icon(Icons.emoji_events, size: 16, color: AppColors.primary),
                              const SizedBox(width: 4),
                            ],
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 140),
                              child: Text(row.player.username, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                        onTap: row.player.playerId == 0
                            ? null
                            : () => PlayerProfileScreen.open(context, row.player.playerId, username: row.player.username),
                      ),
                      for (final c in columns)
                        DataCell(Text(
                          c.format(row),
                          style: TextStyle(fontFamily: AppFonts.mono, fontWeight: c.label == 'Pts' ? FontWeight.w700 : FontWeight.w400),
                        )),
                    ]),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 0),
            child: _Legend(),
          ),
        ],
      ),
    );
  }
}

class _Column {
  final String label;
  final num? Function(LeaderboardRow row) value;
  final FormatStat? stat;
  // Sort low-to-high on the first tap (e.g. placement)
  final bool ascendingFirst;

  _Column(this.label, this.value, {this.stat, this.ascendingFirst = false});

  String format(LeaderboardRow row) {
    final v = value(row);
    if (v == null) return '–';
    if (label == 'Place') return ordinal(v.toInt());
    if (label == 'GD' && v > 0) return '+$v';
    return v is double ? formatStatValue(v) : '$v';
  }
}
