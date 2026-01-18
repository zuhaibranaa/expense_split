import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/environment.dart';
import '../utils/platform_info.dart';
import '../utils/global_error_handler.dart';

final apiClientProvider = Provider((ref) => ApiClient());

class ApiClient {
  late final String baseUrl;

  ApiClient() {
    var url = Environment.apiBaseUrl;
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    baseUrl = url;

    if (kDebugMode) {
      print(
        'ApiClient initialized for ${PlatformInfo.platformName} with baseUrl: $baseUrl',
      );
    }
  }

  String? _authToken;

  void setToken(String token) {
    _authToken = token;
  }

  void clearToken() {
    _authToken = null;
  }

  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  Future<dynamic> get(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: _getHeaders(),
    );
    return _handleResponse(response);
  }

  Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool shouldHandleError = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http.post(
        uri,
        headers: _getHeaders(),
        body: jsonEncode(body),
      );
      return _handleResponse(response, shouldHandleError: shouldHandleError);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool shouldHandleError = true,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: _getHeaders(),
      body: jsonEncode(body),
    );
    return _handleResponse(response, shouldHandleError: shouldHandleError);
  }

  Future<dynamic> delete(String endpoint) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: _getHeaders(),
    );
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

    // Add auth header to multipart request
    if (_authToken != null) {
      request.headers['Authorization'] = 'Bearer $_authToken';
    }

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
      // Check for standard success response format {status: true, ...}
      if (body is Map<String, dynamic>) {
        // The user stated: {status: true, message: Success, data: {...}}
        if (body['status'] == true) {
          return body['data'];
        }
        // Fallback if status is string "success" or just missing
        if (body['status'] == 'success') {
          return body['data'];
        }
      }
      return body;
    } else {
      final errorMessage = _getFriendlyErrorMessage(
        response.statusCode,
        response.body,
      );
      if (shouldHandleError) {
        GlobalErrorHandler.showError(errorMessage);
        throw Exception(errorMessage);
      } else {
        throw Exception(errorMessage);
      }
    }
  }

  String _getFriendlyErrorMessage(int statusCode, String responseBody) {
    try {
      final json = jsonDecode(responseBody);
      if (json is Map<String, dynamic>) {
        if (json.containsKey('message')) {
          // If 'errors' field exists (Laravel validation errors likely), append it
          if (json['errors'] != null && json['errors'] is Map) {
            final errors = json['errors'] as Map<String, dynamic>;
            final message = json['message'].toString();
            final buffer = StringBuffer();
            buffer.writeln(message);

            errors.forEach((key, value) {
              if (value is List) {
                for (var jsVal in value) {
                  final errStr = jsVal.toString();
                  if (errStr != message) {
                    buffer.writeln('• $errStr');
                  }
                }
              } else {
                final errStr = value.toString();
                if (errStr != message) {
                  buffer.writeln('• $errStr');
                }
              }
            });
            return buffer.toString().trim();
          }
          return json['message'].toString();
        }
        // Legacy/Other formats
        if (json['status'] == false && json.containsKey('error')) {
          return json['error'].toString();
        }
      }
    } catch (e) {
      // Not JSON
    }

    if (statusCode == 401) return 'Invalid credentials. Please try again.';
    if (statusCode == 403) {
      return 'You do not have permission to perform this action.';
    }
    if (statusCode == 404) return 'Resource not found.';
    if (statusCode >= 500) return 'Server error. Please try again later.';

    return 'Something went wrong ($statusCode)';
  }
}
