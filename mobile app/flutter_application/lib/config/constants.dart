import 'package:flutter/foundation.dart' show kIsWeb;
// `Platform` is not available on web, so import inside try/catch at runtime
import 'dart:io' show Platform;

class AppConstants {
  // API Configuration - choose sensible defaults per platform
  // - Android emulator: use 10.0.2.2 to reach host localhost
  // - iOS Simulator / desktop: localhost
  // - Web: 127.0.0.1
  static String get baseUrl {
    try {
      if (kIsWeb) return 'http://127.0.0.1:8000';
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
      if (Platform.isIOS) return 'http://localhost:8000';
    } catch (e) {
      // Fallback to localhost
    }
    return 'http://127.0.0.1:8000';
  }

  static const String apiVersion = '/api/v1';
  
  // Endpoints
  static const String loginEndpoint = '/login';
  static const String registerEndpoint = '/api/auth/register';
  static const String predictEndpoint = '/predict';
  static const String verifyEndpoint = '/verify';
  static const String extractFingerprintEndpoint = '/extract_fingerprint';
  static const String scansEndpoint = '/scans';
  static const String metricsEndpoint = '/metrics';
  static const String usersEndpoint = '/users';
  
  // Mineral types
  static const List<String> mineralTypes = [
    'Gold',
    'Chalcopyrite',
    'Hematite',
  ];
  
  // Mineral colors for UI
  static const Map<String, int> mineralColors = {
    'gold': 0xFFFFD700,
    'chalcopyrite': 0xFFB8860B,
    'hematite': 0xFF8B4513,
  };
  
  // Site locations
  static const List<String> siteLocations = [
    'Central_Equatoria',
    'Kapoeta_East',
    'Yei_River',
  ];
  
  // App info
  static const String appName = 'Mineral Tracer';
  static const String appVersion = '1.0.0';
  
  // Storage keys
  static const String userTokenKey = 'user_token';
  static const String userIdKey = 'user_id';
  static const String userNameKey = 'user_name';
  static const String userEmailKey = 'user_email';
  static const String userRoleKey = 'user_role';
  
  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration scanTimeout = Duration(seconds: 60);
}
