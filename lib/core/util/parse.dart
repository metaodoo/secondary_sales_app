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

/// Nullable double. Returns null when the value is absent (`null`/`false`) or unparseable.
double? asNullableDouble(Object? value) {
  if (value == null || value == false) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
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

/// Non-null string. Returns [defaultValue] when absent (null or false) or empty.
String asString(Object? value, {String defaultValue = ''}) {
  if (value == null || value == false) return defaultValue;
  final str = value.toString();
  return str.isEmpty ? defaultValue : str;
}

/// String or null. Maps `null`, `false` and empty strings to null.
String? asNullableString(Object? value) {
  if (value == null || value == false) return null;
  final stringValue = value.toString();
  return stringValue.isEmpty ? null : stringValue;
}

/// Parses an ISO date/time string from server, mapping `null`/`false`/unparseable to null.
/// Server timestamps (UTC) are converted to the local time zone (e.g. GMT+6 for Asia/Dhaka)
/// so that all timestamps shown across the app strictly reflect the configured local timezone.
DateTime? asDateTime(Object? value) {
  if (value == null || value == false) return null;
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;

  // Pure date format YYYY-MM-DD
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
    return DateTime.tryParse(raw);
  }

  final parsed = DateTime.tryParse(raw.replaceAll(' ', 'T'));
  if (parsed == null) return null;

  // If already parsed as UTC or has explicit offset:
  if (parsed.isUtc || raw.endsWith('Z') || raw.contains('+')) {
    return parsed.toLocal();
  }

  // Naive datetime (already localized from backend in user/Dhaka timezone):
  return parsed;
}

/// Formats a time/datetime value as a user-friendly 12-hour time string (e.g. "09:30 AM").
/// Accepts ISO strings, naive datetime strings, pure time strings, and DateTime objects.
String formatDisplayTime(Object? value, {String defaultValue = '--:--'}) {
  if (value == null || value == false) return defaultValue;
  final raw = value.toString().trim();
  if (raw.isEmpty || raw == 'false') return defaultValue;

  // If it's pure time HH:mm or HH:mm:ss
  if (RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$').hasMatch(raw)) {
    final parts = raw.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = (h % 12 == 0) ? 12 : (h % 12);
    final hStr = h12.toString().padLeft(2, '0');
    final mStr = m.toString().padLeft(2, '0');
    return '$hStr:$mStr $period';
  }

  final dt = asDateTime(raw);
  if (dt != null) {
    final h = dt.hour;
    final m = dt.minute;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = (h % 12 == 0) ? 12 : (h % 12);
    final hStr = h12.toString().padLeft(2, '0');
    final mStr = m.toString().padLeft(2, '0');
    return '$hStr:$mStr $period';
  }

  return raw;
}

/// Formats a date/time value as "yyyy-MM-dd hh:mm a" (e.g. "2026-10-19 09:30 AM").
String formatDisplayDateTime(Object? value, {String defaultValue = 'N/A'}) {
  if (value == null || value == false) return defaultValue;
  final raw = value.toString().trim();
  if (raw.isEmpty || raw == 'false') return defaultValue;

  final dt = asDateTime(raw);
  if (dt != null) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour;
    final m = dt.minute;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = (h % 12 == 0) ? 12 : (h % 12);
    final hStr = h12.toString().padLeft(2, '0');
    final mStr = m.toString().padLeft(2, '0');
    return '$y-$mo-$d $hStr:$mStr $period';
  }

  return raw;
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

/// Formats location names to display updated terminology:
/// - Customer Location -> Salable Product Location
/// - Scrap Damaged Location / Scrap Damaged -> Non Saleable Product Location
/// - Scrap Quality Location / Scrap Quality -> Quality Return Product Location
String formatLocationName(Object? value) {
  String text = '';
  if (value is Map<String, dynamic>) {
    text = value['name']?.toString() ?? '-';
  } else if (value != null && value != false) {
    text = value.toString();
  } else {
    return '-';
  }

  if (text.isEmpty || text == '-') return '-';

  return text
      .replaceAll('Customer Location', 'Salable Product Location')
      .replaceAll('Scrap Damaged Location', 'Non Saleable Product Location')
      .replaceAll('Scrap Damaged', 'Non Saleable Product Location')
      .replaceAll('Scrap Quality Location', 'Quality Return Product Location')
      .replaceAll('Scrap Quality', 'Quality Return Product Location');
}
