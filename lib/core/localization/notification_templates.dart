import 'dart:convert';

/// Trilingual ('en' | 'ar' | 'am') renderer for system notifications,
/// on-device scheduled reminders, and in-app Notification Center items.
class NotificationTemplates {
  NotificationTemplates._();

  static const List<List<String>> _monthForms = [
    ['January', 'يناير', 'ጃንዋሪ'],
    ['February', 'فبراير', 'ፌብሩዋሪ'],
    ['March', 'مارس', 'ማርች'],
    ['April', 'أبريل', 'ኤፕሪል'],
    ['May', 'مايو', 'ሜይ'],
    ['June', 'يونيو', 'ጁን'],
    ['July', 'يوليو', 'ጁላይ'],
    ['August', 'أغسطس', 'ኦገስት'],
    ['September', 'سبتمبر', 'ሴፕቴምበር'],
    ['October', 'أكتوبر', 'ኦክቶበር'],
    ['November', 'نوفمبر', 'ኖቬምበር'],
    ['December', 'ديسمبر', 'ዲሴምበር'],
  ];

  static String _normLang(String code) {
    final lower = code.trim().toLowerCase();
    if (lower == 'ar' || lower == 'am') return lower;
    return 'en';
  }

  /// Normalizes month strings like "November 2026" or "ኖቬምበር 2026" into [lang].
  static String localizeMonthLabel(String raw, String lang) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    final cleanLang = _normLang(lang);
    final langIdx = cleanLang == 'ar' ? 1 : (cleanLang == 'am' ? 2 : 0);

