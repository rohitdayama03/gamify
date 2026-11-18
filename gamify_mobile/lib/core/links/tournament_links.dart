import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../screens/tournaments/tournament_detail_screen.dart';
import '../notifications/push_notifications.dart';

/// Shareable tournament links, and opening the tournament when one is tapped.
///
/// A shared link is `https://gamify-api.duckdns.org/t/42`. Android opens it in the app once the server
/// verifies the app (its /.well-known/assetlinks.json); otherwise the link page opens
/// `gamify://tournament/42`, or the Play Store when the app isn't installed. Tapped inside the app (in a
/// chat message) the link opens the tournament directly.
class TournamentLinks {
  TournamentLinks._();

  static final TournamentLinks instance = TournamentLinks._();

  /// Where shared links point: the backend, which serves the link page. Must match the https host in
  /// AndroidManifest.xml. Override with `--dart-define=SHARE_BASE_URL=https://example.com`.
  static const String shareBaseUrl = String.fromEnvironment(
    'SHARE_BASE_URL',
    defaultValue: 'https://gamify-api.duckdns.org',
  );

  static const String _appScheme = 'gamify';

  /// The link to share for a tournament.
  static String urlFor(int tournamentId) => '$shareBaseUrl/t/$tournamentId';

  /// The tournament a link points to, or null if it isn't a tournament link. Accepts the shared web link
  /// (`/t/42`, or `/t?id=42`) and the app link `gamify://tournament/42`.
  static int? tournamentIdFrom(Uri uri) {
    if (uri.scheme == _appScheme) {
      if (uri.host != 'tournament' || uri.pathSegments.length != 1) return null;
      return _parseId(uri.pathSegments.first);
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length == 2 && segments.first == 't') return _parseId(segments.last);
    if (segments.length == 1 && segments.first == 't') return _parseId(uri.queryParameters['id']);
    return null;
  }

  static int? _parseId(String? value) {
    if (value == null || !RegExp(r'^[0-9]{1,18}$').hasMatch(value)) return null;
    final id = int.tryParse(value);
    return id == null || id <= 0 ? null : id;
  }

  StreamSubscription<Uri>? _subscription;
  bool _signedIn = false;
  // A link that arrived before sign-in finished; opened once the main screen is up
  int? _pending;

  /// Call once before runApp. The stream also delivers the link that launched the app.
  void init() {
    if (kIsWeb || _subscription != null) return;
    try {
      _subscription = AppLinks().uriLinkStream.listen(_onLink, onError: (Object e) => debugPrint('App link failed: $e'));
    } catch (e) {
      debugPrint('App links unavailable: $e');
    }
  }

  /// Call when the signed-in main screen appears; opens a link that was waiting for it.
  void attach() {
    _signedIn = true;
    final pending = _pending;
    _pending = null;
    if (pending != null) _open(pending);
  }

  /// Call when the main screen goes away (signed out).
  void detach() => _signedIn = false;

  void _onLink(Uri uri) {
    final id = tournamentIdFrom(uri);
    if (id == null) return;
    if (_signedIn) {
      _open(id);
    } else {
      // Signing in (or onboarding) comes first; the tournament opens afterwards
      _pending = id;
    }
  }

  void _open(int tournamentId) {
    // Wait for a frame so the navigator exists when the link launched the app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotifications.navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournamentId: tournamentId)),
      );
    });
    // The app may be idle with no frame coming; ask for one so the callback runs
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}
