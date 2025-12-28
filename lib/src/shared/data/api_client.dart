import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/platform_info.dart';
import '../utils/global_error_handler.dart';

final apiClientProvider = Provider((ref) => ApiClient());

class ApiClient {
  late final String baseUrl;

  ApiClient() {
    var url = PlatformInfo.getDefaultApiBaseUrl();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    baseUrl = url;

    print('ApiClient: Initialized for ${PlatformInfo.platformName}');
    print('ApiClient: Using Base URL: $baseUrl');

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

  Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool shouldHandleError = true,
  }) async {
    try {
      print('ApiClient: POST $endpoint payload: $body');
      final uri = Uri.parse('$baseUrl$endpoint');
      print('ApiClient: Full URI: $uri');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      print('ApiClient: POST $endpoint response: ${response.statusCode}');
      return _handleResponse(response, shouldHandleError: shouldHandleError);
    } catch (e) {
      print('ApiClient: POST $endpoint failed: $e');
      rethrow;
    }
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
      final errorMessage = _getFriendlyErrorMessage(
        response.statusCode,
        responseBody,
      );
      GlobalErrorHandler.showError(errorMessage);
      throw Exception('API Error: ${response.statusCode} $responseBody');
    }
  }

  dynamic _handleResponse(
    http.Response response, {
    bool shouldHandleError = true,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body);
      // Check for standard success response format
      if (body is Map<String, dynamic> && body['status'] == 'success') {
        return body['data'];
      }
      return body;
    } else {
      final errorMessage = _getFriendlyErrorMessage(
        response.statusCode,
        response.body,
      );
      if (shouldHandleError) {
        GlobalErrorHandler.showError(errorMessage);
        throw Exception('API Error: ${response.statusCode} ${response.body}');
      } else {
        throw Exception(errorMessage);
      }
    }
  }

  String _getFriendlyErrorMessage(int statusCode, String responseBody) {
    try {
      final json = jsonDecode(responseBody);
      if (json is Map<String, dynamic>) {
        // Standard ApiError format
        if (json['status'] == 'error' && json.containsKey('message')) {
          // If validation errors exist, maybe append them?
          if (json['errors'] != null) {
            return "${json['message']} (${json['errors']})";
          }
          return json['message'].toString();
        }
        // Legacy formats
        if (json.containsKey('detail')) {
          return json['detail'].toString();
        }
        if (json.containsKey('message')) {
          return json['message'].toString();
        }
      }
    } catch (e) {
      // Not JSON
    }

    if (statusCode == 401) return 'Invalid credentials. Please try again.';
    if (statusCode == 403)
      return 'You do not have permission to perform this action.';
    if (statusCode == 404) return 'Resource not found.';
    if (statusCode >= 500) return 'Server error. Please try again later.';

    return 'Something went wrong ($statusCode)';
  }
}
