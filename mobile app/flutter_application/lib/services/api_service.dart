import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/user.dart';
import '../models/scan.dart';
import '../models/prediction_result.dart';
import '../models/verification_result.dart';

class ApiService {
  final String baseUrl;
  String? _authToken;

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? AppConstants.baseUrl;

  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> _getHeaders({bool includeAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (includeAuth && _authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // Authentication
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl${AppConstants.loginEndpoint}'),
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Login failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? organization,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl${AppConstants.registerEndpoint}'),
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'role': role,
          'organization': organization,
        }),
      ).timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Registration failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Registration error: $e');
    }
  }

  // Google Sign-In
  Future<Map<String, dynamic>> googleSignIn({
    required String idToken,
    required String accessToken,
    required String name,
    required String email,
    String? photoUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/google'),
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({
          'id_token': idToken,
          'access_token': accessToken,
          'name': name,
          'email': email,
          'photo_url': photoUrl,
        }),
      ).timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Google Sign-In failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Google Sign-In error: $e');
    }
  }

  // Check user approval status
  Future<Map<String, dynamic>> checkApprovalStatus(String email) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/approval-status?email=$email'),
        headers: _getHeaders(includeAuth: false),
      ).timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to check approval status: ${response.body}');
      }
    } catch (e) {
      throw Exception('Approval status error: $e');
    }
  }

  // Admin: Get pending users
  Future<List<Map<String, dynamic>>> getPendingUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/pending-users'),
        headers: _getHeaders(),
      ).timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> users = data['users'];
        return users.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get pending users: ${response.body}');
      }
    } catch (e) {
      throw Exception('Get pending users error: $e');
    }
  }

  // Admin: Approve user
  Future<Map<String, dynamic>> approveUser(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/approve-user'),
        headers: _getHeaders(),
        body: jsonEncode({'user_id': userId}),
      ).timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to approve user: ${response.body}');
      }
    } catch (e) {
      throw Exception('Approve user error: $e');
    }
  }

  // Admin: Deny user
  Future<Map<String, dynamic>> denyUser(String userId, {String? reason}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/deny-user'),
        headers: _getHeaders(),
        body: jsonEncode({
          'user_id': userId,
          'reason': reason,
        }),
      ).timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to deny user: ${response.body}');
      }
    } catch (e) {
      throw Exception('Deny user error: $e');
    }
  }

  // Update user profile
  Future<Map<String, dynamic>> updateProfile({
    required String userId,
    String? name,
    String? email,
    String? currentPassword,
    String? newPassword,
  }) async {
    try {
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/profile/$userId'),
      );

      // Add headers
      request.headers.addAll(_getHeaders());

      // Add form fields
      if (name != null && name.isNotEmpty) {
        request.fields['name'] = name;
      }
      if (email != null && email.isNotEmpty) {
        request.fields['email'] = email;
      }
      if (currentPassword != null && currentPassword.isNotEmpty) {
        request.fields['current_password'] = currentPassword;
      }
      if (newPassword != null && newPassword.isNotEmpty) {
        request.fields['new_password'] = newPassword;
      }

      final streamedResponse = await request.send().timeout(AppConstants.apiTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to update profile');
      }
    } catch (e) {
      throw Exception('Update profile error: $e');
    }
  }

  // Prediction
  Future<PredictionResult> predict({
    File? imageFile,
    File? audioFile,
    List<double>? chemicalData,
    String? siteId,
    String? userId,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl${AppConstants.predictEndpoint}'),
      );

      // Add files
      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', imageFile.path),
        );
      }

      if (audioFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('audio', audioFile.path),
        );
      }

      // Add form fields
      if (chemicalData != null && chemicalData.isNotEmpty) {
        request.fields['chemical'] = jsonEncode(chemicalData);
      }

      if (siteId != null) {
        request.fields['site_id'] = siteId;
      }

      if (userId != null) {
        request.fields['user_id'] = userId;
      }

      if (latitude != null) {
        request.fields['latitude'] = latitude.toString();
      }

      if (longitude != null) {
        request.fields['longitude'] = longitude.toString();
      }

      final streamedResponse = await request.send().timeout(AppConstants.scanTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PredictionResult.fromJson(data);
      } else {
        throw Exception('Prediction failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Prediction error: $e');
    }
  }

  // Verification
  Future<VerificationResult> verify({
    File? imageFile,
    File? audioFile,
    List<double>? chemicalData,
    String? fingerprintId,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl${AppConstants.verifyEndpoint}'),
      );

      // Add files
      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', imageFile.path),
        );
      }

      if (audioFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('audio', audioFile.path),
        );
      }

      // Add form fields
      if (chemicalData != null && chemicalData.isNotEmpty) {
        request.fields['chemical'] = jsonEncode(chemicalData);
      }

      if (fingerprintId != null) {
        request.fields['fingerprint_id'] = fingerprintId;
      }

      final streamedResponse = await request.send().timeout(AppConstants.scanTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return VerificationResult.fromJson(data);
      } else {
        throw Exception('Verification failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Verification error: $e');
    }
  }

  // Get scans
  Future<List<Scan>> getScans({String? userId, String? location}) async {
    try {
      final queryParams = <String, String>{};
      if (userId != null) queryParams['user_id'] = userId;
      if (location != null) queryParams['location'] = location;

      final uri = Uri.parse('$baseUrl${AppConstants.scansEndpoint}')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: _getHeaders(),
      ).timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final scansList = data['scans'] ?? data['data'] ?? [];
        return (scansList as List).map((scan) => Scan.fromJson(scan)).toList();
      } else {
        throw Exception('Failed to get scans: ${response.body}');
      }
    } catch (e) {
      throw Exception('Get scans error: $e');
    }
  }

  // Get metrics
  Future<Map<String, dynamic>> getMetrics() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl${AppConstants.metricsEndpoint}'),
        headers: _getHeaders(),
      ).timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get metrics: ${response.body}');
      }
    } catch (e) {
      throw Exception('Get metrics error: $e');
    }
  }

  // Get users
  Future<List<User>> getUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl${AppConstants.usersEndpoint}'),
        headers: _getHeaders(),
      ).timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final usersList = data['users'] ?? data['data'] ?? [];
        return (usersList as List).map((user) => User.fromJson(user)).toList();
      } else {
        throw Exception('Failed to get users: ${response.body}');
      }
    } catch (e) {
      throw Exception('Get users error: $e');
    }
  }

  // Health check
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
