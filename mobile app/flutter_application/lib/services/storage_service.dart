import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // User data
  Future<void> saveUserData({
    required String userId,
    required String name,
    required String email,
    required String role,
    String? token,
  }) async {
    await _prefs.setString(AppConstants.userIdKey, userId);
    await _prefs.setString(AppConstants.userNameKey, name);
    await _prefs.setString(AppConstants.userEmailKey, email);
    await _prefs.setString(AppConstants.userRoleKey, role);
    if (token != null) {
      await _prefs.setString(AppConstants.userTokenKey, token);
    }
  }

  String? getUserId() => _prefs.getString(AppConstants.userIdKey);
  String? getUserName() => _prefs.getString(AppConstants.userNameKey);
  String? getUserEmail() => _prefs.getString(AppConstants.userEmailKey);
  String? getUserRole() => _prefs.getString(AppConstants.userRoleKey);
  String? getToken() => _prefs.getString(AppConstants.userTokenKey);

  Future<void> setUserName(String name) async {
    await _prefs.setString(AppConstants.userNameKey, name);
  }

  Future<void> setUserEmail(String email) async {
    await _prefs.setString(AppConstants.userEmailKey, email);
  }

  Future<void> clearUserData() async {
    await _prefs.remove(AppConstants.userIdKey);
    await _prefs.remove(AppConstants.userNameKey);
    await _prefs.remove(AppConstants.userEmailKey);
    await _prefs.remove(AppConstants.userRoleKey);
    await _prefs.remove(AppConstants.userTokenKey);
  }

  bool isLoggedIn() {
    return _prefs.getString(AppConstants.userIdKey) != null;
  }

  // Onboarding
  Future<void> setOnboardingCompleted(bool value) async {
    await _prefs.setBool('onboarding_completed', value);
  }

  bool hasCompletedOnboarding() {
    return _prefs.getBool('onboarding_completed') ?? false;
  }

  // Generic storage
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  String? getString(String key) => _prefs.getString(key);

  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  bool? getBool(String key) => _prefs.getBool(key);

  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  // PIN management
  Future<void> setPin(String pin) async {
    await _prefs.setString('user_pin', pin);
  }

  Future<String?> getPin() async {
    return _prefs.getString('user_pin');
  }

  Future<void> removePin() async {
    await _prefs.remove('user_pin');
  }

  // Profile picture
  Future<void> setProfilePicture(String imagePath) async {
    await _prefs.setString('profile_picture', imagePath);
  }

  String? getProfilePicture() {
    return _prefs.getString('profile_picture');
  }

  Future<void> removeProfilePicture() async {
    await _prefs.remove('profile_picture');
  }

  // Scan ID persistence
  Future<void> addScanId(String scanId) async {
    final list = _prefs.getStringList(AppConstants.scanIdsKey) ?? <String>[];
    // prepend latest
    list.insert(0, scanId);
    await _prefs.setStringList(AppConstants.scanIdsKey, list);
    await _prefs.setString(AppConstants.lastScanIdKey, scanId);
  }

  List<String> getScanIds() {
    return _prefs.getStringList(AppConstants.scanIdsKey) ?? <String>[];
  }

  String? getLastScanId() => _prefs.getString(AppConstants.lastScanIdKey);

  Future<void> clearScanIds() async {
    await _prefs.remove(AppConstants.scanIdsKey);
    await _prefs.remove(AppConstants.lastScanIdKey);
  }
}
