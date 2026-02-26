import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class AppConstants {
  // ================================
  // API Configuration
  // ================================
  // Your computer IP address (from ipconfig)
  static const String _localIp = '10.102.137.176';
  static const String _port = '8000';

  static String get baseUrl {
    // the address the running client can reach. depending on where
    // the Flutter code is executing the host machine may not be
    // directly accessible by its LAN IP, and some environments
    // (desktop, simulators) will prefer localhost.
    try {
      // Web browser always uses the LAN IP (same origin rules apply).
      if (kIsWeb) {
        return 'http://$_localIp:$_port';
      }

      // Android emulator (Android Studio / AVD) routes 10.0.2.2 ->
      // host loopback. Genymotion would use 10.0.3.2 instead.
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:$_port';
      }

      // iOS simulator can use localhost since it shares the host
      // networking stack. Physical devices must still use the LAN IP.
      if (Platform.isIOS) {
        return 'http://localhost:$_port';
      }

      // Windows, macOS, Linux desktop builds are running on the same
      // machine that hosts the API; use localhost to avoid firewall
      // and binding issues. If you bind your server explicitly to the
      // LAN IP or 0.0.0.0 this could be changed accordingly.
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        return 'http://localhost:$_port';
      }
    } catch (e) {
      // ignore and fall back
    }

    // default for physical non-desktop devices (e.g. real phones)
    return 'http://$_localIp:$_port';
  }

  // ================================
  // API Version
  // ================================
  static const String apiVersion = '/api/v1';

  // ================================
  // Endpoints
  // ================================
  static const String loginEndpoint = '/login';
  static const String registerEndpoint = '/api/auth/register';
  static const String predictEndpoint = '/predict';
  static const String verifyEndpoint = '/verify';
  static const String extractFingerprintEndpoint = '/extract_fingerprint';
  static const String scansEndpoint = '/scans';
  static const String metricsEndpoint = '/metrics';
  static const String usersEndpoint = '/users';

  // ================================
  // Mineral types
  // ================================
  static const List<String> mineralTypes = [
    'Gold',
    'Chalcopyrite',
    'Hematite',
  ];

  // ================================
  // Mineral colors for UI
  // ================================
  static const Map<String, int> mineralColors = {
    'gold': 0xFFFFD700,
    'chalcopyrite': 0xFFB8860B,
    'hematite': 0xFF8B4513,
  };

  // ================================
  // Site locations
  // ================================
  static const List<String> siteLocations = [
    'Central_Equatoria',
    'Kapoeta_East',
    'Yei_River',
  ];

  // ================================
  // App info
  // ================================
  static const String appName = 'Mineral Tracer';
  static const String appVersion = '1.0.0';

  // ================================
  // Storage keys
  // ================================
  static const String userTokenKey = 'user_token';
  static const String userIdKey = 'user_id';
  static const String userNameKey = 'user_name';
  static const String userEmailKey = 'user_email';
  static const String userRoleKey = 'user_role';
  static const String scanIdsKey = 'scan_ids';
  static const String lastScanIdKey = 'last_scan_id';

  // ================================
  // Timeouts
  // ================================
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration scanTimeout = Duration(seconds: 60);

  // ================================
  // Helper: Build full endpoint URL
  // ================================
  static String getPredictUrl() => '$baseUrl$predictEndpoint';
  static String getVerifyUrl() => '$baseUrl$verifyEndpoint';
  static String getExtractFingerprintUrl() => '$baseUrl$extractFingerprintEndpoint';
  static String getScansUrl() => '$baseUrl$scansEndpoint';
}