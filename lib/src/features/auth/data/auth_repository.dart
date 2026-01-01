import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import '../../../shared/data/api_client.dart';
import '../domain/user_model.dart';

// Use SharedPreferences instead of FlutterSecureStorage for web compatibility
// FlutterSecureStorage has Platform issues on web
const _kUserIdKey = 'user_id';

class AuthRepository {
  final ApiClient _api;
  User? _currentUser;

  AuthRepository(this._api);

  User? get currentUser => _currentUser;

  Future<User?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();

    // Restore token first
    final token = prefs.getString('auth_token');
    if (token != null) {
      _api.setToken(token);
    }

    final userJsonString = prefs.getString('user_session');
    if (userJsonString != null) {
      try {
        final json = jsonDecode(userJsonString);
        _currentUser = User.fromJson(json);
        // Optionally verify token validity or refresh user
        return _currentUser;
      } catch (e) {
        // Session invalid
        await logout();
        return null;
      }
    }
    return null;
  }

  Future<bool> checkEmail(String email) async {
    try {
      final response = await _api.post('/auth/check-email', {'email': email});
      return response['exists'] as bool;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    final response = await _api.post('/auth/login', {
      'email': email,
      'password': password,
    }, shouldHandleError: false);

    final token = response['access_token'];
    final userMap = response['user'];

    if (token != null) {
      _api.setToken(token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
    }

    _currentUser = User.fromJson(userMap);
    await _saveSession(_currentUser!);
  }

  Future<void> register(
    String email,
    String password,
    String name,
    String currency,
  ) async {
    final response = await _api.post('/auth/register', {
      'email': email,
      'password': password,
      'password_confirmation': password,
      'name': name,
      'currency': currency,
    });

    // response is body['data'] => {access_token: ..., user: ...}
    final token = response['access_token'];
    final userMap =
        response['user']; // Assuming register returns same structure

    if (token != null) {
      _api.setToken(token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
    }

    _currentUser = User.fromJson(userMap);
    await _saveSession(_currentUser!);
  }

  Future<void> _saveSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_session', jsonEncode(user.toJson()));
  }

  Future<void> updateProfile({
    String? name,
    String? avatarUrl,
    String? currency,
    String? phone,
    String? iban,
  }) async {
    if (_currentUser == null) return;

    final response = await _api.put('/auth/me', {
      // Changed from /me/{id} to /auth/me or similar if standard, but usually it's implied
      // Actually user didn't specify update endpoint change, but generally with token it's /me or /user
      // Keeping original logic but mindful that response might be unwrapped
      'email': _currentUser!.email,
      'name': name ?? _currentUser!.name,
      'avatar_url': avatarUrl ?? _currentUser!.avatarUrl,
      'default_currency': currency ?? _currentUser!.defaultCurrency,
      'phone': phone ?? _currentUser!.phone,
      'iban': iban ?? _currentUser!.iban,
    });

    // If response is the user object directly (data['user'] or just data=user)
    // The previous code expected response to be the user json.
    // If the API returns {status: true, data: {user: ...}} for update, we need to handle that.
    // Or if it returns {status: true, data: <UserObject>}.
    // For now assuming it returns the updated user object in 'data'.

    _currentUser = User.fromJson(response);
    await _saveSession(_currentUser!);
  }

  Future<String> uploadAvatar(XFile file) async {
    dynamic response;
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      response = await _api.postMultipart(
        '/upload',
        'file',
        fileBytes: bytes,
        filename: file.name,
      );
    } else {
      response = await _api.postMultipart(
        '/upload',
        'file',
        filePath: file.path,
      );
    }
    debugPrint('Upload Response: $response');

    if (response is Map<String, dynamic>) {
      // Check for status
      final status = response['status'];
      if (status == true || status == 'success') {
        final data = response['data'];
        if (data is Map<String, dynamic> && data.containsKey('url')) {
          return data['url'];
        }
      }

      // If failure or missing data, look for message
      if (response.containsKey('message')) {
        throw Exception(response['message']);
      }
    }

    throw Exception('Failed to upload avatar: Unexpected response format');
  }

  Future<void> requestVerification() async {
    if (_currentUser == null) return;
    if (_currentUser!.isVerified) return;

    await _api.post('/auth/verify-request', {'email': _currentUser!.email});
    // Removed query param style if we are posting body now, but kept both or cleaned up.
    // Previous was: /auth/verify-request?email=...
  }

  Future<void> logout() async {
    _currentUser = null;
    _api.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserIdKey);
    await prefs.remove('user_session');
    await prefs.remove('auth_token');

    try {
      // Optional: Call logout endpoint if exists
      await _api.post('/auth/logout', {});
    } catch (e) {
      // ignore
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<User?>>((ref) {
      return AuthController(ref);
    });

class AuthController extends StateNotifier<AsyncValue<User?>> {
  final Ref ref;
  AuthController(this.ref) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    final repo = ref.read(authRepositoryProvider);
    final user = await repo.restoreSession();
    state = AsyncValue.data(user);
  }

  Future<void> login(String email, String password) async {
    final repo = ref.read(authRepositoryProvider);
    // Do not set global loading state here to prevent UI reset
    await repo.login(email, password);
    state = AsyncValue.data(repo.currentUser);
  }

  Future<void> register(
    String email,
    String password,
    String name,
    String currency,
  ) async {
    final repo = ref.read(authRepositoryProvider);
    // Do not set global loading state here to prevent UI reset
    await repo.register(email, password, name, currency);
    state = AsyncValue.data(repo.currentUser);
  }

  Future<bool> checkEmail(String email) async {
    final repo = ref.read(authRepositoryProvider);
    return await repo.checkEmail(email);
  }

  Future<void> updateProfile({
    String? name,
    String? avatarUrl,
    String? currency,
    String? phone,
    String? iban,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    // Don't set loading state to prevent AuthGate from rebuilding entire app
    state = await AsyncValue.guard(() async {
      await repo.updateProfile(
        name: name,
        avatarUrl: avatarUrl,
        currency: currency,
        phone: phone,
        iban: iban,
      );
      return repo.currentUser;
    });
  }

  Future<void> requestVerification() async {
    final repo = ref.read(authRepositoryProvider);
    // don't set global loading state for this, just fire and forget or handle error locally if needed
    // but for now let's just await
    await repo.requestVerification();
  }

  Future<void> uploadAvatar(XFile file) async {
    final repo = ref.read(authRepositoryProvider);
    state = await AsyncValue.guard(() async {
      final url = await repo.uploadAvatar(file);
      await repo.updateProfile(avatarUrl: url); // Update profile with new URL
      return repo.currentUser;
    });
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = const AsyncValue.data(null);
  }
}
