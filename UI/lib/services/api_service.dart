import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/login'),
      body: {
        'email': email,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Login failed');
    }
  }

  Future<Map<String, dynamic>> predictSample({
    PlatformFile? image,
    PlatformFile? audio,
    required double au,
    required double cu,
    required double fe,
    required double s,
    required double o,
  }) async {
    // At least one modality must be provided
    if (image == null && audio == null) {
      throw ArgumentError('At least image or audio must be provided');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/predict'),
    );

    if (image != null) {
      request.files.add(await _multipartFileFromPlatformFile('image', image));
    }
    if (audio != null) {
      request.files.add(await _multipartFileFromPlatformFile('audio', audio));
    }
    request.fields.addAll(_chemicalFields(au: au, cu: cu, fe: fe, s: s, o: o));

    final response = await _client.send(request);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> generateFingerprint({
    PlatformFile? image,
    PlatformFile? audio,
    required double au,
    required double cu,
    required double fe,
    required double s,
    required double o,
    required String sampleId,
    required String site,
    required String mineral,
    required String userId,
    required String userName,
  }) async {
    // At least one modality must be provided
    if (image == null && audio == null) {
      throw ArgumentError('At least image or audio must be provided');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/fingerprint'),
    );

    if (image != null) {
      request.files.add(await _multipartFileFromPlatformFile('image', image));
    }
    if (audio != null) {
      request.files.add(await _multipartFileFromPlatformFile('audio', audio));
    }
    request.fields.addAll(_chemicalFields(au: au, cu: cu, fe: fe, s: s, o: o));
    request.fields['sample_id'] = sampleId;
    request.fields['site'] = site;
    request.fields['mineral'] = mineral;
    request.fields['user_id'] = userId;
    request.fields['user_name'] = userName;

    final response = await _client.send(request);
    return _decodeResponse(response);
  }

  // GET methods for web dashboard

  Future<Map<String, dynamic>> getFingerprints({
    String? site,
    String? mineral,
    int? limit,
  }) async {
    final queryParams = <String, String>{};
    if (site != null) queryParams['site'] = site;
    if (mineral != null) queryParams['mineral'] = mineral;
    if (limit != null) queryParams['limit'] = limit.toString();

    final uri = Uri.parse('$baseUrl/fingerprints').replace(
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );

    final response = await _client.get(uri);
    return _decodeRegularResponse(response);
  }

  Future<Map<String, dynamic>> getVerifications({
    String? site,
    int? limit,
  }) async {
    final queryParams = <String, String>{};
    if (site != null) queryParams['site'] = site;
    if (limit != null) queryParams['limit'] = limit.toString();

    final uri = Uri.parse('$baseUrl/verifications').replace(
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );

    final response = await _client.get(uri);
    return _decodeRegularResponse(response);
  }

  Future<Map<String, dynamic>> getStats() async {
    final uri = Uri.parse('$baseUrl/stats');
    final response = await _client.get(uri);
    return _decodeRegularResponse(response);
  }

  Future<Map<String, dynamic>> getMetrics() async {
    final uri = Uri.parse('$baseUrl/metrics');
    final response = await _client.get(uri);
    return _decodeRegularResponse(response);
  }

  Future<Map<String, dynamic>> getHealth() async {
    final uri = Uri.parse('$baseUrl/health');
    final response = await _client.get(uri);
    return _decodeRegularResponse(response);
  }

  // User management methods

  Future<Map<String, dynamic>> getUsers({String? role}) async {
    final queryParams = <String, String>{};
    if (role != null) queryParams['role'] = role;

    final uri = Uri.parse('$baseUrl/users').replace(
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );

    final response = await _client.get(uri);
    return _decodeRegularResponse(response);
  }

  Future<Map<String, dynamic>> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/users'),
    );

    request.fields['name'] = name;
    request.fields['email'] = email;
    request.fields['password'] = password;
    request.fields['role'] = role;

    final response = await _client.send(request);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> updateUser({
    required String userId,
    String? name,
    String? email,
    String? role,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('$baseUrl/users/$userId'),
    );

    if (name != null) request.fields['name'] = name;
    if (email != null) request.fields['email'] = email;
    if (role != null) request.fields['role'] = role;

    final response = await _client.send(request);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> deleteUser(String userId) async {
    final uri = Uri.parse('$baseUrl/users/$userId');
    final response = await _client.delete(uri);
    return _decodeRegularResponse(response);
  }

  Future<Map<String, dynamic>> updateProfile({
    required String userId,
    String? name,
    String? email,
    String? currentPassword,
    String? newPassword,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('$baseUrl/profile/$userId'),
    );

    if (name != null) request.fields['name'] = name;
    if (email != null) request.fields['email'] = email;
    if (currentPassword != null) request.fields['current_password'] = currentPassword;
    if (newPassword != null) request.fields['new_password'] = newPassword;

    final response = await _client.send(request);
    return _decodeResponse(response);
  }

  Future<http.MultipartFile> _multipartFileFromPlatformFile(
    String fieldName,
    PlatformFile file,
  ) async {
    if (file.bytes != null) {
      return http.MultipartFile.fromBytes(
        fieldName,
        file.bytes!,
        filename: file.name,
      );
    }

    if (file.path == null || file.path!.isEmpty) {
      throw StateError('Missing file data for $fieldName.');
    }

    return http.MultipartFile.fromPath(
      fieldName,
      file.path!,
      filename: file.name,
    );
  }

  Map<String, String> _chemicalFields({
    required double au,
    required double cu,
    required double fe,
    required double s,
    required double o,
  }) {
    return {
      'Au': au.toString(),
      'Cu': cu.toString(),
      'Fe': fe.toString(),
      'S': s.toString(),
      'O': o.toString(),
    };
  }

  Future<Map<String, dynamic>> _decodeResponse(
    http.StreamedResponse response,
  ) async {
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Request failed: ${response.statusCode} ${response.reasonPhrase}. Body: $body',
        response.request?.url,
      );
    }

    if (body.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {'data': decoded};
  }

  Future<Map<String, dynamic>> _decodeRegularResponse(
    http.Response response,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Request failed: ${response.statusCode} ${response.reasonPhrase}. Body: ${response.body}',
        response.request?.url,
      );
    }

    if (response.body.isEmpty) {
      return Future.value(<String, dynamic>{});
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return Future.value(decoded);
    }

    return Future.value({'data': decoded});
  }
}
