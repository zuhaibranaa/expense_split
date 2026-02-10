import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import '../../../shared/data/api_client.dart';
import '../domain/user_model.dart';

import '../../../shared/services/notification_service.dart';

// Use SharedPreferences instead of FlutterSecureStorage for web compatibility
// FlutterSecureStorage has Platform issues on web
const _kUserIdKey = 'user_id';

class AuthRepository {
  final ApiClient _api;
  final NotificationService _notificationService;
  User? _currentUser;

  AuthRepository(this._api, this._notificationService);

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
        // Update FCM Token on restore
        _updateFcmToken();
        return _currentUser;
      } catch (e) {
        // Session invalid
        await logout();
        return null;
      }
    }
    return null;
  }

  Future<void> _updateFcmToken() async {
    try {
      final token = await _notificationService.getFcmToken();
      if (token != null) {
        String deviceType = 'android';
        if (kIsWeb) {
          deviceType = 'web';
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          deviceType = 'ios';
        }

        await _api.post('/fcm-token', {
          'fcm_token': token,
          'device_type': deviceType,
        }, shouldHandleError: false);
      }
    } catch (e) {
      debugPrint('Failed to update FCM token: $e');
    }
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
    await _updateFcmToken();
  }

  Future<void> register(
    String email,
    String password,
    String confirmPassword,
    String name,
    String currency,
  ) async {
    final response = await _api.post('/auth/register', {
      'email': email,
      'password': password,
      'password_confirmation': confirmPassword,
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
    await _updateFcmToken();
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
    String? password,
    String? passwordConfirmation,
    bool shouldHandleError = true,
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
      if (password != null) 'password': password,
      if (passwordConfirmation != null)
        'password_confirmation': passwordConfirmation,
    }, shouldHandleError: shouldHandleError);

    // If response is the user object directly (data['user'] or just data=user)
    // The previous code expected response to be the user json.
    // If the API returns {status: true, data: {user: ...}} for update, we need to handle that.
    // Or if it returns {status: true, data: <UserObject>}.
    // For now assuming it returns the updated user object in 'data'.

    _currentUser = User.fromJson(response);
    await _saveSession(_currentUser!);
  }

  Future<User?> refreshUser() async {
    try {
      final response = await _api.get('/auth/me');
      _currentUser = User.fromJson(response);
      await _saveSession(_currentUser!);
      return _currentUser;
    } catch (e) {
      rethrow;
    }
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

  Future<void> forgotPassword(String email) async {
    await _api.post('/auth/forgot-password', {
      'email': email,
    }, shouldHandleError: false);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(notificationServiceProvider),
  );
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
    String confirmPassword,
    String name,
    String currency,
  ) async {
    final repo = ref.read(authRepositoryProvider);
    // Do not set global loading state here to prevent UI reset
    await repo.register(email, password, confirmPassword, name, currency);
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
    String? password,
    String? passwordConfirmation,
    bool shouldHandleError = true,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    // Don't set loading state to prevent AuthGate from rebuilding entire app
    try {
      await repo.updateProfile(
        name: name,
        avatarUrl: avatarUrl,
        currency: currency,
        phone: phone,
        iban: iban,
        password: password,
        passwordConfirmation: passwordConfirmation,
        shouldHandleError: shouldHandleError,
      );
      state = AsyncValue.data(repo.currentUser);
    } catch (e) {
      // Do NOT set state = AsyncValue.error(e) here.
      // Doing so triggers AuthGate to show LoginScreen because global state becomes error.
      // We just rethrow so the UI (dialog) handles the specific validation error.
      rethrow;
    }
  }

  Future<void> reloadUser() async {
    final repo = ref.read(authRepositoryProvider);
    // Use try-catch instead of AsyncValue.guard to prevent setting state to error
    // which would cause AuthGate to redirect to LoginScreen
    try {
      final user = await repo.refreshUser();
      if (user != null) {
        state = AsyncValue.data(user);
      }
    } catch (e) {
      debugPrint('Failed to reload user: $e');
      // Do not update state to error, keep previous state (data)
    }
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

  Future<void> forgotPassword(String email) async {
    final repo = ref.read(authRepositoryProvider);
    // Don't set global loading state to prevent UI reset or navigation issues
    // Just await and let the UI handle success/error feedback
    await repo.forgotPassword(email);
  }
}
