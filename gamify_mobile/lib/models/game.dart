import 'package:flutter/material.dart';

// Mirrors the backend Game enum; apiValue is the name the API sends and expects
enum Game {
  gta(
    apiValue: 'GTA',
    label: 'GTA Online (GTA V)',
    shortLabel: 'GTA Online',
    tagline: 'Heists, missions, races & car meets',
    profileIntro: 'Add your GTA Online details so players can find you for heists, missions, races and casual sessions.',
    icon: Icons.directions_car_filled_outlined,
    logoAsset: 'assets/logos/gta_online.png',
  ),
  bgmi(
    apiValue: 'BGMI',
    label: 'BGMI',
    shortLabel: 'BGMI',
    tagline: 'Squads by role, language & schedule',
    profileIntro: 'Add your BGMI details so squads and teams can discover you.',
    icon: Icons.my_location_outlined,
    logoAsset: 'assets/logos/bgmi.png',
  ),
  efootball(
    apiValue: 'EFOOTBALL',
    label: 'eFootball',
    shortLabel: 'eFootball',
    tagline: '1v1 opponents & co-op partners',
    profileIntro: 'Add your eFootball details so opponents and co-op partners can find you.',
    icon: Icons.sports_soccer_outlined,
    logoAsset: 'assets/logos/efootball.png',
  );

  final String apiValue;
  final String label;
  final String shortLabel;
  final String tagline;
  // Game-specific copy shown when inviting a player to add this game's profile (PRD §5)
  final String profileIntro;
  // Fallback when the logo can't be shown
  final IconData icon;
  final String logoAsset;

  const Game({
    required this.apiValue,
    required this.label,
    required this.shortLabel,
    required this.tagline,
    required this.profileIntro,
    required this.icon,
    required this.logoAsset,
  });

  static Game? fromApi(dynamic value) {
    for (final game in values) {
      if (game.apiValue == value) return game;
    }
    return null;
  }

  // Unknown values from the API are dropped rather than failing the whole profile
  static List<Game> listFromApi(dynamic value) =>
      value is List ? value.map(fromApi).whereType<Game>().toList() : const [];
}
