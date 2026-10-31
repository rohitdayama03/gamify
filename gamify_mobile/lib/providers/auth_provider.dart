import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/api/api_error.dart';
import '../core/api/msg91_otp.dart';
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

  /// Sends a sign-in code. The server first checks the number (and for [OtpPurpose.register], that
  /// [username] is free) so a code isn't spent on an account that can't be used, then says whether MSG91
  /// sends it or the server issued it itself (testing). Returns null on failure.
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
      final data = response.data as Map<String, dynamic>;
      final OtpSent sent;
      if (data['provider'] == 'MSG91') {
        final msg91 = Msg91Otp(widgetId: data['widgetId'], tokenAuth: data['tokenAuth']);
        sent = OtpSent(msg91: msg91, reqId: await msg91.send(phoneNumber));
      } else {
        sent = OtpSent(remainingToday: data['remainingToday']);
      }
      _errorMessage = null;
      _setLoading(false);
      return sent;
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Could not send the code');
    } on Msg91Exception catch (e) {
      _errorMessage = e.message;
    }
    _setLoading(false);
    return null;
  }

  /// Sends [sent]'s code again. Returns the code to check from now on, or null on failure.
  Future<OtpSent?> resendOtp(
    OtpSent sent, {
    required String phoneNumber,
    required OtpPurpose purpose,
    String? username,
  }) async {
    final msg91 = sent.msg91;
    if (msg91 == null) {
      return sendOtp(phoneNumber: phoneNumber, purpose: purpose, username: username);
    }
    _setLoading(true);
    try {
      await msg91.retry(sent.reqId!);
      _errorMessage = null;
      _setLoading(false);
      return sent;
    } on Msg91Exception catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      return null;
    }
  }

  Future<bool> login({
    required String phoneNumber,
    required OtpSent sent,
    required String otp,
  }) async {
    _setLoading(true);
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.login,
        data: {'phoneNumber': phoneNumber, ...await _codeProof(sent, otp)},
      );
      return await _signedIn(response.data);
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Login failed');
    } on Msg91Exception catch (e) {
      _errorMessage = e.message;
    }
    _setLoading(false);
    return false;
  }

  Future<bool> register({
    required String username,
    required String phoneNumber,
    required OtpSent sent,
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
          ...await _codeProof(sent, otp),
          'acceptedTerms': acceptedTerms,
        },
      );
      return await _signedIn(response.data);
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Registration failed');
    } on Msg91Exception catch (e) {
      _errorMessage = e.message;
    }
    _setLoading(false);
    return false;
  }

  // MSG91 checks the code and hands back a token the server confirms; a server-issued code goes as is
  Future<Map<String, dynamic>> _codeProof(OtpSent sent, String otp) async {
    final msg91 = sent.msg91;
    if (msg91 == null) return {'otp': otp};
    return {'accessToken': await msg91.verify(sent.reqId!, otp)};
  }

  Future<bool> _signedIn(dynamic data) async {
    _authResponse = AuthResponse.fromJson(data);
    await _storage.saveToken(_authResponse!.token);
    _errorMessage = null;
    _setLoading(false);
    return true;
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
