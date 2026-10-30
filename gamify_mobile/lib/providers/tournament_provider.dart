import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/api/api_error.dart';
import '../models/chat_model.dart';
import '../models/game.dart';
import '../models/tournament_model.dart';

class TournamentProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  // Inbox data, kept fresh by the main screen's refresh
  List<TournamentChat> _chats = [];
  List<TournamentRequest> _requests = [];
  bool _isLoading = false;
  String? _errorMessage;
  // Request ids with an accept/reject in flight, to disable their buttons
  final Set<int> _busyRequestIds = {};

  List<TournamentChat> get chats => _chats;
  List<TournamentRequest> get requests => _requests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get totalUnread => _chats.fold(0, (sum, c) => sum + c.unreadCount);
  bool isBusy(int requestId) => _busyRequestIds.contains(requestId);

  /// Reloads the announcement chats and the join requests waiting on the player.
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    try {
      final responses = await Future.wait([
        _apiClient.dio.get(ApiEndpoints.tournamentChats),
        _apiClient.dio.get(ApiEndpoints.tournamentRequests),
      ]);
      _chats = ((responses[0].data ?? []) as List).map((e) => TournamentChat.fromJson(e)).toList();
      _requests = ((responses[1].data ?? []) as List).map((e) => TournamentRequest.fromJson(e)).toList();
      _errorMessage = null;
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Failed to load tournaments');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Open tournaments, soonest first; all games when [game] is null. Returns null on failure.
  Future<List<TournamentSummary>?> fetchOpen({Game? game}) =>
      _listRequest(() => _apiClient.dio.get(ApiEndpoints.tournaments, queryParameters: {'game': ?game?.apiValue}));

  /// Tournaments the player organizes or has asked to join. Returns null on failure.
  Future<List<TournamentSummary>?> fetchMine() => _listRequest(() => _apiClient.dio.get(ApiEndpoints.myTournaments));

  Future<List<PlayerTournament>?> fetchPlayerTournaments(int playerId) async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.playerTournaments(playerId));
      _errorMessage = null;
      return ((response.data ?? []) as List).map((e) => PlayerTournament.fromJson(e)).toList();
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Failed to load tournaments');
      return null;
    }
  }

  Future<TournamentDetail?> createTournament({
    required String name,
    required Game game,
    String? description,
    required DateTime startsAt,
    int? maxParticipants,
  }) =>
      _detailRequest(
        () => _apiClient.dio.post(ApiEndpoints.tournaments, data: {
          'name': name,
          'game': game.apiValue,
          'description': description,
          // UTC with an offset, which the backend's OffsetDateTime expects
          'startsAt': startsAt.toUtc().toIso8601String(),
          'maxParticipants': maxParticipants,
        }),
        'Could not create the tournament',
      );

  Future<TournamentDetail?> fetchTournament(int id) =>
      _detailRequest(() => _apiClient.dio.get(ApiEndpoints.tournament(id)), 'Failed to load the tournament', refreshAfter: false);

  Future<TournamentDetail?> requestToJoin(int id) =>
      _detailRequest(() => _apiClient.dio.post(ApiEndpoints.joinTournament(id)), 'Could not send your request');

  Future<TournamentDetail?> withdraw(int id) =>
      _detailRequest(() => _apiClient.dio.delete(ApiEndpoints.joinTournament(id)), 'Could not withdraw');

  Future<TournamentDetail?> acceptRequest(int requestId) =>
      _answer(requestId, () => _apiClient.dio.post(ApiEndpoints.acceptTournamentRequest(requestId)), 'Could not accept the request');

  Future<TournamentDetail?> rejectRequest(int requestId) =>
      _answer(requestId, () => _apiClient.dio.post(ApiEndpoints.rejectTournamentRequest(requestId)), 'Could not reject the request');

  /// [placements] maps player ids to their place (1 = winner).
  Future<TournamentDetail?> recordResult(int id, Map<int, int> placements, String? notes) => _detailRequest(
        () => _apiClient.dio.put(ApiEndpoints.tournamentResult(id), data: {
          'placements': [
            for (final entry in placements.entries) {'playerId': entry.key, 'placement': entry.value},
          ],
          'notes': notes,
        }),
        'Could not save the result',
      );

  Future<bool> deleteTournament(int id) async {
    try {
      await _apiClient.dio.delete(ApiEndpoints.tournament(id));
      _errorMessage = null;
      await refresh();
      return true;
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Could not cancel the tournament');
      return false;
    }
  }

  /// Announcements, oldest first. Pass [afterId] to poll for new ones
  /// or [beforeId] to load an older page. Returns null on failure.
  Future<List<ChatMessage>?> fetchMessages(int id, {int? afterId, int? beforeId}) async {
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.tournamentMessages(id),
        queryParameters: {
          'afterId': ?afterId,
          'beforeId': ?beforeId,
        },
      );
      final List data = response.data ?? [];
      _errorMessage = null;
      return data.map((e) => ChatMessage.fromJson(e)).toList();
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Failed to load messages');
      return null;
    }
  }

  /// Organizer only.
  Future<ChatMessage?> sendMessage(int id, String content) async {
    try {
      final response = await _apiClient.dio.post(ApiEndpoints.tournamentMessages(id), data: {'content': content});
      _errorMessage = null;
      return ChatMessage.fromJson(response.data);
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Message not sent');
      return null;
    }
  }

  Future<TournamentDetail?> _answer(int requestId, Future<Response> Function() request, String fallbackError) async {
    _busyRequestIds.add(requestId);
    notifyListeners();
    try {
      final detail = await _detailRequest(request, fallbackError);
      // A stale request (e.g. already answered elsewhere) should disappear from the list
      if (detail == null) await refresh();
      return detail;
    } finally {
      _busyRequestIds.remove(requestId);
      notifyListeners();
    }
  }

  Future<List<TournamentSummary>?> _listRequest(Future<Response> Function() request) async {
    try {
      final response = await request();
      _errorMessage = null;
      return ((response.data ?? []) as List).map((e) => TournamentSummary.fromJson(e)).toList();
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Failed to load tournaments');
      return null;
    }
  }

  // Runs a request that answers with the tournament, then reloads the Inbox data so badges stay right
  Future<TournamentDetail?> _detailRequest(Future<Response> Function() request, String fallbackError,
      {bool refreshAfter = true}) async {
    try {
      final response = await request();
      _errorMessage = null;
      if (refreshAfter) await refresh();
      return TournamentDetail.fromJson(response.data);
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, fallbackError);
      return null;
    }
  }
}
