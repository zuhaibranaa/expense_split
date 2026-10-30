import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firestore_converters.dart';

class Category {
  final String id;
  final String name;
  final String? groupId;
  final String? icon;

  const Category({
    required this.id,
    required this.name,
    this.groupId,
    this.icon,
  });

  factory Category.fromDoc(
    String groupId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return Category.fromMap(groupId, doc.id, doc.data() ?? const {});
  }

  factory Category.fromMap(
    String groupId,
    String id,
    Map<String, dynamic> map,
  ) {
    return Category(
      id: id,
      name: asString(map['name'], 'General'),
      groupId: groupId,
      icon: asStringOrNull(map['icon']),
    );
  }
}
