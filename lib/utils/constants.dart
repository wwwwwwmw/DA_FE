import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

class Constants {
  // Sử dụng --dart-define=API_BASE_URL=https://<your-ngrok>.ngrok-free.dev khi dùng ngrok
  static String get apiBaseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    // Mặc định cho môi trường dev (không dùng dart:io để tránh lỗi trên web):
    if (kIsWeb) return 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator: host máy = 10.0.2.2
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  static String get socketBaseUrl => apiBaseUrl;
}
