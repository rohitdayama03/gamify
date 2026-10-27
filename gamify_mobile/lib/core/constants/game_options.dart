import 'package:flutter/material.dart';

/// Preset choices for game profile forms. Values must match the backend's allowed lists.
class GtaOptions {
  static const List<String> platforms = ['PlayStation', 'PC'];
  static const String platformHelp =
      "Players only show as playable with you when they're on the same platform.";

  static const Map<String, IconData> activities = {
    'Heist': Icons.savings_outlined,
    'Free roam': Icons.explore_outlined,
    'Racing': Icons.sports_score_outlined,
    'Casual mission': Icons.flag_outlined,
  };

  static const int minRank = 1;
  static const int maxRank = 100;

  static IconData activityIcon(String activity) =>
      activities[activity] ?? Icons.sports_esports_outlined;
}
