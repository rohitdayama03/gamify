import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// A signed link from the backend for uploading one file straight to S3.
class UploadTicket {
  final String key;
  final String url;
  final String method;
  final Map<String, String> headers;

  UploadTicket({required this.key, required this.url, required this.method, required this.headers});

  factory UploadTicket.fromJson(Map<String, dynamic> json) {
    return UploadTicket(
      key: json['key'],
      url: json['uploadUrl'],
      method: json['method'] ?? 'PUT',
      headers: Map<String, String>.from(json['headers'] ?? const {}),
    );
  }

  static List<UploadTicket> listFromSession(dynamic session) {
    final List uploads = session['uploads'] ?? [];
    return uploads.map((e) => UploadTicket.fromJson(e)).toList();
  }
}

/// Uploads files to S3 with the backend's signed links.
class DirectUpload {
  // Talks to S3 directly: no API base URL or login token, and long timeouts for videos on mobile data
  static final Dio _s3 = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    sendTimeout: const Duration(minutes: 10),
    receiveTimeout: const Duration(minutes: 1),
  ));

  /// PUTs the bytes with exactly the headers that were signed. Returns null on success, or a message to show.
  static Future<String?> put(UploadTicket ticket, Uint8List bytes, {ValueChanged<double>? onProgress}) async {
    try {
      await _s3.request<void>(
        ticket.url,
        data: Stream<List<int>>.value(bytes),
        options: Options(method: ticket.method, headers: {...ticket.headers, Headers.contentLengthHeader: bytes.length}),
        onSendProgress: onProgress == null
            ? null
            : (sent, total) {
                if (total > 0) onProgress(sent / total);
              },
      );
      return null;
    } on DioException catch (e) {
      debugPrint('S3 upload failed: ${e.response?.statusCode} ${e.response?.data ?? e.message}');
      return e.response == null
          ? 'Upload failed. Check your connection and try again.'
          : 'Upload failed (storage replied HTTP ${e.response?.statusCode}). Please try again.';
    }
  }
}
