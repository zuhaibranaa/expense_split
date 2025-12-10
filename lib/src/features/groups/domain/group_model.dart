class Group {
  final int id;
  final String name;
  final String currency;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.currency,
    required this.createdAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'],
      name: json['name'],
      currency: json['currency'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
