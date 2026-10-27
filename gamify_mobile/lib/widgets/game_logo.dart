import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/game.dart';

/// A game's logo on a dark tile. Logos have different shapes (BGMI is a wide wordmark),
/// so callers pick a box size and the logo is fitted inside it.
class GameLogo extends StatelessWidget {
  final Game game;
  final double width;
  final double height;
  final double padding;
  final double radius;

  const GameLogo({
    super.key,
    required this.game,
    this.width = 64,
    this.height = 44,
    this.padding = 6,
    this.radius = AppRadius.input,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Image.asset(
        game.logoAsset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        semanticLabel: '${game.shortLabel} logo',
        errorBuilder: (_, _, _) => Icon(game.icon, color: AppColors.secondary),
      ),
    );
  }
}
