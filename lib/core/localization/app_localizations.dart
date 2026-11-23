import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// AppLocalizations handles multi-language translation and RTL layout.
/// Supported languages:
/// - English ('en')
/// - Arabic ('ar') with native right-to-left (RTL) reading flow
/// - Amharic ('am') with authentic Ge'ez typography
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isRtl => locale.languageCode == 'ar';
  TextDirection get textDirection =>
      isRtl ? TextDirection.rtl : TextDirection.ltr;

  static final Map<String, Map<String, String>> _localizedValues = {
    // =========================================================================
    // ENGLISH
    // =========================================================================
    'en': {
      // General & Common
      'appName': 'Kheyrukum Islamic Center',
      'greeting': 'Assalamu Alaikum',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'confirm': 'Confirm',
      'close': 'Close',
      'retry': 'Retry',
      'search': 'Search',
      'live': 'LIVE',
      'all': 'All',
      'pending': 'Pending',
      'submitted': 'Submitted',
      'approved': 'Approved',
      'rejected': 'Rejected',
      'overdue': 'Overdue',
      'none': 'None',
      'viewAll': 'View all',
      'post': '+ Post',

      // Navigation Bar
      'navHome': 'Home',
      'navCircles': 'Circles',
      'navMessages': 'Messages',
      'navResources': 'Resources',
      'navMore': 'More',

      // Roles
      'roleSuperadmin': 'Superadmin',
      'roleAdmin': 'Director',
      'roleTeacher': 'Ustaz',
      'roleParent': 'Parent',
      'roleStudent': 'Student',

      // Dashboard
      'academyOverview': 'ACADEMY OVERVIEW',
      'quickActions': 'Quick Actions',
      'schoolAnnouncements': 'School Announcements',
      'officialCirculars': 'Official circulars and schedule notices',
      'studentsCount': 'Students',
      'circlesCount': 'Circles',
      'ustazsCount': 'Ustazs',
      'postNotice': 'Post Notice',
      'inviteCodes': 'Invite Codes',
      'addStudent': 'Add Student',
      'studyCircles': 'Study Circles',

      // Student Enrollment
      'enrollStudent': 'Enroll New Student',
      'studentFullName': 'Student Full Name',
      'studentAge': 'Student Age (Years)',
      'studentPhoto': 'Photo (Optional)',
      'assignedCircle': 'Assigned Study Circle (Halaqah)',
      'parentLinkage': 'Parent Linkage',
      'startingMilestone': 'Starting Memorization Milestone',
      'juzLabel': 'Juz (1-30)',
      'surahLabel': 'Surah (1-114)',

      // User Management
      'userManagement': 'User Management',
      'teachersTab': 'Teachers',
      'parentsTab': 'Parents',
      'adminsTab': 'Admins',
      'invitesTab': 'Invites',
      'promoteUser': 'Promote / Change Role',
      'suspendUser': 'Suspend Account',
      'reactivateUser': 'Reactivate Account',
      'removeUser': 'Remove User',
      'updatePhoto': 'Update Photo',

      // Fees & Payments
      'tuitionAndFees': 'Halaqah Fees & Tuition',
      'issueFee': 'Issue Fee',
      'feeStartDate': 'Fee Start Date',
      'feeAmount': 'Fee Amount',
      'feeMonth': 'Tuition Month',
      'monthlyFeeReminder': 'Monthly Tuition Fee Reminder',
      'uploadReceipt': 'Upload Receipt',
      'receiptProof': 'Bank Receipt Proof',
      'verifyReceipt': 'Verify Receipt',
      'approvePayment': 'Approve Payment',
      'rejectPayment': 'Reject Payment',
      'accessRestrictedFees': 'Payment records are restricted to Super Administrators and Parents.',

      // Settings
      'portalSettings': 'Portal Settings',
      'appearance': 'APPEARANCE',
      'language': 'LANGUAGE / اللغات / ቋንቋ',
      'warmSanctuary': 'Warm Sanctuary',
      'emeraldNight': 'Emerald Night',
      'daylightIvory': 'Daylight Ivory',
      'midnightPine': 'Midnight Pine',
      'accountAndSecurity': 'ACCOUNT & SECURITY',
      'signOut': 'Sign Out',
      'signOutConfirm': 'Are you sure you want to sign out?',
    },

    // =========================================================================
    // ARABIC (العربية) - RTL
    // =========================================================================
    'ar': {
      // General & Common
      'appName': 'مركز خيركم لتحفيظ القرآن',
      'greeting': 'السلام عليكم ورحمة الله',
      'save': 'حفظ',
      'cancel': 'إلغاء',
      'delete': 'حذف',
      'confirm': 'تأكيد',
      'close': 'إغلاق',
      'retry': 'إعادة المحاولة',
      'search': 'بحث',
      'live': 'مباشر',
      'all': 'الكل',
      'pending': 'قيد الانتظار',
      'submitted': 'تم التقديم',
      'approved': 'معتمد',
      'rejected': 'مرفوض',
      'overdue': 'متأخر',
      'none': 'لا يوجد',
      'viewAll': 'عرض الكل',
      'post': '+ نشر',

      // Navigation Bar
      'navHome': 'الرئيسية',
      'navCircles': 'الحلقات',
      'navMessages': 'الرسائل',
      'navResources': 'المكتبة',
      'navMore': 'المزيد',

      // Roles
      'roleSuperadmin': 'المشرف العام',
      'roleAdmin': 'مدير المركز',
      'roleTeacher': 'أستاذ',
      'roleParent': 'ولي أمر',
      'roleStudent': 'طالب',

      // Dashboard
      'academyOverview': 'نظرة عامة على المركز',
      'quickActions': 'إجراءات سريعة',
      'schoolAnnouncements': 'إعلانات المركز',
      'officialCirculars': 'التعاميم الرسمية والمواعيد',
      'studentsCount': 'الطلاب',
      'circlesCount': 'الحلقات',
      'ustazsCount': 'المعلمون',
      'postNotice': 'نشر إعلان',
      'inviteCodes': 'رموز الدعوة',
      'addStudent': 'إضافة طالب',
      'studyCircles': 'حلقات التحفيظ',

      // Student Enrollment
      'enrollStudent': 'تسجيل طالب جديد',
      'studentFullName': 'اسم الطالب الكامل',
      'studentAge': 'عمر الطالب (بالسنوات) *',
      'studentPhoto': 'الصورة الشخصية (اختياري)',
      'assignedCircle': 'حلقة التحفيظ المخصصة',
      'parentLinkage': 'ربط حساب ولي الأمر',
      'startingMilestone': 'بداية مرحلة الحفظ',
      'juzLabel': 'الجزء (1-30)',
      'surahLabel': 'السورة (1-114)',

      // User Management
      'userManagement': 'إدارة المستخدمين',
      'teachersTab': 'المعلمون',
      'parentsTab': 'أولياء الأمور',
      'adminsTab': 'المسؤولون',
      'invitesTab': 'الدعوات',
      'promoteUser': 'ترقية / تعديل الدور',
      'suspendUser': 'تعليق الحساب',
      'reactivateUser': 'تنشيط الحساب',
      'removeUser': 'حذف المستخدم',
      'updatePhoto': 'تعديل الصورة',

      // Fees & Payments
      'tuitionAndFees': 'الرسوم الشهرية والاشتراكات',
      'issueFee': 'إصدار رسوم',
      'feeStartDate': 'تاريخ بدء الرسوم',
      'feeAmount': 'مبلغ الرسوم',
      'feeMonth': 'شهر الرسوم',
      'monthlyFeeReminder': 'تذكير الرسوم الشهرية',
      'uploadReceipt': 'إرفاق الإيصال',
      'receiptProof': 'إيصال التحويل البنكي',
      'verifyReceipt': 'التحقق من الإيصال',
      'approvePayment': 'اعتماد الدفع',
      'rejectPayment': 'رفض الدفع',
      'accessRestrictedFees': 'سجلات الرسوم المالية مقتصرة حصرياً على المشرف العام وأولياء الأمور.',

      // Settings
      'portalSettings': 'إعدادات البوابة',
      'appearance': 'المظهر والسمة',
      'language': 'اللغة / Language / ቋንቋ',
      'warmSanctuary': 'الواحة الهادئة (فاتح)',
      'emeraldNight': 'الليل الزمردي (داكن)',
      'daylightIvory': 'عاجي نهاري',
      'midnightPine': 'صنوبري ليلي',
      'accountAndSecurity': 'الحساب والأمان',
      'signOut': 'تسجيل الخروج',
      'signOutConfirm': 'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
    },

    // =========================================================================
    // AMHARIC (አማርኛ)
    // =========================================================================
    'am': {
      // General & Common
      'appName': 'ኸይሩኩም የቁርኣን ማዕከል',
      'greeting': 'ሰላም ለእናንተ ይሁን',
      'save': 'አስቀምጥ',
      'cancel': 'ሰርዝ',
      'delete': 'አጥፋ',
      'confirm': 'አረጋግጥ',
      'close': 'ዝጋ',
      'retry': 'እንደገና ሞክር',
      'search': 'ፈልግ',
      'live': 'ቀጥታ',
      'all': 'ሁሉም',
      'pending': 'በመጠባበቅ ላይ',
      'submitted': 'የገባ',
      'approved': 'የጸደቀ',
      'rejected': 'ተቀባይነት ያጣ',
      'overdue': 'ያለፈበት',
      'none': 'የለም',
      'viewAll': 'ሁሉንም ተመልከት',
      'post': '+ ፖስት',

      // Navigation Bar
      'navHome': 'ዋና ገጽ',
      'navCircles': 'ሐለቃህ (ክበባት)',
      'navMessages': 'መልእክቶች',
      'navResources': 'መጻሕፍት',
      'navMore': 'ተጨማሪ',

      // Roles
      'roleSuperadmin': 'ዋና አስተዳዳሪ (ሱፐር አድሚን)',
      'roleAdmin': 'የማዕከሉ አስተዳዳሪ',
      'roleTeacher': 'ኡስታዝ (አስተማሪ)',
      'roleParent': 'ወላጅ',
      'roleStudent': 'ተማሪ',

      // Dashboard
      'academyOverview': 'የማዕከሉ አጠቃላይ እይታ',
      'quickActions': 'ፈጣን እርምጃዎች',
      'schoolAnnouncements': 'የትምህርት ቤት ማስታወቂያዎች',
      'officialCirculars': 'ኦፊሴላዊ መግለጫዎች እና የጊዜ ሰሌዳዎች',
      'studentsCount': 'ተማሪዎች',
      'circlesCount': 'ክበባት (ሐለቃህ)',
      'ustazsCount': 'ኡስታዞች',
      'postNotice': 'ማስታወቂያ ለጥፍ',
      'inviteCodes': 'የግብዣ ኮዶች',
      'addStudent': 'ተማሪ መዝግብ',
      'studyCircles': 'የጥናት ክበባት',

      // Student Enrollment
      'enrollStudent': 'አዲስ ተማሪ መመዝገብ',
      'studentFullName': 'የተማሪ ሙሉ ስም',
      'studentAge': 'የተማሪው ዕድሜ (በዓመታት) *',
      'studentPhoto': 'የተማሪ ፎቶ (አማራጭ)',
      'assignedCircle': 'የተመደበበት ሐለቃህ',
      'parentLinkage': 'የወላጅ ግንኙነት',
      'startingMilestone': 'የሂፍዝ መነሻ ደረጃ',
      'juzLabel': 'ጁዝዕ (1-30)',
      'surahLabel': 'ሱራህ (1-114)',

      // User Management
      'userManagement': 'የተጠቃሚዎች አስተዳደር',
      'teachersTab': 'ኡስታዞች',
      'parentsTab': 'ወላጆች',
      'adminsTab': 'አስተዳዳሪዎች',
      'invitesTab': 'ግብዣዎች',
      'promoteUser': 'ደረጃ ከፍ አድርግ / ሚና ቀይር',
      'suspendUser': 'መለያ አግድ',
      'reactivateUser': 'መለያ አንቃ',
      'removeUser': 'ተጠቃሚ አስወግድ',
      'updatePhoto': 'ፎቶ ቀይር',

      // Fees & Payments
      'tuitionAndFees': 'ወርሃዊ የትምህርት ክፍያዎች',
      'issueFee': 'ክፍያ አውጣ',
      'feeStartDate': 'ክፍያ የሚጀምርበት ቀን',
      'feeAmount': 'የክፍያ መጠን',
      'feeMonth': 'የትምህርት ወር',
      'monthlyFeeReminder': 'የወርሃዊ ክፍያ ማሳሰቢያ',
      'uploadReceipt': 'ደረሰኝ ጫን',
      'receiptProof': 'የባንክ ደረሰኝ ማረጋገጫ',
      'verifyReceipt': 'ደረሰኝ አረጋግጥ',
      'approvePayment': 'ክፍያ አጽድቅ',
      'rejectPayment': 'ክፍያ ውድቅ አድርግ',
      'accessRestrictedFees': 'የክፍያ መረጃዎች የሚፈቀዱት ለዋና አስተዳዳሪ (ሱፐር አድሚን) እና ለወላጆች ብቻ ነው።',

      // Settings
      'portalSettings': 'የፖርታል ቅንብሮች',
      'appearance': 'የገጽታ ገጽታ (Appearance)',
      'language': 'ቋንቋ / Language / اللغة',
      'warmSanctuary': 'ሞቃት መቅደስ (ነጭ)',
      'emeraldNight': 'ኤመራልድ ሌሊት (ጥቁር)',
      'daylightIvory': 'የቀን ነጭ',
      'midnightPine': 'የሌሊት አረንጓዴ',
      'accountAndSecurity': 'መለያ እና ደህንነት',
      'signOut': 'ውጣ (Sign Out)',
      'signOutConfirm': 'እርግጠኛ ነዎት ከመለያዎ መውጣት ይፈልጋሉ?',
    },
  };

  String translate(String key) {
    final lang = locale.languageCode;
    return _localizedValues[lang]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }

  // Getters for quick access
  String get appName => translate('appName');
  String get greeting => translate('greeting');
  String get save => translate('save');
  String get cancel => translate('cancel');
  String get delete => translate('delete');
  String get confirm => translate('confirm');
  String get close => translate('close');
  String get retry => translate('retry');
  String get search => translate('search');
  String get live => translate('live');
  String get all => translate('all');
  String get pending => translate('pending');
  String get submitted => translate('submitted');
  String get approved => translate('approved');
  String get rejected => translate('rejected');
  String get overdue => translate('overdue');
  String get viewAll => translate('viewAll');
  String get post => translate('post');

  String get navHome => translate('navHome');
  String get navCircles => translate('navCircles');
  String get navMessages => translate('navMessages');
  String get navResources => translate('navResources');
  String get navMore => translate('navMore');

  String get roleSuperadmin => translate('roleSuperadmin');
  String get roleAdmin => translate('roleAdmin');
  String get roleTeacher => translate('roleTeacher');
  String get roleParent => translate('roleParent');
  String get roleStudent => translate('roleStudent');

  String get academyOverview => translate('academyOverview');
  String get quickActions => translate('quickActions');
  String get schoolAnnouncements => translate('schoolAnnouncements');
  String get officialCirculars => translate('officialCirculars');
  String get studentsCount => translate('studentsCount');
  String get circlesCount => translate('circlesCount');
  String get ustazsCount => translate('ustazsCount');
  String get postNotice => translate('postNotice');
  String get inviteCodes => translate('inviteCodes');
  String get addStudent => translate('addStudent');
  String get studyCircles => translate('studyCircles');

  String get enrollStudent => translate('enrollStudent');
  String get studentFullName => translate('studentFullName');
  String get studentAge => translate('studentAge');
  String get studentPhoto => translate('studentPhoto');
  String get assignedCircle => translate('assignedCircle');
  String get parentLinkage => translate('parentLinkage');
  String get startingMilestone => translate('startingMilestone');
  String get juzLabel => translate('juzLabel');
  String get surahLabel => translate('surahLabel');

  String get userManagement => translate('userManagement');
  String get teachersTab => translate('teachersTab');
  String get parentsTab => translate('parentsTab');
  String get adminsTab => translate('adminsTab');
  String get invitesTab => translate('invitesTab');
  String get promoteUser => translate('promoteUser');
  String get suspendUser => translate('suspendUser');
  String get reactivateUser => translate('reactivateUser');
  String get removeUser => translate('removeUser');
  String get updatePhoto => translate('updatePhoto');

  String get tuitionAndFees => translate('tuitionAndFees');
  String get issueFee => translate('issueFee');
  String get feeStartDate => translate('feeStartDate');
  String get feeAmount => translate('feeAmount');
  String get feeMonth => translate('feeMonth');
  String get monthlyFeeReminder => translate('monthlyFeeReminder');
  String get uploadReceipt => translate('uploadReceipt');
  String get receiptProof => translate('receiptProof');
  String get verifyReceipt => translate('verifyReceipt');
  String get approvePayment => translate('approvePayment');
  String get rejectPayment => translate('rejectPayment');
  String get accessRestrictedFees => translate('accessRestrictedFees');

  String get portalSettings => translate('portalSettings');
  String get appearance => translate('appearance');
  String get language => translate('language');
  String get warmSanctuary => translate('warmSanctuary');
  String get emeraldNight => translate('emeraldNight');
  String get daylightIvory => translate('daylightIvory');
  String get midnightPine => translate('midnightPine');
  String get accountAndSecurity => translate('accountAndSecurity');
  String get signOut => translate('signOut');
  String get signOutConfirm => translate('signOutConfirm');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'ar', 'am'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
