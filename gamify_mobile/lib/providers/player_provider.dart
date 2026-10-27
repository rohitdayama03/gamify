import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/api/api_error.dart';
import '../models/game.dart';
import '../models/player_model.dart';

class PlayerProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  PlayerResponse? _currentPlayer;
  List<PlayerResponse> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;
  bool _sessionExpired = false;
  // Game named by the latest search text (sent back by the backend), e.g. "gta" -> Game.gta
  Game? _matchedGame;
  int _searchRequestId = 0;

  static const String matchedGameHeader = 'x-matched-game';

  PlayerResponse? get currentPlayer => _currentPlayer;
  List<PlayerResponse> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get errorMessage => _errorMessage;
  bool get sessionExpired => _sessionExpired;
  Game? get matchedGame => _matchedGame;

  /// Returns false when the profile couldn't be loaded; [sessionExpired] says whether signing in again will help.
  Future<bool> fetchMyProfile() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.myProfile);
      _currentPlayer = PlayerResponse.fromJson(response.data);
      _errorMessage = null;
      _sessionExpired = false;
      return true;
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Failed to load profile');
      _sessionExpired = e.response?.statusCode == 401;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.put(ApiEndpoints.updateProfile, data: data);
      _currentPlayer = PlayerResponse.fromJson(response.data);
      _errorMessage = null;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Update failed');
      notifyListeners();
      return false;
    }
  }

  /// Another player's public profile; null (with [errorMessage] set) if it couldn't be loaded
  Future<PlayerResponse?> fetchPlayer(int playerId) async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.player(playerId));
      return PlayerResponse.fromJson(response.data);
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Could not load this player');
      return null;
    }
  }

  Future<bool> updateInterests(List<Game> games) =>
      updateProfile({'interestedGames': [for (final g in games) g.apiValue]});

  /// Remembers the game the player is browsing; failures are ignored since it's only a convenience
  Future<void> setLastGame(Game game) async {
    if (_currentPlayer?.lastGame == game) return;
    await updateProfile({'lastGame': game.apiValue});
  }

  void clear() {
    _currentPlayer = null;
    _searchResults = [];
    notifyListeners();
  }

  Future<bool> updateGtaProfile(Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.put(ApiEndpoints.gtaProfile, data: data);
      await fetchMyProfile();
      return true;
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Update failed');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBgmiProfile(Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.put(ApiEndpoints.bgmiProfile, data: data);
      await fetchMyProfile();
      return true;
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Update failed');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateEfootballProfile(Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.put(ApiEndpoints.efootballProfile, data: data);
      await fetchMyProfile();
      return true;
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Update failed');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteGtaProfile() => _deleteGameProfile(ApiEndpoints.gtaProfile);

  Future<bool> deleteBgmiProfile() => _deleteGameProfile(ApiEndpoints.bgmiProfile);

  Future<bool> deleteEfootballProfile() => _deleteGameProfile(ApiEndpoints.efootballProfile);

  Future<bool> _deleteGameProfile(String endpoint) async {
    try {
      await _apiClient.dio.delete(endpoint);
      await fetchMyProfile();
      return true;
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Delete failed');
      notifyListeners();
      return false;
    }
  }

  /// [query] is matched against usernames (prefix) and game names; the backend ignores it under 3 characters.
  Future<void> searchPlayers({
    String? query,
    String? username,
    String? country,
    String? language,
    Game? game,
    String? gtaPlatform,
    String? gtaActivity,
    String? bgmiRole,
    String? efootballTier,
  }) async {
    final requestId = ++_searchRequestId;
    _isSearching = true;
    notifyListeners();

    final queryParams = <String, dynamic>{};
    if (query != null && query.isNotEmpty) queryParams['q'] = query;
    if (username != null && username.isNotEmpty) queryParams['username'] = username;
    if (country != null && country.isNotEmpty) queryParams['country'] = country;
    if (language != null && language.isNotEmpty) queryParams['language'] = language;
    if (game != null) queryParams['game'] = game.apiValue;
    if (gtaPlatform != null && gtaPlatform.isNotEmpty) queryParams['gtaPlatform'] = gtaPlatform;
    if (gtaActivity != null && gtaActivity.isNotEmpty) queryParams['gtaActivity'] = gtaActivity;
    if (bgmiRole != null && bgmiRole.isNotEmpty) queryParams['bgmiRole'] = bgmiRole;
    if (efootballTier != null && efootballTier.isNotEmpty) queryParams['efootballTier'] = efootballTier;

    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.searchPlayers,
        queryParameters: queryParams,
      );
      // A slower, older search must not overwrite the results of the latest one
      if (requestId != _searchRequestId) return;
      final List content = response.data['content'] ?? [];
      _searchResults = content.map((e) => PlayerResponse.fromJson(e)).toList();
      _matchedGame = Game.fromApi(response.headers.value(matchedGameHeader));
      _errorMessage = null;
    } on DioException catch (e) {
      if (requestId != _searchRequestId) return;
      _errorMessage = apiErrorMessage(e, 'Search failed');
    } finally {
      if (requestId == _searchRequestId) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }
}