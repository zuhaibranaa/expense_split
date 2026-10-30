import 'package:cloud_firestore/cloud_firestore.dart';

/// Tolerant converters between Firestore values and Dart domain values.
/// Firestore documents may be written by clients, functions, or older builds,
/// so reads never throw on a missing/mistyped field.

DateTime? timestampToDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}

DateTime timestampToDateOrNow(dynamic value) =>
    timestampToDate(value) ?? DateTime.now();

Timestamp? dateToTimestamp(DateTime? value) =>
    value == null ? null : Timestamp.fromDate(value);

double asDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

double roundMoney(double value) => (value * 100).round() / 100.0;

String asString(dynamic value, [String fallback = '']) {
  if (value is String) return value;
  if (value == null) return fallback;
  return value.toString();
}

String? asStringOrNull(dynamic value) {
  if (value == null) return null;
  final result = value is String ? value : value.toString();
  return result.isEmpty ? null : result;
}

bool asBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value == 'true' || value == '1';
  return fallback;
}

int asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

List<String> asStringList(dynamic value) {
  if (value is Iterable) {
    return value
        .where((item) => item != null)
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const [];
}

Map<String, dynamic> asStringMap(dynamic value) {
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const {};
}

/// Reads `splits`/`payments` entries of the form `{memberId, amount}`.
List<Map<String, dynamic>> asEntryList(dynamic value) {
  if (value is Iterable) {
    return value
        .whereType<Map>()
        .map((entry) => entry.map((k, v) => MapEntry(k.toString(), v)))
        .toList(growable: false);
  }
  return const [];
}
