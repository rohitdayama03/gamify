import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Sends and checks sign-in codes with the MSG91 OTP Widget. The backend says which widget to use and
/// confirms the access token [verify] returns.
class Msg91Otp {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://control.msg91.com/api/v5/widget',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      // MSG91 doesn't always label its JSON replies as JSON, so they're decoded here
      responseType: ResponseType.plain,
    ),
  );

  final String widgetId;
  final String tokenAuth;

  const Msg91Otp({required this.widgetId, required this.tokenAuth});

  /// Sends a code to [phoneNumber] (E.164, e.g. +919876543210) and returns the request id for [retry]
  /// and [verify].
  Future<String> send(String phoneNumber) => _call(
    '/sendOtpMobile',
    {'identifier': phoneNumber.substring(1)},
    'Could not send the code',
  );

  /// Sends the code again by the widget's retry channel.
  Future<void> retry(String reqId) =>
      _call('/retryOtp', {'reqId': reqId}, 'Could not resend the code');

  /// Checks the code the player typed and returns the access token the backend signs them in with.
  Future<String> verify(String reqId, String otp) =>
      _call('/verifyOtp', {'reqId': reqId, 'otp': otp}, 'Incorrect code');

  // Every call answers {type: success|error, message}. On success the message is the request id or
  // access token; on error it says what went wrong
  Future<String> _call(String path, Map<String, dynamic> body, String fallback) async {
    try {
      final redirects = Options(
        followRedirects: false,
        validateStatus: (status) => status != null && status < 400,
      );
      var response = await _dio.post(
        path,
        data: {'widgetId': widgetId, 'tokenAuth': tokenAuth, ...body},
        options: redirects,
      );
      // MSG91 redirects to a regional server with the request in the link, to be fetched with GET (as
      // MSG91's own SDK does); Dio won't follow a POST's redirect on its own
      for (var hops = 0; response.statusCode! >= 300 && hops < 5; hops++) {
        final location = response.headers.value('location');
        if (location == null) break;
        response = await _dio.get(location, options: redirects);
      }
      final data = _json(response.data);
      if (data is Map && data['type'] == 'success' && data['message'] is String) {
        return data['message'];
      }
      debugPrint('MSG91 $path answered: $data');
      throw Msg91Exception(_describe(data is Map ? data['message'] : null, fallback));
    } on DioException catch (e) {
      final data = _json(e.response?.data);
      debugPrint('MSG91 $path failed: ${e.type} ${e.response?.statusCode} $data');
      throw Msg91Exception(
        e.response == null
            ? 'No connection. Check your internet and try again.'
            : _describe(data is Map ? data['message'] : null, fallback),
      );
    }
  }

  static Object? _json(Object? body) {
    if (body is! String) return body;
    try {
      return jsonDecode(body);
    } on FormatException {
      return body;
    }
  }

  // The sign-up screen keeps the code step open for errors that mention the code. Anything unrecognised
  // keeps MSG91's own reason (e.g. a widget setting), which is what's needed to fix it
  static String _describe(Object? message, String fallback) {
    final text = message is String ? message.toLowerCase() : '';
    debugPrint('MSG91: $message');
    if (text.contains('expire')) return 'This code has expired. Request a new one.';
    // A throttled widget token is a setting to fix in MSG91, not this player's limit
    if (!text.contains('token') && (text.contains('limit') || text.contains('maximum'))) {
      return 'Too many codes requested for this number. Try again later.';
    }
    if (text.contains('otp') && (text.contains('match') || text.contains('invalid'))) {
      return 'Incorrect code';
    }
    return text.isEmpty ? fallback : '$fallback: $message';
  }
}

class Msg91Exception implements Exception {
  final String message;

  Msg91Exception(this.message);

  @override
  String toString() => message;
}
