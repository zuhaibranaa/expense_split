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

final membersFutureProvider = FutureProvider.autoDispose
    .family<List<Member>, int>((ref, groupId) async {
      final repo = ref.watch(membersRepositoryProvider);
      return await repo.getMembers(groupId);
    });
