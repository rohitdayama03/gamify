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

  /// Sends a sign-in code on WhatsApp. For [OtpPurpose.register], [username] is checked
  /// first so a code isn't spent on an account that can't be created. Returns null on failure.
  Future<OtpSent?> sendOtp({
    required String phoneNumber,
    required OtpPurpose purpose,
    String? username,
  }) async {
    _setLoading(true);
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.sendOtp,
        data: {
          'phoneNumber': phoneNumber,
          'purpose': purpose.name.toUpperCase(),
          'username': ?username,
        },
      );
      _errorMessage = null;
      _setLoading(false);
      return OtpSent.fromJson(response.data);
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Could not send the code');
      _setLoading(false);
      return null;
    }
  }

  Future<bool> login({required String phoneNumber, required String otp}) async {
    _setLoading(true);
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.login,
        data: {'phoneNumber': phoneNumber, 'otp': otp},
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
    required String phoneNumber,
    required String otp,
    required bool acceptedTerms,
  }) async {
    _setLoading(true);
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.register,
        data: {
          'username': username,
          'phoneNumber': phoneNumber,
          'otp': otp,
          'acceptedTerms': acceptedTerms,
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
