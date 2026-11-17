import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tournament_format_model.dart';
import '../../widgets/primary_button.dart';
import 'tournament_widgets.dart';

/// Design a tournament's format: how many players, the stages they go through, and the stats recorded with
/// each result. Problems are shown as they happen, and saving is blocked until the format works.
///
/// Without [onSave] it pops with the finished [FormatDraft]. With [onSave] (editing a tournament's format) it
/// calls it and pops with true once it succeeds; [onSave] answers with an error message or null.
class FormatBuilderScreen extends StatefulWidget {
  final FormatDraft initial;
  final String saveLabel;
  final Future<String?> Function(FormatDraft draft)? onSave;

  const FormatBuilderScreen({super.key, required this.initial, this.saveLabel = 'Use this format', this.onSave});

  @override
  State<FormatBuilderScreen> createState() => _FormatBuilderScreenState();
}

class _FormatBuilderScreenState extends State<FormatBuilderScreen> {
  late final FormatDraft _draft = widget.initial.copy();
  bool _saving = false;
  String? _saveError;

  void _update(VoidCallback change) => setState(() {
        change();
        _saveError = null;
      });

  void _applyTemplate(FormatTemplate template) =>
      _update(() => _draft.stages = FormatDraft.fromTemplate(template, _draft.slots).stages);

  void _toggleStat(StatDraft stat) => _update(() {
        final index = _draft.stats.indexWhere((s) => s.label.toLowerCase() == stat.label.toLowerCase());
        if (index >= 0) {
          _draft.stats.removeAt(index);
        } else if (_draft.stats.length < FormatDraft.maxStats) {
          _draft.stats.add(stat);
        }
      });

  Future<void> _addCustomStat() async {
    final stat = await showDialog<StatDraft>(context: context, builder: (_) => _CustomStatDialog(existing: _draft.stats));
    if (stat != null) _update(() => _draft.stats.add(stat));
  }

