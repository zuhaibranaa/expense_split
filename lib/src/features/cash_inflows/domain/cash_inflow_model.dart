import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firestore_converters.dart';

class CashInflow {
  final String id;
  final String userId;
  final double amount;
  final String currencyCode;
  final String category;
  final String description;
  final DateTime date;
  final String? expenseId;
  final DateTime? createdAt;

  const CashInflow({
    required this.id,
    required this.userId,
    required this.amount,
    required this.currencyCode,
    required this.category,
    required this.description,
    required this.date,
    this.expenseId,
    this.createdAt,
  });

  factory CashInflow.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return CashInflow.fromMap(doc.id, doc.data() ?? const {});
  }

  factory CashInflow.fromMap(String id, Map<String, dynamic> map) {
    return CashInflow(
      id: id,
      userId: asString(map['uid']),
      amount: asDouble(map['amount']),
      currencyCode: asString(map['currencyCode'], 'USD'),
      category: asString(map['category'], 'Income'),
      description: asString(map['description']),
      date: timestampToDateOrNow(map['date']),
      expenseId: asStringOrNull(map['expenseId']),
      createdAt: timestampToDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': userId,
      'amount': roundMoney(amount),
      'currencyCode': currencyCode,
      'category': category,
      'description': description,
      'date': dateToTimestamp(date),
      'expenseId': expenseId,
    };
  }
}
