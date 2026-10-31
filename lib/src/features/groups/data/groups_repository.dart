import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/default_categories.dart';
import '../../../core/firebase/firestore_refs.dart';
import '../../auth/data/auth_repository.dart';
import '../../people/domain/member_model.dart';
import '../domain/group_model.dart';

class GroupsRepository {
  GroupsRepository(this._refs, this._auth);

  final FirestoreRefs _refs;
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
    String type = 'REGULAR',
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
      'type': type,
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

    // Seed the nine default categories client-side so groups work without
    // the onGroupCreated Cloud Function (Spark mode, D43). Fixed ids +
    // merge make this idempotent if the trigger also runs.
    for (final category in kDefaultCategories) {
      batch.set(_refs.categories(groupRef.id).doc(category.id), {
        'name': category.name,
        'icon': category.icon,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

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

    for (final category in kDefaultCategories) {
      batch.set(_refs.categories(groupRef.id).doc(category.id), {
        'name': category.name,
        'icon': category.icon,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

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
    final groupSnap = await _refs.group(groupId).get();
    if (!groupSnap.exists) throw StateError('Group not found.');
    if (groupSnap.data()?['ownerUid'] != userId) {
      throw StateError('Only the owner can delete this group.');
    }
    // Batch-delete every subcollection, then the group document.
    for (final collection in const ['members', 'expenses', 'categories']) {
      final snapshot = await _refs.db
          .collection('groups/$groupId/$collection')
          .get();
      for (var i = 0; i < snapshot.docs.length; i += 400) {
        final batch = _refs.db.batch();
        for (final doc in snapshot.docs.skip(i).take(400)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
    await _refs.group(groupId).delete();
  }

  Future<String> generateInvite(
    String groupId,
    String memberId,
    String userId,
  ) async {
    final groupSnap = await _refs.group(groupId).get();
    if (!groupSnap.exists) throw StateError('Group not found.');
    final memberUids = List<String>.from(
      groupSnap.data()?['memberUids'] ?? const [],
    );
    if (!memberUids.contains(userId)) {
      throw StateError('You are not a member of this group.');
    }

    final memberSnap = await _refs.members(groupId).doc(memberId).get();
    if (!memberSnap.exists) throw StateError('Member not found.');
    final memberData = memberSnap.data() ?? const <String, dynamic>{};
    if (memberData['isRemoved'] == true) {
      throw StateError('That person was removed from the group.');
    }
    final existingUid = memberData['uid'] as String?;
    if (existingUid != null && existingUid.isNotEmpty) {
      throw StateError('That person already has an account linked.');
    }

    final token = _generateToken();
    await _refs.db.collection('invites').doc(token).set({
      'groupId': groupId,
      'memberId': memberId,
      'createdBy': userId,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 7)),
      ),
      'used': false,
    });
    return token;
  }

  Future<Map<String, dynamic>> claimInvite(String token, String userId) async {
    if (token.length < 32) throw StateError('Invalid invite code.');
    final inviteRef = _refs.db.collection('invites').doc(token);
    return _refs.db.runTransaction((tx) async {
      final inviteSnap = await tx.get(inviteRef);
      if (!inviteSnap.exists) throw StateError('Invite not found.');
      final invite = inviteSnap.data()!;
      if (invite['used'] == true) {
        throw StateError('This invite has already been used.');
      }
      final expiresAt = (invite['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        throw StateError('This invite has expired.');
      }
      final groupId = invite['groupId'] as String;
      final memberId = invite['memberId'] as String;

      final groupRef = _refs.group(groupId);
      final groupSnap = await tx.get(groupRef);
      if (!groupSnap.exists) throw StateError('Group not found.');
      final memberUids = List<String>.from(
        groupSnap.data()?['memberUids'] ?? const [],
      );
      if (memberUids.contains(userId)) {
        throw StateError('You are already a member of this group.');
      }

      final memberRef = _refs.members(groupId).doc(memberId);
      final memberSnap = await tx.get(memberRef);
      if (!memberSnap.exists) throw StateError('Member not found.');
      final memberData = memberSnap.data() ?? const <String, dynamic>{};
      final existingUid = memberData['uid'] as String?;
      if (existingUid != null && existingUid.isNotEmpty) {
        throw StateError('This member is already linked to an account.');
      }

      final userSnap = await tx.get(_refs.user(userId));
      final userData = userSnap.data() ?? const <String, dynamic>{};
      final name = (userData['name'] as String?)?.trim();
      final email = userData['email'] as String?;
      final avatarUrl = userData['avatarUrl'] as String?;

      tx.update(inviteRef, {'used': true, 'claimedBy': userId});
      tx.update(memberRef, {
        'uid': userId,
        'name': (name == null || name.isEmpty) ? 'Member' : name,
        'email': email,
        'avatarUrl': avatarUrl,
        'hasFcmToken': false,
      });
      tx.update(groupRef, {
        'memberUids': [...memberUids, userId],
      });
      tx.delete(inviteRef);
      return {'groupId': groupId, 'memberId': memberId};
    });
  }

  String _generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
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

  /// Client-side replacement. Deletes every personal-group expense and the
  /// signed-in user's cash inflows.
  Future<void> resetPersonalBalance() async {
    final uid = _uid;
    final userSnap = await _refs.user(uid).get();
    final groupId = userSnap.data()?['personalGroupId'] as String?;
    if (groupId == null || groupId.isEmpty) {
      throw StateError('No personal group found.');
    }
    final expenseSnap = await _refs.db
        .collection('groups/$groupId/expenses')
        .get();
    for (var i = 0; i < expenseSnap.docs.length; i += 400) {
      final batch = _refs.db.batch();
      for (final doc in expenseSnap.docs.skip(i).take(400)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    final inflowSnap = await _refs.db
        .collection('cashInflows')
        .where('uid', isEqualTo: uid)
        .get();
    for (var i = 0; i < inflowSnap.docs.length; i += 400) {
      final batch = _refs.db.batch();
      for (final doc in inflowSnap.docs.skip(i).take(400)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  /// Returns the default categories used when creating a group.
  static List<DefaultCategory> get defaults => kDefaultCategories;
}

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return GroupsRepository(
    ref.watch(firestoreRefsProvider),
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
