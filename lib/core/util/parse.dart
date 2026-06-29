/// Shared coercion helpers for Odoo JSON-RPC responses.
///
/// Odoo returns `false` for empty fields and sometimes sends numbers as
/// strings, so every model needs the same defensive parsing. These were
/// previously duplicated (with subtly different behaviour) across ~12 files;
/// centralising them keeps coercion consistent.
library;

/// Non-null int. Returns 0 when the value is absent or unparseable.
int asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

/// Nullable int that **preserves 0**. Returns null only when the value is
/// absent (`null`/`false`) or unparseable. Use where 0 is a valid id/value
/// (e.g. the auth session's `employeeId`, whose null-ness gates login).
int? asIntOrNull(Object? value) {
  if (value == null || value == false) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

/// Nullable int that also treats 0 as absent. Use where 0 means "no record"
/// (e.g. an optional `lot_id`).
int? asNonZeroInt(Object? value) {
  if (value == null || value == false) return null;
  final parsed = asInt(value);
  return parsed == 0 ? null : parsed;
}

/// Non-null double. Returns 0.0 when the value is absent or unparseable.
double asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

/// Odoo booleans: real bools, numbers (0 == false) and the string forms
/// ('', '0', 'false', 'no' are false; everything else true).
bool asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return !['', '0', 'false', 'no'].contains(value.toLowerCase());
  }
  return false;
}

/// String or null. Maps `null`, `false` and empty strings to null.
String? asNullableString(Object? value) {
  if (value == null || value == false) return null;
  final stringValue = value.toString();
  return stringValue.isEmpty ? null : stringValue;
}

/// Parses an ISO date string, mapping `null`/`false`/unparseable to null.
DateTime? asDateTime(Object? value) {
  if (value == null || value == false) return null;
  return DateTime.tryParse(value.toString());
}

/// Coerces to a typed map, defaulting to an empty map.
Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return <String, dynamic>{};
}

/// Coerces to a typed map or null when the value is absent (`null`/`false`).
Map<String, dynamic>? asMapOrNull(Object? value) {
  if (value == null || value == false) return null;
  return asMap(value);
}
