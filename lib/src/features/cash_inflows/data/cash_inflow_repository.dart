import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_converters.dart';
import '../../../core/firebase/firestore_refs.dart';
import '../domain/cash_inflow_model.dart';

class CashInflowRepository {
  CashInflowRepository(this._refs, this._auth);

  final FirestoreRefs _refs;
  final FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('You must be signed in to do that.');
    }
    return uid;
  }

  Query<Map<String, dynamic>> _query({DateTime? startDate, DateTime? endDate}) {
    Query<Map<String, dynamic>> query = _refs.cashInflows.where(
      'uid',
      isEqualTo: _uid,
    );
    if (startDate != null) {
      query = query.where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(
          DateTime(startDate.year, startDate.month, startDate.day),
        ),
      );
    }
    if (endDate != null) {
      query = query.where(
        'date',
        isLessThanOrEqualTo: Timestamp.fromDate(
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999),
        ),
      );
    }
    return query.orderBy('date', descending: true);
  }

  Stream<List<CashInflow>> watchInflows({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _query(startDate: startDate, endDate: endDate).snapshots().map(
      (snapshot) =>
          snapshot.docs.map(CashInflow.fromDoc).toList(growable: false),
    );
  }

  Future<List<CashInflow>> getInflows({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final snapshot = await _query(startDate: startDate, endDate: endDate).get();
    return snapshot.docs.map(CashInflow.fromDoc).toList(growable: false);
  }

  Future<CashInflow> createInflow({
    required double amount,
    required String currencyCode,
    String? category,
    required String description,
    DateTime? date,
  }) async {
    final ref = await _refs.cashInflows.add({
      'uid': _uid,
      'amount': roundMoney(amount),
      'currencyCode': currencyCode,
      'category': category ?? 'Income',
      'description': description.trim(),
      'date': dateToTimestamp(date ?? DateTime.now()),
      'expenseId': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final snapshot = await ref.get();
    return CashInflow.fromDoc(snapshot);
  }

  Future<void> deleteInflow(String id) async {
    await _refs.cashInflow(id).delete();
  }

  Future<CashInflow> updateInflow({
    required String id,
    required double amount,
    required String currencyCode,
    String? category,
    required String description,
    DateTime? date,
  }) async {
    final ref = _refs.cashInflow(id);
    await ref.update({
      'amount': roundMoney(amount),
      'currencyCode': currencyCode,
      'category': category ?? 'Income',
      'description': description.trim(),
      'date': dateToTimestamp(date ?? DateTime.now()),
    });

    final snapshot = await ref.get();
    return CashInflow.fromDoc(snapshot);
  }
}

final cashInflowRepositoryProvider = Provider<CashInflowRepository>((ref) {
  return CashInflowRepository(
    ref.watch(firestoreRefsProvider),
    ref.watch(firebaseAuthProvider),
  );
});
