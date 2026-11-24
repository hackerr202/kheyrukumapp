import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';

/// Centralized ValueNotifier for application language and directionality.
/// Supported language codes:
/// - 'en': English (LTR)
/// - 'ar': Arabic / العربية (RTL)
/// - 'am': Amharic / አማርኛ (LTR)
class LocaleNotifier extends ValueNotifier<Locale> {
  LocaleNotifier._() : super(const Locale('en'));

  static final LocaleNotifier instance = LocaleNotifier._();

  static const String prefKey = 'app_language_code';

  Future<void> loadSavedLocale() async {
    try {
      final code =
          await LocalStorageService.instance.getString(prefKey) ?? 'en';
      if (['en', 'ar', 'am'].contains(code) && value.languageCode != code) {
        value = Locale(code);
      }
    } catch (_) {}
  }

  Future<void> setLocale(String languageCode) async {
    final clean = languageCode.toLowerCase().trim();
    if (!['en', 'ar', 'am'].contains(clean)) return;
    value = Locale(clean);
    try {
      await LocalStorageService.instance.saveString(prefKey, clean);
    } catch (_) {}
  }

  bool get isRtl => value.languageCode == 'ar';
  String get currentLanguageCode => value.languageCode;
}
