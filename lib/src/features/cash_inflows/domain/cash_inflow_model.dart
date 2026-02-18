class CashInflow {
  final int id;
  final int userId;
  final double amount;
  final String currencyCode;
  final String category;
  final String description;
  final DateTime date;
  final int? expenseId;

  CashInflow({
    required this.id,
    required this.userId,
    required this.amount,
    required this.currencyCode,
    required this.category,
    required this.description,
    required this.date,
    this.expenseId,
  });

  factory CashInflow.fromJson(Map<String, dynamic> json) {
    return CashInflow(
      id: json['id'],
      userId: json['user_id'],
      amount: (json['amount'] ?? 0).toDouble(),
      currencyCode: json['currency_code'] ?? 'USD',
      category: json['category'] ?? 'Income',
      description: json['description'] ?? '',
      date: DateTime.parse(json['date']),
      expenseId: json['expense_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'currency_code': currencyCode,
      'category': category,
      'description': description,
      'date': date.toIso8601String(),
      'expense_id': expenseId,
    };
  }
}
