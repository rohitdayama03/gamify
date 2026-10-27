import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/api/api_error.dart';
import '../core/notifications/push_notifications.dart';
import '../core/storage/secure_storage.dart';
import '../models/auth_model.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  final SecureStorage _storage = SecureStorage();

  bool _isLoading = false;
  String? _errorMessage;
  AuthResponse? _authResponse;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _authResponse != null;
  AuthResponse? get authResponse => _authResponse;

  Future<bool> checkAuthStatus() async {
    final token = await _storage.getToken();
    return token != null;
  }

  Future<bool> login(String username, String password) async {
    _setLoading(true);
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.login,
        data: {'username': username, 'password': password},
      );
      _authResponse = AuthResponse.fromJson(response.data);
      await _storage.saveToken(_authResponse!.token);
      _errorMessage = null;
      _setLoading(false);
      return true;
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Login failed');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    String? playerBio,
    String? language,
    String? country,
    required String secretQuestion,
    required String secretAnswer,
    required bool acceptedTerms,
  }) async {
    _setLoading(true);
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.register,
        data: {
          'username': username,
          'email': email,
          'password': password,
          'acceptedTerms': acceptedTerms,
          'playerBio': playerBio,
          'language': language,
          'country': country,
          'secretQuestion': secretQuestion,
          'secretAnswer': secretAnswer,
        },
      );
      _authResponse = AuthResponse.fromJson(response.data);
      await _storage.saveToken(_authResponse!.token);
      _errorMessage = null;
      _setLoading(false);
      return true;
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Registration failed');
      _setLoading(false);
      return false;
    }
  }

  Future<SecretQuestionResponse?> getSecretQuestion(String username) async {
    _setLoading(true);
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.secretQuestion,
        queryParameters: {'username': username},
      );
      _errorMessage = null;
      _setLoading(false);
      return SecretQuestionResponse.fromJson(response.data);
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'User not found');
      _setLoading(false);
      return null;
    }
  }

  Future<bool> resetPassword(String username, String secretAnswer, String newPassword) async {
    _setLoading(true);
    try {
      await _apiClient.dio.post(
        ApiEndpoints.resetPassword,
        data: {
          'username': username,
          'secretAnswer': secretAnswer,
          'newPassword': newPassword,
        },
      );
      _errorMessage = null;
      _setLoading(false);
      return true;
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Password reset failed');
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    // Before the login token is discarded, so the server can stop pushing to this phone
    await PushNotifications.instance.stop();
    try {
      await _apiClient.dio.post(ApiEndpoints.logout);
    } catch (_) {}
    await _storage.deleteToken();
    _authResponse = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}