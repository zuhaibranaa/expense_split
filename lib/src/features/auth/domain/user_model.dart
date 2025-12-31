class User {
  final int id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String defaultCurrency;
  final String? phone;
  final String? iban;
  final bool isVerified;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    required this.defaultCurrency,
    this.phone,
    this.iban,
    this.isVerified = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      avatarUrl: json['avatar_url'],
      defaultCurrency: json['default_currency'] ?? 'USD',
      phone: json['phone'],
      iban: json['iban'],
      isVerified: json['is_verified'] == 1 || json['is_verified'] == true,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar_url': avatarUrl,
      'default_currency': defaultCurrency,
      'phone': phone,
      'iban': iban,
      'is_verified': isVerified,
    };
  }
}

class AuthResponse {
  final User user;
  final String token;

  AuthResponse({required this.user, required this.token});
}