  Future<void> _save() async {
    if (_draft.problem != null || _saving) return;
    final onSave = widget.onSave;
    if (onSave == null) {
      Navigator.pop(context, _draft);
      return;
    }
    setState(() => _saving = true);
    final error = await onSave(_draft);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveError = error;
    });
    if (error == null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final checks = _draft.check();
    final problem = _draft.problem;
    final customStats = _draft.stats
        .where((s) => !efootballStatPresets.any((p) => p.label.toLowerCase() == s.label.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Tournament format')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          const SectionLabel('PLAYERS'),
          OutlineCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CountStepper(
                  label: 'Number of players',
                  hint: 'The tournament starts once every spot is filled',
                  value: _draft.slots,
                  min: FormatDraft.minSlots,
                  max: FormatDraft.maxSlots,
                  onChanged: (v) => _update(() => _draft.slots = v),
                ),
                const SizedBox(height: AppSpacing.xs),
                ChoiceRow<int>(
                  options: const [(4, '4'), (8, '8'), (16, '16'), (32, '32')],
                  selected: _draft.slots,
                  onSelected: (v) => _update(() => _draft.slots = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionLabel('START FROM'),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final template in FormatTemplate.values)
                ActionChip(label: Text(template.label), onPressed: () => _applyTemplate(template)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionLabel('STAGES'),
          for (var i = 0; i < _draft.stages.length; i++) ...[
            _StageCard(
              index: i,
              stage: _draft.stages[i],
              check: checks[i],
              isLast: i == _draft.stages.length - 1,
              canRemove: _draft.stages.length > 1,
              onChanged: () => _update(() {}),
              onRemove: () => _update(() => _draft.stages.removeAt(i)),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (_draft.stages.length < FormatDraft.maxStages)
            OutlinedButton.icon(
              onPressed: () => _update(() => _draft.stages.add(StageDraft(type: StageType.knockout))),
              icon: const Icon(Icons.add),
              label: const Text('Add stage'),
            ),
          const SizedBox(height: AppSpacing.lg),
          const SectionLabel('STATS'),
          const Text(
            'Recorded with each result and shown on the leaderboard. Goals come from the score.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final preset in efootballStatPresets)
                _StatChip(
                  label: preset.label + (preset.aggregation == StatAggregation.avg ? ' (avg)' : ''),
                  selected: _draft.stats.any((s) => s.label.toLowerCase() == preset.label.toLowerCase()),
                  onTap: () => _toggleStat(preset),
                ),
              for (final custom in customStats)
                InputChip(
                  label: Text(custom.label + (custom.aggregation == StatAggregation.avg ? ' (avg)' : '')),
                  selected: true,
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  labelStyle: AppTheme.chipLabel(true),
                  deleteIconColor: AppColors.onPrimary,
                  onDeleted: () => _toggleStat(custom),
                ),
              if (_draft.stats.length < FormatDraft.maxStats)
                ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('Custom'), onPressed: _addCustomStat),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '${_draft.slots} players · ${_draft.stages.length} stage${_draft.stages.length == 1 ? '' : 's'} · ${_draft.totalMatches} matches',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (problem != null || _saveError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            MessageBanner(message: _saveError ?? problem!),
          ],
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: widget.saveLabel,
            icon: Icons.check,
            loading: _saving,
            onPressed: problem == null ? _save : null,
          ),
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  final int index;
  final StageDraft stage;
  final StageCheck check;
  final bool isLast;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _StageCard({
    required this.index,
    required this.stage,
    required this.check,
    required this.isLast,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  void _set(VoidCallback change) {
    change();
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final league = stage.type == StageType.league;
    final smallestGroup = stage.groupCount > 0 ? check.entrants ~/ stage.groupCount : 0;
    return OutlineCard(
      borderColor: check.problem != null ? AppColors.error.withValues(alpha: 0.6) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('STAGE ${index + 1}', style: AppFonts.label(color: AppColors.primary)),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '${check.entrants} players · ${check.matches} matches',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
              if (canRemove)
                IconButton(
                  tooltip: 'Remove stage ${index + 1}',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
                ),
            ],
          ),
          ChoiceRow<StageType>(
            options: [for (final t in StageType.values) (t, t.label)],
            selected: stage.type,
            onSelected: (t) => _set(() => stage.type = t),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (league) ...[
            CountStepper(
              label: 'Groups',
              hint: stage.groupCount == 1
                  ? 'Everyone plays everyone'
                  : smallestGroup >= 2
                      ? '${stage.groupCount} groups of $smallestGroup${check.entrants % stage.groupCount == 0 ? '' : '–${smallestGroup + 1}'}'
                      : null,
              value: stage.groupCount,
              min: 1,
              max: 16,
              onChanged: (v) => _set(() => stage.groupCount = v),
            ),
            ChoiceRow<int>(
              options: const [(1, 'Meet once'), (2, 'Home & away')],
              selected: stage.rounds,
              onSelected: (v) => _set(() => stage.rounds = v),
            ),
            if (!isLast) ...[
              const SizedBox(height: AppSpacing.xs),
              CountStepper(
                label: 'Go through per group',
                hint: '${stage.groupCount * stage.advancePerGroup} players reach stage ${index + 2}',
                value: stage.advancePerGroup,
                min: 1,
                max: 16,
                onChanged: (v) => _set(() => stage.advancePerGroup = v),
              ),
            ],
          ] else
            MergeSemantics(
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Third-place match'),
                        Text('Semi-final losers play for 3rd', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Switch(value: stage.thirdPlace, onChanged: (v) => _set(() => stage.thirdPlace = v)),
                ],
              ),
            ),
          if (check.problem != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(check.problem!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AppColors.primary,
      labelStyle: AppTheme.chipLabel(selected),
    );
  }
}

class _CustomStatDialog extends StatefulWidget {
  final List<StatDraft> existing;

  const _CustomStatDialog({required this.existing});

  @override
  State<_CustomStatDialog> createState() => _CustomStatDialogState();
}

class _CustomStatDialogState extends State<_CustomStatDialog> {
  final _controller = TextEditingController();
  StatAggregation _aggregation = StatAggregation.sum;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _problem {
    final label = _controller.text.trim();
    if (label.isEmpty) return null;
    if (label.toLowerCase() == 'goals') return 'Goals come from the score';
    if (widget.existing.any((s) => s.label.toLowerCase() == label.toLowerCase())) return 'You already have this stat';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final label = _controller.text.trim();
    final canAdd = label.isNotEmpty && _problem == null;
    return AlertDialog(
      title: const Text('Custom stat'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 20,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Name', hintText: 'e.g. Tackles', errorText: _problem),
          ),
          const SizedBox(height: AppSpacing.xs),
          ChoiceRow<StatAggregation>(
            options: const [(StatAggregation.sum, 'Total'), (StatAggregation.avg, 'Average')],
            selected: _aggregation,
            onSelected: (v) => setState(() => _aggregation = v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: canAdd ? () => Navigator.pop(context, StatDraft(label, _aggregation)) : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// A format at a glance, e.g. "16 players" then one line per stage. Tapping [onEdit] opens the builder.
class FormatSummaryCard extends StatelessWidget {
  final FormatDraft draft;
  final VoidCallback? onEdit;

  const FormatSummaryCard({super.key, required this.draft, this.onEdit});

  static String describe(StageDraft stage, bool isLast) {
    if (stage.type == StageType.knockout) return stage.thirdPlace ? 'Knockout · third-place match' : 'Knockout';
    final groups = stage.groupCount == 1 ? 'League' : '${stage.groupCount} groups';
    final legs = stage.rounds == 2 ? ' · home & away' : '';
    final through = isLast ? '' : ' · top ${stage.advancePerGroup} go through';
    return '$groups$legs$through';
  }

  @override
  Widget build(BuildContext context) {
    final problem = draft.problem;
    return OutlineCard(
      borderColor: problem != null ? AppColors.error.withValues(alpha: 0.6) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${draft.slots} players · ${draft.totalMatches} matches',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (onEdit != null) TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.tune, size: 18), label: const Text('Edit')),
            ],
          ),
          for (var i = 0; i < draft.stages.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Stage ${i + 1}  ${describe(draft.stages[i], i == draft.stages.length - 1)}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          if (draft.stats.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Stats: ${draft.stats.map((s) => s.label).join(', ')}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          if (problem != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(problem, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}
