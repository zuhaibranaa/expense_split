import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/group_model.dart';
import '../../people/domain/member_model.dart';
import '../../../shared/data/api_client.dart';
import '../../auth/data/auth_repository.dart';

class GroupsRepository {
  final ApiClient _api;

  GroupsRepository(this._api);

  Future<void> createGroup(
    String name,
    String currency,
    int creatorUserId,
  ) async {
    await _api.post('/groups/', {
      'name': name,
      'currency': currency,
      'creator_user_id': creatorUserId,
    });
    // Optimistic update or refresh handled by Stream/Future provider usually
    // For now, we rely on refetching.
  }

  Future<List<Group>> getGroups(int? userId) async {
    final List<dynamic> json = await _api.get(
      '/groups/${userId != null ? "?user_id=$userId" : ""}',
    );
    return json.map((e) => Group.fromJson(e)).toList();
  }

  Future<void> updateGroup(
    int groupId,
    int userId, {
    String? name,
    String? currency,
  }) async {
    await _api.put('/groups/$groupId?user_id=$userId', {
      if (name != null) 'name': name,
      if (currency != null) 'currency': currency,
    });
  }

  Future<void> deleteGroup(int groupId, int userId) async {
    await _api.delete('/groups/$groupId?user_id=$userId');
  }

  Future<String> generateInvite(int groupId, int memberId, int userId) async {
    final response = await _api.post(
      '/groups/$groupId/members/$memberId/invite?user_id=$userId',
      {},
    );
    return response['token'];
  }

  Future<Map<String, dynamic>> claimInvite(String token, int userId) async {
    final response = await _api.post('/invites/claim?user_id=$userId', {
      'token': token,
    });
    return response;
  }

  Future<List<Member>> getMembers(int groupId) async {
    final List<dynamic> json = await _api.get('/groups/$groupId/members/');
    return json.map((e) => Member.fromJson(e)).toList();
  }
}

// Re-using the same provider name, but changing type to FutureProvider for simplicity with HTTP,
// or StreamProvider if we poll/socket. Let's start with FutureProvider/polling.
// Actually, UI expects Stream, so we can yield results periodically or just Stream.fromFuture.
final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return GroupsRepository(api);
});

final groupsListFutureProvider = FutureProvider.autoDispose<List<Group>>((
  ref,
) async {
  final repo = ref.watch(groupsRepositoryProvider);
  final user = ref.watch(authControllerProvider).value;

  if (user == null) {
    return [];
  }

  return await repo.getGroups(user.id);
});

final groupMembersProvider = FutureProvider.family<List<Member>, int>((
  ref,
  groupId,
) async {
  final repo = ref.watch(groupsRepositoryProvider);
  return repo.getMembers(groupId);
});
