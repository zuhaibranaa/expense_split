import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_refs.dart';
import '../domain/category_model.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository(
    ref.watch(firestoreRefsProvider),
    ref.watch(firebaseAuthProvider),
  );
});

final groupCategoriesProvider = StreamProvider.autoDispose
    .family<List<Category>, String>((ref, groupId) {
      return ref.watch(categoriesRepositoryProvider).watchCategories(groupId);
    });

class CategoriesRepository {
  CategoriesRepository(this._refs, this._auth);

  final FirestoreRefs _refs;
  final FirebaseAuth _auth;

  Stream<List<Category>> watchCategories(String groupId) {
    return _refs
        .categories(groupId)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Category.fromDoc(groupId, doc))
              .toList(growable: false),
        );
  }

  Future<List<Category>> getCategories(String groupId) async {
    final snapshot = await _refs.categories(groupId).orderBy('name').get();
    return snapshot.docs
        .map((doc) => Category.fromDoc(groupId, doc))
        .toList(growable: false);
  }

  Future<Category> createCategory(
    String groupId,
    String name, {
    String? icon,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('Category name cannot be empty.');
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('You must be signed in to do that.');
    }

    final userSnapshot = await _refs.user(uid).get();
    if (userSnapshot.data()?['isPremium'] != true) {
      throw StateError('Custom categories are a premium feature.');
    }

    final duplicate = await _refs
        .categories(groupId)
        .where('name', isEqualTo: cleanName)
        .limit(1)
        .get();
    if (duplicate.docs.isNotEmpty) {
      throw StateError('A category named "$cleanName" already exists.');
    }

    final ref = await _refs.categories(groupId).add({
      'name': cleanName,
      'icon': icon ?? '📦',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final snapshot = await ref.get();
    return Category.fromDoc(groupId, snapshot);
  }

  Future<void> deleteCategory(String groupId, String categoryId) async {
    final categoryRef = _refs.categories(groupId).doc(categoryId);
    final categorySnapshot = await categoryRef.get();
    final name = categorySnapshot.data()?['name'];

    if (name is String && name.isNotEmpty) {
      final inUse = await _refs
          .expenses(groupId)
          .where('category', isEqualTo: name)
          .limit(1)
          .get();
      if (inUse.docs.isNotEmpty) {
        throw StateError(
          'This category is used by an expense and cannot be deleted.',
        );
      }
    }

    await categoryRef.delete();
  }
}
