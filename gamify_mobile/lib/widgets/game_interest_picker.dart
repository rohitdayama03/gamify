import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/game.dart';
import 'game_tile.dart';

/// Multi-select list of game tiles (1–3 games, PRD §4.1). Selection order is kept so the first pick becomes the default game.
class GameInterestPicker extends StatelessWidget {
  final List<Game> selected;
  final ValueChanged<List<Game>> onChanged;

  const GameInterestPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  void _toggle(Game game) {
    onChanged(
      selected.contains(game)
          ? selected.where((g) => g != game).toList()
          : [...selected, game],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final game in Game.values) ...[
          GameTile(
            game: game,
            selected: selected.contains(game),
            onTap: () => _toggle(game),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          selected.isEmpty
              ? 'Pick at least one game to continue.'
              : '${selected.length} of ${Game.values.length} selected',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
