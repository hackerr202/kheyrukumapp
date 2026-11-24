import 'dart:math';

/// Pure-Dart RFC-4122 UUID v4 generator and validator.
/// Ensures offline-created records have real database-compatible UUIDs so
/// idempotent upserts (`onConflict: 'id'`) never produce duplicates.
class UuidV4 {
  UuidV4._();

  static final Random _random = _createRandom();

  static Random _createRandom() {
    try {
      return Random.secure();
    } catch (_) {
      return Random();
    }
  }

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Generates a genuine RFC-4122 version 4 UUID (lowercase 8-4-4-4-12).
  static String generate() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    // Version 4: set top 4 bits of byte 6 to 0100.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Variant 1: set top 2 bits of byte 8 to 10.
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        hex.write('-');
      }
      hex.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return hex.toString();
  }

  /// Validates standard hyphenated UUID format.
  static bool isValid(String? value) {
    if (value == null) return false;
    return _uuidRegex.hasMatch(value.trim());
  }
}
