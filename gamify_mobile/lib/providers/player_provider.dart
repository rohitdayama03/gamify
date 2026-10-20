import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/player_model.dart';

class PlayerProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  PlayerResponse? _currentPlayer;
  List<PlayerResponse> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;

  PlayerResponse? get currentPlayer => _currentPlayer;
  List<PlayerResponse> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get errorMessage => _errorMessage;

  Future<void> fetchMyProfile() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.myProfile);
      _currentPlayer = PlayerResponse.fromJson(response.data);
      _errorMessage = null;
    } on DioException catch (e) {
      _errorMessage = e.response?.data['message'] ?? 'Failed to load profile';
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
      _errorMessage = e.response?.data['message'] ?? 'Update failed';
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
      _errorMessage = e.response?.data['message'] ?? 'Update failed';
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
      _errorMessage = e.response?.data['message'] ?? 'Update failed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteBgmiProfile() => _deleteGameProfile(ApiEndpoints.bgmiProfile);

  Future<bool> deleteEfootballProfile() => _deleteGameProfile(ApiEndpoints.efootballProfile);

  Future<bool> _deleteGameProfile(String endpoint) async {
    try {
      await _apiClient.dio.delete(endpoint);
      await fetchMyProfile();
      return true;
    } on DioException catch (e) {
      _errorMessage = e.response?.data['message'] ?? 'Delete failed';
      notifyListeners();
      return false;
    }
  }

  Future<void> searchPlayers({
    String? username,
    String? country,
    String? language,
    String? bgmiRole,
    String? efootballTier,
  }) async {
    _isSearching = true;
    notifyListeners();

    final queryParams = <String, dynamic>{};
    if (username != null && username.isNotEmpty) queryParams['username'] = username;
    if (country != null && country.isNotEmpty) queryParams['country'] = country;
    if (language != null && language.isNotEmpty) queryParams['language'] = language;
    if (bgmiRole != null && bgmiRole.isNotEmpty) queryParams['bgmiRole'] = bgmiRole;
    if (efootballTier != null && efootballTier.isNotEmpty) queryParams['efootballTier'] = efootballTier;

    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.searchPlayers,
        queryParameters: queryParams,
      );
      final List content = response.data['content'] ?? [];
      _searchResults = content.map((e) => PlayerResponse.fromJson(e)).toList();
      _errorMessage = null;
    } on DioException catch (e) {
      _errorMessage = e.response?.data['message'] ?? 'Search failed';
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }
}