class Category {
  final int id;
  final String name;
  final int? groupId;
  final String? icon;

  Category({required this.id, required this.name, this.groupId, this.icon});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      groupId: json['group_id'],
      icon: json['icon'],
    );
  }
}
