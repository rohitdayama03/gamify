import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/api/api_error.dart';
import '../models/chat_model.dart';
import '../models/squad_model.dart';

class SquadProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<SquadSummary> _squads = [];
  List<SquadInvite> _invites = [];
  bool _isLoading = false;
  String? _errorMessage;
  // Invite ids with an accept/decline request in flight, to disable their buttons
  final Set<int> _busyInviteIds = {};

  List<SquadSummary> get squads => _squads;
  List<SquadInvite> get invites => _invites;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get totalUnread => _squads.fold(0, (sum, s) => sum + s.unreadCount);
  bool isBusy(int inviteId) => _busyInviteIds.contains(inviteId);

  /// Reloads the squad list and pending invites together.
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    try {
      final responses = await Future.wait([
        _apiClient.dio.get(ApiEndpoints.squads),
        _apiClient.dio.get(ApiEndpoints.squadInvites),
      ]);
      _squads = ((responses[0].data ?? []) as List).map((e) => SquadSummary.fromJson(e)).toList();
      _invites = ((responses[1].data ?? []) as List).map((e) => SquadInvite.fromJson(e)).toList();
      _errorMessage = null;
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Failed to load squads');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a squad and invites [memberIds]. Returns null on failure (e.g. the name is taken).
  Future<SquadDetail?> createSquad(String name, List<int> memberIds) =>
      _detailRequest(() => _apiClient.dio.post(ApiEndpoints.squads, data: {'name': name, 'memberIds': memberIds}),
          'Could not create the squad');

  Future<SquadDetail?> fetchSquad(int squadId) =>
      _detailRequest(() => _apiClient.dio.get(ApiEndpoints.squad(squadId)), 'Failed to load the squad', refreshAfter: false);

  Future<SquadDetail?> inviteMembers(int squadId, List<int> playerIds) =>
      _detailRequest(() => _apiClient.dio.post(ApiEndpoints.inviteToSquad(squadId), data: {'playerIds': playerIds}),
          'Could not send the invites');

  /// Owner only: removes a member or withdraws a pending invite.
  Future<SquadDetail?> removeMember(int squadId, int playerId) =>
      _detailRequest(() => _apiClient.dio.delete(ApiEndpoints.squadMember(squadId, playerId)), 'Could not remove the member');

  Future<bool> leaveSquad(int squadId) async {
    try {
      await _apiClient.dio.post(ApiEndpoints.leaveSquad(squadId));
      _errorMessage = null;
      await refresh();
      return true;
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Could not leave the squad');
      return false;
    }
  }

  /// Returns the joined squad, or null on failure.
  Future<SquadDetail?> acceptInvite(int inviteId) async {
    _busyInviteIds.add(inviteId);
    notifyListeners();
    try {
      return await _detailRequest(
          () => _apiClient.dio.post(ApiEndpoints.acceptSquadInvite(inviteId)), 'Failed to join the squad');
    } finally {
      _busyInviteIds.remove(inviteId);
      notifyListeners();
    }
  }

  Future<bool> declineInvite(int inviteId) async {
    _busyInviteIds.add(inviteId);
    notifyListeners();
    try {
      await _apiClient.dio.post(ApiEndpoints.declineSquadInvite(inviteId));
      _errorMessage = null;
      return true;
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Failed to decline the invite');
      return false;
    } finally {
      _busyInviteIds.remove(inviteId);
      // Also picks up a squad that was deleted while the invite was showing
      await refresh();
    }
  }

  /// Squad messages, oldest first. Pass [afterId] to poll for new messages
  /// or [beforeId] to load an older page. Returns null on failure.
  Future<List<ChatMessage>?> fetchMessages(int squadId, {int? afterId, int? beforeId}) async {
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.squadMessages(squadId),
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

  Future<ChatMessage?> sendMessage(int squadId, String content) async {
    try {
      final response = await _apiClient.dio.post(ApiEndpoints.squadMessages(squadId), data: {'content': content});
      _errorMessage = null;
      return ChatMessage.fromJson(response.data);
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Message not sent');
      return null;
    }
  }

  // Runs a request that answers with the squad, then reloads the list so every screen shows the new state
  Future<SquadDetail?> _detailRequest(Future<Response> Function() request, String fallbackError,
      {bool refreshAfter = true}) async {
    try {
      final response = await request();
      _errorMessage = null;
      if (refreshAfter) await refresh();
      return SquadDetail.fromJson(response.data);
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, fallbackError);
      return null;
    }
  }
}
