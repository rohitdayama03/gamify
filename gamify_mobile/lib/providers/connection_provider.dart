import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/connection_model.dart';

/// How the logged-in player relates to another player.
enum RelationStatus { none, inviteSent, inviteReceived, friends, declined }

class ConnectionProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<ConnectionResponse> _connections = [];
  bool _isLoading = false;
  String? _errorMessage;
  // Connection ids with an accept/decline/invite request in flight, to disable their buttons
  final Set<int> _busyIds = {};

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool isBusy(int id) => _busyIds.contains(id);

  List<ConnectionResponse> get pendingInvites => _connections
      .where((c) => c.direction == ConnectionDirection.received && c.status == ConnectionStatus.pending)
      .toList();

  // Invites I sent that were accepted, shown as "X accepted your invite"
  List<ConnectionResponse> get acceptedSentInvites => _connections
      .where((c) => c.direction == ConnectionDirection.sent && c.status == ConnectionStatus.accepted)
      .toList();

  List<PlayerSummary> get friends => _connections
      .where((c) => c.status == ConnectionStatus.accepted)
      .map((c) => c.otherPlayer)
      .toList();

  RelationStatus statusWith(int playerId) {
    final withPlayer = _connections.where((c) => c.otherPlayer.playerId == playerId);
    bool has(ConnectionDirection? direction, ConnectionStatus status) =>
        withPlayer.any((c) => c.status == status && (direction == null || c.direction == direction));

    if (has(null, ConnectionStatus.accepted)) return RelationStatus.friends;
    if (has(ConnectionDirection.received, ConnectionStatus.pending)) return RelationStatus.inviteReceived;
    if (has(ConnectionDirection.sent, ConnectionStatus.pending)) return RelationStatus.inviteSent;
    // Only an invite *I* sent being declined blocks me; declining theirs does not
    if (has(ConnectionDirection.sent, ConnectionStatus.declined)) return RelationStatus.declined;
    return RelationStatus.none;
  }

  ConnectionResponse? pendingInviteFrom(int playerId) {
    for (final c in pendingInvites) {
      if (c.otherPlayer.playerId == playerId) return c;
    }
    return null;
  }

  Future<void> fetchConnections() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.connections);
      final List data = response.data ?? [];
      _connections = data.map((e) => ConnectionResponse.fromJson(e)).toList();
      _errorMessage = null;
    } on DioException catch (e) {
      _errorMessage = e.response?.data['message'] ?? 'Failed to load invites';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendInvite(int playerId) =>
      _mutate(-playerId, () => _apiClient.dio.post(ApiEndpoints.sendInvite(playerId)), 'Failed to send invite');

  Future<bool> acceptInvite(int connectionId) =>
      _mutate(connectionId, () => _apiClient.dio.post(ApiEndpoints.acceptInvite(connectionId)), 'Failed to accept invite');

  Future<bool> declineInvite(int connectionId) =>
      _mutate(connectionId, () => _apiClient.dio.post(ApiEndpoints.declineInvite(connectionId)), 'Failed to decline invite');

  bool isInviting(int playerId) => _busyIds.contains(-playerId);

  // Runs a request, then reloads all connections so every screen shows the new state.
  // Invites use the negated player id as the busy key so they never clash with connection ids.
  Future<bool> _mutate(int busyKey, Future<Response> Function() request, String fallbackError) async {
    _busyIds.add(busyKey);
    notifyListeners();
    try {
      await request();
      _errorMessage = null;
      await fetchConnections();
      return true;
    } on DioException catch (e) {
      _errorMessage = e.response?.data['message'] ?? fallbackError;
      // Our view was stale (e.g. they already invited us); refresh so the UI matches the server
      await fetchConnections();
      return false;
    } finally {
      _busyIds.remove(busyKey);
      notifyListeners();
    }
  }
}
