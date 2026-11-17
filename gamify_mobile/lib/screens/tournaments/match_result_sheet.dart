import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tournament_format_model.dart';
import '../../providers/tournament_provider.dart';
import '../../widgets/primary_button.dart';
import 'tournament_widgets.dart';

/// Organizer enters or corrects a match result: the score, the penalty shootout when a knockout match is level,
/// and the tournament's stats for each player. Pops with the updated fixtures once saved.
class MatchResultSheet extends StatefulWidget {
  final int tournamentId;
  final TournamentMatch match;
  final bool knockout;
  final List<FormatStat> stats;

  const MatchResultSheet({
    super.key,
    required this.tournamentId,
    required this.match,
    required this.knockout,
    required this.stats,
  });

  static Future<TournamentFixtures?> show(
    BuildContext context, {
    required int tournamentId,
    required TournamentMatch match,
    required bool knockout,
    required List<FormatStat> stats,
  }) =>
      showModalBottomSheet<TournamentFixtures>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => MatchResultSheet(tournamentId: tournamentId, match: match, knockout: knockout, stats: stats),
      );

  @override
  State<MatchResultSheet> createState() => _MatchResultSheetState();
}

class _MatchResultSheetState extends State<MatchResultSheet> {
  late int _home = widget.match.home.score ?? 0;
  late int _away = widget.match.away.score ?? 0;
  late int _homePens = widget.match.homePens ?? 0;
  late int _awayPens = widget.match.awayPens ?? 0;
  // Stat id -> (home field, away field)
  late final Map<int, (TextEditingController, TextEditingController)> _statFields = {
    for (final stat in widget.stats)
      stat.id: (
        TextEditingController(text: _initial(widget.match.home.statValue(stat.id))),
        TextEditingController(text: _initial(widget.match.away.statValue(stat.id))),
      ),
  };
  bool _saving = false;
  String? _error;

  static String _initial(double? value) => value == null ? '' : formatStatValue(value);

  @override
  void dispose() {
    for (final (home, away) in _statFields.values) {
      home.dispose();
      away.dispose();
    }
    super.dispose();
  }

  bool get _needsPens => widget.knockout && _home == _away;

  String? get _problem => _needsPens && _homePens == _awayPens ? "A penalty shootout can't end level" : null;

  Future<void> _save() async {
    if (_problem != null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final provider = Provider.of<TournamentProvider>(context, listen: false);
    final fixtures = await provider.recordMatch(
      widget.tournamentId,
      widget.match.id,
      homeScore: _home,
      awayScore: _away,
      homePens: _needsPens ? _homePens : null,
      awayPens: _needsPens ? _awayPens : null,
      stats: {
        for (final entry in _statFields.entries)
          entry.key: (double.tryParse(entry.value.$1.text.trim()), double.tryParse(entry.value.$2.text.trim())),
      },
    );
    if (!mounted) return;
    if (fixtures == null) {
      setState(() {
        _saving = false;
        _error = provider.errorMessage ?? 'Could not save the result';
      });
      return;
    }
    Navigator.pop(context, fixtures);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text([?m.groupName, m.roundName].join(' · ').toUpperCase(), style: AppFonts.label()),
            const SizedBox(height: AppSpacing.sm),
            _ScoreRow(name: m.home.name, value: _home, onChanged: (v) => setState(() => _home = v)),
            const SizedBox(height: AppSpacing.xs),
            _ScoreRow(name: m.away.name, value: _away, onChanged: (v) => setState(() => _away = v)),
            if (_needsPens) ...[
              const SizedBox(height: AppSpacing.md),
              const SectionLabel('PENALTY SHOOTOUT'),
              _ScoreRow(name: m.home.name, value: _homePens, onChanged: (v) => setState(() => _homePens = v)),
              const SizedBox(height: AppSpacing.xs),
              _ScoreRow(name: m.away.name, value: _awayPens, onChanged: (v) => setState(() => _awayPens = v)),
            ],
            if (widget.stats.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              const SectionLabel('STATS (OPTIONAL)'),
              Row(
                children: [
                  const Expanded(child: SizedBox()),
                  _StatHeader(m.home.name),
                  const SizedBox(width: AppSpacing.xs),
                  _StatHeader(m.away.name),
                ],
              ),
              for (final stat in widget.stats)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(child: Text(stat.label)),
                      _StatField(controller: _statFields[stat.id]!.$1, label: '${stat.label}, ${m.home.name}'),
                      const SizedBox(width: AppSpacing.xs),
                      _StatField(controller: _statFields[stat.id]!.$2, label: '${stat.label}, ${m.away.name}'),
                    ],
                  ),
                ),
            ],
            if (_problem != null || _error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              MessageBanner(message: _error ?? _problem!),
            ],
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: m.completed ? 'Update result' : 'Save result',
              icon: Icons.check,
              loading: _saving,
              onPressed: _problem == null ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String name;
  final int value;
  final ValueChanged<int> onChanged;

  const _ScoreRow({required this.name, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => OutlineCard(
        padding: const EdgeInsets.only(left: AppSpacing.sm),
        child: CountStepper(label: name, value: value, min: 0, max: 99, onChanged: onChanged),
      );
}

class _StatHeader extends StatelessWidget {
  final String name;

  const _StatHeader(this.name);

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 80,
        child: Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      );
}

class _StatField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _StatField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 80,
        child: Semantics(
          label: label,
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,6}(\.\d?)?'))],
            decoration: const InputDecoration(isDense: true, hintText: '–'),
          ),
        ),
      );
}
