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
      '/members/$memberId/invite?user_id=$userId',
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

  Future<List<Member>> getMembers(
    int groupId, {
    bool includeDeleted = false,
  }) async {
    final query = includeDeleted ? '?include_deleted=true' : '';
    final List<dynamic> json = await _api.get(
      '/groups/$groupId/members/$query',
    );
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

final groupsListProvider =
    AsyncNotifierProvider.autoDispose<GroupsNotifier, List<Group>>(
      GroupsNotifier.new,
    );

class GroupsNotifier extends AutoDisposeAsyncNotifier<List<Group>> {
  @override
  Future<List<Group>> build() async {
    final repo = ref.watch(groupsRepositoryProvider);
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return [];
    return repo.getGroups(user.id);
  }

  Future<void> addGroup(String name, String currency) async {
    final user = ref.read(authControllerProvider).value;
    if (user == null) return;
    final repo = ref.read(groupsRepositoryProvider);

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repo.createGroup(name, currency, user.id);
      return repo.getGroups(user.id); // Refetch to get ID and server fields
    });
  }

  Future<void> updateGroup(
    int groupId, {
    String? name,
    String? currency,
  }) async {
    final user = ref.read(authControllerProvider).value;
    if (user == null) return;
    final repo = ref.read(groupsRepositoryProvider);

    // Optimistic Update
    final previousState = state;
    if (previousState.value != null) {
      state = AsyncValue.data(
        previousState.value!.map((g) {
          if (g.id == groupId) {
            return Group(
              id: g.id,
              name: name ?? g.name,
              currency: currency ?? g.currency,
              createdAt: g.createdAt,
              // creatorUserId: g.creatorUserId, // Removed as it's not in model or needed for optimistic
            );
          }
          return g;
        }).toList(),
      );
    }

    try {
      await repo.updateGroup(groupId, user.id, name: name, currency: currency);
    } catch (e) {
      // Revert on failure
      state = previousState;
      rethrow;
    }
  }

  Future<void> deleteGroup(int groupId) async {
    final user = ref.read(authControllerProvider).value;
    if (user == null) return;
    final repo = ref.read(groupsRepositoryProvider);

    // Optimistic Update
    final previousState = state;
    if (previousState.value != null) {
      state = AsyncValue.data(
        previousState.value!.where((g) => g.id != groupId).toList(),
      );
    }

    try {
      await repo.deleteGroup(groupId, user.id);
    } catch (e) {
      state = previousState;
      rethrow;
    }
  }
}

final groupMembersProvider = FutureProvider.family<List<Member>, int>((
  ref,
  groupId,
) async {
  final repo = ref.watch(groupsRepositoryProvider);
  return repo.getMembers(groupId);
});

final allMembersFutureProvider = FutureProvider.family<List<Member>, int>((
  ref,
  groupId,
) async {
  final repo = ref.watch(groupsRepositoryProvider);
  return repo.getMembers(groupId, includeDeleted: true);
});
