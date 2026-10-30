import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/time_format.dart';
import '../../models/tournament_model.dart';
import '../../widgets/game_logo.dart';

/// A tournament in a list: game logo, name, start time, slots, and where the player stands.
class TournamentCard extends StatelessWidget {
  final TournamentSummary tournament;
  final VoidCallback onTap;

  const TournamentCard({super.key, required this.tournament, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final game = t.game;
    return Material(
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (game != null) GameLogo(game: game, width: 56, height: 40) else const SizedBox(width: 56),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(formatDateTime(t.startsAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      '${t.slotsLabel} · by ${t.organizer.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              TournamentStatusChip(tournament: t),
            ],
          ),
        ),
      ),
    );
  }
}

/// Short label for the tournament's state from the player's side, e.g. "ORGANIZER", "PENDING", "FULL".
class TournamentStatusChip extends StatelessWidget {
  final TournamentSummary tournament;

  const TournamentStatusChip({super.key, required this.tournament});

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final (String label, Color color) = switch (t.myRole) {
      TournamentRole.organizer => ('ORGANIZER', AppColors.primary),
      TournamentRole.accepted => ('JOINED', AppColors.primary),
      TournamentRole.pending => ('PENDING', AppColors.secondary),
      TournamentRole.rejected => ('DECLINED', AppColors.error),
      TournamentRole.none when t.completed => ('FINISHED', AppColors.textSecondary),
      TournamentRole.none when t.isFull => ('FULL', AppColors.textSecondary),
      TournamentRole.none when t.hasStarted => ('STARTED', AppColors.textSecondary),
      TournamentRole.none => ('OPEN', AppColors.secondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
    );
  }
}
