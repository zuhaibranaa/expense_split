import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firestore_converters.dart';

class ExpenseSplit {
  final String memberId;
  final double amount;

  const ExpenseSplit({required this.memberId, required this.amount});

  factory ExpenseSplit.fromMap(Map<String, dynamic> map) {
    return ExpenseSplit(
      memberId: asString(map['memberId']),
      amount: asDouble(map['amount']),
    );
  }

  Map<String, dynamic> toMap() {
    return {'memberId': memberId, 'amount': roundMoney(amount)};
  }
}

class ExpensePayment {
  final String memberId;
  final double amount;

  const ExpensePayment({required this.memberId, required this.amount});

  factory ExpensePayment.fromMap(Map<String, dynamic> map) {
    return ExpensePayment(
      memberId: asString(map['memberId']),
      amount: asDouble(map['amount']),
    );
  }

  Map<String, dynamic> toMap() {
    return {'memberId': memberId, 'amount': roundMoney(amount)};
  }
}

class Expense {
  final String id;
  final String description;
  final double amount;
  final String category;
  final String payerId;
  final String payerName;
  final String groupId;
  final DateTime date;
  final bool isSettlement;
  final List<ExpenseSplit> splits;
  final List<ExpensePayment> payments;
  final List<String> memberIds;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Expense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.category,
    required this.payerId,
    this.payerName = '',
    required this.date,
    this.isSettlement = false,
    this.splits = const [],
    this.payments = const [],
    this.memberIds = const [],
    this.createdBy = '',
    this.createdAt,
    this.updatedAt,
  });

  factory Expense.fromDoc(
    String groupId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return Expense.fromMap(groupId, doc.id, doc.data() ?? const {});
  }

  factory Expense.fromMap(String groupId, String id, Map<String, dynamic> map) {
    final payerId = asString(map['payerId']);
    final splits = asEntryList(
      map['splits'],
    ).map(ExpenseSplit.fromMap).toList(growable: false);
    final payments = asEntryList(
      map['payments'],
    ).map(ExpensePayment.fromMap).toList(growable: false);
    final storedMemberIds = asStringList(map['memberIds']);

    return Expense(
      id: id,
      groupId: groupId,
      description: asString(map['description']),
      amount: asDouble(map['amount']),
      category: asString(map['category'], 'General'),
      payerId: payerId,
      payerName: asString(map['payerName']),
      date: timestampToDateOrNow(map['date']),
      isSettlement: asBool(map['isSettlement']),
      splits: splits,
      payments: payments,
      memberIds: storedMemberIds.isEmpty
          ? _deriveMemberIds(payerId, splits, payments)
          : storedMemberIds,
      createdBy: asString(map['createdBy']),
      createdAt: timestampToDate(map['createdAt']),
      updatedAt: timestampToDate(map['updatedAt']),
    );
  }

  /// Union of the payer, everyone in `splits`, and everyone in `payments`.
  /// Used as a denormalized filter key (`memberIds array-contains`).
  static List<String> _deriveMemberIds(
    String payerId,
    List<ExpenseSplit> splits,
    List<ExpensePayment> payments,
  ) {
    final ids = <String>{
      if (payerId.isNotEmpty) payerId,
      ...splits.map((split) => split.memberId),
      ...payments.map((payment) => payment.memberId),
    };
    return ids.where((id) => id.isNotEmpty).toList(growable: false);
  }

  static List<String> buildMemberIds({
    required String payerId,
    required Map<String, double> splits,
    Map<String, double>? payments,
  }) {
    final ids = <String>{
      if (payerId.isNotEmpty) payerId,
      ...splits.keys.where((id) => id.isNotEmpty),
      ...?payments?.keys.where((id) => id.isNotEmpty),
    };
    return ids.toList(growable: false);
  }

  /// Fields written by the client. `createdAt`/`updatedAt` are added by the
  /// repository so they can use `FieldValue.serverTimestamp()`.
  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'amount': roundMoney(amount),
      'category': category,
      'payerId': payerId,
      'payerName': payerName,
      'date': dateToTimestamp(date),
      'isSettlement': isSettlement,
      'splits': splits.map((split) => split.toMap()).toList(growable: false),
      'payments': payments
          .map((payment) => payment.toMap())
          .toList(growable: false),
      'memberIds': memberIds,
      'createdBy': createdBy,
    };
  }
}
