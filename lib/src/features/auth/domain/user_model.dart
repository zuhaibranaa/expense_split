class User {
  final int id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String defaultCurrency;
  final String? phone;
  final String? iban;
  final bool isVerified;
  final bool hasPassword;
  final double balance;
  final bool isPremium;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    required this.defaultCurrency,
    this.phone,
    this.iban,
    this.isVerified = false,
    this.hasPassword = true,
    this.balance = 0.0,
    this.isPremium = false,
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
      hasPassword: json['has_password'] ?? true,
      balance: (json['balance'] ?? 0).toDouble(),
      isPremium:
          json['is_active_premium'] == 1 || json['is_active_premium'] == true,
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
      'has_password': hasPassword,
      'balance': balance,
      'is_active_premium': isPremium,
    };
  }
}

class AuthResponse {
  final User user;
  final String token;

  AuthResponse({required this.user, required this.token});
}
