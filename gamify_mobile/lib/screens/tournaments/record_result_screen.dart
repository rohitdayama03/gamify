import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/tournament_model.dart';
import '../../providers/tournament_provider.dart';
import '../../widgets/primary_button.dart';

/// Organizer picks each accepted player's place (1st = winner, ties allowed, or unplaced) and adds notes.
/// Saving marks the tournament finished; it can be opened again to correct the result. Pops with the update.
class RecordResultScreen extends StatefulWidget {
  final TournamentDetail detail;

  const RecordResultScreen({super.key, required this.detail});

  @override
  State<RecordResultScreen> createState() => _RecordResultScreenState();
}

class _RecordResultScreenState extends State<RecordResultScreen> {
  // Player id -> place; players not in the map are unplaced
  late final Map<int, int> _placements = {
    for (final p in widget.detail.accepted)
      if (p.placement != null) p.player.playerId: p.placement!,
  };
  late final _notesController = TextEditingController(text: widget.detail.resultNotes ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_placements.isEmpty || _saving) return;
    setState(() => _saving = true);
    final provider = Provider.of<TournamentProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final notes = _notesController.text.trim();
    final updated = await provider.recordResult(widget.detail.tournament.id, _placements, notes.isEmpty ? null : notes);
    if (!mounted) return;
    setState(() => _saving = false);
    if (updated == null) {
      messenger.showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Could not save the result')));
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('Result saved. Participants have been notified.')));
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final players = widget.detail.accepted;
    final places = List.generate(players.length, (i) => i + 1);
    final correcting = widget.detail.tournament.completed;

    return Scaffold(
      appBar: AppBar(title: Text(correcting ? 'Edit result' : 'Record result')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          Text(
            'Set each player\'s place. 1st is the winner; players can share a place, and you can leave anyone unplaced.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final p in players)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: _placements[p.player.playerId] == 1 ? AppColors.primary : AppColors.border),
                ),
                child: Row(
                  children: [
                    if (_placements[p.player.playerId] == 1) ...[
                      const Icon(Icons.emoji_events, color: AppColors.primary, size: 20),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(p.player.username, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    DropdownButton<int?>(
                      value: _placements[p.player.playerId],
                      underline: const SizedBox.shrink(),
                      hint: const Text('No place', style: TextStyle(color: AppColors.textSecondary)),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('No place')),
                        for (final place in places) DropdownMenuItem<int?>(value: place, child: Text(ordinal(place))),
                      ],
                      onChanged: (value) => setState(() {
                        if (value == null) {
                          _placements.remove(p.player.playerId);
                        } else {
                          _placements[p.player.playerId] = value;
                        }
                      }),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _notesController,
            minLines: 2,
            maxLines: 5,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'Final score, MVP, prize details…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: _placements.isEmpty ? 'Place at least one player' : 'Save result',
            icon: Icons.check,
            loading: _saving,
            onPressed: _placements.isEmpty ? null : _save,
          ),
        ],
      ),
    );
  }
}
