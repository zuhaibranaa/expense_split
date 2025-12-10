class User {
  final int id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String defaultCurrency;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    required this.defaultCurrency,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      avatarUrl: json['avatar_url'],
      defaultCurrency: json['default_currency'] ?? 'USD',
    );
  }
}
