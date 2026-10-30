import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/time_format.dart';
import '../../models/game.dart';
import '../../providers/tournament_provider.dart';
import '../../widgets/game_logo.dart';
import '../../widgets/primary_button.dart';
import 'tournament_detail_screen.dart';

/// Set up a tournament: game, name, start time, optional player limit and description.
/// Opens the new tournament's page once it's created.
class CreateTournamentScreen extends StatefulWidget {
  final Game? initialGame;

  const CreateTournamentScreen({super.key, this.initialGame});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _maxController = TextEditingController();
  late Game _game = widget.initialGame ?? Game.values.first;
  DateTime? _startsAt;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() => _error = null));
    _maxController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  String get _name => _nameController.text.trim().replaceAll(RegExp(r'\s+'), ' ');

  int? get _max => int.tryParse(_maxController.text.trim());

  String? get _maxProblem {
    if (_maxController.text.trim().isEmpty) return null;
    final max = _max;
    if (max == null || max < 2) return 'At least 2 players';
    if (max > 1000) return 'At most 1000 players';
    return null;
  }

  bool get _canCreate =>
      _name.length >= 3 && _startsAt != null && _startsAt!.isAfter(DateTime.now()) && _maxProblem == null;

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final initial = _startsAt ?? now.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return;
    setState(() {
      _startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _error = null;
    });
  }

  Future<void> _create() async {
    if (!_canCreate || _creating) return;
    setState(() => _creating = true);
    final provider = Provider.of<TournamentProvider>(context, listen: false);
    final description = _descriptionController.text.trim();
    final detail = await provider.createTournament(
      name: _name,
      game: _game,
      description: description.isEmpty ? null : description,
      startsAt: _startsAt!,
      maxParticipants: _max,
    );
    if (!mounted) return;
    setState(() => _creating = false);
    if (detail == null) {
      setState(() => _error = provider.errorMessage ?? 'Could not create the tournament');
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournamentId: detail.tournament.id, name: detail.tournament.name)),
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${detail.tournament.name} is open for requests')));
  }

  @override
  Widget build(BuildContext context) {
    final startsAt = _startsAt;
    final startInPast = startsAt != null && !startsAt.isAfter(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Organize a tournament')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          const Text('GAME', style: _labelStyle),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              for (final game in Game.values) ...[
                if (game != Game.values.first) const SizedBox(width: AppSpacing.xs),
                Expanded(child: _GameOption(game: game, selected: game == _game, onTap: () => setState(() => _game = game))),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _nameController,
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Tournament name',
              hintText: 'e.g. Friday Night Custom Room',
              prefixIcon: Icon(Icons.emoji_events_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: _pickStart,
            borderRadius: BorderRadius.circular(AppRadius.input),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Starts',
                prefixIcon: const Icon(Icons.event_outlined),
                errorText: startInPast ? 'Pick a time in the future' : null,
                helperText: 'Requests close when it starts',
              ),
              child: Text(
                startsAt == null ? 'Pick date and time' : formatDateTime(startsAt),
                style: TextStyle(color: startsAt == null ? AppColors.textSecondary : AppColors.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _maxController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Max players (optional)',
              helperText: 'Leave empty for no limit',
              errorText: _maxProblem,
              prefixIcon: const Icon(Icons.groups_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'Format, rules, prizes, how to join the room…',
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            MessageBanner(message: _error!),
          ],
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: 'Create tournament',
            icon: Icons.emoji_events,
            loading: _creating,
            onPressed: _canCreate ? _create : null,
          ),
        ],
      ),
    );
  }

  static const TextStyle _labelStyle =
      TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6);
}

class _GameOption extends StatelessWidget {
  final Game game;
  final bool selected;
  final VoidCallback onTap;

  const _GameOption({required this.game, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: game.shortLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
          ),
          child: Column(
            children: [
              GameLogo(game: game, width: double.infinity, height: 40),
              const SizedBox(height: 6),
              Text(
                game.shortLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
