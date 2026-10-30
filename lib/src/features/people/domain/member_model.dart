import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firestore_converters.dart';

class Member {
  final String id;
  final String name;
  final String groupId;
  final String? userId; // Firebase uid, set when an invite is claimed
  final bool isAdmin;
  final bool isRemoved;
  final String? iban;
  final String? avatarUrl;
  final String? email;
  final String? phone;
  final bool hasFcmToken;
  final DateTime? createdAt;

  const Member({
    required this.id,
    required this.name,
    required this.groupId,
    this.userId,
    this.isAdmin = false,
    this.isRemoved = false,
    this.iban,
    this.avatarUrl,
    this.email,
    this.phone,
    this.hasFcmToken = false,
    this.createdAt,
  });

  factory Member.fromDoc(
    String groupId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return Member.fromMap(groupId, doc.id, doc.data() ?? const {});
  }

  factory Member.fromMap(String groupId, String id, Map<String, dynamic> map) {
    return Member(
      id: id,
      name: asString(map['name'], 'Member'),
      groupId: groupId,
      userId: asStringOrNull(map['uid']),
      isAdmin: asBool(map['isAdmin']),
      isRemoved: asBool(map['isRemoved']),
      iban: asStringOrNull(map['iban']),
      avatarUrl: asStringOrNull(map['avatarUrl']),
      email: asStringOrNull(map['email']),
      phone: asStringOrNull(map['phone']),
      hasFcmToken: asBool(map['hasFcmToken']),
      createdAt: timestampToDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'uid': userId,
      'isAdmin': isAdmin,
      'isRemoved': isRemoved,
      'iban': iban,
      'avatarUrl': avatarUrl,
      'email': email,
      'phone': phone,
      'hasFcmToken': hasFcmToken,
      'createdAt': dateToTimestamp(createdAt ?? DateTime.now()),
    };
  }

  Member copyWith({
    String? name,
    String? userId,
    bool? isAdmin,
    bool? isRemoved,
    String? iban,
    String? avatarUrl,
    String? email,
    String? phone,
    bool? hasFcmToken,
  }) {
    return Member(
      id: id,
      name: name ?? this.name,
      groupId: groupId,
      userId: userId ?? this.userId,
      isAdmin: isAdmin ?? this.isAdmin,
      isRemoved: isRemoved ?? this.isRemoved,
      iban: iban ?? this.iban,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      hasFcmToken: hasFcmToken ?? this.hasFcmToken,
      createdAt: createdAt,
    );
  }
}
