import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/data/api_client.dart';
import '../domain/user_model.dart';
import 'package:currency_picker/currency_picker.dart';

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
      'default_currency': 'USD'
    });
    _currentUser = User.fromJson(json);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserIdKey, _currentUser!.id.toString());
  }

  Future<void> updateProfile({required String currency}) async {
    if (_currentUser == null) return;
    
    final json = await _api.put('/me/${_currentUser!.id}', {
      'name': _currentUser!.name,
      'email': _currentUser!.email, // Read only technically
      'avatar_url': _currentUser!.avatarUrl,
      'default_currency': currency
    });
    _currentUser = User.fromJson(json);
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

  Future<void> updateCurrency(String currencyCode) async {
     final repo = ref.read(authRepositoryProvider);
     state = const AsyncValue.loading();
     state = await AsyncValue.guard(() async {
       await repo.updateProfile(currency: currencyCode);
       return repo.currentUser;
     });
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = const AsyncValue.data(null);
  }
}

final authControllerProvider = AsyncNotifierProvider.autoDispose<AuthController, User?>(() {
  return AuthController();
});
