import 'package:flutter/material.dart';

// Design tokens: near-black terminal surfaces, hairline borders and a mint-green accent
class AppColors {
  static const Color background = Color(0xFF0A0C0B);
  static const Color cardBackground = Color(0xFF111413);
  static const Color surfaceAlt = Color(0xFF171B19);
  static const Color border = Color(0xFF232A26);
  // Reserved for primary CTAs and active states
  static const Color primary = Color(0xFF4AF2A1);
  // Text and icons drawn on top of the bright accent
  static const Color onPrimary = Color(0xFF04140C);
  // Dimmer green for low-emphasis accents (icons, tags, links)
  static const Color secondary = Color(0xFF5FD39A);
  static const Color textPrimary = Color(0xFFF2F5F3);
  static const Color textSecondary = Color(0xFF8C9690);
  static const Color error = Color(0xFFFF5C5C);
  // A liked post's heart
  static const Color like = Color(0xFFFF4D6D);
  // Only for explicit user-set availability or confirmed success
  static const Color success = Color(0xFF4AF2A1);
}

class AppSpacing {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double gutter = 16;
}

// Sharp, technical corners
class AppRadius {
  static const double card = 6;
  static const double input = 4;
  static const double chip = 4;
}

class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);

  // Honour the OS "reduce motion" setting
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.of(context).disableAnimations ? Duration.zero : duration;
}
