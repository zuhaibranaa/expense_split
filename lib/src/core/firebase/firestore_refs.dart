import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instance;
});

/// Typed entry points for every collection used by the app.
class FirestoreRefs {
  FirestoreRefs(this.db);

  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> get users => db.collection('users');

  DocumentReference<Map<String, dynamic>> user(String uid) => users.doc(uid);

  CollectionReference<Map<String, dynamic>> devices(String uid) =>
      user(uid).collection('devices');

  CollectionReference<Map<String, dynamic>> get groups =>
      db.collection('groups');

  DocumentReference<Map<String, dynamic>> group(String groupId) =>
      groups.doc(groupId);

  CollectionReference<Map<String, dynamic>> members(String groupId) =>
      group(groupId).collection('members');

  DocumentReference<Map<String, dynamic>> member(
    String groupId,
    String memberId,
  ) => members(groupId).doc(memberId);

  CollectionReference<Map<String, dynamic>> expenses(String groupId) =>
      group(groupId).collection('expenses');

  DocumentReference<Map<String, dynamic>> expense(
    String groupId,
    String expenseId,
  ) => expenses(groupId).doc(expenseId);

  CollectionReference<Map<String, dynamic>> categories(String groupId) =>
      group(groupId).collection('categories');

  CollectionReference<Map<String, dynamic>> get cashInflows =>
      db.collection('cashInflows');

  DocumentReference<Map<String, dynamic>> cashInflow(String id) =>
      cashInflows.doc(id);
}

final firestoreRefsProvider = Provider<FirestoreRefs>((ref) {
  return FirestoreRefs(ref.watch(firestoreProvider));
});
