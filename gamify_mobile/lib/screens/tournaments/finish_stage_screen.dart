import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tournament_format_model.dart';
import '../../models/tournament_model.dart';
import '../../providers/tournament_provider.dart';
import '../../widgets/primary_button.dart';
import 'tournament_widgets.dart';

/// Organizer reviews a league stage's final tables before finishing it. Players level on every tiebreaker can be
/// dragged into order (only among themselves). Finishing sends the top players through, or after the last stage
/// sets everyone's placement. Pops with the updated tournament.
class FinishStageScreen extends StatefulWidget {
  final int tournamentId;
  final FormatStage stage;
  final StageTable table;
  final bool isLast;

  const FinishStageScreen({super.key, required this.tournamentId, required this.stage, required this.table, required this.isLast});

  @override
  State<FinishStageScreen> createState() => _FinishStageScreenState();
}

class _FinishStageScreenState extends State<FinishStageScreen> {
  // Group -> rows in the organizer's order
  late final Map<int, List<StandingRow>> _orders = {for (final g in widget.table.groups) g.groupNo: List.of(g.rows)};
  bool _saving = false;
  String? _error;

  bool get _hasTies => widget.table.groups.any((g) => g.rows.any((r) => r.tied));

  Future<void> _finish() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final provider = Provider.of<TournamentProvider>(context, listen: false);
    final updated = await provider.finishStage(
      widget.tournamentId,
      widget.stage.id,
      groupOrders: {
        for (final g in widget.table.groups)
          if (g.rows.any((r) => r.tied)) g.groupNo: _orders[g.groupNo]!.map((r) => r.participantId).toList(),
      },
    );
    if (!mounted) return;
    if (updated == null) {
      setState(() {
        _saving = false;
        _error = provider.errorMessage ?? 'Could not finish the stage';
      });
      return;
    }
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final advance = widget.stage.advancePerGroup;
    return Scaffold(
      appBar: AppBar(title: Text(widget.isLast ? 'Finish tournament' : 'Finish stage ${widget.stage.seq}')),
      body: ListView(
        // The extra bottom space keeps the last button clear of the phone's navigation bar
        padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter, AppSpacing.gutter, AppSpacing.gutter, AppSpacing.gutter + MediaQuery.viewPaddingOf(context).bottom),
        children: [
          Text(
            widget.isLast
                ? 'Final positions come from this table. Results are locked once you finish.'
                : 'The top $advance of each group go through to stage ${widget.stage.seq + 1}. Results in this stage are locked once you finish.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (_hasTies) ...[
            const SizedBox(height: AppSpacing.sm),
            const MessageBanner(
              message: 'Some players are level on every tiebreaker. Drag them into the order they finished.',
              isError: false,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          for (final group in widget.table.groups) ...[
            SectionLabel(group.name.toUpperCase()),
            _GroupOrder(
              rows: _orders[group.groupNo]!,
              cutoff: widget.isLast ? 0 : advance,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_error != null) ...[MessageBanner(message: _error!), const SizedBox(height: AppSpacing.sm)],
          PrimaryButton(
            label: widget.isLast ? 'Finish tournament' : 'Finish stage ${widget.stage.seq}',
            icon: Icons.flag,
            loading: _saving,
            onPressed: _finish,
          ),
        ],
      ),
    );
  }
}

/// A group's table where only runs of level players (same tie block) can be reordered.
class _GroupOrder extends StatelessWidget {
  final List<StandingRow> rows;
  // Positions up to this one go through (0 in the last stage)
  final int cutoff;
  final VoidCallback onChanged;

  const _GroupOrder({required this.rows, required this.cutoff, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final segments = <Widget>[];
    var start = 0;
    while (start < rows.length) {
      var end = start + 1;
      while (end < rows.length && rows[end].tied && rows[end].tieBlock == rows[start].tieBlock) {
        end++;
      }
      final from = start;
      if (end - start == 1) {
        segments.add(_row(from, rows[from], draggable: false));
      } else {
        segments.add(ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (oldIndex, newIndex) {
            rows.insert(from + newIndex, rows.removeAt(from + oldIndex));
            onChanged();
          },
          children: [
            for (var i = from; i < end; i++)
              ReorderableDragStartListener(
                key: ValueKey(rows[i].participantId),
                index: i - from,
                child: _row(i, rows[i], draggable: true),
              ),
          ],
        ));
      }
      start = end;
    }
    return OutlineCard(padding: EdgeInsets.zero, child: Column(children: segments));
  }

  Widget _row(int index, StandingRow row, {required bool draggable}) {
    final through = index < cutoff;
    final r = row.record;
    return Container(
      color: draggable ? AppColors.surfaceAlt : null,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(ordinal(index + 1),
                style: AppFonts.label(color: through ? AppColors.primary : AppColors.textSecondary, fontSize: 12)),
          ),
          Expanded(child: Text(row.player.username, overflow: TextOverflow.ellipsis)),
          Text('${r.points} pts · ${r.goalDifference > 0 ? '+' : ''}${r.goalDifference}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          if (draggable) ...[
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.drag_handle, color: AppColors.textSecondary),
          ],
        ],
      ),
    );
  }
}
