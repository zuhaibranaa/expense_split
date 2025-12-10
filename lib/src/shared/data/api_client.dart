import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/platform_info.dart';

final apiClientProvider = Provider((ref) => ApiClient());

class ApiClient {
  late final String baseUrl;

  ApiClient() {
    // Automatically detect platform and use appropriate base URL
    // Web & Desktop: http://localhost:8000
    // Android emulator: http://10.0.2.2:8000
    // iOS simulator: http://localhost:8000
    baseUrl = PlatformInfo.getDefaultApiBaseUrl();

    if (kDebugMode) {
      print(
        'ApiClient initialized for ${PlatformInfo.platformName} with baseUrl: $baseUrl',
      );
    }
  }

  Future<dynamic> get(String endpoint) async {
    final response = await http.get(Uri.parse('$baseUrl$endpoint'));
    return _handleResponse(response);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<dynamic> delete(String endpoint) async {
    final response = await http.delete(Uri.parse('$baseUrl$endpoint'));
    return _handleResponse(response);
  }

  Future<dynamic> postMultipart(
    String endpoint,
    String fieldName, {
    String? filePath,
    Uint8List? fileBytes,
    String? filename,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl$endpoint'),
    );

    if (fileBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          fileBytes,
          filename: filename ?? 'upload.jpg',
        ),
      );
    } else if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
    } else {
      throw Exception('Either filePath or fileBytes must be provided');
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(responseBody);
    } else {
      throw Exception('API Error: ${response.statusCode} $responseBody');
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw Exception('API Error: ${response.statusCode} ${response.body}');
    }
  }
}
