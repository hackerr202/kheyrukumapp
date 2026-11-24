import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
      'optional': 'Optional',
      'submit': 'Submit',
      'create': 'Create',
      'edit': 'Edit',
      'update': 'Update',
      'loading': 'Loading...',
      'copiedToClipboard': 'Copied to clipboard.',
      'yes': 'Yes',
      'no': 'No',
      'today': 'Today',
      'yesterday': 'Yesterday',
      'now': 'Now',

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

      // Auth & Splash
      'welcomeBack': 'Welcome Back',
      'signInToAccount': 'Sign in to Kheyrukum Portal',
      'createAccount': 'Create Account',
      'haveInviteCode': 'Have an Invitation Code?',
      'signIn': 'Sign In',
      'signUp': 'Create Account',
      'email': 'Email Address',
      'password': 'Password',
      'forgotPassword': 'Forgot Password?',
      'resetPassword': 'Reset Password',
      'enterEmailAndPassword': 'Please enter your email and password.',
      'invitationCode': 'Invitation Code',
      'joinWithCode': 'Activate Account',
      'loadingPortal': 'Preparing your portal...',

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
      'centerManagement': 'Center Management',
      'dailyHifzSummary': 'Daily Hifz & Attendance Summary',

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
      'parentEmailOptional': 'Parent Email (Optional)',

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
      'activeStatus': 'Active',
      'suspendedStatus': 'Suspended',

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
      'accessRestrictedFees':
          'Payment records are restricted to Super Administrators and Parents.',
      'sendMonthlyReminders': 'Send Monthly Reminders',
      'allPayments': 'All',
      'pendingReview': 'In Review',
      'collectedTotal': 'Collected',
      'markAsPaid': 'Mark Cash Paid',
      'accountNumber': 'Account No.',
      'schoolPaymentDetails': 'Center Tuition Transfer Details',

      // Messaging & Chat
      'messagesSubtitleAdmin': 'Direct conversations with Ustazs & parents',
      'messagesSubtitleTeacher': 'Class parents, fellow teachers & Director',
      'messagesSubtitleParent': 'Direct channels with Ustaz & Director',
      'searchChatsHint': 'Search chats, parents or circles...',
      'ustazDirect': 'Ustaz Direct',
      'directorDirect': 'Director Direct',
      'classParents': 'Class Parents',
      'allContacts': 'All Contacts',
      'noConversationsYet': 'No conversations yet',
      'noChatsMatching': 'No chats found',
      'startNewChat': 'Start New Chat',
      'clearSearch': 'Clear Search',
      'loadingConversations': 'Loading conversations...',
      'couldNotLoadMessages': 'Could Not Load Messages',
      'newChat': 'New Chat',
      'chooseContactSubtitle': 'Choose a verified school contact',
      'filterContactsHint': 'Filter contacts by name, email or role...',
      'noContactsAvailable': 'No Contacts Available',
      'writeMessageHint': 'Write a message...',
      'holdMicHint': 'Hold microphone button to record a voice note.',
      'deleteMessage': 'Delete Message',
      'deleteMessageConfirm':
          'This will remove the message for everyone in this chat.',
      'editMessage': 'Edit Message',
      'copyMessageText': 'Copy Message Text',
      'shareAttachment': 'Share Attachment',
      'voiceMessage': 'Voice message',
      'photoAttachment': 'Photo',
      'documentAttachment': 'Document',

      // Students, Attendance & Homework
      'studentRoster': 'Student Roster',
      'dailyAttendance': 'Daily Attendance',
      'present': 'Present',
      'lateStatus': 'Late',
      'absent': 'Absent',
      'excused': 'Excused',
      'weeklyReport': 'Weekly Report',
      'weeklyReports': 'Weekly Reports',
      'requestExcuse': 'Request Excuse',
      'submitExcuse': 'Submit Excuse',
      'approveAndExcuse': 'Approve & Excuse',
      'decline': 'Decline',
      'markAllPresent': 'Mark All Present',
      'sabaq': 'Sabaq (New Lesson)',
      'sabqi': 'Sabqi (Recent Revision)',
      'manzil': 'Manzil (Retention)',
      'tajweedEvaluation': 'Tajweed Evaluation',
      'assignedHomework': 'Quran & Tajweed Homework',
      'assignHomework': 'Assign Quran Homework',
      'practiceAtHome': 'Practice at Home',
      'confirmPractice': 'Confirm Practice',
      'endorseSubmission': 'Endorse Submission',
      'submitEndorsement': 'Submit Endorsement',
      'createHalaqahCircle': 'Create Halaqah Circle',
      'manageCircles': 'Manage Study Circles',

      // Announcements & Invites
      'schoolCirculars': 'School Circulars & Notices',
      'postAnnouncement': 'Post Announcement',
      'targetAudience': 'Target Audience',
      'everyone': 'Everyone',
      'teachersOnly': 'Teachers Only',
      'parentsOnly': 'Parents Only',
      'urgentNotice': 'Mark as Urgent Notice',
      'generateInviteCode': 'Generate Invite Code',
      'selectRole': 'Select Target Role',

      // Settings & Account Management
      'portalSettings': 'Portal Settings',
      'portalSettingsSubtitle': 'Appearance, language & account security',
      'appearance': 'APPEARANCE',
      'language': 'LANGUAGE / اللغات / ቋንቋ',
      'warmSanctuary': 'Warm Sanctuary',
      'emeraldNight': 'Emerald Night',
      'systemTheme': 'System',
      'daylightIvory': 'Daylight Ivory',
      'midnightPine': 'Midnight Pine',
      'systemAuto': 'Match Device',
      'accountAndSecurity': 'ACCOUNT & SECURITY',
      'editProfile': 'Edit Profile',
      'editNameAndPhone': 'Edit Name & Phone',
      'fullName': 'Full Name',
      'phoneOptional': 'Phone Number (Optional)',
      'emailAddress': 'Email Address',
      'changePassword': 'Change Password',
      'newPassword': 'New Password',
      'confirmPassword': 'Confirm New Password',
      'passwordsDoNotMatch': 'Passwords do not match.',
      'passwordTooShort': 'Password must be at least 6 characters.',
      'passwordUpdated': 'Password updated successfully.',
      'profileUpdated': 'Profile details updated.',
      'profilePhotoUpdated': 'Profile photo updated successfully.',
      'profilePhotoRemoved': 'Profile photo removed.',
      'chooseFromGallery': 'Choose from Gallery',
      'takePhoto': 'Take Photo',
      'removePhoto': 'Remove Photo',
      'notifications': 'NOTIFICATIONS & ABOUT',
      'notificationsEnabled': 'Push Notifications Active',
      'notificationsDisabled': 'Notifications Disabled',
      'enableNotifications': 'Enable Alerts',
      'aboutApp': 'Kheyrukum Portal',
      'appVersion': 'Version 2.0 • Production Build',
      'signOut': 'Sign Out',
      'signOutConfirm': 'Are you sure you want to sign out of your account?',

      // Offline-First & Auto-Sync
      'offlineModeViewingSaved': 'Offline mode — viewing saved data',
      'offlinePendingChanges': 'changes saved locally',
      'offlineWillSync': 'Will sync automatically',
      'syncingPendingChanges': 'Syncing pending changes...',
      'failedSyncTapToReview': 'changes couldn\'t sync — Tap to review',
      'allChangesSynced': 'All changes synced',
      'syncAndOfflineStorage': 'Sync & Offline Storage',
      'syncQueueSubtitle': 'Pending offline writes & media uploads',
      'syncNow': 'Sync Now',
      'retryAll': 'Retry All',
      'discard': 'Discard',
      'noPendingChanges': 'No Pending Changes',
      'allCaughtUpMessage':
          'All saved attendance, reports, messages, and receipts are synced with the cloud.',
      'lastSynced': 'Last synced',
      'neverSynced': 'Not yet synced in this session',
      'statusOnline': 'Online',
      'statusOffline': 'Offline',
      'internetRequiredAction': 'Internet connection required for this action.',
      'signOutUnsyncedWarning':
          'You have unsynced offline changes that will be permanently lost if you sign out before reconnecting.',
      'savedOfflineQueued':
          'Saved offline — will sync automatically when connected.',
      'syncingStatus': 'Syncing',
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
      'optional': 'اختياري',
      'submit': 'إرسال',
      'create': 'إنشاء',
      'edit': 'تعديل',
      'update': 'تحديث',
      'loading': 'جارٍ التحميل...',
      'copiedToClipboard': 'تم النسخ إلى الحافظة.',
      'yes': 'نعم',
      'no': 'لا',
      'today': 'اليوم',
      'yesterday': 'أمس',
      'now': 'الآن',

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

      // Auth & Splash
      'welcomeBack': 'مرحباً بعودتك',
      'signInToAccount': 'تسجيل الدخول إلى بوابة خيركم',
      'createAccount': 'إنشاء حساب جديد',
      'haveInviteCode': 'هل لديك رمز دعوة؟',
      'signIn': 'تسجيل الدخول',
      'signUp': 'إنشاء الحساب',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'forgotPassword': 'نسيت كلمة المرور؟',
      'resetPassword': 'استعادة كلمة المرور',
      'enterEmailAndPassword': 'يرجى إدخال البريد الإلكتروني وكلمة المرور.',
      'invitationCode': 'رمز الدعوة',
      'joinWithCode': 'تفعيل الحساب',
      'loadingPortal': 'جارٍ تجهيز البوابة...',

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
      'centerManagement': 'إدارة المركز',
      'dailyHifzSummary': 'ملخص الحفظ والحضور اليومي',

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
      'parentEmailOptional': 'البريد الإلكتروني لولي الأمر (اختياري)',

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
      'activeStatus': 'نشط',
      'suspendedStatus': 'معلّق',

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
      'accessRestrictedFees':
          'سجلات الرسوم المالية مقتصرة حصرياً على المشرف العام وأولياء الأمور.',
      'sendMonthlyReminders': 'إرسال تذكيرات شهرية',
      'allPayments': 'الكل',
      'pendingReview': 'قيد المراجعة',
      'collectedTotal': 'المحصّل',
      'markAsPaid': 'تسجيل الدفع نقداً',
      'accountNumber': 'رقم الحساب',
      'schoolPaymentDetails': 'بيانات التحويل البنكي للمركز',

      // Messaging & Chat
      'messagesSubtitleAdmin': 'محادثات مباشرة مع المعلمين وأولياء الأمور',
      'messagesSubtitleTeacher': 'أولياء أمور الحلقة والمعلمون وإدارة المركز',
      'messagesSubtitleParent': 'قنوات تواصل مباشرة مع الأستاذ والإدارة',
      'searchChatsHint': 'ابحث في المحادثات أو أولياء الأمور أو الحلقات...',
      'ustazDirect': 'مراسلة الأستاذ',
      'directorDirect': 'مراسلة الإدارة',
      'classParents': 'أولياء أمور الحلقة',
      'allContacts': 'جميع جهات الاتصال',
      'noConversationsYet': 'لا توجد محادثات بعد',
      'noChatsMatching': 'لم يتم العثور على محادثات',
      'startNewChat': 'بدء محادثة جديدة',
      'clearSearch': 'مسح البحث',
      'loadingConversations': 'جارٍ تحميل المحادثات...',
      'couldNotLoadMessages': 'تعذر تحميل الرسائل',
      'newChat': 'محادثة جديدة',
      'chooseContactSubtitle': 'اختر جهة اتصال معتمدة من المركز',
      'filterContactsHint': 'تصفية بالاسم أو البريد أو الدور...',
      'noContactsAvailable': 'لا توجد جهات اتصال متاحة',
      'writeMessageHint': 'اكتب رسالة...',
      'holdMicHint': 'اضغط مطولاً على زر الميكروفون لتسجيل رسالة صوتية.',
      'deleteMessage': 'حذف الرسالة',
      'deleteMessageConfirm':
          'سيتم حذف هذه الرسالة للجميع في هذه المحادثة.',
      'editMessage': 'تعديل الرسالة',
      'copyMessageText': 'نسخ نص الرسالة',
      'shareAttachment': 'مشاركة مرفق',
      'voiceMessage': 'رسالة صوتية',
      'photoAttachment': 'صورة',
      'documentAttachment': 'مستند',

      // Students, Attendance & Homework
      'studentRoster': 'سجل الطلاب',
      'dailyAttendance': 'الحضور اليومي',
      'present': 'حاضر',
      'lateStatus': 'متأخر',
      'absent': 'غائب',
      'excused': 'بعذر',
      'weeklyReport': 'التقرير الأسبوعي',
      'weeklyReports': 'التقارير الأسبوعية',
      'requestExcuse': 'طلب عذر غياب',
      'submitExcuse': 'إرسال العذر',
      'approveAndExcuse': 'قبول العذر',
      'decline': 'رفض',
      'markAllPresent': 'تحضير الجميع',
      'sabaq': 'السبق (الدرس الجديد)',
      'sabqi': 'السبقي (المراجعة القريبة)',
      'manzil': 'المنزل (المراجعة البعيدة)',
      'tajweedEvaluation': 'تقييم التجويد',
      'assignedHomework': 'واجبات القرآن والتجويد',
      'assignHomework': 'تعيين واجب قرآني',
      'practiceAtHome': 'التدريب المنزلي',
      'confirmPractice': 'تأكيد التدريب',
      'endorseSubmission': 'اعتماد المراجعة',
      'submitEndorsement': 'إرسال التقييم',
      'createHalaqahCircle': 'إنشاء حلقة تحفيظ',
      'manageCircles': 'إدارة حلقات التحفيظ',

      // Announcements & Invites
      'schoolCirculars': 'تعميمات وإعلانات المركز',
      'postAnnouncement': 'نشر إعلان جديد',
      'targetAudience': 'الفئة المستهدفة',
      'everyone': 'الجميع',
      'teachersOnly': 'المعلمون فقط',
      'parentsOnly': 'أولياء الأمور فقط',
      'urgentNotice': 'تحديد كإعلان عاجل',
      'generateInviteCode': 'إنشاء رمز دعوة',
      'selectRole': 'اختر الدور المستهدف',

      // Settings & Account Management
      'portalSettings': 'إعدادات البوابة',
      'portalSettingsSubtitle': 'المظهر واللغة وأمان الحساب',
      'appearance': 'المظهر والسمة',
      'language': 'اللغة / Language / ቋንቋ',
      'warmSanctuary': 'الواحة الهادئة',
      'emeraldNight': 'الليل الزمردي',
      'systemTheme': 'النظام',
      'daylightIvory': 'عاجي نهاري',
      'midnightPine': 'صنوبري ليلي',
      'systemAuto': 'تلقائي حسب الجهاز',
      'accountAndSecurity': 'الحساب والأمان',
      'editProfile': 'تعديل الملف',
      'editNameAndPhone': 'تعديل الاسم ورقم الهاتف',
      'fullName': 'الاسم الكامل',
      'phoneOptional': 'رقم الهاتف (اختياري)',
      'emailAddress': 'البريد الإلكتروني',
      'changePassword': 'تغيير كلمة المرور',
      'newPassword': 'كلمة المرور الجديدة',
      'confirmPassword': 'تأكيد كلمة المرور الجديدة',
      'passwordsDoNotMatch': 'كلمتا المرور غير متطابقتين.',
      'passwordTooShort': 'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل.',
      'passwordUpdated': 'تم تحديث كلمة المرور بنجاح.',
      'profileUpdated': 'تم تحديث بيانات الملف الشخصي.',
      'profilePhotoUpdated': 'تم تحديث الصورة الشخصية بنجاح.',
      'profilePhotoRemoved': 'تمت إزالة الصورة الشخصية.',
      'chooseFromGallery': 'اختيار من المعرض',
      'takePhoto': 'التقاط صورة',
      'removePhoto': 'إزالة الصورة',
      'notifications': 'الإشعارات ومعلومات التطبيق',
      'notificationsEnabled': 'إشعارات الدفع مفعّلة',
      'notificationsDisabled': 'الإشعارات معطّلة',
      'enableNotifications': 'تفعيل التنبيهات',
      'aboutApp': 'بوابة خيركم',
      'appVersion': 'الإصدار 2.0 • نسخة الإنتاج',
      'signOut': 'تسجيل الخروج',
      'signOutConfirm': 'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟',

      // Offline-First & Auto-Sync
      'offlineModeViewingSaved': 'وضع عدم الاتصال — عرض البيانات المحفوظة',
      'offlinePendingChanges': 'تغييرات محفوظة محلياً',
      'offlineWillSync': 'ستتم المزامنة تلقائياً',
      'syncingPendingChanges': 'جارٍ مزامنة التغييرات المعلقة...',
      'failedSyncTapToReview': 'تغييرات تعذرت مزامنتها — اضغط للمراجعة',
      'allChangesSynced': 'تمت مزامنة جميع التغييرات',
      'syncAndOfflineStorage': 'المزامنة والتخزين دون اتصال',
      'syncQueueSubtitle': 'العمليات والوسائط المعلقة للمزامنة',
      'syncNow': 'مزامنة الآن',
      'retryAll': 'إعادة المحاولة للكل',
      'discard': 'تجاهل',
      'noPendingChanges': 'لا توجد تغييرات معلقة',
      'allCaughtUpMessage':
          'جميع سجلات الحضور والتقارير والرسائل والإيصالات متزامنة مع السحابة.',
      'lastSynced': 'آخر مزامنة',
      'neverSynced': 'لم تتم المزامنة بعد في هذه الجلسة',
      'statusOnline': 'متصل',
      'statusOffline': 'غير متصل',
      'internetRequiredAction': 'يلزم الاتصال بالإنترنت لتنفيذ هذا الإجراء.',
      'signOutUnsyncedWarning':
          'لديك تغييرات غير متزامنة ستفقد نهائياً إذا سجلت الخروج قبل إعادة الاتصال بالإنترنت.',
      'savedOfflineQueued':
          'تم الحفظ دون اتصال — ستتم المزامنة تلقائياً عند توفر الإنترنت.',
      'syncingStatus': 'جارٍ المزامنة',
    },

    // =========================================================================
    // AMHARIC (አማርኛ) - Ge'ez Script
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
      'post': '+ ለጥፍ',
      'optional': 'አማራጭ',
      'submit': 'ላክ',
      'create': 'ፍጠር',
      'edit': 'አርትዕ',
      'update': 'አዘምን',
      'loading': 'በመጫን ላይ...',
      'copiedToClipboard': 'ወደ ክሊፕቦርድ ተቀድቷል።',
      'yes': 'አዎ',
      'no': 'አይ',
      'today': 'ዛሬ',
      'yesterday': 'ትናንት',
      'now': 'አሁን',

      // Navigation Bar
      'navHome': 'ዋና ገጽ',
      'navCircles': 'ሐለቃዎች',
      'navMessages': 'መልእክቶች',
      'navResources': 'መጻሕፍት',
      'navMore': 'ተጨማሪ',

      // Roles
      'roleSuperadmin': 'ዋና አስተዳዳሪ',
      'roleAdmin': 'የማዕከሉ አስተዳዳሪ',
      'roleTeacher': 'ኡስታዝ',
      'roleParent': 'ወላጅ',
      'roleStudent': 'ተማሪ',

      // Auth & Splash
      'welcomeBack': 'እንኳን በደህና ተመለሱ',
      'signInToAccount': 'ወደ ኸይሩኩም ፖርታል ይግቡ',
      'createAccount': 'አዲስ መለያ ፍጠር',
      'haveInviteCode': 'የግብዣ ኮድ አለዎት?',
      'signIn': 'ግባ',
      'signUp': 'መለያ ፍጠር',
      'email': 'ኢሜይል',
      'password': 'የይለፍ ቃል',
      'forgotPassword': 'የይለፍ ቃል ረስተዋል?',
      'resetPassword': 'የይለፍ ቃል ዳግም አስጀምር',
      'enterEmailAndPassword': 'እባክዎ ኢሜይል እና የይለፍ ቃል ያስገቡ።',
      'invitationCode': 'የግብዣ ኮድ',
      'joinWithCode': 'መለያ አንቃ',
      'loadingPortal': 'ፖርታሉ በመዘጋጀት ላይ ነው...',

      // Dashboard
      'academyOverview': 'የማዕከሉ አጠቃላይ እይታ',
      'quickActions': 'ፈጣን እርምጃዎች',
      'schoolAnnouncements': 'የማዕከሉ ማስታወቂያዎች',
      'officialCirculars': 'ኦፊሴላዊ መግለጫዎች እና መርሃ ግብሮች',
      'studentsCount': 'ተማሪዎች',
      'circlesCount': 'ሐለቃዎች',
      'ustazsCount': 'ኡስታዞች',
      'postNotice': 'ማስታወቂያ ለጥፍ',
      'inviteCodes': 'የግብዣ ኮዶች',
      'addStudent': 'ተማሪ መዝግብ',
      'studyCircles': 'የቁርኣን ሐለቃዎች',
      'centerManagement': 'የማዕከሉ አስተዳደር',
      'dailyHifzSummary': 'ዕለታዊ የሂፍዝ እና የተገኝነት ማጠቃለያ',

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
      'parentEmailOptional': 'የወላጅ ኢሜይል (አማራጭ)',

      // User Management
      'userManagement': 'የተጠቃሚዎች አስተዳደር',
      'teachersTab': 'ኡስታዞች',
      'parentsTab': 'ወላጆች',
      'adminsTab': 'አስተዳዳሪዎች',
      'invitesTab': 'ግብዣዎች',
      'promoteUser': 'ደረጃ አሳድግ / ሚና ቀይር',
      'suspendUser': 'መለያ አግድ',
      'reactivateUser': 'መለያ አንቃ',
      'removeUser': 'ተጠቃሚ አስወግድ',
      'updatePhoto': 'ፎቶ ቀይር',
      'activeStatus': 'ንቁ',
      'suspendedStatus': 'የታገደ',

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
      'accessRestrictedFees':
          'የክፍያ መረጃዎች የሚፈቀዱት ለዋና አስተዳዳሪ እና ለወላጆች ብቻ ነው።',
      'sendMonthlyReminders': 'ወርሃዊ ማሳሰቢያ ላክ',
      'allPayments': 'ሁሉም',
      'pendingReview': 'በግምገማ ላይ',
      'collectedTotal': 'የተሰበሰበ',
      'markAsPaid': 'በጥሬ ገንዘብ ተከፍሏል',
      'accountNumber': 'የሂሳብ ቁጥር',
      'schoolPaymentDetails': 'የማዕከሉ የባንክ ዝርዝር',

      // Messaging & Chat
      'messagesSubtitleAdmin': 'ከኡስታዞች እና ከወላጆች ጋር ቀጥታ ውይይት',
      'messagesSubtitleTeacher': 'የክፍል ወላጆች፣ ኡስታዞች እና አስተዳዳሪ',
      'messagesSubtitleParent': 'ከኡስታዝ እና ከአስተዳዳሪ ጋር ቀጥታ መገናኛ',
      'searchChatsHint': 'ውይይቶችን፣ ወላጆችን ወይም ሐለቃዎችን ፈልግ...',
      'ustazDirect': 'ከኡስታዝ ጋር',
      'directorDirect': 'ከአስተዳዳሪ ጋር',
      'classParents': 'የክፍል ወላጆች',
      'allContacts': 'ሁሉም እውቂያዎች',
      'noConversationsYet': 'እስካሁን ምንም ውይይት የለም',
      'noChatsMatching': 'ተዛማጅ ውይይት አልተገኘም',
      'startNewChat': 'አዲስ ውይይት ጀምር',
      'clearSearch': 'ፍለጋን አጽዳ',
      'loadingConversations': 'ውይይቶች በመጫን ላይ ናቸው...',
      'couldNotLoadMessages': 'መልእክቶችን መጫን አልተቻለም',
      'newChat': 'አዲስ ውይይት',
      'chooseContactSubtitle': 'የተረጋገጠ የማዕከል እውቂያ ይምረጡ',
      'filterContactsHint': 'በስም፣ በኢሜይል ወይም በሚና አጣራ...',
      'noContactsAvailable': 'ምንም እውቂያ አልተገኘም',
      'writeMessageHint': 'መልእክት ይጻፉ...',
      'holdMicHint': 'የድምጽ መልእክት ለመቅዳት ማይክሮፎኑን ተጭነው ይያዙ።',
      'deleteMessage': 'መልእክት ሰርዝ',
      'deleteMessageConfirm': 'ይህ መልእክት በውይይቱ ውስጥ ለሁሉም ሰው ይጠፋል።',
      'editMessage': 'መልእክት አርትዕ',
      'copyMessageText': 'ጽሑፍ ቅዳ',
      'shareAttachment': 'ፋይል አጋራ',
      'voiceMessage': 'የድምጽ መልእክት',
      'photoAttachment': 'ፎቶ',
      'documentAttachment': 'ሰነድ',

      // Students, Attendance & Homework
      'studentRoster': 'የተማሪዎች ዝርዝር',
      'dailyAttendance': 'ዕለታዊ ተገኝነት',
      'present': 'ተገኝቷል',
      'lateStatus': 'ዘግይቷል',
      'absent': 'ቀርቷል',
      'excused': 'በፈቃድ የቀረ',
      'weeklyReport': 'ሳምንታዊ ሪፖርት',
      'weeklyReports': 'ሳምንታዊ ሪፖርቶች',
      'requestExcuse': 'የፈቃድ ጥያቄ አቅርብ',
      'submitExcuse': 'ጥያቄ ላክ',
      'approveAndExcuse': 'አጽድቅና ፍቀድ',
      'decline': 'ውድቅ አድርግ',
      'markAllPresent': 'ሁሉም ተገኝተዋል በል',
      'sabaq': 'ሰበቅ (አዲስ ትምህርት)',
      'sabqi': 'ሰብቂ (የቅርብ ክለሳ)',
      'manzil': 'መንዚል (ማጽናት)',
      'tajweedEvaluation': 'የተጅዊድ ግምገማ',
      'assignedHomework': 'የቁርኣን እና የተጅዊድ የቤት ሥራ',
      'assignHomework': 'የቁርኣን የቤት ሥራ ስጥ',
      'practiceAtHome': 'በቤት ልምምድ',
      'confirmPractice': 'ልምምዱን አረጋግጥ',
      'endorseSubmission': 'ግምገማ ስጥ',
      'submitEndorsement': 'ግምገማ ላክ',
      'createHalaqahCircle': 'አዲስ ሐለቃህ ፍጠር',
      'manageCircles': 'ሐለቃዎችን አስተዳድር',

      // Announcements & Invites
      'schoolCirculars': 'የማዕከሉ ማስታወቂያዎች',
      'postAnnouncement': 'ማስታወቂያ አውጣ',
      'targetAudience': 'ዒላማ ተመልካቾች',
      'everyone': 'ሁሉም ሰው',
      'teachersOnly': 'ኡስታዞች ብቻ',
      'parentsOnly': 'ወላጆች ብቻ',
      'urgentNotice': 'እንደ አስቸኳይ ምልክት አድርግ',
      'generateInviteCode': 'የግብዣ ኮድ ፍጠር',
      'selectRole': 'ሚና ይምረጡ',

      // Settings & Account Management
      'portalSettings': 'የፖርታል ቅንብሮች',
      'portalSettingsSubtitle': 'ገጽታ፣ ቋንቋ እና የመለያ ደህንነት',
      'appearance': 'ገጽታ',
      'language': 'ቋንቋ / Language / اللغة',
      'warmSanctuary': 'ብሩህ ቀን',
      'emeraldNight': 'ኤመራልድ ሌሊት',
      'systemTheme': 'ስርዓት',
      'daylightIvory': 'የቀን ነጭ',
      'midnightPine': 'የሌሊት አረንጓዴ',
      'systemAuto': 'ከመሣሪያው ጋር አዛምድ',
      'accountAndSecurity': 'መለያ እና ደህንነት',
      'editProfile': 'መገለጫ አርትዕ',
      'editNameAndPhone': 'ስም እና ስልክ አርትዕ',
      'fullName': 'ሙሉ ስም',
      'phoneOptional': 'ስልክ ቁጥር (አማራጭ)',
      'emailAddress': 'ኢሜይል አድራሻ',
      'changePassword': 'የይለፍ ቃል ቀይር',
      'newPassword': 'አዲስ የይለፍ ቃል',
      'confirmPassword': 'አዲሱን የይለፍ ቃል አረጋግጥ',
      'passwordsDoNotMatch': 'የይለፍ ቃሎቹ አይዛመዱም።',
      'passwordTooShort': 'የይለፍ ቃል ቢያንስ 6 ቁምፊዎች መሆን አለበት።',
      'passwordUpdated': 'የይለፍ ቃል በተሳካ ሁኔታ ተቀይሯል።',
      'profileUpdated': 'የመገለጫ መረጃ ተዘምኗል።',
      'profilePhotoUpdated': 'የመገለጫ ፎቶ በተሳካ ሁኔታ ተዘምኗል።',
      'profilePhotoRemoved': 'የመገለጫ ፎቶ ተወግዷል።',
      'chooseFromGallery': 'ከጋለሪ ምረጥ',
      'takePhoto': 'ፎቶ አንሳ',
      'removePhoto': 'ፎቶ አስወግድ',
      'notifications': 'ማሳወቂያዎች እና መረጃ',
      'notificationsEnabled': 'ማሳወቂያዎች በርተዋል',
      'notificationsDisabled': 'ማሳወቂያዎች ጠፍተዋል',
      'enableNotifications': 'ማሳወቂያዎችን አንቃ',
      'aboutApp': 'ኸይሩኩም ፖርታል',
      'appVersion': 'ስሪት 2.0 • ዋና እትም',
      'signOut': 'ውጣ',
      'signOutConfirm': 'እርግጠኛ ነዎት ከመለያዎ መውጣት ይፈልጋሉ?',

      // Offline-First & Auto-Sync
      'offlineModeViewingSaved': 'ከመስመር ውጭ — የተቀመጠ መረጃ በማየት ላይ',
      'offlinePendingChanges': 'ለውጦች በመሣሪያው ላይ ተቀምጠዋል',
      'offlineWillSync': 'በራስ-ሰር ይመሳሰላል',
      'syncingPendingChanges': 'በመጠባበቅ ላይ ያሉ ለውጦችን በማመሳሰል ላይ...',
      'failedSyncTapToReview': 'ያልተመሳሰሉ ለውጦች — ለመገምገም ይንኩ',
      'allChangesSynced': 'ሁሉም ለውጦች ተመሳስለዋል',
      'syncAndOfflineStorage': 'ማመሳሰል እና ከመስመር ውጭ ማከማቻ',
      'syncQueueSubtitle': 'በመጠባበቅ ላይ ያሉ ከመስመር ውጭ ለውጦች',
      'syncNow': 'አሁን አመሳስል',
      'retryAll': 'ሁሉንም እንደገና ሞክር',
      'discard': 'አስወግድ',
      'noPendingChanges': 'ምንም በመጠባበቅ ላይ ያለ ለውጥ የለም',
      'allCaughtUpMessage':
          'ሁሉም መገኘት፣ ሪፖርቶች፣ መልዕክቶች እና ደረሰኞች ከደመና ጋር ተመሳስለዋል።',
      'lastSynced': 'መጨረሻ የተመሳሰለበት',
      'neverSynced': 'በዚህ ክፍለ ጊዜ ገና አልተመሳሰለም',
      'statusOnline': 'በመስመር ላይ',
      'statusOffline': 'ከመስመር ውጭ',
      'internetRequiredAction': 'ለዚህ ተግባር የኢንተርኔት ግንኙነት ያስፈልጋል።',
      'signOutUnsyncedWarning':
          'ወደ መስመር ከመመለስዎ በፊት ከወጡ በቋሚነት የሚጠፉ ያልተመሳሰሉ ከመስመር ውጭ ለውጦች አሉዎት።',
      'savedOfflineQueued':
          'ከመስመር ውጭ ተቀምጧል — ግንኙነት ሲመለስ በራስ-ሰር ይመሳሰላል።',
      'syncingStatus': 'በማመሳሰል ላይ',
    },
  };

  String translate(String key) {
    final lang = locale.languageCode;
    return _localizedValues[lang]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }

  // General & Common
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
  String get none => translate('none');
  String get viewAll => translate('viewAll');
  String get post => translate('post');
  String get optional => translate('optional');
  String get submit => translate('submit');
  String get create => translate('create');
  String get edit => translate('edit');
  String get update => translate('update');
  String get loading => translate('loading');
  String get copiedToClipboard => translate('copiedToClipboard');
  String get today => translate('today');
  String get yesterday => translate('yesterday');
  String get now => translate('now');

  // Navigation
  String get navHome => translate('navHome');
  String get navCircles => translate('navCircles');
  String get navMessages => translate('navMessages');
  String get navResources => translate('navResources');
  String get navMore => translate('navMore');

  // Roles
  String get roleSuperadmin => translate('roleSuperadmin');
  String get roleAdmin => translate('roleAdmin');
  String get roleTeacher => translate('roleTeacher');
  String get roleParent => translate('roleParent');
  String get roleStudent => translate('roleStudent');

  // Auth
  String get welcomeBack => translate('welcomeBack');
  String get signInToAccount => translate('signInToAccount');
  String get createAccount => translate('createAccount');
  String get haveInviteCode => translate('haveInviteCode');
  String get signIn => translate('signIn');
  String get signUp => translate('signUp');
  String get email => translate('email');
  String get password => translate('password');
  String get forgotPassword => translate('forgotPassword');
  String get resetPassword => translate('resetPassword');
  String get enterEmailAndPassword => translate('enterEmailAndPassword');
  String get invitationCode => translate('invitationCode');
  String get joinWithCode => translate('joinWithCode');
  String get loadingPortal => translate('loadingPortal');

  // Dashboard & Overview
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
  String get centerManagement => translate('centerManagement');
  String get dailyHifzSummary => translate('dailyHifzSummary');

  // Student Enrollment
  String get enrollStudent => translate('enrollStudent');
  String get studentFullName => translate('studentFullName');
  String get studentAge => translate('studentAge');
  String get studentPhoto => translate('studentPhoto');
  String get assignedCircle => translate('assignedCircle');
  String get parentLinkage => translate('parentLinkage');
  String get startingMilestone => translate('startingMilestone');
  String get juzLabel => translate('juzLabel');
  String get surahLabel => translate('surahLabel');
  String get parentEmailOptional => translate('parentEmailOptional');

  // User Management
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
  String get activeStatus => translate('activeStatus');
  String get suspendedStatus => translate('suspendedStatus');

  // Fees & Payments
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
  String get sendMonthlyReminders => translate('sendMonthlyReminders');
  String get allPayments => translate('allPayments');
  String get pendingReview => translate('pendingReview');
  String get collectedTotal => translate('collectedTotal');
  String get markAsPaid => translate('markAsPaid');
  String get accountNumber => translate('accountNumber');
  String get schoolPaymentDetails => translate('schoolPaymentDetails');

  // Messaging & Chat
  String get messagesSubtitleAdmin => translate('messagesSubtitleAdmin');
  String get messagesSubtitleTeacher => translate('messagesSubtitleTeacher');
  String get messagesSubtitleParent => translate('messagesSubtitleParent');
  String get searchChatsHint => translate('searchChatsHint');
  String get ustazDirect => translate('ustazDirect');
  String get directorDirect => translate('directorDirect');
  String get classParents => translate('classParents');
  String get allContacts => translate('allContacts');
  String get noConversationsYet => translate('noConversationsYet');
  String get noChatsMatching => translate('noChatsMatching');
  String get startNewChat => translate('startNewChat');
  String get clearSearch => translate('clearSearch');
  String get loadingConversations => translate('loadingConversations');
  String get couldNotLoadMessages => translate('couldNotLoadMessages');
  String get newChat => translate('newChat');
  String get chooseContactSubtitle => translate('chooseContactSubtitle');
  String get filterContactsHint => translate('filterContactsHint');
  String get noContactsAvailable => translate('noContactsAvailable');
  String get writeMessageHint => translate('writeMessageHint');
  String get holdMicHint => translate('holdMicHint');
  String get deleteMessage => translate('deleteMessage');
  String get deleteMessageConfirm => translate('deleteMessageConfirm');
  String get editMessage => translate('editMessage');
  String get copyMessageText => translate('copyMessageText');
  String get shareAttachment => translate('shareAttachment');
  String get voiceMessage => translate('voiceMessage');
  String get photoAttachment => translate('photoAttachment');
  String get documentAttachment => translate('documentAttachment');

  // Students, Attendance & Homework
  String get studentRoster => translate('studentRoster');
  String get dailyAttendance => translate('dailyAttendance');
  String get present => translate('present');
  String get lateStatus => translate('lateStatus');
  String get absent => translate('absent');
  String get excused => translate('excused');
  String get weeklyReport => translate('weeklyReport');
  String get weeklyReports => translate('weeklyReports');
  String get requestExcuse => translate('requestExcuse');
  String get submitExcuse => translate('submitExcuse');
  String get approveAndExcuse => translate('approveAndExcuse');
  String get decline => translate('decline');
  String get markAllPresent => translate('markAllPresent');
  String get sabaq => translate('sabaq');
  String get sabqi => translate('sabqi');
  String get manzil => translate('manzil');
  String get tajweedEvaluation => translate('tajweedEvaluation');
  String get assignedHomework => translate('assignedHomework');
  String get assignHomework => translate('assignHomework');
  String get practiceAtHome => translate('practiceAtHome');
  String get confirmPractice => translate('confirmPractice');
  String get endorseSubmission => translate('endorseSubmission');
  String get submitEndorsement => translate('submitEndorsement');
  String get createHalaqahCircle => translate('createHalaqahCircle');
  String get manageCircles => translate('manageCircles');

  // Announcements & Invites
  String get schoolCirculars => translate('schoolCirculars');
  String get postAnnouncement => translate('postAnnouncement');
  String get targetAudience => translate('targetAudience');
  String get everyone => translate('everyone');
  String get teachersOnly => translate('teachersOnly');
  String get parentsOnly => translate('parentsOnly');
  String get urgentNotice => translate('urgentNotice');
  String get generateInviteCode => translate('generateInviteCode');
  String get selectRole => translate('selectRole');

  // Settings & Account Management
  String get portalSettings => translate('portalSettings');
  String get portalSettingsSubtitle => translate('portalSettingsSubtitle');
  String get appearance => translate('appearance');
  String get language => translate('language');
  String get warmSanctuary => translate('warmSanctuary');
  String get emeraldNight => translate('emeraldNight');
  String get systemTheme => translate('systemTheme');
  String get daylightIvory => translate('daylightIvory');
  String get midnightPine => translate('midnightPine');
  String get systemAuto => translate('systemAuto');
  String get accountAndSecurity => translate('accountAndSecurity');
  String get editProfile => translate('editProfile');
  String get editNameAndPhone => translate('editNameAndPhone');
  String get fullName => translate('fullName');
  String get phoneOptional => translate('phoneOptional');
  String get emailAddress => translate('emailAddress');
  String get changePassword => translate('changePassword');
  String get newPassword => translate('newPassword');
  String get confirmPassword => translate('confirmPassword');
  String get passwordsDoNotMatch => translate('passwordsDoNotMatch');
  String get passwordTooShort => translate('passwordTooShort');
  String get passwordUpdated => translate('passwordUpdated');
  String get profileUpdated => translate('profileUpdated');
  String get profilePhotoUpdated => translate('profilePhotoUpdated');
  String get profilePhotoRemoved => translate('profilePhotoRemoved');
  String get chooseFromGallery => translate('chooseFromGallery');
  String get takePhoto => translate('takePhoto');
  String get removePhoto => translate('removePhoto');
  String get notifications => translate('notifications');
  String get notificationsEnabled => translate('notificationsEnabled');
  String get notificationsDisabled => translate('notificationsDisabled');
  String get enableNotifications => translate('enableNotifications');
  String get aboutApp => translate('aboutApp');
  String get appVersion => translate('appVersion');
  String get signOut => translate('signOut');
  String get signOutConfirm => translate('signOutConfirm');

  // Offline-First & Auto-Sync
  String get offlineModeViewingSaved => translate('offlineModeViewingSaved');
  String get offlinePendingChanges => translate('offlinePendingChanges');
  String get offlineWillSync => translate('offlineWillSync');
  String get syncingPendingChanges => translate('syncingPendingChanges');
  String get failedSyncTapToReview => translate('failedSyncTapToReview');
  String get allChangesSynced => translate('allChangesSynced');
  String get syncAndOfflineStorage => translate('syncAndOfflineStorage');
  String get syncQueueSubtitle => translate('syncQueueSubtitle');
  String get syncNow => translate('syncNow');
  String get retryAll => translate('retryAll');
  String get discard => translate('discard');
  String get noPendingChanges => translate('noPendingChanges');
  String get allCaughtUpMessage => translate('allCaughtUpMessage');
  String get lastSynced => translate('lastSynced');
  String get neverSynced => translate('neverSynced');
  String get statusOnline => translate('statusOnline');
  String get statusOffline => translate('statusOffline');
  String get internetRequiredAction => translate('internetRequiredAction');
  String get signOutUnsyncedWarning => translate('signOutUnsyncedWarning');
  String get savedOfflineQueued => translate('savedOfflineQueued');
  String get syncingStatus => translate('syncingStatus');
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

/// Registered AFTER GlobalMaterialLocalizations.delegate so native Material
/// localizations (including Arabic RTL) load natively, falling back only when
/// an unsupported locale is requested.
class FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      !GlobalMaterialLocalizations.delegate.isSupported(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    return SynchronousFuture<MaterialLocalizations>(
      const DefaultMaterialLocalizations(),
    );
  }

  @override
  bool shouldReload(FallbackMaterialLocalizationsDelegate old) => false;
}

/// Registered AFTER GlobalCupertinoLocalizations.delegate so native Cupertino
/// localizations (including Arabic RTL) load natively, falling back only when
/// an unsupported locale (e.g. Amharic on older engines) is requested.
class FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      !GlobalCupertinoLocalizations.delegate.isSupported(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    return SynchronousFuture<CupertinoLocalizations>(
      const DefaultCupertinoLocalizations(),
    );
  }

  @override
  bool shouldReload(FallbackCupertinoLocalizationsDelegate old) => false;
}
