import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/member_model.dart';
import '../../../shared/data/api_client.dart';

class MembersRepository {
  final ApiClient _api;

  MembersRepository(this._api);

  Future<void> addMember(int groupId, String name) async {
    await _api.post('/groups/$groupId/members/', {'name': name});
  }

  Future<List<Member>> getMembers(int groupId) async {
    final List<dynamic> json = await _api.get('/groups/$groupId/members/');
    return json.map((e) => Member.fromJson(e)).toList();
  }

  Future<void> updateMember(
    int groupId,
    int memberId,
    int userId, {
    String? name,
  }) async {
    await _api.put('/groups/$groupId/members/$memberId?user_id=$userId', {
      if (name != null) 'name': name,
    });
  }

  Future<void> removeMember(int groupId, int memberId, int userId) async {
    await _api.delete('/groups/$groupId/members/$memberId?user_id=$userId');
  }
}

final membersRepositoryProvider = Provider<MembersRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return MembersRepository(api);
});

final membersFutureProvider = AsyncNotifierProvider.autoDispose
    .family<MembersNotifier, List<Member>, int>(MembersNotifier.new);

class MembersNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<Member>, int> {
  @override
  Future<List<Member>> build(int arg) async {
    final repo = ref.read(membersRepositoryProvider);
    return repo.getMembers(arg); // arg is groupId
  }

  Future<void> addMember(String name) async {
    final repo = ref.read(membersRepositoryProvider);
    // Optimistic or Refetch? Simple refetch is safer for list additions usually
    // But we can optimistic add if we have an ID? We don't have ID from server without response.
    // So we'll trigger Loading state then refetch.

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repo.addMember(arg, name);
      return repo.getMembers(arg);
    });
  }

  Future<void> updateMember(int memberId, int userId, {String? name}) async {
    final repo = ref.read(membersRepositoryProvider);
    final previousState = state;

    // Optimistic Update
    if (previousState.value != null) {
      state = AsyncValue.data(
        previousState.value!.map((m) {
          if (m.id == memberId) {
            return Member(
              id: m.id,
              groupId: m.groupId,
              name: name ?? m.name,
              userId: m.userId,
              isAdmin: m.isAdmin,
              avatarUrl: m.avatarUrl,
              email: m.email,
              phone: m.phone,
              iban: m.iban,
            );
          }
          return m;
        }).toList(),
      );
    }

    try {
      await repo.updateMember(arg, memberId, userId, name: name);
    } catch (e) {
      state = previousState;
      rethrow;
    }
  }

  Future<void> removeMember(int memberId, int userId) async {
    final repo = ref.read(membersRepositoryProvider);
    final previousState = state;

    // Optimistic Update
    if (previousState.value != null) {
      state = AsyncValue.data(
        previousState.value!.where((m) => m.id != memberId).toList(),
      );
    }

    try {
      await repo.removeMember(arg, memberId, userId);
    } catch (e) {
      state = previousState;
      rethrow;
    }
  }
}
