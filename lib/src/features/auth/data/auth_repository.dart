import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cross_file/cross_file.dart';
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
    final userJsonString = prefs.getString('user_session'); // Changed key
    if (userJsonString != null) {
      try {
        final json = jsonDecode(userJsonString);
        _currentUser = User.fromJson(json);
        // Optionally, re-fetch user data to ensure it's up-to-date
        // final updatedUserJson = await _api.get('/users/me/${_currentUser!.id}');
        // _currentUser = User.fromJson(updatedUserJson);
        return _currentUser;
      } catch (e) {
        // Session invalid or parsing error
        await logout();
        return null;
      }
    }
    return null;
  }

  Future<bool> checkEmail(String email) async {
    try {
      final response = await _api.post('/auth/check-email', {'email': email});
      // final response = await _api.get('/');
      debugPrint('Check email response: $response');
      return response['exists'] as bool;
    } catch (e) {
      // If error, assume false or rethrow. For now rethrow to handle in UI
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    final response = await _api.post('/auth/login', {
      'email': email,
      'password': password,
    }, shouldHandleError: false);
    _currentUser = User.fromJson(response);
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
      'name': name,
      'currency': currency,
    });
    _currentUser = User.fromJson(response);
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

    final response = await _api.put('/me/${_currentUser!.id}', {
      'email': _currentUser!.email, // Required by backend schema
      'name': name ?? _currentUser!.name,
      'avatar_url': avatarUrl ?? _currentUser!.avatarUrl,
      'default_currency': currency ?? _currentUser!.defaultCurrency,
      'phone': phone ?? _currentUser!.phone,
      'iban': iban ?? _currentUser!.iban,
    });

    _currentUser = User.fromJson(response);
    await _saveSession(_currentUser!);
  }

  Future<String> uploadAvatar(XFile file) async {
    dynamic response;
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      response = await _api.postMultipart(
        '/upload/image',
        'file',
        fileBytes: bytes,
        filename: file.name,
      );
    } else {
      response = await _api.postMultipart(
        '/upload/image',
        'file',
        filePath: file.path,
      );
    }
    return response['url'];
  }

  Future<void> requestVerification() async {
    if (_currentUser == null) return;
    if (_currentUser!.isVerified) return;

    await _api.post('/auth/verify-request?email=${_currentUser!.email}', {});
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserIdKey);
    await prefs.remove('user_session'); // Also remove the user session
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
    state = const AsyncValue.loading();
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
    state = const AsyncValue.loading();
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
