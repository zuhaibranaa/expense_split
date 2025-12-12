class Member {
  final int id;
  final String name;
  final int groupId;
  final int? userId; // Link to user account
  final int isAdmin; // 1 for admin, 0 for regular member
  final String? iban;
  final String? avatarUrl;

  Member({
    required this.id,
    required this.name,
    required this.groupId,
    this.userId,
    this.isAdmin = 0,
    this.iban,
    this.avatarUrl,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return Member(
      id: json['id'],
      name: json['name'],
      groupId: json['group_id'],
      userId: json['user_id'],
      isAdmin: json['is_admin'] ?? 0,
      iban: user != null ? user['iban'] : null,
      avatarUrl: user != null ? user['avatar_url'] : null,
    );
  }
}
