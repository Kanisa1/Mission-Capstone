class ApiConfig {
  /// Base URL for the API
  /// 
  /// Can be overridden at runtime using environment variables:
  /// flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000
  /// 
  /// Configuration Guide:
  /// - Emulator/Simulator: Use http://127.0.0.1:8000 (default)
  /// - Physical Device (local network): Use http://YOUR_IP:8000
  /// - Production: Use https://api.yourdomain.com
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  
  /// Connection timeout duration
  static const Duration connectionTimeout = Duration(seconds: 30);
  
  /// Request timeout duration
  static const Duration requestTimeout = Duration(seconds: 60);
  
  /// Maximum image size for upload (in bytes)
  /// Default: 10MB
  static const int maxImageSize = 10 * 1024 * 1024;
  
  /// Maximum audio size for upload (in bytes)
  /// Default: 5MB
  static const int maxAudioSize = 5 * 1024 * 1024;
}
