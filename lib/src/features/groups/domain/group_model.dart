import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firestore_converters.dart';

class Group {
  final String id;
  final String name;
  final String currency;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastActivityAt;
  final String type; // "REGULAR" or "PERSONAL"
  final String ownerUid;
  final List<String> memberUids;

  const Group({
    required this.id,
    required this.name,
    required this.currency,
    required this.createdAt,
    required this.type,
    this.updatedAt,
    this.lastActivityAt,
    this.ownerUid = '',
    this.memberUids = const [],
  });

  bool get isPersonal => type == 'PERSONAL';

  factory Group.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Group.fromMap(doc.id, doc.data() ?? const {});
  }

  factory Group.fromMap(String id, Map<String, dynamic> map) {
    return Group(
      id: id,
      name: asString(map['name'], 'Group'),
      currency: asString(map['currency'], 'USD'),
      createdAt: timestampToDateOrNow(map['createdAt']),
      updatedAt: timestampToDate(map['updatedAt']),
      lastActivityAt: timestampToDate(map['lastActivityAt']),
      type: asString(map['type'], 'REGULAR'),
      ownerUid: asString(map['ownerUid']),
      memberUids: asStringList(map['memberUids']),
    );
  }

  Group copyWith({
    String? name,
    String? currency,
    DateTime? updatedAt,
    DateTime? lastActivityAt,
    String? type,
    String? ownerUid,
    List<String>? memberUids,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      type: type ?? this.type,
      ownerUid: ownerUid ?? this.ownerUid,
      memberUids: memberUids ?? this.memberUids,
    );
  }
}
