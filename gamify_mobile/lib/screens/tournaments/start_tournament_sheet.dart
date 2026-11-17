import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tournament_model.dart';
import '../../widgets/player_avatar.dart';
import '../../widgets/primary_button.dart';
import 'tournament_widgets.dart';

/// How the organizer wants the players drawn: shuffled, or in an order they set by dragging.
/// Pops with `(order: null)` for a random draw, `(order: [participant ids, slot 1 first])` for manual
/// seeding, or plain null when dismissed.
class StartTournamentSheet extends StatefulWidget {
  final List<TournamentParticipant> players;

  const StartTournamentSheet({super.key, required this.players});

  static Future<({List<int>? order})?> show(BuildContext context, List<TournamentParticipant> players) =>
      showModalBottomSheet<({List<int>? order})>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => StartTournamentSheet(players: players),
      );

  @override
  State<StartTournamentSheet> createState() => _StartTournamentSheetState();
}

class _StartTournamentSheetState extends State<StartTournamentSheet> {
  bool _manual = false;
  late final List<TournamentParticipant> _order = List.of(widget.players);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: _manual ? 0.9 : 0.5,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Start tournament', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'The fixtures lock, requests close and anyone still waiting is declined. Every player is notified.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            ChoiceRow<bool>(
              options: const [(false, 'Random draw'), (true, 'Seed manually')],
              selected: _manual,
              onSelected: (v) => setState(() => _manual = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_manual) ...[
              const Text(
                'Drag players into slots. Groups are filled in turn (slot 1 to group A, slot 2 to group B…), and in a '
                'knockout slots 1 and 2 can only meet in the final.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: ReorderableListView.builder(
                  scrollController: scrollController,
                  itemCount: _order.length,
                  onReorderItem: (from, to) => setState(() => _order.insert(to, _order.removeAt(from))),
                  itemBuilder: (context, i) {
                    final p = _order[i];
                    return ListTile(
                      key: ValueKey(p.id),
                      contentPadding: EdgeInsets.zero,
                      leading: SizedBox(
                        width: 28,
                        child: Text('${i + 1}', style: AppFonts.label(color: AppColors.primary, fontSize: 13)),
                      ),
                      title: Row(
                        children: [
                          PlayerAvatar(name: p.player.username, url: p.player.avatarUrl, radius: 14),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(child: Text(p.player.username, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ] else
              const Spacer(),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: _manual ? 'Start with this seeding' : 'Draw and start',
              icon: Icons.play_arrow,
              onPressed: () => Navigator.pop(context, (order: _manual ? _order.map((p) => p.id).toList() : null)),
            ),
          ],
        ),
      ),
    );
  }
}
