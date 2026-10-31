import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/default_categories.dart';
import '../../../core/firebase/firestore_refs.dart';
import '../../auth/data/auth_repository.dart';
import '../../people/domain/member_model.dart';
import '../domain/group_model.dart';

class GroupsRepository {
  GroupsRepository(this._refs, this._functions, this._auth);

  final FirestoreRefs _refs;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('You must be signed in to do that.');
    }
    return uid;
  }

  /// Creates a regular group plus its owner member document.
  /// Default categories are seeded by the `onGroupCreated` Cloud Function so
  /// non-premium users do not need category-write permission.
  Future<String> createGroup(
    String name,
    String currency,
    String creatorUserId, {
    String creatorName = '',
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('Group name cannot be empty.');
    }
    await _assertUniqueName(cleanName);

    final groupRef = _refs.groups.doc();
    final batch = _refs.db.batch();

    batch.set(groupRef, {
      'name': cleanName,
      'currency': currency,
      'type': 'REGULAR',
      'ownerUid': creatorUserId,
      'memberUids': [creatorUserId],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });

    batch.set(_refs.members(groupRef.id).doc(creatorUserId), {
      'name': creatorName.trim().isEmpty ? 'Owner' : creatorName.trim(),
      'uid': creatorUserId,
      'isAdmin': true,
      'isRemoved': false,
      'email': _auth.currentUser?.email,
      'avatarUrl': _auth.currentUser?.photoURL,
      'hasFcmToken': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return groupRef.id;
  }

  /// Client-side provisioning of the personal group for accounts whose
  /// `bootstrapUser` trigger never ran (D40). Mirrors the Cloud Function's
  /// payload; `onGroupCreated` seeds the default categories as for any group.
  /// Skips the duplicate-name check on purpose: a regular group may
  /// legitimately be called "Personal".
  Future<String> createPersonalGroup(
    String uid, {
    String name = 'Personal',
    String? currency,
    String creatorName = '',
  }) async {
    final groupRef = _refs.groups.doc();
    final batch = _refs.db.batch();

    batch.set(groupRef, {
      'name': name,
      'currency': currency ?? 'USD',
      'type': 'PERSONAL',
      'ownerUid': uid,
      'memberUids': [uid],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });

    batch.set(_refs.members(groupRef.id).doc(uid), {
      'name': creatorName.trim().isEmpty ? 'Me' : creatorName.trim(),
      'uid': uid,
      'isAdmin': true,
      'isRemoved': false,
      'email': _auth.currentUser?.email,
      'avatarUrl': _auth.currentUser?.photoURL,
      'hasFcmToken': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return groupRef.id;
  }

  /// Backfills `users/{uid}.personalGroupId` when the pointer is missing or
  /// dangling (D40). Self-writes are allowed by the rules;
  /// `isPremium`/`premiumUntil` stay Admin-SDK-only.
  Future<void> setPersonalGroupId(String uid, String groupId) async {
    await _refs.user(uid).set({
      'personalGroupId': groupId,
    }, SetOptions(merge: true));
  }

  Future<void> _assertUniqueName(String name) async {
    final existing = await _refs.groups
        .where('memberUids', arrayContains: _uid)
        .where('name', isEqualTo: name)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw StateError('You already have a group named "$name".');
    }
  }

  Stream<List<Group>> watchGroups(String userId) {
    return _refs.groups
        .where('memberUids', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(Group.fromDoc).toList(growable: false),
        );
  }

  Future<List<Group>> getGroups(String? userId) async {
    if (userId == null) return const [];
    final snapshot = await _refs.groups
        .where('memberUids', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map(Group.fromDoc).toList(growable: false);
  }

  Future<void> updateGroup(
    String groupId,
    String userId, {
    String? name,
    String? currency,
  }) async {
    if (name != null && name.trim().isNotEmpty) {
      await _assertUniqueName(name.trim());
    }
    await _refs.group(groupId).update({
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      'currency': ?currency,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteGroup(String groupId, String userId) async {
    await _call('deleteGroup', {'groupId': groupId});
  }

  Future<String> generateInvite(
    String groupId,
    String memberId,
    String userId,
  ) async {
    final result = await _call('createInvite', {
      'groupId': groupId,
      'memberId': memberId,
    });
    final token = result.data is Map ? result.data['token'] : null;
    if (token is! String || token.isEmpty) {
      throw StateError('Could not create an invite link. Please try again.');
    }
    return token;
  }

  Future<Map<String, dynamic>> claimInvite(String token, String userId) async {
    final result = await _call('claimInvite', {'token': token});
    final data = result.data;
    return data is Map
        ? data.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
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

  /// Client-side replacement for the old reset job. Deletes every personal
  /// inflow and personal-group expense for the signed-in user.
  Future<void> resetPersonalBalance() async {
    await _call('resetPersonalBalance', const {});
  }

  /// Returns the default categories used when creating a group.
  static List<DefaultCategory> get defaults => kDefaultCategories;

  Future<HttpsCallableResult<dynamic>> _call(
    String name,
    Map<String, dynamic> payload,
  ) {
    return _functions.httpsCallable(name).call<dynamic>(payload);
  }
}

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return GroupsRepository(
    ref.watch(firestoreRefsProvider),
    ref.watch(firebaseFunctionsProvider),
    ref.watch(firebaseAuthProvider),
  );
});

/// Real-time group list for the signed-in user.
/// Stays an [AsyncNotifier] because screens call `.notifier` for mutations.
final groupsListProvider =
    AsyncNotifierProvider.autoDispose<GroupsNotifier, List<Group>>(
      GroupsNotifier.new,
    );

class GroupsNotifier extends AutoDisposeAsyncNotifier<List<Group>> {
  StreamSubscription<List<Group>>? _subscription;

  @override
  Future<List<Group>> build() async {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const [];

    ref.onDispose(() => _subscription?.cancel());

    final repo = ref.watch(groupsRepositoryProvider);
    final stream = repo.watchGroups(user.id);
    final first = Completer<List<Group>>();
    _subscription = stream.listen(
      (groups) {
        if (!first.isCompleted) first.complete(groups);
        state = AsyncValue.data(groups);
      },
      onError: (Object error, StackTrace stack) {
        if (!first.isCompleted) first.completeError(error, stack);
        state = AsyncValue.error(error, stack);
      },
    );

    return first.future;
  }

  Future<void> addGroup(String name, String currency) async {
    final user = ref.read(authControllerProvider).value;
    if (user == null) return;
    final repo = ref.read(groupsRepositoryProvider);
    await repo.createGroup(name, currency, user.id, creatorName: user.name);
  }

  Future<void> updateGroup(
    String groupId, {
    String? name,
    String? currency,
  }) async {
    final user = ref.read(authControllerProvider).value;
    if (user == null) return;
    final repo = ref.read(groupsRepositoryProvider);

    final previousState = state;
    if (previousState.value != null) {
      state = AsyncValue.data(
        previousState.value!
            .map(
              (group) => group.id == groupId
                  ? group.copyWith(name: name, currency: currency)
                  : group,
            )
            .toList(growable: false),
      );
    }

    try {
      await repo.updateGroup(groupId, user.id, name: name, currency: currency);
    } catch (error) {
      state = previousState;
      rethrow;
    }
  }

  Future<void> deleteGroup(String groupId) async {
    final user = ref.read(authControllerProvider).value;
    if (user == null) return;
    final repo = ref.read(groupsRepositoryProvider);

    final previousState = state;
    if (previousState.value != null) {
      state = AsyncValue.data(
        previousState.value!
            .where((group) => group.id != groupId)
            .toList(growable: false),
      );
    }

    try {
      await repo.deleteGroup(groupId, user.id);
    } catch (error) {
      state = previousState;
      rethrow;
    }
  }
}

final groupMembersProvider = StreamProvider.autoDispose
    .family<List<Member>, String>((ref, groupId) {
      return ref.watch(groupsRepositoryProvider).watchMembers(groupId);
    });

/// Includes removed members so historical expenses can still resolve names.
final allMembersFutureProvider = StreamProvider.autoDispose
    .family<List<Member>, String>((ref, groupId) {
      return ref
          .watch(groupsRepositoryProvider)
          .watchMembers(groupId, includeDeleted: true);
    });
