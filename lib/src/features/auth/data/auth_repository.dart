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
    final uid = prefs.getString(_kUserIdKey);
    if (uid != null) {
      try {
        final json = await _api.get('/me/$uid');
        _currentUser = User.fromJson(json);
        return _currentUser;
      } catch (e) {
        // Session invalid
        await logout();
        return null;
      }
    }
    return null;
  }

  Future<void> loginMock(String email, String name) async {
    final json = await _api.post('/auth/login', {
      'email': email,
      'name': name,
      'avatar_url': 'https://ui-avatars.com/api/?name=$name&background=random',
      'default_currency': 'USD',
    });
    _currentUser = User.fromJson(json);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserIdKey, _currentUser!.id.toString());
  }

  Future<void> updateProfile({
    String? name,
    String? avatarUrl,
    String? currency,
    String? phone,
  }) async {
    if (_currentUser == null) return;

    final json = await _api.put('/me/${_currentUser!.id}', {
      'name': name ?? _currentUser!.name,
      'email': _currentUser!.email,
      'avatar_url': avatarUrl ?? _currentUser!.avatarUrl,
      'default_currency': currency ?? _currentUser!.defaultCurrency,
      'phone': phone ?? _currentUser!.phone,
    });
    _currentUser = User.fromJson(json);
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
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return AuthRepository(api);
});

// AsyncNotifier to handle Auth State changes reactively
class AuthController extends AutoDisposeAsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    // Initial load
    final repo = ref.watch(authRepositoryProvider);
    return repo.restoreSession();
  }

  Future<void> login(String email, String name) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      await repo.loginMock(email, name);
      return repo.currentUser;
    });
  }

  Future<void> updateProfile({
    String? name,
    String? avatarUrl,
    String? currency,
    String? phone,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repo.updateProfile(
        name: name,
        avatarUrl: avatarUrl,
        currency: currency,
        phone: phone,
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

final authControllerProvider =
    AsyncNotifierProvider.autoDispose<AuthController, User?>(() {
      return AuthController();
    });
