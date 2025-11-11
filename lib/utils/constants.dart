import 'dart:io' show Platform;

class Constants {
  // Base API depending on platform.
  // Android emulator cannot reach 'localhost' of your PC; use 10.0.2.2.
  // iOS simulator uses host loopback so 'localhost' works, but LAN IP is fine too.
  static String get apiBaseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    const lanIp = '0.0.0.0'; // Your backend HOST
    const port = 5000;
    if (Platform.isAndroid) {
      // Distinguish between emulator vs real device by heuristic: emulator usually has 'android' manufacturer.
      // Simpler: always use LAN IP for Android real devices; if using emulator and backend runs on host machine use 10.0.2.2.
      // Provide an override via --dart-define=USE_EMULATOR=true when launching.
      const useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
      final host = useEmulator ? '10.0.2.2' : lanIp;
      return 'http://$host:$port';
    }
    // For all other platforms we can use LAN IP directly to allow physical devices to connect.
    return 'http://$lanIp:$port';
  }

  // Socket base URL (same as API). Keep trailing slash optional.
  static String get socketBaseUrl => apiBaseUrl;
}
