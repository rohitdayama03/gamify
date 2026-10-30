import 'package:flutter/material.dart';
import '../../models/game.dart';
import 'edit_bgmi_profile_screen.dart';
import 'edit_efootball_profile_screen.dart';
import 'edit_gta_profile_screen.dart';

abstract final class EditGameProfilesScreen {
  /// Opens the profile editor for [game]; each game has its own screen
  static Future<void> open(BuildContext context, Game game) {
    final screen = switch (game) {
      Game.gta => const EditGtaProfileScreen(),
      Game.bgmi => const EditBgmiProfileScreen(),
      Game.efootball => const EditEfootballProfileScreen(),
    };
    return Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}
