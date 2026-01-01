import '../../people/domain/member_model.dart';

class ExpenseSplit {
  final int id;
  final int memberId;
  final double amount;

  ExpenseSplit({
    required this.id,
    required this.memberId,
    required this.amount,
  });

  factory ExpenseSplit.fromJson(Map<String, dynamic> json) {
    return ExpenseSplit(
      id: json['id'],
      memberId: json['member_id'],
      amount: json['amount'] is String
          ? double.parse(json['amount'])
          : (json['amount'] as num).toDouble(),
    );
  }
}

class Expense {
  final int id;
  final String description;
  final double amount;
  final String category;
  final int payerId;
  final int groupId;
  final Member? payer;
  final DateTime date;
  final bool isSettlement;
  final List<ExpenseSplit> splits;

  Expense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.category,
    required this.payerId,
    this.payer,
    required this.date,
    this.isSettlement = false,
    this.splits = const [],
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      groupId: json['group_id'],
      description: json['description'],
      amount: json['amount'] is String
          ? double.parse(json['amount'])
          : (json['amount'] as num).toDouble(),
      category: json['category'] ?? 'General',
      payerId: json['payer_id'],
      payer: json['payer'] != null ? Member.fromJson(json['payer']) : null,
      date: DateTime.parse(json['date']),
      isSettlement: json['is_settlement'] == true || json['is_settlement'] == 1,
      splits:
          (json['splits'] as List?)
              ?.map((e) => ExpenseSplit.fromJson(e))
              .toList() ??
          [],
    );
  }
}
