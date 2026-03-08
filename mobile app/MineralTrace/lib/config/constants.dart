class AppConstants {
  // ================================
  // API Configuration
  // ================================
  static const String baseUrl = 'https://mineraltrace-api.onrender.com';
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

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
  static const String appName = 'MineralTrace';
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
  static String getExtractFingerprintUrl() =>
      '$baseUrl$extractFingerprintEndpoint';
  static String getScansUrl() => '$baseUrl$scansEndpoint';
}
