/// Shared defensive JSON parsing & safe string utilities for models and UI.
class JsonParsers {
  JsonParsers._();

  static String asString(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    final s = v.toString();
    return s;
  }

  static String? asNullableString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int asInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim()) ??
        double.tryParse(v.toString().trim())?.toInt() ??
        fallback;
  }

  static int? asNullableInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim()) ??
        double.tryParse(v.toString().trim())?.toInt();
  }

  static double asDouble(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim()) ?? fallback;
  }

  static bool asBool(dynamic v, [bool fallback = false]) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final lower = v.toString().trim().toLowerCase();
    if (lower == 'true' || lower == '1' || lower == 'yes') return true;
    if (lower == 'false' || lower == '0' || lower == 'no') return false;
    return fallback;
  }

  static DateTime asDateTime(dynamic v, [DateTime? fallback]) {
    final parsed = asNullableDateTime(v);
    return parsed ?? fallback ?? DateTime.now();
  }

  static DateTime? asNullableDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static Map<String, dynamic>? asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), val));
    }
    return null;
  }

  static List<String> asStringList(dynamic v) {
    if (v is List) {
      return v
          .where((e) => e != null)
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  /// Safely returns the first uppercase character of a trimmed display name,
  /// avoiding RangeError on whitespace-only strings and preserving surrogate pairs.
  static String safeInitial(String? name, [String fallback = 'K']) {
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return fallback;
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }
}
