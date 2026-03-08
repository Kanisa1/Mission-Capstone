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
      final response = await http
          .post(
            Uri.parse('$baseUrl${AppConstants.loginEndpoint}'),
            headers: _getHeaders(includeAuth: false),
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(AppConstants.apiTimeout);

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
      final response = await http
          .post(
            Uri.parse('$baseUrl${AppConstants.registerEndpoint}'),
            headers: _getHeaders(includeAuth: false),
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
              'role': role,
              'organization': organization,
            }),
          )
          .timeout(AppConstants.apiTimeout);

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
    String? idToken,
    String? accessToken,
    required String name,
    required String email,
    String? photoUrl,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/google'),
            headers: _getHeaders(includeAuth: false),
            body: jsonEncode({
              'id_token': idToken ?? '',
              'access_token': accessToken ?? '',
              'name': name,
              'email': email,
              'photo_url': photoUrl,
            }),
          )
          .timeout(AppConstants.apiTimeout);

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
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/auth/approval-status?email=$email'),
            headers: _getHeaders(includeAuth: false),
          )
          .timeout(AppConstants.apiTimeout);

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
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/admin/pending-users'),
            headers: _getHeaders(),
          )
          .timeout(AppConstants.apiTimeout);

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
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/admin/approve-user'),
            headers: _getHeaders(),
            body: jsonEncode({'user_id': userId}),
          )
          .timeout(AppConstants.apiTimeout);

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
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/admin/deny-user'),
            headers: _getHeaders(),
            body: jsonEncode({
              'user_id': userId,
              'reason': reason,
            }),
          )
          .timeout(AppConstants.apiTimeout);

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

      final streamedResponse =
          await request.send().timeout(AppConstants.apiTimeout);
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

      // Add chemical form fields (API expects individual element fields)
      // chemicalData order: [Au, Cu, Fe, S, O]
      double au = 0.0, cu = 0.0, fe = 0.0, s = 0.0, o = 0.0;
      if (chemicalData != null && chemicalData.length >= 5) {
        au = chemicalData[0];
        cu = chemicalData[1];
        fe = chemicalData[2];
        s = chemicalData[3];
        o = chemicalData[4];
      }
      request.fields['Au'] = au.toString();
      request.fields['Cu'] = cu.toString();
      request.fields['Fe'] = fe.toString();
      request.fields['S'] = s.toString();
      request.fields['O'] = o.toString();

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

      final streamedResponse =
          await request.send().timeout(AppConstants.scanTimeout);
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

      // Add chemical form fields (API expects individual element fields)
      double au2 = 0.0, cu2 = 0.0, fe2 = 0.0, s2 = 0.0, o2 = 0.0;
      if (chemicalData != null && chemicalData.length >= 5) {
        au2 = chemicalData[0];
        cu2 = chemicalData[1];
        fe2 = chemicalData[2];
        s2 = chemicalData[3];
        o2 = chemicalData[4];
      }
      request.fields['Au'] = au2.toString();
      request.fields['Cu'] = cu2.toString();
      request.fields['Fe'] = fe2.toString();
      request.fields['S'] = s2.toString();
      request.fields['O'] = o2.toString();

      if (fingerprintId != null) {
        request.fields['fingerprint_id'] = fingerprintId;
      }

      final streamedResponse =
          await request.send().timeout(AppConstants.scanTimeout);
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
    List<Scan> mapVerificationsToScans(List<dynamic> verifications) {
      return verifications.map((item) {
        final row = item as Map<String, dynamic>;
        final status = (row['status'] ?? '').toString().toLowerCase();
        return Scan.fromJson({
          'scan_id': row['id'] ?? row['scan_id'] ?? '',
          'mineral': row['mineral'] ?? row['predicted_mineral'] ?? '',
          'predicted_mineral': row['predicted_mineral'] ?? row['mineral'] ?? '',
          'confidence': row['confidence'] ?? 0.0,
          'site_id': row['site'] ?? row['location'] ?? '',
          'timestamp': row['timestamp'],
          'user_id': row['user_id'] ?? '',
          'verified': status == 'verified',
        });
      }).toList();
    }

    try {
      final queryParams = <String, String>{};
      if (userId != null) queryParams['user_id'] = userId;
      if (location != null) queryParams['location'] = location;

      final uri = Uri.parse('$baseUrl${AppConstants.scansEndpoint}')
          .replace(queryParameters: queryParams);

      final response = await http
          .get(
            uri,
            headers: _getHeaders(),
          )
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final scansList = data['scans'] ?? data['data'] ?? [];
        final scans =
            (scansList as List).map((scan) => Scan.fromJson(scan)).toList();
        if (scans.isNotEmpty) {
          return scans;
        }
      } else {
        // continue to fallback endpoint below
      }

      final fallbackParams = <String, String>{
        if (location != null) 'site': location,
        'limit': '200',
      };
      final fallbackUri = Uri.parse('$baseUrl/verifications')
          .replace(queryParameters: fallbackParams);

      final fallbackResponse = await http
          .get(
            fallbackUri,
            headers: _getHeaders(),
          )
          .timeout(AppConstants.apiTimeout);

      if (fallbackResponse.statusCode == 200) {
        final data = jsonDecode(fallbackResponse.body);
        final verifications = data['verifications'] ?? data['data'] ?? [];
        var scans = mapVerificationsToScans(verifications as List<dynamic>);
        if (userId != null && userId.isNotEmpty) {
          scans = scans.where((scan) => scan.userId == userId).toList();
        }
        return scans;
      }

      throw Exception(
        'Failed to get scans: ${response.statusCode} / ${fallbackResponse.statusCode}',
      );
    } catch (e) {
      throw Exception('Get scans error: $e');
    }
  }

  // Register a scan record on the server (useful when client generated a scan_id)
  Future<Scan> registerScan({
    required String scanId,
    required String mineral,
    required double confidence,
    String? location,
    required String userId,
    DateTime? timestamp,
    String? fingerprintId,
    Map<String, double>? chemicalUsed,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl${AppConstants.scansEndpoint}');
      final body = {
        'scan_id': scanId,
        'predicted_mineral': mineral,
        'confidence': confidence,
        if (location != null) 'site_id': location,
        'user_id': userId,
        'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
        if (fingerprintId != null) 'fingerprint_id': fingerprintId,
        if (chemicalUsed != null) 'chemical_used': chemicalUsed,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

      final response = await http
          .post(
            uri,
            headers: _getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Scan.fromJson(data);
      } else {
        throw Exception('Register scan failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Register scan error: $e');
    }
  }

  // Get metrics
  Future<Map<String, dynamic>> getMetrics() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl${AppConstants.metricsEndpoint}'),
            headers: _getHeaders(),
          )
          .timeout(AppConstants.apiTimeout);

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
      final response = await http
          .get(
            Uri.parse('$baseUrl${AppConstants.usersEndpoint}'),
            headers: _getHeaders(),
          )
          .timeout(AppConstants.apiTimeout);

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

  // Admin: Create user
  Future<Map<String, dynamic>> createUser({
    required String name,
    required String email,
    required String role,
    required String password,
    String? organization,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl${AppConstants.usersEndpoint}'),
      );

      if (_authToken != null) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }

      request.fields['name'] = name;
      request.fields['email'] = email;
      request.fields['role'] = role;
      request.fields['password'] = password;
      if (organization != null && organization.trim().isNotEmpty) {
        request.fields['organization'] = organization.trim();
      }

      final streamedResponse =
          await request.send().timeout(AppConstants.apiTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to create user');
      }
    } catch (e) {
      throw Exception('Create user error: $e');
    }
  }

  // Admin: Update user
  Future<Map<String, dynamic>> updateUser({
    required String userId,
    String? name,
    String? email,
    String? role,
    String? password,
  }) async {
    try {
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl${AppConstants.usersEndpoint}/$userId'),
      );

      if (_authToken != null) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }

      if (name != null && name.trim().isNotEmpty) {
        request.fields['name'] = name.trim();
      }
      if (email != null && email.trim().isNotEmpty) {
        request.fields['email'] = email.trim();
      }
      if (role != null && role.trim().isNotEmpty) {
        request.fields['role'] = role.trim();
      }
      if (password != null && password.isNotEmpty) {
        request.fields['password'] = password;
      }

      final streamedResponse =
          await request.send().timeout(AppConstants.apiTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to update user');
      }
    } catch (e) {
      throw Exception('Update user error: $e');
    }
  }

  // Admin: Delete user
  Future<Map<String, dynamic>> deleteUser(String userId) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl${AppConstants.usersEndpoint}/$userId'),
            headers: _getHeaders(),
          )
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to delete user');
      }
    } catch (e) {
      throw Exception('Delete user error: $e');
    }
  }

  // Extract and store fingerprint
  Future<Map<String, dynamic>> extractFingerprint({
    required String sampleId,
    required String site,
    required String mineral,
    required String userId,
    required String userName,
    File? imageFile,
    File? audioFile,
    Map<String, double>? chemicalUsed,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/fingerprint'),
      );

      // Required form fields
      request.fields['sample_id'] = sampleId;
      request.fields['site'] = site;
      request.fields['mineral'] = mineral;
      request.fields['user_id'] = userId;
      request.fields['user_name'] = userName;

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

      // Add chemical fields
      if (chemicalUsed != null) {
        request.fields['Au'] = (chemicalUsed['Au'] ?? 0.0).toString();
        request.fields['Cu'] = (chemicalUsed['Cu'] ?? 0.0).toString();
        request.fields['Fe'] = (chemicalUsed['Fe'] ?? 0.0).toString();
        request.fields['S'] = (chemicalUsed['S'] ?? 0.0).toString();
        request.fields['O'] = (chemicalUsed['O'] ?? 0.0).toString();
      }

      // Add GPS coordinates
      if (latitude != null) {
        request.fields['latitude'] = latitude.toString();
      }
      if (longitude != null) {
        request.fields['longitude'] = longitude.toString();
      }

      final streamedResponse =
          await request.send().timeout(AppConstants.scanTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 409) {
        String message =
            'Duplicate sample ID detected. Please use a new scan ID.';
        try {
          final error = jsonDecode(response.body);
          final detail = error['detail'];
          if (detail is String && detail.trim().isNotEmpty) {
            message = detail;
          }
        } catch (_) {}
        throw Exception('DuplicateSampleId: $message');
      } else {
        throw Exception('Fingerprint extraction failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Fingerprint extraction error: $e');
    }
  }

  // Health check
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/health'),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