    var result = trimmed;
    for (final forms in _monthForms) {
      for (final f in forms) {
        if (result.toLowerCase().contains(f.toLowerCase())) {
          result = result.replaceAll(
            RegExp(RegExp.escape(f), caseSensitive: false),
            forms[langIdx],
          );
          return result;
        }
      }
    }
    return result;
  }

  static String _localizeAttendanceStatus(String status, String lang) {
    final s = status.trim().toLowerCase();
    switch (_normLang(lang)) {
      case 'ar':
        return switch (s) {
          'present' => 'حاضر',
          'late' => 'متأخر',
          'absent' => 'غائب',
          'excused' => 'بعذر',
          _ => status,
        };
      case 'am':
        return switch (s) {
          'present' => 'ተገኝቷል',
          'late' => 'ዘግይቷል',
          'absent' => 'ቀርቷል',
          'excused' => 'በፈቃድ',
          _ => status,
        };
      default:
        return switch (s) {
          'present' => 'Present',
          'late' => 'Late',
          'absent' => 'Absent',
          'excused' => 'Excused',
          _ => status,
        };
    }
  }

  static String _localizeRating(String rating, String lang) {
    final r = rating.trim().toLowerCase();
    switch (_normLang(lang)) {
      case 'ar':
        if (r.contains('mumtaz') || r.contains('excellent')) {
          return 'ممتاز';
        }
        if (r.contains('jiddan') || r.contains('very good')) {
          return 'جيد جداً';
        }
        if (r.contains('jayyid') || r.contains('good')) {
          return 'جيد';
        }
        if (r.contains('needs') || r.contains('revision')) {
          return 'يحتاج مراجعة';
        }
        return rating;
      case 'am':
        if (r.contains('mumtaz') || r.contains('excellent')) {
          return 'ሙምታዝ (በጣም ጥሩ)';
        }
        if (r.contains('jiddan') || r.contains('very good')) {
          return 'ጀይድ ጂዳን (በጣም መልካም)';
        }
        if (r.contains('jayyid') || r.contains('good')) {
          return 'ጀይድ (ጥሩ)';
        }
        if (r.contains('needs') || r.contains('revision')) {
          return 'ክለሳ ያስፈልጋል';
        }
        return rating;
      default:
        if (r.contains('mumtaz') || r.contains('excellent')) return 'Excellent';
        if (r.contains('jiddan') || r.contains('very good')) return 'Very Good';
        if (r.contains('jayyid') || r.contains('good')) return 'Good';
        if (r.contains('needs') || r.contains('revision')) {
          return 'Needs Revision';
        }
        return rating;
    }
  }

  static ({String title, String body}) render({
    required String templateKey,
    Map<String, dynamic> params = const {},
    required String languageCode,
    String fallbackTitle = '',
    String fallbackBody = '',
  }) {
    final lang = _normLang(languageCode);
    String p(String key, [String def = '']) {
      final v = params[key]?.toString().trim() ?? '';
      return v.isNotEmpty ? v : def;
    }

    final month = localizeMonthLabel(p('month'), lang);
    final student = p('student_name', lang == 'ar' ? 'الطالب' : (lang == 'am' ? 'ተማሪው' : 'Student'));
    final parent = p('parent_name', lang == 'ar' ? 'ولي الأمر' : (lang == 'am' ? 'ወላጅ' : 'A parent'));
    final amount = p('amount');
    final reason = p('reason');
    final hwTitle = p('title');
    final surah = p('surah');
    final fromAyah = p('from_ayah', '1');
    final toAyah = p('to_ayah', '1');
    final rating = _localizeRating(p('rating'), lang);
    final status = _localizeAttendanceStatus(p('status'), lang);
    final date = p('date');
    final sabaq = p('sabaq');
    final halaqah = p('halaqah_name');
    final sender = p('sender_name', lang == 'ar' ? 'رسالة جديدة' : (lang == 'am' ? 'አዲስ መልእክት' : 'New Message'));
    final msgBody = p('body');
    final duration = p('duration', '0');
    final fileName = p('file_name', lang == 'ar' ? 'مستند' : (lang == 'am' ? 'ሰነድ' : 'Document'));
    final actor = p('actor_name', lang == 'ar' ? 'مستخدم' : (lang == 'am' ? 'ተጠቃሚ' : 'A user'));

    switch (templateKey) {
      case 'prayer_reminder':
        return switch (lang) {
          'ar' => (
              title: 'تذكير بالصلاة اليومية 🕌',
              body: 'لا تنسَ صلاتك. خذ لحظة هادئة لذكر الله (حَيَّ عَلَى الصَّلَاةِ).',
            ),
          'am' => (
              title: 'የዕለት ሶላት ማስታወሻ 🕌',
              body: 'ሶላትዎን አይርሱ። አላህን ለማውሳትና ሶላት ለመስገድ የተረጋጋ ጊዜ ይውሰዱ።',
            ),
          _ => (
              title: 'Daily Prayer Reminder 🕌',
              body:
                  'Don\'t forget to pray. Take a peaceful moment to remember Allah (حَيَّ عَلَى الصَّلَاةِ).',
            ),
        };

      case 'monthly_tuition_local_reminder':
        return switch (lang) {
          'ar' => (
              title: 'تذكير بالرسوم الشهرية 💳',
              body: 'حان موعد الرسوم الشهرية لحفظ القرآن. يرجى السداد ورفع صورة الإيصال.',
            ),
          'am' => (
              title: 'ወርሃዊ የትምህርት ክፍያ ማስታወሻ 💳',
              body: 'የወሩ የቁርኣን ትምህርት ክፍያ ደርሷል። እባክዎ ከፍለው የደረሰኝ ምስል ይስቀሉ።',
            ),
          _ => (
              title: 'Monthly Tuition Fee Reminder 💳',
              body:
                  'Monthly Quran memorization fee is due. Please submit payment and upload receipt proof.',
            ),
        };

      case 'monthly_tuition_due':
        final start = p('fee_start_date');
        return switch (lang) {
          'ar' => (
              title: 'رسوم دراسية جديدة مستحقة 💳',
              body: start.isNotEmpty
                  ? 'تم إصدار رسوم شهر $month للطالب $student بمبلغ $amount بر (تاريخ البدء: $start).'
                  : 'تم إصدار رسوم شهر $month للطالب $student بمبلغ $amount بر.',
            ),
          'am' => (
              title: 'አዲስ ወርሃዊ ክፍያ ተልኳል 💳',
              body: start.isNotEmpty
                  ? 'ለ$student የ$month ወር ክፍያ ($amount ብር) ከ$start ጀምሮ ተልኳል።'
                  : 'ለ$student የ$month ወር ክፍያ ($amount ብር) ተልኳል።',
            ),
          _ => (
              title: 'Monthly Tuition Fee Due 💳',
              body: start.isNotEmpty
                  ? 'Tuition for $month ($amount ETB) starting on $start has been issued for $student.'
                  : 'Tuition for $month ($amount ETB) has been issued for $student.',
            ),
        };

      case 'monthly_tuition_reminder':
        final hasStudent = p('student_name').isNotEmpty;
        final hasAmount = amount.isNotEmpty;
        return switch (lang) {
          'ar' => (
              title: 'تذكير بالرسوم الشهرية 💳',
              body: hasStudent && hasAmount
                  ? 'تستحق رسوم الطالب $student لشهر $month بمبلغ $amount بر. يرجى السداد ورفع إيصال التحويل.'
                  : 'تستحق الرسوم الشهرية لحفظ القرآن لشهر $month. يرجى السداد ورفع الإيصال في قسم المدفوعات.',
            ),
          'am' => (
              title: 'ወርሃዊ የትምህርት ክፍያ ማስታወሻ 💳',
              body: hasStudent && hasAmount
                  ? 'የ$student የ$month ወርሃዊ ክፍያ ($amount ብር) ደርሷል። እባክዎ ከፍለው ደረሰኙን ይስቀሉ።'
                  : 'የ$month የቁርኣን ትምህርት ክፍያ ደርሷል። እባክዎ ክፍያዎን ፈጽመው በክፍያ ክፍል ደረሰኙን ይስቀሉ።',
            ),
          _ => (
              title: 'Monthly Tuition Reminder 💳',
              body: hasStudent && hasAmount
                  ? 'Tuition for $student ($month — $amount ETB) is due. Please submit your payment and upload your receipt.'
                  : 'Monthly Quran memorization fee for $month is now due. Please submit your payment and upload the receipt in Payments.',
            ),
        };

      case 'payment_receipt_submitted':
        return switch (lang) {
          'ar' => (
              title: 'تم استلام إيصال دفع 📥',
              body: 'رفع $parent إيصال رسوم شهر $month للمراجعة والاعتماد.',
            ),
          'am' => (
              title: 'የክፍያ ደረሰኝ ቀርቧል 📥',
              body: '$parent የ$month የትምህርት ክፍያ ደረሰኝ ለማረጋገጫ ሰቅለዋል።',
            ),
          _ => (
              title: 'Payment Receipt Submitted 📥',
              body: '$parent uploaded a tuition receipt for $month.',
            ),
        };

      case 'payment_approved':
        return switch (lang) {
          'ar' => (
              title: 'تم اعتماد الدفع ✅',
              body: 'تم التحقق من دفعة الطالب $student لشهر $month واعتمادها.',
            ),
          'am' => (
              title: 'ክፍያው ጸድቋል ✅',
              body: 'የ$student የ$month ወር የትምህርት ክፍያ ተረጋግጦ ጸድቋል።',
            ),
          _ => (
              title: 'Payment Approved ✅',
              body:
                  'Your tuition payment for $month ($student) has been approved.',
            ),
        };

      case 'payment_rejected':
        return switch (lang) {
          'ar' => (
              title: 'إيصال الدفع يحتاج مراجعة ❌',
              body: 'تعذر اعتماد إيصال شهر $month: $reason',
            ),
          'am' => (
              title: 'የክፍያ ደረሰኙ ውድቅ ተደርጓል ❌',
              body: 'የ$month ወር የክፍያ ደረሰኝ ውድቅ ተደርጓል፦ $reason',
            ),
          _ => (
              title: 'Payment Rejected ❌',
              body: 'Your tuition receipt for $month was rejected: $reason',
            ),
        };

      case 'overdue_tuition_admin_alert':
        return switch (lang) {
          'ar' => (
              title: 'تنبيه تأخر سداد الرسوم ⚠️',
              body: 'رسوم الطالب $student (ولي الأمر: $parent) لشهر $month متأخرة عن موعد الاستحقاق.',
            ),
          'am' => (
              title: 'የዘገየ ክፍያ ማንቂያ ⚠️',
              body: 'የተማሪ $student (ወላጅ፦ $parent) የ$month ወር ክፍያ ጊዜው አልፎበታል።',
            ),
          _ => (
              title: 'Overdue Tuition Alert ⚠️',
              body:
                  'Payment for student $student (Parent: $parent) is past due date for $month.',
            ),
        };

      case 'homework_assigned':
        return switch (lang) {
          'ar' => (
              title: 'تم تعيين واجب جديد 📖',
              body: '$hwTitle ($surah، آية $fromAyah-$toAyah)',
            ),
          'am' => (
              title: 'አዲስ የቤት ሥራ ተሰጥቷል 📖',
              body: '$hwTitle ($surah፣ አንቀጽ $fromAyah-$toAyah)',
            ),
          _ => (
              title: 'New Homework Assigned 📖',
              body: '$hwTitle ($surah, Ayah $fromAyah-$toAyah)',
            ),
        };

      case 'homework_submitted':
        final titleSuffix = hwTitle.isNotEmpty ? ' ($hwTitle)' : '';
        return switch (lang) {
          'ar' => (
              title: 'تم إرسال تدريب الواجب 🎙️',
              body: 'أكمل الطالب $student الواجب المنزلي$titleSuffix وأرسله للمراجعة.',
            ),
          'am' => (
              title: 'የቤት ሥራ ቀርቧል 🎙️',
              body: '$student የቤት ሥራውን$titleSuffix አጠናቆ ለግምገማ ልኳል።',
            ),
          _ => (
              title: 'Homework Practiced at Home 🎙️',
              body: '$student completed home practice$titleSuffix for review.',
            ),
        };

      case 'homework_reviewed':
        return switch (lang) {
          'ar' => (
              title: 'قام الأستاذ بتقييم الواجب ⭐',
              body: '$student: $rating',
            ),
          'am' => (
              title: 'ኡስታዝ የቤት ሥራውን ገምግመዋል ⭐',
              body: '$student፦ $rating',
            ),
          _ => (
              title: 'Homework Reviewed by Ustaz ⭐',
              body: '$student: $rating',
            ),
        };

      case 'hifz_logged':
        return switch (lang) {
          'ar' => (
              title: 'تحديث الحفظ اليومي 📖',
              body: 'تسميع $student ($surah): $rating',
            ),
          'am' => (
              title: 'የዕለት ሒፍዝ ተመዝግቧል 📖',
              body: 'የ$student ንባብ ($surah)፦ $rating',
            ),
          _ => (
              title: 'Daily Hifz Logged 📖',
              body: '$student recited $surah ($rating).',
            ),
        };

      case 'attendance_marked':
        return switch (lang) {
          'ar' => (
              title: 'تحديث الحضور اليومي ✓',
              body: 'تم تسجيل $student: $status ($date).',
            ),
          'am' => (
              title: 'የዕለት ክትትል ተዘምኗል ✓',
              body: '$student $status ተብሎ ተመዝግቧል ($date)።',
            ),
          _ => (
              title: 'Daily Attendance Update ✓',
              body: '$student was marked $status ($date).',
            ),
        };

      case 'weekly_report':
        return switch (lang) {
          'ar' => (
              title: 'تقرير التقدم الأسبوعي 📊',
              body: 'التقرير الأسبوعي للطالب $student: $sabaq ($rating).',
            ),
          'am' => (
              title: 'ሳምንታዊ የቁርኣን እድገት ሪፖርት 📊',
              body: 'የ$student ሳምንታዊ ሪፖርት፦ $sabaq ($rating)።',
            ),
          _ => (
              title: 'Weekly Quran Progress Report 📊',
              body: 'Weekly report for $student: $sabaq ($rating).',
            ),
        };

      case 'absence_submitted':
        return switch (lang) {
          'ar' => (
              title: 'طلب إذن غياب جديد 📝',
              body: 'قدّم $parent طلب عذر غياب للطالب $student.',
            ),
          'am' => (
              title: 'አዲስ የፈቃድ ጥያቄ ቀርቧል 📝',
              body: '$parent ለ$student የመቅረት ፈቃድ አቅርበዋል።',
            ),
          _ => (
              title: 'Absence Excuse Request 📝',
              body: '$parent submitted an excuse for $student.',
            ),
        };

      case 'absence_approved':
        return switch (lang) {
          'ar' => (
              title: 'تمت الموافقة على عذر الغياب ✅',
              body: 'تمت الموافقة على عذر الغياب للطالب $student.',
            ),
          'am' => (
              title: 'የመቅረት ፈቃድ ጸድቋል ✅',
              body: 'ለ$student የቀረበው የመቅረት ፈቃድ ጸድቋል።',
            ),
          _ => (
              title: 'Absence Excuse Approved ✅',
              body: 'Absence excuse for $student has been approved.',
            ),
        };

      case 'absence_declined':
        return switch (lang) {
          'ar' => (
              title: 'تحديث طلب الغياب',
              body: 'تم رفض طلب عذر الغياب للطالب $student.',
            ),
          'am' => (
              title: 'የመቅረት ጥያቄ ማሻሻያ',
              body: 'ለ$student የቀረበው የመቅረት ፈቃድ ተቀባይነት አላገኘም።',
            ),
          _ => (
              title: 'Absence Request Update',
              body: 'Absence excuse for $student was declined.',
            ),
        };

      case 'student_enrolled':
        return switch (lang) {
          'ar' => (
              title: 'تم تسجيل طالب جديد 🎓',
              body: 'تم تسجيل $student في حلقة $halaqah وربطه بحسابك.',
            ),
          'am' => (
              title: 'አዲስ ተማሪ ተመዝግቧል 🎓',
              body: '$student በ$halaqah ሐለቃ ተመዝግቦ ከመለያዎ ጋር ተገናኝቷል።',
            ),
          _ => (
              title: 'New Student Enrolled 🎓',
              body:
                  '$student has been enrolled in $halaqah and linked to your account.',
            ),
        };

      case 'chat_voice':
        return switch (lang) {
          'ar' => (
              title: sender,
              body: 'رسالة صوتية (${duration}ث)',
            ),
          'am' => (
              title: sender,
              body: 'የድምጽ መልእክት (${duration}ሴ)',
            ),
          _ => (
              title: sender,
              body: 'Voice message (${duration}s)',
            ),
        };

      case 'chat_photo':
        return switch (lang) {
          'ar' => (
              title: sender,
              body: 'مرفق صورة',
            ),
          'am' => (
              title: sender,
              body: 'የፎቶ አባሪ',
            ),
          _ => (
              title: sender,
              body: 'Photo attachment',
            ),
        };

      case 'chat_document':
        return switch (lang) {
          'ar' => (
              title: sender,
              body: 'مستند: $fileName',
            ),
          'am' => (
              title: sender,
              body: 'ሰነድ፦ $fileName',
            ),
          _ => (
              title: sender,
              body: 'Document: $fileName',
            ),
        };

      case 'chat_message':
        return (
          title: sender,
          body: msgBody.isNotEmpty
              ? msgBody
              : (lang == 'ar'
                  ? 'لديك رسالة جديدة'
                  : (lang == 'am' ? 'አዲስ መልእክት ደርሶዎታል' : 'New message received')),
        );

      case 'security_alert':
        return switch (lang) {
          'ar' => (
              title: 'تنبيه أمني عاجل',
              body: 'حاول $actor الوصول إلى سجل المالية المقيد.',
            ),
          'am' => (
              title: 'አስቸኳይ የደህንነት ማንቂያ',
              body: '$actor የተገደበውን የፋይናንስ መዝገብ ለማግኘት ሞክሯል።',
            ),
          _ => (
              title: 'Security Alert',
              body: '$actor attempted to access restricted financial ledger.',
            ),
        };

      default:
        return (title: fallbackTitle, body: fallbackBody);
    }
  }

  static ({String title, String body}) resolveFromData(
    Map<String, dynamic>? data, {
    required String languageCode,
    required String fallbackTitle,
    required String fallbackBody,
  }) {
    if (data == null || data.isEmpty) {
      return (title: fallbackTitle, body: fallbackBody);
    }
    final nestedMeta = data['metadata'] is Map
        ? Map<String, dynamic>.from(data['metadata'] as Map)
        : null;
    final key = (data['template_key'] ?? nestedMeta?['template_key'])
        ?.toString()
        .trim();
    if (key == null || key.isEmpty) {
      return (title: fallbackTitle, body: fallbackBody);
    }

    final rawParams = data['params'] ?? nestedMeta?['params'];
    var params = <String, dynamic>{};
    if (rawParams is Map) {
      params = Map<String, dynamic>.from(rawParams);
    } else if (rawParams is String && rawParams.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(rawParams);
        if (decoded is Map) {
          params = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    } else {
      // Also support flat fields saved directly in notification data
      params = data;
    }

    return render(
      templateKey: key,
      params: params,
      languageCode: languageCode,
      fallbackTitle: fallbackTitle,
      fallbackBody: fallbackBody,
    );
  }
}
