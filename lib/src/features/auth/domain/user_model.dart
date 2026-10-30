import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firestore_converters.dart';

class User {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String defaultCurrency;
  final String? phone;
  final String? iban;
  final bool isVerified;
  final bool hasPassword;
  final bool isPremium;
  final DateTime? premiumUntil;
  final String? personalGroupId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.defaultCurrency = 'USD',
    this.phone,
    this.iban,
    this.isVerified = false,
    this.hasPassword = true,
    this.isPremium = false,
    this.premiumUntil,
    this.personalGroupId,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return User.fromMap(doc.id, doc.data() ?? const {});
  }

  factory User.fromMap(String id, Map<String, dynamic> map) {
    return User(
      id: id,
      email: asString(map['email']),
      name: asString(map['name'], asString(map['email']).split('@').first),
      avatarUrl: asStringOrNull(map['avatarUrl']),
      defaultCurrency: asString(map['defaultCurrency'], 'USD'),
      phone: asStringOrNull(map['phone']),
      iban: asStringOrNull(map['iban']),
      isVerified: asBool(map['isVerified']),
      hasPassword: asBool(map['hasPassword'], true),
      isPremium: asBool(map['isPremium']),
      premiumUntil: timestampToDate(map['premiumUntil']),
      personalGroupId: asStringOrNull(map['personalGroupId']),
      createdAt: timestampToDate(map['createdAt']),
      updatedAt: timestampToDate(map['updatedAt']),
    );
  }

  User copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    String? defaultCurrency,
    String? phone,
    String? iban,
    bool? isVerified,
    bool? hasPassword,
    bool? isPremium,
    DateTime? premiumUntil,
    String? personalGroupId,
  }) {
    return User(
      id: id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      phone: phone ?? this.phone,
      iban: iban ?? this.iban,
      isVerified: isVerified ?? this.isVerified,
      hasPassword: hasPassword ?? this.hasPassword,
      isPremium: isPremium ?? this.isPremium,
      premiumUntil: premiumUntil ?? this.premiumUntil,
      personalGroupId: personalGroupId ?? this.personalGroupId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'avatarUrl': avatarUrl,
      'defaultCurrency': defaultCurrency,
      'phone': phone,
      'iban': iban,
      'isVerified': isVerified,
      'hasPassword': hasPassword,
      'isPremium': isPremium,
      'premiumUntil': dateToTimestamp(premiumUntil),
      'personalGroupId': personalGroupId,
    };
  }
}
