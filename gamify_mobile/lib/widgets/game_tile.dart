import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/game.dart';
import 'game_logo.dart';

/// Tappable game card. In multi-select it shows a checkmark; as a single picker it highlights the active game.
class GameTile extends StatelessWidget {
  final Game game;
  final bool selected;
  final VoidCallback? onTap;
  final bool showTagline;
  final bool compact;

  const GameTile({
    super.key,
    required this.game,
    required this.selected,
    this.onTap,
    this.showTagline = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.of(context, AppMotion.normal);

    return Semantics(
      button: true,
      selected: selected,
      label: game.label,
      hint: showTagline ? game.tagline : null,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 44),
            padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.14)
                  : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: compact ? _buildCompact() : _buildFull(context, duration),
          ),
        ),
      ),
    );
  }

  Widget _buildFull(BuildContext context, Duration duration) {
    return Row(
      children: [
        GameLogo(game: game, width: 72, height: 48),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                game.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (showTagline) ...[
                const SizedBox(height: 2),
                Text(
                  game.tagline,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        AnimatedSwitcher(
          duration: duration,
          child: Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            key: ValueKey(selected),
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCompact() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameLogo(game: game, width: double.infinity, height: 48),
        const SizedBox(height: AppSpacing.xs),
        Text(
          game.shortLabel,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
