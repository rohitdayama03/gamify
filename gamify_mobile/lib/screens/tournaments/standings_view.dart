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
          _Legend(leaderboard.points),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final FormatPoints points;

  const _Legend(this.points);

  @override
  Widget build(BuildContext context) => Text(
        '${points.summary}. Ranked by points, then goal difference, goals scored, and head-to-head.',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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

/// Every player across all matches: played, won, drawn, lost, goals and points. Tap a column to sort by it.
/// The tournament's stats have their own tab ([StatsView]).
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
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 0),
            child: _Legend(widget.leaderboard.points),
          ),
        ],
      ),
    );
  }
}

class _Column {
  final String label;
  final num? Function(LeaderboardRow row) value;
  // Sort low-to-high on the first tap (e.g. placement)
  final bool ascendingFirst;

  _Column(this.label, this.value, {this.ascendingFirst = false});

  String format(LeaderboardRow row) {
    final v = value(row);
    if (v == null) return '–';
    if (label == 'Place') return ordinal(v.toInt());
    if (label == 'GD' && v > 0) return '+$v';
    return v is double ? formatStatValue(v) : '$v';
  }
}

/// One table per stat: pick a stat and every player is ranked by it, highest first. Players with nothing
/// recorded for it yet are listed last. Players level on the value share a rank.
class StatsView extends StatefulWidget {
  final TournamentLeaderboard leaderboard;
  final Future<void> Function() onRefresh;

  const StatsView({super.key, required this.leaderboard, required this.onRefresh});

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> {
  late int? _statId = widget.leaderboard.stats.isEmpty ? null : widget.leaderboard.stats.first.id;

  @override
  Widget build(BuildContext context) {
    final stats = widget.leaderboard.stats;
    // The format may have changed since the last pick
    final stat = stats.where((s) => s.id == _statId).firstOrNull ?? stats.firstOrNull;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, AppSpacing.lg),
        children: stat == null
            ? const [EmptyNote("This tournament doesn't track any stats.")]
            : [
                ChoiceRow<int>(
                  options: [for (final s in stats) (s.id, s.label)],
                  selected: stat.id,
                  onSelected: (id) => setState(() => _statId = id),
                ),
                const SizedBox(height: AppSpacing.md),
                _StatTable(stat: stat, rows: widget.leaderboard.overall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  stat.aggregation == StatAggregation.avg
                      ? '${stat.label}: average per match, over the matches it was recorded in.'
                      : '${stat.label}: total across all matches.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
      ),
    );
  }
}

class _StatTable extends StatelessWidget {
  final FormatStat stat;
  final List<LeaderboardRow> rows;

  const _StatTable({required this.stat, required this.rows});

  @override
  Widget build(BuildContext context) {
    final recorded = rows.where((r) => r.statValue(stat.id) != null).toList()
      ..sort((a, b) => b.statValue(stat.id)!.compareTo(a.statValue(stat.id)!));
    final missing = rows.where((r) => r.statValue(stat.id) == null).toList();
    if (recorded.isEmpty) return EmptyNote('No ${stat.label} recorded yet. It fills in as results are entered.');

    // Equal values share a rank: 1, 2, 2, 4
    final ranks = <int>[];
    for (var i = 0; i < recorded.length; i++) {
      final same = i > 0 && recorded[i].statValue(stat.id) == recorded[i - 1].statValue(stat.id);
      ranks.add(same ? ranks[i - 1] : i + 1);
    }

    return OutlineCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _StatRow(rank: '#', name: 'PLAYER', value: stat.label.toUpperCase(), header: true),
          for (final (i, row) in recorded.indexed)
            _StatRow(
              rank: '${ranks[i]}',
              name: row.player.username,
              value: formatStatValue(row.statValue(stat.id)!),
              leader: ranks[i] == 1,
              onTap: row.player.playerId == 0
                  ? null
                  : () => PlayerProfileScreen.open(context, row.player.playerId, username: row.player.username),
            ),
          for (final row in missing) _StatRow(rank: '–', name: row.player.username, value: '–', faded: true),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String rank;
  final String name;
  final String value;
  final bool header;
  final bool leader;
  final bool faded;
  final VoidCallback? onTap;

  const _StatRow({
    required this.rank,
    required this.name,
    required this.value,
    this.header = false,
    this.leader = false,
    this.faded = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = faded ? AppColors.textSecondary : (leader ? AppColors.primary : AppColors.textPrimary);
    final TextStyle text = header
        ? AppFonts.label(fontSize: 10.5)
        : TextStyle(color: color, fontWeight: leader ? FontWeight.w700 : FontWeight.w400);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
        decoration: header ? null : const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        child: Row(
          children: [
            SizedBox(width: 32, child: Text(rank, style: header ? text : text.copyWith(color: AppColors.textSecondary))),
            Expanded(child: Text(name, overflow: TextOverflow.ellipsis, style: text)),
            const SizedBox(width: AppSpacing.sm),
            Text(value, style: header ? text : text.copyWith(fontFamily: AppFonts.mono)),
          ],
        ),
      ),
    );
  }
}
