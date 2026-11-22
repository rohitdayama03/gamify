import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tournament_format_model.dart';
import '../../providers/tournament_provider.dart';
import '../../widgets/primary_button.dart';
import 'tournament_widgets.dart';

/// Organizer enters or corrects a match result: who won (or a draw, outside knockouts), the final score, an
/// optional penalty shootout score when a knockout match is level, and the tournament's optional stats for each
/// player. Pops with the updated fixtures once saved.
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

enum _Pick { home, away, draw }

class _MatchResultSheetState extends State<MatchResultSheet> {
  // An existing result opens with its winner picked
  late _Pick? _pick = widget.match.winnerId != null && widget.match.winnerId == widget.match.home.participantId
      ? _Pick.home
      : widget.match.winnerId != null && widget.match.winnerId == widget.match.away.participantId
          ? _Pick.away
          : widget.match.completed
              ? _Pick.draw
              : null;
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

  // A level knockout match went to penalties; the shootout score is optional
  bool get _wentToPens => widget.knockout && _home == _away && _pick != null && _pick != _Pick.draw;

  bool get _pensEntered => _wentToPens && _homePens != _awayPens;

  String _name(bool home) => home ? widget.match.home.name : widget.match.away.name;

  // The winner and the score must tell the same story (the server checks this too)
  String? get _problem {
    final pick = _pick;
    if (pick == null) return null;
    if (pick == _Pick.draw) return _home == _away ? null : 'A draw needs a level final score';
    final homeWon = pick == _Pick.home;
    if (_home != _away) return (_home > _away) == homeWon ? null : 'The final score has ${_name(_home > _away)} winning';
    if (!widget.knockout) return 'The final score is level, so pick Draw';
    if (_pensEntered && (_homePens > _awayPens) != homeWon) {
      return 'The penalty shootout has ${_name(_homePens > _awayPens)} winning';
    }
    return null;
  }

  bool get _canSave => _pick != null && _problem == null;

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final provider = Provider.of<TournamentProvider>(context, listen: false);
    final fixtures = await provider.recordMatch(
      widget.tournamentId,
      widget.match.id,
      winner: switch (_pick!) { _Pick.home => 'HOME', _Pick.away => 'AWAY', _Pick.draw => 'DRAW' },
      homeScore: _home,
      awayScore: _away,
      homePens: _pensEntered ? _homePens : null,
      awayPens: _pensEntered ? _awayPens : null,
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
      // Above the keyboard when it's open, otherwise above the phone's navigation bar
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom > MediaQuery.viewPaddingOf(context).bottom
              ? MediaQuery.viewInsetsOf(context).bottom
              : MediaQuery.viewPaddingOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text([?m.groupName, m.roundName].join(' · ').toUpperCase(), style: AppFonts.label()),
            const SizedBox(height: AppSpacing.md),
            const SectionLabel('WHO WON'),
            Row(
              children: [
                Expanded(
                  child: _WinnerOption(
                    label: m.home.name,
                    selected: _pick == _Pick.home,
                    onTap: () => setState(() => _pick = _Pick.home),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _WinnerOption(
                    label: m.away.name,
                    selected: _pick == _Pick.away,
                    onTap: () => setState(() => _pick = _Pick.away),
                  ),
                ),
              ],
            ),
            // Only group and league matches can end level
            if (!widget.knockout) ...[
              const SizedBox(height: AppSpacing.xs),
              _WinnerOption(
                label: 'Draw',
                selected: _pick == _Pick.draw,
                compact: true,
                onTap: () => setState(() => _pick = _Pick.draw),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            const SectionLabel('FINAL SCORE'),
            _ScoreRow(name: m.home.name, value: _home, onChanged: (v) => setState(() => _home = v)),
            const SizedBox(height: AppSpacing.xs),
            _ScoreRow(name: m.away.name, value: _away, onChanged: (v) => setState(() => _away = v)),
            if (_wentToPens) ...[
              const SizedBox(height: AppSpacing.md),
              const SectionLabel('PENALTY SHOOTOUT (OPTIONAL)'),
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
              onPressed: _canSave ? _save : null,
            ),
            if (_pick == null) ...[
              const SizedBox(height: AppSpacing.xs),
              const Text('Pick who won to save',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}

/// One choice in "Who won": a player, or Draw. The picked one is outlined in the accent colour with a tick.
class _WinnerOption extends StatelessWidget {
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _WinnerOption({required this.label, required this.selected, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: compact ? 10 : AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) ...[
                  const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
