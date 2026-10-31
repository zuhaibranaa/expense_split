import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_refs.dart';
import '../domain/member_model.dart';

class MembersRepository {
  MembersRepository(this._refs, this._functions);

  final FirestoreRefs _refs;
  final FirebaseFunctions _functions;

  Future<void> addMember(String groupId, String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('Member name cannot be empty.');
    }
    await _refs.members(groupId).add({
      'name': cleanName,
      'uid': null,
      'isAdmin': false,
      'isRemoved': false,
      'hasFcmToken': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Member>> watchMembers(
    String groupId, {
    bool includeDeleted = false,
  }) {
    Query<Map<String, dynamic>> query = _refs.members(groupId);
    if (!includeDeleted) {
      query = query.where('isRemoved', isEqualTo: false);
    }
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Member.fromDoc(groupId, doc))
          .toList(growable: false),
    );
  }

  Future<List<Member>> getMembers(
    String groupId, {
    bool includeDeleted = false,
  }) async {
    Query<Map<String, dynamic>> query = _refs.members(groupId);
    if (!includeDeleted) {
      query = query.where('isRemoved', isEqualTo: false);
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Member.fromDoc(groupId, doc))
        .toList(growable: false);
  }

  Future<void> updateMember(
    String groupId,
    String memberId, {
    String? name,
  }) async {
    final cleanName = name?.trim();
    await _refs.member(groupId, memberId).update({
      if (cleanName != null && cleanName.isNotEmpty) 'name': cleanName,
    });
  }

  Future<void> sendTestNotification(String userId) async {
    await _functions.httpsCallable('sendTestNotification').call({
      'toUid': userId,
    });
  }

  Future<void> sendSettlementReminder({
    required String userId,
    required String groupId,
    required String groupName,
    required double amount,
    required String currencySymbol,
  }) async {
    await _functions.httpsCallable('sendSettlementReminder').call({
      'toUid': userId,
      'groupId': groupId,
      'groupName': groupName,
      'amount': amount,
      'currencySymbol': currencySymbol,
    });
  }

  Future<void> removeMember(
    String groupId,
    String memberId,
    String userId,
  ) async {
    final groupSnap = await _refs.group(groupId).get();
    if (!groupSnap.exists) throw StateError('Group not found.');
    final groupData = groupSnap.data() ?? const <String, dynamic>{};
    final ownerUid = groupData['ownerUid'] as String? ?? '';
    final isAdmin = await _isGroupAdmin(groupId, userId);
    if (ownerUid != userId && !isAdmin) {
      throw StateError('Admin access required.');
    }

    final memberSnap = await _refs.members(groupId).doc(memberId).get();
    if (!memberSnap.exists) throw StateError('Member not found.');
    final memberUid = memberSnap.data()?['uid'] as String?;

    final batch = _refs.db.batch();
    batch.update(_refs.members(groupId).doc(memberId), {'isRemoved': true});
    if (memberUid != null && memberUid.isNotEmpty) {
      final memberUids = List<String>.from(groupData['memberUids'] ?? const [])
        ..remove(memberUid);
      batch.update(_refs.group(groupId), {'memberUids': memberUids});
    }
    await batch.commit();
  }

  Future<bool> _isGroupAdmin(String groupId, String userId) async {
    try {
      final snap = await _refs.members(groupId).doc(userId).get();
      return snap.exists && snap.data()?['isAdmin'] == true;
    } catch (_) {
      return false;
    }
  }
}

final membersRepositoryProvider = Provider<MembersRepository>((ref) {
  return MembersRepository(
    ref.watch(firestoreRefsProvider),
    ref.watch(firebaseFunctionsProvider),
  );
});

final membersFutureProvider = AsyncNotifierProvider.autoDispose
    .family<MembersNotifier, List<Member>, String>(MembersNotifier.new);

class MembersNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<Member>, String> {
  StreamSubscription<List<Member>>? _subscription;

  @override
  Future<List<Member>> build(String groupId) async {
    ref.onDispose(() => _subscription?.cancel());

    final repo = ref.read(membersRepositoryProvider);
    final stream = repo.watchMembers(groupId);
    final first = Completer<List<Member>>();

    _subscription = stream.listen(
      (members) {
        if (!first.isCompleted) first.complete(members);
        state = AsyncValue.data(members);
      },
      onError: (Object error, StackTrace stack) {
        if (!first.isCompleted) first.completeError(error, stack);
        state = AsyncValue.error(error, stack);
      },
    );

    return first.future;
  }

  Future<void> addMember(String name) async {
    final repo = ref.read(membersRepositoryProvider);
    await repo.addMember(arg, name);
  }

  Future<void> updateMember(
    String memberId,
    String userId, {
    String? name,
  }) async {
    final repo = ref.read(membersRepositoryProvider);
    final previousState = state;

    if (previousState.value != null) {
      state = AsyncValue.data(
        previousState.value!
            .map(
              (member) =>
                  member.id == memberId ? member.copyWith(name: name) : member,
            )
            .toList(growable: false),
      );
    }

    try {
      await repo.updateMember(arg, memberId, name: name);
    } catch (error) {
      state = previousState;
      rethrow;
    }
  }

  Future<void> removeMember(String memberId, String userId) async {
    final repo = ref.read(membersRepositoryProvider);
    final previousState = state;

    if (previousState.value != null) {
      state = AsyncValue.data(
        previousState.value!
            .where((member) => member.id != memberId)
            .toList(growable: false),
      );
    }

    try {
      await repo.removeMember(arg, memberId, userId);
    } catch (error) {
      state = previousState;
      rethrow;
    }
  }
}
