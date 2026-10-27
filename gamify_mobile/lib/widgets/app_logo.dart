import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_theme.dart';

/// GAMIFY wordmark with its controller mark; [size] is the wordmark font size.
class AppLogo extends StatelessWidget {
  static const String markAsset = 'assets/branding/logo_mark.png';
  static const String iconAsset = 'assets/branding/app_icon.png';

  final double size;

  const AppLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'GAMIFY',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.input),
            child: Image.asset(
              markAsset,
              width: size * 1.7,
              height: size * 1.7,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => Icon(Icons.sports_esports, color: AppColors.primary, size: size * 1.4),
            ),
          ),
          SizedBox(width: size * 0.5),
          Text(
            'GAMIFY',
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontSize: size,
              fontWeight: FontWeight.w700,
              letterSpacing: size * 0.04,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The full app icon (mark + wordmark), for screens where the brand is the focus.
class AppIconImage extends StatelessWidget {
  final double size;

  const AppIconImage({super.key, this.size = 112});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'GAMIFY',
      image: true,
      excludeSemantics: true,
      child: ClipRRect(
        // The artwork has its own rounded frame; clip just the outer corners to match it
        borderRadius: BorderRadius.circular(size * 0.18),
        child: Image.asset(
          AppLogo.iconAsset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => const AppLogo(size: 26),
        ),
      ),
    );
  }
}
