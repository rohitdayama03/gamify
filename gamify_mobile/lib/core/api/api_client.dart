import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../storage/secure_storage.dart';

class ApiClient {
  late final Dio dio;
  final SecureStorage _storage = SecureStorage();

  // Override with --dart-define=API_BASE_URL=... (e.g. another port or a deployed server).
  // Otherwise web runs in a browser on the same machine as the backend; physical devices use the LAN IP
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kIsWeb ? 'http://localhost:8080/api/v1' : 'http://192.168.1.15:8080/api/v1',
  );
  // static String get baseUrl {
  //   if (Platform.isAndroid) {
  //     return 'http://10.0.2.2:8080/api/v1'; // Android Emulator
  //   } else {
  //     return 'http://localhost:8080/api/v1'; // iOS Simulator
  //   }
  // }

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }
}