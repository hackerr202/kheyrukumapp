import 'dart:async';
import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../services/local_storage_service.dart';
import '../services/push_notification_service.dart';
import '../services/supabase_service.dart';

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
    unawaited(syncPreferredLanguageToProfile(clean));
    unawaited(PushNotificationService.instance.rescheduleForCurrentLocale());
  }

  /// Syncs the selected language to `public.profiles.preferred_language`
  /// when authenticated and online, ignoring offline/network errors gracefully.
  Future<void> syncPreferredLanguageToProfile([String? languageCode]) async {
    final code = (languageCode ?? value.languageCode).toLowerCase().trim();
    if (!['en', 'ar', 'am'].contains(code)) return;
    if (!ConnectivityService.instance.isOnline) return;

    final client = SupabaseService.instance.client;
    final user = SupabaseService.instance.currentUser;
    if (client == null || user == null) return;

    try {
      await client
          .from('profiles')
          .update({'preferred_language': code}).eq('id', user.id);
    } catch (e) {
      debugPrint('[LocaleNotifier] preferred_language sync note: $e');
    }
  }

  bool get isRtl => value.languageCode == 'ar';
  String get currentLanguageCode => value.languageCode;
}
