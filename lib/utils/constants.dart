import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

class Constants {
  // Sử dụng --dart-define=API_BASE_URL=https://<your-ngrok>.ngrok-free.dev khi dùng ngrok
  static String get apiBaseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    // Mặc định dùng ngrok để máy thật kết nối ngay khi RUN.
    // Cập nhật URL này khi bạn tạo phiên ngrok mới.
    const defaultNgrok = 'https://unranging-cruciformly-aleta.ngrok-free.dev';
    if (defaultNgrok.isNotEmpty) return defaultNgrok;

    // Fallback dev (ít dùng khi đã cấu hình ngrok ở trên)
    if (kIsWeb) return 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator: host máy = 10.0.2.2
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  static String get socketBaseUrl => apiBaseUrl;
}
