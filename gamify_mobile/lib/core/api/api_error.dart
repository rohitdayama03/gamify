import 'package:dio/dio.dart';

/// Turns a failed API call into a message a player can act on.
String apiErrorMessage(DioException e, String fallback) {
  final data = e.response?.data;
  if (data is Map) {
    // Field validation errors are more specific than the generic "Validation failed" message
    final fieldErrors = data['validationErrors'];
    if (fieldErrors is Map && fieldErrors.isNotEmpty) {
      return '${fieldErrors.values.first}';
    }
    final message = data['message'];
    if (message is String && message.isNotEmpty) return message;
  }
  if (e.response == null) {
    return "Can't reach the GAMIFY server. Check your connection and try again.";
  }
  // A reply that isn't the backend's JSON (e.g. a proxy's redirect or error page); the status helps diagnose it
  final status = e.response?.statusCode;
  return status == null ? fallback : '$fallback (server replied HTTP $status)';
}
