class Member {
  final int id;
  final String name;
  final int groupId;
  final int? userId; // Link to user account
  final int isAdmin; // 1 for admin, 0 for regular member
  final String? iban;
  final String? avatarUrl;
  final String? email;
  final String? phone;

  Member({
    required this.id,
    required this.name,
    required this.groupId,
    this.userId,
    this.isAdmin = 0,
    this.iban,
    this.avatarUrl,
    this.email,
    this.phone,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    var isAdminInt = 0;
    if (json['is_admin'] != null) {
      if (json['is_admin'] is bool) {
        isAdminInt = json['is_admin'] ? 1 : 0;
      } else if (json['is_admin'] is int) {
        isAdminInt = json['is_admin'];
      }
    }

    return Member(
      id: json['id'],
      name: json['name'],
      groupId: json['group_id'],
      userId: json['user_id'],
      isAdmin: isAdminInt,
      iban: user != null ? user['iban'] : null,
      avatarUrl: user != null ? user['avatar_url'] : null,
      email: user != null ? json['email'] : null,
      phone: user != null ? user['phone'] : null,
    );
  }
}
