import '../localization/app_localizations.dart';

/// Immutable tabular Hijri calendar date value.
class HijriDate {
  final int year;
  final int month;
  final int day;

  const HijriDate({
    required this.year,
    required this.month,
    required this.day,
  });
}

/// Pure-Dart Gregorian-to-Hijri converter (Kuwaiti tabular algorithm).
/// Introduces zero external dependencies and localizes via [AppLocalizations].
class HijriDateHelper {
  HijriDateHelper._();

  static HijriDate fromGregorian(DateTime date) {
    var d = date.day;
    var m = date.month;
    var y = date.year;

    if (m < 3) {
      y -= 1;
      m += 12;
    }

    final a = y ~/ 100;
    var b = 2 - a + (a ~/ 4);
    if (y < 1583) b = 0;

    final jd = (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        d +
        b -
        1524;

    const iYear = 10631.0 / 30.0;
    const epochAstro = 1948084;
    const shift1 = 8.01 / 60.0;

    var z = (jd - epochAstro).toDouble();
    final cyc = (z / 10631.0).floor();
    z -= 10631 * cyc;
    final j = ((z - shift1) / iYear).floor();
    final iy = (30 * cyc + j).toInt();
    z -= (j * iYear + shift1).floor();
    var im = ((z + 28.5001) / 29.5).floor();
    if (im == 13) im = 12;
    final id = (z - (29.5001 * im - 29).floor()).toInt();

    return HijriDate(
      year: iy,
      month: im.clamp(1, 12),
      day: id.clamp(1, 30),
    );
  }

  /// Formats [date] as e.g. `14 Jumada al-Thani 1448 AH`,
  /// `14 جمادى الآخرة 1448 هـ`, or `14 ጁማዳ አል-ሳኒ 1448 ዓ.ሂ.`.
  static String format(DateTime date, AppLocalizations loc) {
    final h = fromGregorian(date);
    final monthName = loc.translate('hijriMonth${h.month}');
    final era = loc.translate('hijriEraSuffix');
    return '${h.day} $monthName ${h.year} $era';
  }
}
