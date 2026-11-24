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
      'openStatus': 'Open',
      'currentJuzMetric': 'Current Juz',
      'ayahMetric': 'Ayah',
      'ayahValueLabel': 'Ayah {ayah}',
      'receiptAttachedInspect': 'Receipt Screenshot Attached • Tap to Inspect',
      'studentGender': 'Gender',
      'male': 'Male',
      'female': 'Female',
      'editStudent': 'Edit Student',
      'studentEnrolledMsg': 'Student "{name}" enrolled successfully.',
      'studentUpdatedMsg': 'Updated "{name}" successfully.',
      'enrollmentFailedMsg': 'Enrollment failed: {error}',
      'updateFailedMsg': 'Update failed: {error}',
      'noHalaqahsYetMsg': 'No halaqahs yet. Create one first.',
      'parentFallbackWithValue': '{name} ({contact})',
      'portalTagline': 'Parent & Teacher Quranic Collaborative Portal',
      'roleGroup': 'Group',
      'userFallback': 'User',
      'administratorTitle': 'Administrator',
      'centerDirectorTitle': 'Center Director',
      'centerAdministrationTitle': 'Center Administration',
      'assignedUstazTitle': 'Assigned Ustaz',
      'studyCircleFallback': 'Study Circle',
      'accessRestrictedTitle': 'Access Restricted',
      'sessionPermissionsUnverified': 'Your session permissions could not be verified.',
      'unknownError': 'Unknown error',
      'unableToConnectServer': 'Unable to connect to server.',
      'justNow': 'Just now',
      'minutesAgo': '{count}m ago',
      'minutesShort': '{count}m',
      'hoursAgo': '{count}h ago',
      'amLabel': 'AM',
      'pmLabel': 'PM',
      'reminderTag': 'REMINDER',
      'noticeTag': 'NOTICE',
      'timeForPrayerDefault': 'Time for Prayer',
      'prayerReminderBodyDefault': 'Take a peaceful moment to remember Allah.',
      'adhanPrayerReminderTitle': 'Adhan & Prayer Reminder',
      'understood': 'Understood',
      'savingProgress': 'Saving...',
      'submittingProgress': 'Submitting...',
      'assigningProgress': 'Assigning...',
      'changeAction': 'Change',
      'copyAction': 'Copy',
      'copyCodeTooltip': 'Copy Code',
      'copiedCodeMsg': 'Copied "{code}" to clipboard.',
      'copiedLabelMsg': '{label} copied to clipboard.',
      'activeTag': 'ACTIVE',
      'usedTag': 'USED',
      'activeLabel': 'Active',
      'reviewAction': 'Review',
      'juzOf30': 'Juz {juz} of 30',
      'juzShort': 'Juz {juz}',
      'juzSurahAyahSummary': 'Juz {juz} • Surah #{surah}, Ayah {ayah}',
      'languageEnglishLabel': 'English',
      'languageArabicLabel': 'Arabic',
      'languageAmharicLabel': 'Amharic',
      'studentCountOne': '1 Student Enrolled',
      'studentCountMany': '{count} Students Enrolled',
      'ustazStudentsMeta': 'Ustaz: {name} • {countLabel}',
      'dailyCurriculumDesc': 'Daily Curriculum: Sabaq (new memorization), Sabqi (recent revision), and Manzil (cumulative revision). Record daily attendance and keep parents updated.',
      'classRosterHeader': 'CLASS ROSTER',
      'noStudentsCurrentlyAssigned': 'No students currently assigned.',
      'manageUsersSubtitle': 'Manage teachers, parents, circle assignments & access',
      'manageCirclesSubtitle': 'Create circles, assign Ustazs & view enrollment',
      'generateInvitesSubtitle': 'Generate sign-up codes for teachers & parents',
      'rosterAndCurriculumMeta': '{circle} • Roster & Curriculum',
      'broadcastNoticesSubtitle': 'Broadcast notices to parents & teachers',
      'parentFeesSubtitle': 'Upload bank receipts & check monthly fee status',
      'adminFeesSubtitle': 'Issue monthly tuition, verify receipts & overdue alerts',
      'centerSetupTitle': 'Center Setup',
      'completeOnboardingSubtitle': 'Complete onboarding to launch all circles',
      'stepsOf3': '{count} of 3',
      'checklistStep1': 'Create a study circle (Halaqah)',
      'checklistStep2': 'Generate a teacher invite code',
      'checklistStep3': 'Enroll your first student',
      'createFirstHalaqahAction': 'Create First Halaqah',
      'generateTeacherCodeAction': 'Generate Teacher Invite Code',
      'enrollFirstStudentAction': 'Enroll First Student',
      'assignedStudyCircleHeader': 'ASSIGNED STUDY CIRCLE',
      'studentsBadgeLabel': '{count} Students',
      'studentBadgeOne': '1 Student',
      'todaysAttendanceLabel': 'Today\'s Attendance',
      'markedProgressLabel': '{marked} / {total} marked',
      'pendingExcusesNoticeOne': '1 pending absence excuse to review',
      'pendingExcusesNoticeMany': '{count} pending absence excuses to review',
      'takeAttendanceAction': 'Take Attendance',
      'homeworkLabel': 'Homework',
      'familyLearningHubHeader': 'FAMILY LEARNING HUB',
      'welcomeParentFallback': 'Welcome Parent',
      'enrolledCountBadge': '{count} Enrolled',
      'todayAttBadge': 'Today: {status}',
      'noChildrenLinkedBanner': 'No children linked to your account yet. Please contact center administration.',
      'learningProgressAction': 'Learning Progress',
      'noAnnouncementsTitle': 'No announcements yet',
      'noAnnouncementsDesc': 'Official circulars and center notices will appear here as soon as they are published.',
      'pinnedTag': 'Pinned',
      'centerNoticeTag': 'CENTER NOTICE',
      'attachmentFallback': 'Attachment',
      'tapToOpenConvo': 'Tap to open conversation',
      'messageClassParentTitle': 'Message Class Parent',
      'selectParentFromCircle': 'Select a parent from {circle}',
      'noStudentsInClassTitle': 'No students in class',
      'noStudentsInCircleMsg': 'No students are currently assigned to your study circle.',
      'noLinkedParentMsg': '{name} does not have a linked parent account yet.',
      'couldNotOpenChatMsg': 'Could not open chat: {error}',
      'couldNotStartChatMsg': 'Could not start chat: {error}',
      'adminMessagingHubTitle': 'Admin Messaging Hub',
      'adminMessagingHubSubtitle': 'Start a direct chat or circle group',
      'messageTeacherOrParent': 'Message Teacher or Parent',
      'browseActiveContacts': 'Browse all active staff and parent contacts',
      'studyCircleParentsGroupFallback': 'Study Circle Parents Group',
      'failedToCreateGroupMsg': 'Failed to create group: {error}',
      'createParentGroupTitle': 'Create Parent Halaqah Group',
      'createParentGroupSubtitle': 'Group discussion with circle parents',
      'studentContactMeta': 'Student: {name} • {phone}',
      'tajweedAndRecitationHeader': 'TAJWEED & RECITATION',
      'assignSurahGoalsHint': 'Assign Surah goals and Tajweed rules to your circle. Review submissions when parents log home practice.',
      'noHomeworkFoundTitle': 'No Homework Tasks Found',
      'noHomeworkForCircleMsg': 'No homework has been assigned for {circle} yet. Tap "{action}" to give your students their first recitation goal.',
      'practicedAtHomeCount': '{completed} of {total} Practiced at Home',
      'noStudentsInHalaqahTitle': 'No students in circle',
      'noEnrolledStudentsHalaqahMsg': 'No enrolled students found for this halaqah.',
      'reviewedStatus': 'Reviewed',
      'practicedStatus': 'Practiced',
      'needsPracticeStatus': 'Needs Practice',
      'homeRepetitionsLine': 'Home Repetitions: {count}x recited with parent',
      'parentNoteQuote': 'Parent Note: "{note}"',
      'ratingExcellent': 'Excellent',
      'ratingVeryGood': 'Very Good',
      'ratingGood': 'Good',
      'ratingNeedsRevision': 'Needs Revision',
      'ratingFeedbackLine': 'Rating: {rating} • "{feedback}"',
      'submissionEndorsedMsg': 'Submission endorsed for {name}.',
      'homeworkAssignedMsg': 'Homework assigned successfully.',
      'noLinkedChildrenTitle': 'No Linked Children',
      'noLinkedChildrenDesc': 'No children are currently linked to your parent account. Contact center administration to enroll your children.',
      'tasksCountBadge': '{count} Tasks',
      'noHomeworkAssignedTitle': 'No Homework Tasks Assigned',
      'ustazNoHomeworkYetMsg': 'Ustaz has not posted any homework tasks for {name}\'s circle yet.',
      'surahAyahRange': '{surah} (Ayahs {from}–{to})',
      'surahAyahWithTeacher': '{surah} (Ayahs {from}–{to}) • Ustaz: {teacher}',
      'dueDateLabel': 'Due: {date}',
      'completedRepetitionsLine': 'Completed: {count}x recited at home',
      'yourNoteQuote': 'Your Note: "{note}"',
      'ustazGradeLine': 'Ustaz Grade: {rating}',
      'feedbackQuote': 'Feedback: "{feedback}"',
      'markedPracticedMsg': 'Marked practiced for {name}. Ustaz notified.',
      'totalAssignmentsMeta': '{count} total assignments across study circles',
      'noHomeworkRecordedTitle': 'No Homework Tasks Recorded',
      'teachersNoHomeworkYetMsg': 'Teachers have not created any homework tasks across any study circles yet.',
      'defaultEndorseFeedback': 'Masha\'Allah excellent recitation with clear Tajweed.',
      'gradePracticeTitle': 'Grade {name}\'s Practice',
      'recitationRatingLabel': 'Recitation Rating',
      'ustazFeedbackLabel': 'Ustaz Feedback / Advice',
      'ustazFeedbackHint': 'Enter guidance for parent and student...',
      'failedEndorseMsg': 'Failed to submit endorsement: {error}',
      'defaultHomeworkTitle': 'Surah Memorization & Tajweed',
      'defaultTajweedFocus': 'Ghunnah & Ikhfa Rules',
      'defaultHomeworkInstructions': 'Recite each verse at least 3 times focusing on correct elongation and nasalization.',
      'circlePrefixLabel': 'Circle: {circle}',
      'assignmentTitleLabel': 'Assignment Title',
      'assignmentTitleHint': 'e.g. Surah Al-Mulk Practice',
      'surahNameLabel': 'Surah Name',
      'fromAyahLabel': 'From Ayah',
      'toAyahLabel': 'To Ayah',
      'tajweedFocusLabel': 'Tajweed Rule Focus',
      'tajweedFocusHint': 'e.g. Qalqalah, Ghunnah, Madd',
      'instructionsParentsStudentsLabel': 'Instructions for Parents & Students',
      'changeDateAction': 'Change Date',
      'failedAssignHomeworkMsg': 'Failed to assign homework: {error}',
      'defaultPracticeNote': 'Recited smoothly with parent.',
      'practiceForStudentTitle': 'Practice for {name}',
      'repetitionsQuestion': 'How many times did your child recite at home?',
      'repetitionsCountLabel': '{count} Repetitions',
      'parentNotesOptionalLabel': 'Parent Notes (Optional)',
      'parentNotesHint': 'e.g. Read smoothly, struggled on Ayah 7...',
      'failedSavePracticeMsg': 'Failed to save practice: {error}',
      'assignedClassHeader': 'ASSIGNED CLASS',
      'allPresentSuccessMsg': 'All class students marked Present. Parents notified.',
      'failedMarkAttendanceMsg': 'Failed to mark attendance: {error}',
      'allPresentAction': 'All Present',
      'pendingAbsenceExcusesTitle': 'Pending Absence Excuses ({count})',
      'submittedByParentsSubtitle': 'Submitted by parents for review',
      'reasonLabelValue': 'Reason: {reason}',
      'absenceExcuseApprovedMsg': 'Absence excuse approved for {name}.',
      'failedApproveRequestMsg': 'Failed to approve request: {error}',
      'failedDeclineRequestMsg': 'Failed to decline request: {error}',
      'classAttendanceSheetTitle': 'Class Attendance Sheet',
      'classAttendanceSheetSubtitle': 'Tap a status to record attendance; parents are notified automatically.',
      'noStudentsInThisCircleTitle': 'No students enrolled in this circle',
      'studentsAssignedByAdminMsg': 'Students assigned to {circle} by administration will appear here.',
      'attendanceForDateLabel': 'Attendance for {date}',
      'todayDateParens': 'Today ({date})',
      'messageParentAction': 'Message Parent',
      'attendanceHistoryTitle': 'Attendance History',
      'studentMarkedStatusMsg': '{name} marked {status}. Parent notified.',
      'failedSaveAttendanceMsg': 'Failed to save attendance: {error}',
      'noChildrenLinkedTitle': 'No Children Linked',
      'whenAdminEnrollsChildMsg': 'When center administration enrolls your child and links them to your account, their Quran progress and attendance will appear here.',
      'myEnrolledChildrenHeader': 'My Enrolled Children ({count})',
      'messageUstazAction': 'Message Ustaz',
      'quranMemorizationProgressTitle': 'Quran Memorization Progress',
      'unrecordedStatus': 'Unrecorded',
      'declinedStatus': 'Declined',
      'excuseReasonLine': 'Excuse: {reason}',
      'noAttendanceLoggedTitle': 'No attendance logged yet',
      'dailyAttendanceAppearHereMsg': 'Daily attendance entries recorded by Ustaz will appear here.',
      'weeklyQuranProgressReportsTitle': 'Weekly Quran Progress Reports',
      'sabaqSabqiManzilSubtitle': 'Sabaq, Sabqi, Manzil & Tajweed evaluations',
      'noWeeklyReportsTitle': 'No weekly reports yet',
      'weeklyReportsAppearHereMsg': 'Weekly memorization and Tajweed evaluations will appear here once published.',
      'parentContactLine': 'Parent: {name}{contact}',
      'removeStudentConfirmTitle': 'Remove {name}?',
      'removeStudentConfirmBody': 'This will permanently remove this student and their linked records from the roster.',
      'removeAction': 'Remove',
      'removedStudentMsg': 'Removed {name} from roster.',
      'failedRemoveStudentPermsMsg': 'Failed to remove student. Please check permissions.',
      'failedRemoveStudentMsg': 'Failed to remove student: {error}',
      'removeStudentMenuLabel': 'Remove Student',
      'attendanceShortTab': 'Attendance',
      'reportShortTab': 'Report',
      'messageShortAction': 'Message',
      'attendanceLogTitle': 'Attendance Log: {name}',
      'noAttendanceRecordedYet': 'No attendance recorded yet.',
      'attendanceRecordedNotifyMsg': 'Attendance recorded. Parent {name} notified.',
      'weeklyReportPostedNotifyMsg': 'Weekly report posted. Parent {name} notified.',
      'defaultAttendedOnTime': 'Attended circle on time',
      'weekOfDateLabel': 'Week of {date}',
      'ustazNotesQuote': 'Ustaz Notes: "{notes}"',
      'absenceExcuseSubmittedMsg': 'Absence excuse submitted for {name}. Ustaz notified.',
      'reasonMedical': 'Medical / Illness',
      'reasonFamilyEmergency': 'Family Emergency',
      'reasonSchoolExam': 'School Academic Exam',
      'reasonTravel': 'Travel / Out of Town',
      'reasonPersonal': 'Personal Reason',
      'editRemarksTitle': 'Edit Remarks: {name}',
      'teacherRemarksLabel': 'Teacher Remarks / Notes',
      'failedSaveNoteMsg': 'Failed to save note: {error}',
      'saveNoteAction': 'Save Note',
      'dailyAttendanceTitle': 'Daily Attendance: {name}',
      'statusFieldLabel': 'Status',
      'teacherRemarksShortLabel': 'Teacher Remarks',
      'saveAndNotifyAction': 'Save & Notify',
      'defaultSabaqSample': 'Surah Al-Mulk (1-15)',
      'defaultSabqiSample': 'Surah Al-Qalam (1-20)',
      'defaultManzilSample': 'Juz 29 Retention',
      'defaultReportRemarks': 'Consistent Tajweed articulation.',
      'weeklyReportTitle': 'Weekly Report: {name}',
      'sabaqNewLessonLabel': 'Sabaq (New Lesson)',
      'sabqiRecentRevisionLabel': 'Sabqi (Recent Revision)',
      'manzilRetentionLabel': 'Manzil (Retention)',
      'ustazEvaluationNotesLabel': 'Ustaz Evaluation Notes',
      'failedSubmitReportMsg': 'Failed to submit report: {error}',
      'submitAndNotifyAction': 'Submit & Notify',
      'defaultExcuseNote': 'Feeling unwell and needs rest at home.',
      'requestExcuseTitle': 'Request Excuse: {name}',
      'dateLineLabel': 'Date: {date}',
      'reasonForAbsenceLabel': 'Reason for Absence',
      'parentExplanationLabel': 'Parent Explanation',
      'parentExplanationHint': 'Enter reason details for the teacher...',
      'failedSubmitExcuseMsg': 'Failed to submit excuse: {error}',
      'cbeBankName': 'Commercial Bank of Ethiopia (CBE)',
      'telebirrAccountLabel': 'Telebirr Mobile Account',
      'cbeMobileBanking': 'CBE Mobile Banking',
      'telebirrMobile': 'Telebirr Mobile',
      'cashDepositLabel': 'Cash Deposit',
      'cashSlipLabel': 'Cash Slip',
      'paymentVerificationRejectedTitle': 'Payment Verification Rejected',
      'reuploadValidReceiptAction': 'Re-upload Valid Receipt',
      'monthlyTuitionHeader': 'MONTHLY TUITION',
      'studentLineLabel': 'Student: {name}',
      'perMonthlyFeeSuffix': '/ Monthly Fee',
      'verifiedApprovedByLine': 'Verified & approved by {name}.',
      'receiptUploadedVerifyingMsg': 'Receipt uploaded. Administration is verifying your payment.',
      'uploadReceiptScreenshotAction': 'Upload Payment Receipt Screenshot',
      'noTuitionDueTitle': 'No Tuition Due At This Time',
      'noTuitionDueDesc': 'When center administration issues monthly tuition fees for your student, your invoices will appear here.',
      'paymentHistoryCount': 'Payment History ({count})',
      'toReviewTab': 'To Review',
      'receiptsAwaitingReviewTitle': 'Receipts Awaiting Review ({count})',
      'actionRequiredTag': 'Action Required',
      'overdueAccountsTitle': 'Overdue Accounts ({count})',
      'pastDueTag': 'Past Due',
      'tuitionRecordsTitle': 'Tuition Records ({count})',
      'plusIssueTuition': '+ Issue Tuition',
      'noTuitionIssuedTitle': 'No Tuition Fees Issued Yet',
      'noTuitionIssuedDesc': 'Issue monthly tuition fees to enrolled students so parents can make payments and upload receipts.',
      'issueFirstTuitionAction': 'Issue First Tuition Fee',
      'parentEmailLine': 'Parent: {name} ({email})',
      'overdueUpperTag': 'OVERDUE',
      'overdueAlertDispatchedMsg': 'Overdue alert dispatched for {name}.',
      'sendAlertAction': 'Send Alert',
      'paymentApprovedForMsg': 'Payment approved for {name}.',
      'rejectAction': 'Reject',
      'approveAction': 'Approve',
      'amountLineLabel': 'Amount: \${amount}',
      'viewReceiptAction': 'View Receipt',
      'rejectionReasonQuote': 'Rejection Reason: "{reason}"',
      'noStudentsEnrolledAlertTitle': 'No Students Enrolled',
      'addOneStudentBeforeTuitionMsg': 'Please add at least one student in the Students tab before issuing tuition fees.',
      'receiptInspectorTitle': 'Receipt Inspector',
      'couldNotLoadReceiptImage': 'Could not load receipt image',
      'tapToZoomHint': 'Tap to Zoom',
      'paymentSummaryHeader': 'PAYMENT SUMMARY',
      'rejectWithReasonAction': 'Reject with Reason',
      'receiptImageTitle': 'Receipt Image',
      'enterTuitionMonthError': 'Please enter the tuition month label.',
      'enterValidTuitionAmountError': 'Please enter a valid tuition fee amount (> 0).',
      'tuitionIssuedForMsg': 'Tuition issued for {name}.',
      'defaultReceiptNote': 'Payment completed via mobile banking.',
      'receiptSubmittedSuccessMsg': 'Receipt submitted successfully. Admin will verify.',
      'uploadPaymentReceiptTitle': 'Upload Payment Receipt',
      'studentMonthLine': 'Student: {name} ({month})',
      'amountDueLine': 'Amount Due: \${amount}',
      'paymentChannelLabel': 'Payment Channel',
      'selectedFileLabel': 'Selected: {name}',
      'tapPickReceiptHint': 'Tap to Pick Receipt Screenshot',
      'tapToChangeImage': 'Tap to change image',
      'chooseSlipFromGallery': 'Choose payment slip or screenshot from gallery',
      'transactionRefLabel': 'Transaction Reference / Notes',
      'submitReceiptAction': 'Submit Receipt',
      'defaultRejectReceiptReason': 'The uploaded screenshot is blurry and the transaction reference number cannot be read. Please re-upload.',
      'paymentRejectedSentMsg': 'Payment rejected and reason sent to {name}.',
      'rejectPaymentReceiptTitle': 'Reject Payment Receipt',
      'specifyRejectionReasonMsg': 'Specify why {name}\'s receipt is rejected. This reason will be shown to the parent.',
      'rejectionReasonRequiredLabel': 'Rejection Reason *',
      'rejectionReasonHint': 'e.g. Blurry screenshot, incorrect amount, missing reference...',
      'confirmRejectionAction': 'Confirm Rejection',
      'failedSendMsg': 'Failed to send message: {error}',
      'micPermissionRequiredMsg': 'Microphone permission is required to record voice notes.',
      'couldNotStartRecordingMsg': 'Could not start recording: {error}',
      'voiceFileUnavailableMsg': 'Voice recording file is no longer available.',
      'voiceExceedsLimitMsg': 'Voice recording exceeds the 25 MB limit.',
      'voiceMessageWithDuration': 'Voice message ({duration})',
      'failedStopRecordingMsg': 'Failed to stop recording: {error}',
      'failedSendVoiceMsg': 'Failed to send voice recording: {error}',
      'voiceUrlUnavailableMsg': 'Voice audio URL is not available.',
      'offlineVoiceNotFoundMsg': 'Offline voice recording file not found.',
      'couldNotAccessVoiceMsg': 'Could not access voice note audio.',
      'errorPlayingAudioMsg': 'Error playing audio: {error}',
      'imageExceedsLimitMsg': 'Image exceeds the 25 MB limit. Please select a smaller file.',
      'failedUploadImageMsg': 'Failed to upload image to cloud storage.',
      'failedAttachImageMsg': 'Failed to attach image: {error}',
      'videoExceedsLimitMsg': 'Video exceeds the 25 MB limit. Please select a shorter clip.',
      'failedUploadVideoMsg': 'Failed to upload video to cloud storage.',
      'failedAttachVideoMsg': 'Failed to attach video: {error}',
      'docExceedsLimitMsg': 'Document exceeds the 25 MB limit. Please select a smaller file.',
      'failedUploadDocMsg': 'Failed to upload document to cloud storage.',
      'failedAttachDocMsg': 'Failed to attach document: {error}',
      'shareAttachmentSubtitle': 'Photos, videos, files, or Quranic reflection',
      'cameraOption': 'Camera',
      'galleryOption': 'Gallery',
      'videoOption': 'Video',
      'ayahQuoteOption': 'Ayah Quote',
      'ayahKahf1810Quote': 'Surah Al-Kahf (18:10): "Our Lord, grant us from Yourself mercy and prepare for us from our affair right guidance."',
      'openInBrowserTooltip': 'Open in browser',
      'failedLoadImagePreview': 'Failed to load image preview',
      'failedDeleteMsg': 'Failed to delete message: {error}',
      'ustazDirectChannel': 'Ustaz Direct Channel',
      'parentDirectChannel': 'Parent Direct Channel',
      'centerChannel': 'Center Channel',
      'directSchoolChannel': 'Direct School Channel',
      'emptyChatPrompt': 'Send a message, document, photo, or voice note to begin.',
      'uploadingAttachmentToCloud': 'Uploading attachment to cloud...',
      'recordingVoiceNoteLabel': 'Recording voice note...',
      'editedTag': 'edited ',
      'viewAction': 'View',
      'videoFileFallback': 'Video File',
      'tapToPlayVideo': 'Tap to play video',
      'couldNotOpenDocUrl': 'Could not open document URL.',
      'tapToViewDownload': 'Tap to view / download',
      'enterUpdatedMsgHint': 'Enter updated message...',
      'failedEditMsg': 'Failed to edit message: {error}',
      'noCirclesCreatedTitle': 'No Study Circles Created Yet',
      'createFirstCircleDesc': 'Create your first Halaqah circle to assign teachers and enroll students.',
      'createFirstCircleAction': 'Create First Circle',
      'deleteCircleTooltip': 'Delete Circle',
      'deleteCircleConfirmTitle': 'Delete Circle?',
      'deleteCircleConfirmBody': 'Are you sure you want to remove "{name}"?',
      'removedCircleMsg': 'Removed circle "{name}".',
      'couldNotDeleteCircleMsg': 'Could not delete circle: {error}',
      'ustazNameLabel': 'Ustaz: {name}',
      'defaultCircleSchedule': 'Daily Recitation Session',
      'circleCreatedSuccessMsg': 'Study Circle "{name}" created successfully.',
      'failedCreateCircleMsg': 'Failed to create circle: {error}',
      'createStudyCircleTitle': 'Create Study Circle',
      'halaqahNameReqLabel': 'Halaqah Name *',
      'assignTeacherOptionalHint': 'Assign Teacher (Optional)',
      'unassignedAssignLater': 'Unassigned (Assign later)',
      'scheduleFieldLabel': 'Schedule',
      'scheduleHint': 'e.g. Mon-Fri 4:00 PM - 6:00 PM',
      'curriculumFocusLabel': 'Circle Notes / Curriculum Focus',
      'curriculumFocusHint': 'e.g. Juz Amma memorization and Makharij revision',
      'createCircleAction': 'Create Circle',
      'noActiveCodesTitle': 'No active codes',
      'generateInviteOnboardingDesc': 'Generate a Teacher or Parent invite code above to onboard new members.',
      'activeCodeReadyTitle': 'Active Code Ready',
      'liveInvitationCodesTitle': 'Live Invitation Codes',
      'noInviteCodesGeneratedYet': 'No invitation codes generated yet.',
      'failedGenerateCodeMsg': 'Failed to generate code',
      'teacherRoleTag': 'TEACHER',
      'parentRoleTag': 'PARENT',
      'suspendWord': 'Suspend',
      'activateWord': 'Activate',
      'suspendActivateConfirmTitle': '{action} {name}?',
      'suspendWarningMsg': 'Suspended users will immediately be prevented from signing in and accessing center data.',
      'activateRestoredMsg': 'The user account will be restored and allowed to log in.',
      'failedUpdateUserStatusMsg': 'Failed to update user status: {error}',
      'userSuspendedMsg': '{name} has been suspended.',
      'userReactivatedMsg': '{name} has been reactivated.',
      'removeUserAccountTitle': 'Remove User Account?',
      'removeUserAccountBody': 'Are you sure you want to permanently remove "{name}"? This action cannot be undone.',
      'removePermanentlyAction': 'Remove Permanently',
      'failedRemoveUserMsg': 'Failed to remove user: {error}',
      'failedRemoveUserSimple': 'Failed to remove user.',
      'removedUserFromCenterMsg': 'Removed {name} from center.',
      'createCircleFirstMsg': 'Please create a Study Circle (Halaqah) first.',
      'assignTeacherTitle': 'Assign {name}',
      'unassignedRemoveFromCircle': 'Unassigned (Remove from Circle)',
      'studyCircleHalaqahLabel': 'Study Circle (Halaqah)',
      'failedUpdateAssignmentMsg': 'Failed to update circle assignment: {error}',
      'profilePhotoUpdatedUserMsg': '{name} profile photo updated.',
      'couldNotUpdatePhotoMsg': 'Could not update photo: {error}',
      'changeRoleForTitle': 'Change Role for {name}',
      'selectPermissionsPrompt': 'Select permissions and access level for this user:',
      'superadminFullControlTitle': 'Superadmin (Full Control)',
      'superadminFullControlDesc': 'Full access including payments, fees, and user role promotion',
      'adminRoleDescTitle': 'Admin (Center Administrator)',
      'adminRoleDescSubtitle': 'Study circles, students, attendance, homework (No payment access)',
      'teacherRoleDescTitle': 'Teacher (Ustaz)',
      'teacherRoleDescSubtitle': 'Assigned study circle, attendance, and recitation grading',
      'parentRoleDescSubtitle': 'Linked children, weekly reports, and tuition payment',
      'cannotDemoteSelfNote': 'Note: You cannot demote your own active Superadmin account.',
      'failedUpdateRoleMsg': 'Failed to update role: {error}',
      'updateRoleAction': 'Update Role',
      'onlyAdminsManageUsersMsg': 'Only center administrators can manage user accounts.',
      'couldNotLoadUsersTitle': 'Could not load users',
      'noUsersFoundTitle': 'No {role}s found',
      'tryModifyingSearchMsg': 'Try clearing or modifying your search query.',
      'registeredUsersAppearMsg': 'Registered {role}s will appear here.',
      'noContactInfo': 'No contact info',
      'unassignedCircleLabel': 'Unassigned Circle',
      'promoteChangeRoleAction': 'Promote / Change Role',
      'assignHalaqahAction': 'Assign Halaqah',
      'reactivateAccountAction': 'Reactivate Account',
      'suspendAccountAction': 'Suspend Account',
      'noMatchingInviteCodes': 'No matching invite codes',
      'noInviteCodesActive': 'No invitation codes active',
      'generateInviteTopRightHint': 'Generate an invite code from the top right button.',
      'teacherRegistrationLabel': 'Teacher Registration',
      'parentRegistrationLabel': 'Parent Registration',
      'deleteInviteCodeTooltip': 'Delete Invite Code',
      'failedDeleteInviteCodeMsg': 'Failed to delete invite code.',
      'noticesAndActivityTitle': 'Notices & Activity',
      'circularsAndAlertsSubtitle': 'Circulars & alerts',
      'postShortButton': 'Post',
      'noAlertsYetTitle': 'No alerts yet',
      'noAlertsYetDesc': 'Daily attendance updates, weekly reports, and tuition reminders will appear here.',
      'markAllReadAction': 'Mark all read',
      'noNoticesFoundTitle': 'No notices found',
      'noNoticesFilterDesc': 'No center announcements match the selected filter.',
      'openTuitionPaymentsAction': 'Open Tuition & Payments',
      'imageUnavailableLabel': 'Image unavailable',
      'attachedDocumentFallback': 'Attached document',
      'attachedFileSuccessMsg': 'Attached "{name}" successfully.',
      'attachedPhotoSuccessMsg': 'Attached photo "{name}" successfully.',
      'announcementBroadcastedMsg': 'Announcement broadcasted to all users successfully.',
      'broadcastCircularTitle': 'Broadcast Circular',
      'pushNoticeSubtitle': 'Push notice to parents & teachers',
      'circularTitleHeader': 'CIRCULAR TITLE',
      'circularTitleHint': 'e.g. Ramadan Recitation Schedule & Timings',
      'messageContentHeader': 'MESSAGE CONTENT',
      'messageContentHint': 'Write the complete circular text here...',
      'attachmentHeader': 'ATTACHMENT',
      'uploadingAttachmentCloudMsg': 'Uploading attachment to cloud storage...',
      'attachedFileFallback': 'Attached File',
      'readyStatusTag': 'Ready',
      'removeAttachmentTooltip': 'Remove Attachment',
      'attachPhotoAction': 'Attach Photo',
      'attachFileAction': 'Attach File',
      'pinCircularLabel': 'Pin this circular to the top of Home screen',
      'signInFailedMsg': 'Sign in failed.',
      'invalidInviteCodeMsg': 'Invalid invite code.',
      'registrationFailedMsg': 'Registration failed.',
      'kheyrukumSupportTitle': 'Kheyrukum Support',
      'supportAddressSubtitle': 'Addis Ababa, Bethel / Near Bethel Hospital',
      'telegramOfficialLabel': 'Telegram Official',
      'whatsappOfficialLabel': 'WhatsApp Official',
      'directPhoneSupportLabel': 'Direct Phone Support',
      'needAssistancePrompt': 'Need assistance from center administration?',
      'parentEmailHint': 'parent@kheyrukum.com',
      'exampleEmailHint': 'name@example.com',
      'enterRegCodePrompt': 'Enter the registration code provided by center administration.',
      'inviteCodeExampleHint': 'e.g. KHY-TEA-1234',
      'verifiedAsRole': 'Verified as {role}',
      'min6CharsHint': 'Minimum 6 characters',
      'telegramShort': 'Telegram',
      'whatsappShort': 'WhatsApp',
      'contactShort': 'Contact',
      'beneficiaryLabel': 'Beneficiary',
      'payerNameLabel': 'Payer Name',
      'amountShort': 'Amount',
      'monthShort': 'Month',
      'circleParentsGroupName': '{circle} Parents Group',
      'halaqahNameHint': 'e.g. Halaqah Bilal',
      'ustazWillMarkMsg': 'Ustaz will mark attendance during circle time.',
      'activityAlertsTab': 'Activity Alerts',
      'announcementsTab': 'Announcements',
      'allNoticesFilter': 'All Notices',
      'attachmentsFilter': 'Attachments',
      'directorRoleShort': 'Director',
      'couldNotReadSelectedFileMsg': 'Could not read selected file from device.',
      'cloudUploadFailedMsg':
          'Cloud upload failed. Please check network connection and try again.',
      'failedSelectFileMsg': 'Failed to select file: {error}',
      'failedPickImageMsg': 'Failed to pick image: {error}',
      'provideTitleAndContentMsg': 'Please provide both title and circular text.',
      'broadcastFailedMsg': 'Broadcast failed. Please check your connection.',
      'unableToConnectCenterServerMsg':
          'Unable to connect to center server. Please try again.',
      'teacherUnassignedCircleMsg': '{name} unassigned from study circle.',
      'teacherAssignedCircleMsg': '{name} assigned to {circle}.',
      'userPromotedRoleMsg': '{name} promoted to {role} successfully.',
      'failedUploadImageToStorageMsg': 'Failed to upload image to storage.',
      'serverNotConnectedMsg': 'Server not connected.',
      'suspendedTag': 'SUSPENDED',
      'noTeachersFoundTitle': 'No teachers found',
      'noParentsFoundTitle': 'No parents found',
      'noAdminsFoundTitle': 'No admins found',
      'registeredTeachersAppearMsg': 'Registered teachers will appear here.',
      'registeredParentsAppearMsg': 'Registered parents will appear here.',
      'registeredAdminsAppearMsg': 'Registered admins will appear here.',
      'enterCredsMsg': 'Please enter your username/email and password.',
      'suspendedInactiveMsg':
          'Your account is suspended or inactive. Please contact center administration.',
      'enterInviteCodeMsg': 'Please enter your school invite code.',
      'completeAllFieldsMsg': 'Please complete all fields.',
      'passwordMin6Msg': 'Password must be at least 6 characters.',
      'accountCreatedVerifyEmailMsg':
          'Account created! Please verify your email before logging in.',
      'resetPasswordAdminMsg':
          'Please contact your center administrator or Ustaz to reset your password.',
      'failedUploadVoiceCloudMsg':
          'Failed to upload voice recording to cloud storage.',
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
      'openStatus': 'غير مسجل',
      'currentJuzMetric': 'الجزء الحالي',
      'ayahMetric': 'الآية',
      'ayahValueLabel': 'آية {ayah}',
      'receiptAttachedInspect': 'تم إرفاق صورة الإيصال • اضغط للفحص',
      'studentGender': 'الجنس',
      'male': 'ذكر',
      'female': 'أنثى',
      'editStudent': 'تعديل بيانات الطالب',
      'studentEnrolledMsg': 'تم تسجيل الطالب "{name}" بنجاح.',
      'studentUpdatedMsg': 'تم تحديث بيانات "{name}" بنجاح.',
      'enrollmentFailedMsg': 'تعذر تسجيل الطالب: {error}',
      'updateFailedMsg': 'تعذر التحديث: {error}',
      'noHalaqahsYetMsg': 'لا توجد حلقات بعد. أنشئ حلقة أولاً.',
      'parentFallbackWithValue': '{name} ({contact})',
      'portalTagline': 'بوابة التعاون القرآني بين أولياء الأمور والمعلمين',
      'roleGroup': 'مجموعة',
      'userFallback': 'مستخدم',
      'administratorTitle': 'المدير',
      'centerDirectorTitle': 'مدير المركز',
      'centerAdministrationTitle': 'إدارة المركز',
      'assignedUstazTitle': 'الأستاذ المسؤول',
      'studyCircleFallback': 'حلقة التحفيظ',
      'accessRestrictedTitle': 'الوصول مقيد',
      'sessionPermissionsUnverified': 'تعذر التحقق من صلاحيات جلستك.',
      'unknownError': 'خطأ غير معروف',
      'unableToConnectServer': 'تعذر الاتصال بالخادم.',
      'justNow': 'الآن',
      'minutesAgo': 'منذ {count} د',
      'minutesShort': '{count}د',
      'hoursAgo': 'منذ {count} س',
      'amLabel': 'ص',
      'pmLabel': 'م',
      'reminderTag': 'تذكير',
      'noticeTag': 'تنبيه',
      'timeForPrayerDefault': 'حان وقت الصلاة',
      'prayerReminderBodyDefault': 'خذ لحظة هادئة لذكر الله.',
      'adhanPrayerReminderTitle': 'تذكير الأذان والصلاة',
      'understood': 'فهمت',
      'savingProgress': 'جارٍ الحفظ...',
      'submittingProgress': 'جارٍ الإرسال...',
      'assigningProgress': 'جارٍ التكليف...',
      'changeAction': 'تغيير',
      'copyAction': 'نسخ',
      'copyCodeTooltip': 'نسخ الرمز',
      'copiedCodeMsg': 'تم نسخ "{code}" إلى الحافظة.',
      'copiedLabelMsg': 'تم نسخ {label} إلى الحافظة.',
      'activeTag': 'نشط',
      'usedTag': 'مستخدم',
      'activeLabel': 'نشط',
      'reviewAction': 'مراجعة',
      'juzOf30': 'الجزء {juz} من 30',
      'juzShort': 'الجزء {juz}',
      'juzSurahAyahSummary': 'الجزء {juz} • سورة رقم {surah}، آية {ayah}',
      'languageEnglishLabel': 'الإنجليزية',
      'languageArabicLabel': 'العربية',
      'languageAmharicLabel': 'الأمهرية',
      'studentCountOne': 'طالب واحد مسجل',
      'studentCountMany': '{count} طلاب مسجلين',
      'ustazStudentsMeta': 'الأستاذ: {name} • {countLabel}',
      'dailyCurriculumDesc': 'المنهج اليومي: السَّبَق (الحفظ الجديد)، السَّبْقي (المراجعة القريبة)، والمنزل (المراجعة التراكمية). سجّل الحضور اليومي وأطلع أولياء الأمور.',
      'classRosterHeader': 'قائمة طلاب الحلقة',
      'noStudentsCurrentlyAssigned': 'لا يوجد طلاب مسجلون حالياً.',
      'manageUsersSubtitle': 'إدارة المعلمين وأولياء الأمور وتوزيع الحلقات والصلاحيات',
      'manageCirclesSubtitle': 'إنشاء الحلقات وتعيين الأساتذة وعرض التسجيل',
      'generateInvitesSubtitle': 'إنشاء رموز تسجيل للمعلمين وأولياء الأمور',
      'rosterAndCurriculumMeta': '{circle} • القائمة والمنهج',
      'broadcastNoticesSubtitle': 'إرسال تعاميم وإعلانات لأولياء الأمور والمعلمين',
      'parentFeesSubtitle': 'رفع إيصالات التحويل ومتابعة حالة الرسوم الشهرية',
      'adminFeesSubtitle': 'إصدار الرسوم الشهرية والتحقق من الإيصالات وتنبيهات التأخر',
      'centerSetupTitle': 'إعداد المركز',
      'completeOnboardingSubtitle': 'أكمل خطوات الإعداد لتشغيل جميع الحلقات',
      'stepsOf3': '{count} من 3',
      'checklistStep1': 'إنشاء حلقة تحفيظ',
      'checklistStep2': 'إنشاء رمز دعوة للأستاذ',
      'checklistStep3': 'تسجيل أول طالب',
      'createFirstHalaqahAction': 'إنشاء أول حلقة',
      'generateTeacherCodeAction': 'إنشاء رمز دعوة للمعلم',
      'enrollFirstStudentAction': 'تسجيل أول طالب',
      'assignedStudyCircleHeader': 'الحلقة المسندة',
      'studentsBadgeLabel': '{count} طلاب',
      'studentBadgeOne': 'طالب واحد',
      'todaysAttendanceLabel': 'حضور اليوم',
      'markedProgressLabel': '{marked} / {total} مسجل',
      'pendingExcusesNoticeOne': 'طلب عذر غياب واحد بانتظار المراجعة',
      'pendingExcusesNoticeMany': '{count} طلبات أعذار غياب بانتظار المراجعة',
      'takeAttendanceAction': 'تسجيل الحضور',
      'homeworkLabel': 'الواجبات',
      'familyLearningHubHeader': 'مركز متابعة الأسرة',
      'welcomeParentFallback': 'مرحباً بولي الأمر',
      'enrolledCountBadge': '{count} مسجل',
      'todayAttBadge': 'اليوم: {status}',
      'noChildrenLinkedBanner': 'لم يتم ربط أي أبناء بحسابك بعد. يرجى التواصل مع إدارة المركز.',
      'learningProgressAction': 'تقدم الحفظ',
      'noAnnouncementsTitle': 'لا توجد إعلانات بعد',
      'noAnnouncementsDesc': 'ستظهر التعاميم الرسمية وإعلانات المركز هنا فور نشرها.',
      'pinnedTag': 'مثبت',
      'centerNoticeTag': 'إعلان المركز',
      'attachmentFallback': 'مرفق',
      'tapToOpenConvo': 'اضغط لفتح المحادثة',
      'messageClassParentTitle': 'مراسلة ولي أمر بالحلقة',
      'selectParentFromCircle': 'اختر ولي أمر من حلقة {circle}',
      'noStudentsInClassTitle': 'لا يوجد طلاب في الحلقة',
      'noStudentsInCircleMsg': 'لا يوجد طلاب مسجلون في حلقتك حالياً.',
      'noLinkedParentMsg': 'لا يملك الطالب {name} حساب ولي أمر مرتبطاً بعد.',
      'couldNotOpenChatMsg': 'تعذر فتح المحادثة: {error}',
      'couldNotStartChatMsg': 'تعذر بدء المحادثة: {error}',
      'adminMessagingHubTitle': 'مركز مراسلة الإدارة',
      'adminMessagingHubSubtitle': 'ابدأ محادثة مباشرة أو مجموعة حلقة',
      'messageTeacherOrParent': 'مراسلة معلم أو ولي أمر',
      'browseActiveContacts': 'استعراض جميع المعلمين وأولياء الأمور النشطين',
      'studyCircleParentsGroupFallback': 'مجموعة أولياء أمور الحلقة',
      'failedToCreateGroupMsg': 'تعذر إنشاء المجموعة: {error}',
      'createParentGroupTitle': 'إنشاء مجموعة أولياء أمور الحلقة',
      'createParentGroupSubtitle': 'مناقشة جماعية مع أولياء أمور الحلقة',
      'studentContactMeta': 'الطالب: {name} • {phone}',
      'tajweedAndRecitationHeader': 'التجويد والتلاوة',
      'assignSurahGoalsHint': 'حدّد أهداف السور وأحكام التجويد لحلقتك، وراجع تدريبات المنزل المسجلة من أولياء الأمور.',
      'noHomeworkFoundTitle': 'لا توجد واجبات منزلية',
      'noHomeworkForCircleMsg': 'لم تُسند واجبات لحلقة {circle} بعد. اضغط "{action}" لتحديد أول هدف تلاوة.',
      'practicedAtHomeCount': 'تدرب {completed} من أصل {total} في المنزل',
      'noStudentsInHalaqahTitle': 'لا يوجد طلاب في الحلقة',
      'noEnrolledStudentsHalaqahMsg': 'لم يتم العثور على طلاب مسجلين في هذه الحلقة.',
      'reviewedStatus': 'تمت المراجعة',
      'practicedStatus': 'تم التدريب',
      'needsPracticeStatus': 'بحاجة للتدريب',
      'homeRepetitionsLine': 'تكرار المنزل: {count} مرات مع ولي الأمر',
      'parentNoteQuote': 'ملاحظة ولي الأمر: "{note}"',
      'ratingExcellent': 'ممتاز',
      'ratingVeryGood': 'جيد جداً',
      'ratingGood': 'جيد',
      'ratingNeedsRevision': 'يحتاج مراجعة',
      'ratingFeedbackLine': 'التقييم: {rating} • "{feedback}"',
      'submissionEndorsedMsg': 'تم اعتماد تمرين {name}.',
      'homeworkAssignedMsg': 'تم تكليف الواجب المنزلي بنجاح.',
      'noLinkedChildrenTitle': 'لا يوجد أبناء مرتبطون',
      'noLinkedChildrenDesc': 'لا يوجد أبناء مرتبطون بحسابك حالياً. تواصل مع إدارة المركز لتسجيل أبنائك.',
      'tasksCountBadge': '{count} واجبات',
      'noHomeworkAssignedTitle': 'لا توجد واجبات مكلفة',
      'ustazNoHomeworkYetMsg': 'لم يرسل الأستاذ واجبات لحلقة {name} بعد.',
      'surahAyahRange': '{surah} (الآيات {from}–{to})',
      'surahAyahWithTeacher': '{surah} (الآيات {from}–{to}) • الأستاذ: {teacher}',
      'dueDateLabel': 'تاريخ التسليم: {date}',
      'completedRepetitionsLine': 'مكتمل: قُرئ {count} مرات في المنزل',
      'yourNoteQuote': 'ملاحظتك: "{note}"',
      'ustazGradeLine': 'تقييم الأستاذ: {rating}',
      'feedbackQuote': 'التوجيه: "{feedback}"',
      'markedPracticedMsg': 'تم تسجيل التدريب للطالب {name} وإشعار الأستاذ.',
      'totalAssignmentsMeta': 'إجمالي {count} واجبات عبر جميع الحلقات',
      'noHomeworkRecordedTitle': 'لا توجد واجبات مسجلة',
      'teachersNoHomeworkYetMsg': 'لم يضف المعلمون أي واجبات منزلية في الحلقات بعد.',
      'defaultEndorseFeedback': 'ما شاء الله تلاوة ممتازة مع تجويد واضح.',
      'gradePracticeTitle': 'تقييم تدريب {name}',
      'recitationRatingLabel': 'تقييم التلاوة',
      'ustazFeedbackLabel': 'ملاحظات وتوجيه الأستاذ',
      'ustazFeedbackHint': 'أدخل توجيهاً لولي الأمر والطالب...',
      'failedEndorseMsg': 'تعذر إرسال التقييم: {error}',
      'defaultHomeworkTitle': 'حفظ سورة وتجويدها',
      'defaultTajweedFocus': 'أحكام الغنة والإخفاء',
      'defaultHomeworkInstructions': 'اتلُ كل آية 3 مرات على الأقل مع مراعاة المد والغنة الصحيحين.',
      'circlePrefixLabel': 'الحلقة: {circle}',
      'assignmentTitleLabel': 'عنوان الواجب',
      'assignmentTitleHint': 'مثال: تدريب سورة الملك',
      'surahNameLabel': 'اسم السورة',
      'fromAyahLabel': 'من الآية',
      'toAyahLabel': 'إلى الآية',
      'tajweedFocusLabel': 'حكم التجويد المستهدف',
      'tajweedFocusHint': 'مثال: القلقلة، الغنة، المد',
      'instructionsParentsStudentsLabel': 'إرشادات لأولياء الأمور والطلاب',
      'changeDateAction': 'تغيير التاريخ',
      'failedAssignHomeworkMsg': 'تعذر تكليف الواجب: {error}',
      'defaultPracticeNote': 'تمت التلاوة بسلاسة مع ولي الأمر.',
      'practiceForStudentTitle': 'تدريب {name}',
      'repetitionsQuestion': 'كم مرة تلا ابنك في المنزل؟',
      'repetitionsCountLabel': '{count} مرات تكرار',
      'parentNotesOptionalLabel': 'ملاحظات ولي الأمر (اختياري)',
      'parentNotesHint': 'مثال: قرأ بسلاسة، احتاج مساعدة في الآية 7...',
      'failedSavePracticeMsg': 'تعذر حفظ التدريب: {error}',
      'assignedClassHeader': 'الحلقة المسندة',
      'allPresentSuccessMsg': 'تم تسجيل حضور جميع طلاب الحلقة وإشعار أولياء الأمور.',
      'failedMarkAttendanceMsg': 'تعذر تسجيل الحضور: {error}',
      'allPresentAction': 'حضور الجميع',
      'pendingAbsenceExcusesTitle': 'أعذار الغياب المعلقة ({count})',
      'submittedByParentsSubtitle': 'مقدمة من أولياء الأمور للمراجعة',
      'reasonLabelValue': 'السبب: {reason}',
      'absenceExcuseApprovedMsg': 'تم قبول عذر غياب {name}.',
      'failedApproveRequestMsg': 'تعذر قبول الطلب: {error}',
      'failedDeclineRequestMsg': 'تعذر رفض الطلب: {error}',
      'classAttendanceSheetTitle': 'كشف حضور الحلقة',
      'classAttendanceSheetSubtitle': 'اضغط لتسجيل حالة الحضور؛ يتم إشعار أولياء الأمور تلقائياً.',
      'noStudentsInThisCircleTitle': 'لا يوجد طلاب مسجلون في هذه الحلقة',
      'studentsAssignedByAdminMsg': 'سيظهر هنا الطلاب المعينون من الإدارة لحلقة {circle}.',
      'attendanceForDateLabel': 'حضور يوم {date}',
      'todayDateParens': 'اليوم ({date})',
      'messageParentAction': 'مراسلة ولي الأمر',
      'attendanceHistoryTitle': 'سجل الحضور',
      'studentMarkedStatusMsg': 'تم تسجيل {name}: {status} وإشعار ولي الأمر.',
      'failedSaveAttendanceMsg': 'تعذر حفظ الحضور: {error}',
      'noChildrenLinkedTitle': 'لا يوجد أبناء مرتبطون',
      'whenAdminEnrollsChildMsg': 'عند تسجيل أبنائك وربطهم بحسابك من الإدارة، سيظهر تقدمهم في الحفظ والحضور هنا.',
      'myEnrolledChildrenHeader': 'أبنائي المسجلون ({count})',
      'messageUstazAction': 'مراسلة الأستاذ',
      'quranMemorizationProgressTitle': 'تقدم حفظ القرآن الكريم',
      'unrecordedStatus': 'غير مسجل',
      'declinedStatus': 'مرفوض',
      'excuseReasonLine': 'العذر: {reason}',
      'noAttendanceLoggedTitle': 'لا يوجد سجل حضور بعد',
      'dailyAttendanceAppearHereMsg': 'ستظهر سجلات الحضور اليومية المسجلة من الأستاذ هنا.',
      'weeklyQuranProgressReportsTitle': 'تقارير التقدم القرآني الأسبوعية',
      'sabaqSabqiManzilSubtitle': 'تقييمات السَّبَق والسَّبْقي والمنزل والتجويد',
      'noWeeklyReportsTitle': 'لا توجد تقارير أسبوعية بعد',
      'weeklyReportsAppearHereMsg': 'ستظهر تقارير الحفظ والتجويد الأسبوعية هنا فور نشرها.',
      'parentContactLine': 'ولي الأمر: {name}{contact}',
      'removeStudentConfirmTitle': 'حذف {name}؟',
      'removeStudentConfirmBody': 'سيؤدي هذا إلى حذف هذا الطالب وسجلاته المرتبطة نهائياً من القائمة.',
      'removeAction': 'حذف',
      'removedStudentMsg': 'تم حذف {name} من القائمة.',
      'failedRemoveStudentPermsMsg': 'تعذر حذف الطالب. يرجى التحقق من الصلاحيات.',
      'failedRemoveStudentMsg': 'تعذر حذف الطالب: {error}',
      'removeStudentMenuLabel': 'حذف الطالب',
      'attendanceShortTab': 'الحضور',
      'reportShortTab': 'التقرير',
      'messageShortAction': 'مراسلة',
      'attendanceLogTitle': 'سجل حضور: {name}',
      'noAttendanceRecordedYet': 'لم يُسجل حضور بعد.',
      'attendanceRecordedNotifyMsg': 'تم تسجيل الحضور وإشعار ولي الأمر {name}.',
      'weeklyReportPostedNotifyMsg': 'تم إرسال التقرير الأسبوعي وإشعار ولي الأمر {name}.',
      'defaultAttendedOnTime': 'حضر الحلقة في الوقت المحدد',
      'weekOfDateLabel': 'أسبوع {date}',
      'ustazNotesQuote': 'ملاحظات الأستاذ: "{notes}"',
      'absenceExcuseSubmittedMsg': 'تم إرسال عذر الغياب للطالب {name} وإشعار الأستاذ.',
      'reasonMedical': 'مرض أو عذر صحي',
      'reasonFamilyEmergency': 'ظرف عائلي طارئ',
      'reasonSchoolExam': 'اختبار مدرسي',
      'reasonTravel': 'سفر أو خارج المدينة',
      'reasonPersonal': 'سبب شخصي',
      'editRemarksTitle': 'تعديل الملاحظات: {name}',
      'teacherRemarksLabel': 'ملاحظات المعلم',
      'failedSaveNoteMsg': 'تعذر حفظ الملاحظة: {error}',
      'saveNoteAction': 'حفظ الملاحظة',
      'dailyAttendanceTitle': 'الحضور اليومي: {name}',
      'statusFieldLabel': 'الحالة',
      'teacherRemarksShortLabel': 'ملاحظات الأستاذ',
      'saveAndNotifyAction': 'حفظ وإشعار',
      'defaultSabaqSample': 'سورة الملك (1-15)',
      'defaultSabqiSample': 'سورة القلم (1-20)',
      'defaultManzilSample': 'مراجعة الجزء 29',
      'defaultReportRemarks': 'أداء مستمر ومتقن لمخارج الحروف.',
      'weeklyReportTitle': 'التقرير الأسبوعي: {name}',
      'sabaqNewLessonLabel': 'السَّبَق (الدرس الجديد)',
      'sabqiRecentRevisionLabel': 'السَّبْقي (المراجعة القريبة)',
      'manzilRetentionLabel': 'المنزل (التثبيت العام)',
      'ustazEvaluationNotesLabel': 'ملاحظات تقييم الأستاذ',
      'failedSubmitReportMsg': 'تعذر إرسال التقرير: {error}',
      'submitAndNotifyAction': 'إرسال وإشعار',
      'defaultExcuseNote': 'يشعر بتوعك ويحتاج للراحة في المنزل.',
      'requestExcuseTitle': 'طلب عذر غياب: {name}',
      'dateLineLabel': 'التاريخ: {date}',
      'reasonForAbsenceLabel': 'سبب الغياب',
      'parentExplanationLabel': 'توضيح ولي الأمر',
      'parentExplanationHint': 'أدخل تفاصيل العذر للأستاذ...',
      'failedSubmitExcuseMsg': 'تعذر إرسال العذر: {error}',
      'cbeBankName': 'البنك التجاري الإثيوبي',
      'telebirrAccountLabel': 'حساب تيلي بر',
      'cbeMobileBanking': 'الخدمات المصرفية عبر البنك التجاري',
      'telebirrMobile': 'تيلي بر',
      'cashDepositLabel': 'إيداع نقدي',
      'cashSlipLabel': 'إيصال نقدي',
      'paymentVerificationRejectedTitle': 'تم رفض التحقق من الدفع',
      'reuploadValidReceiptAction': 'إعادة رفع إيصال صحيح',
      'monthlyTuitionHeader': 'الرسوم الشهرية',
      'studentLineLabel': 'الطالب: {name}',
      'perMonthlyFeeSuffix': '/ رسوم شهرية',
      'verifiedApprovedByLine': 'تم التحقق والاعتماد بواسطة {name}.',
      'receiptUploadedVerifyingMsg': 'تم رفع الإيصال. تتحقق الإدارة من عملية الدفع.',
      'uploadReceiptScreenshotAction': 'رفع صورة إيصال الدفع',
      'noTuitionDueTitle': 'لا توجد رسوم مستحقة حالياً',
      'noTuitionDueDesc': 'عندما تصدر الإدارة رسوم الدراسة الشهرية لطالبك، ستظهر الفواتير هنا.',
      'paymentHistoryCount': 'سجل المدفوعات ({count})',
      'toReviewTab': 'للمراجعة',
      'receiptsAwaitingReviewTitle': 'إيصالات بانتظار المراجعة ({count})',
      'actionRequiredTag': 'مطلوب إجراء',
      'overdueAccountsTitle': 'حسابات متأخرة ({count})',
      'pastDueTag': 'متأخر السداد',
      'tuitionRecordsTitle': 'سجلات الرسوم ({count})',
      'plusIssueTuition': '+ إصدار رسوم',
      'noTuitionIssuedTitle': 'لم تصدر رسوم دراسية بعد',
      'noTuitionIssuedDesc': 'أصدر الرسوم الشهرية للطلاب المسجلين ليتمكن أولياء الأمور من الدفع ورفع الإيصالات.',
      'issueFirstTuitionAction': 'إصدار أول رسوم شهرية',
      'parentEmailLine': 'ولي الأمر: {name} ({email})',
      'overdueUpperTag': 'متأخر',
      'overdueAlertDispatchedMsg': 'تم إرسال تنبيه التأخر إلى {name}.',
      'sendAlertAction': 'إرسال تنبيه',
      'paymentApprovedForMsg': 'تم اعتماد الدفع للطالب {name}.',
      'rejectAction': 'رفض',
      'approveAction': 'اعتماد',
      'amountLineLabel': 'المبلغ: \${amount}',
      'viewReceiptAction': 'عرض الإيصال',
      'rejectionReasonQuote': 'سبب الرفض: "{reason}"',
      'noStudentsEnrolledAlertTitle': 'لا يوجد طلاب مسجلون',
      'addOneStudentBeforeTuitionMsg': 'يرجى إضافة طالب واحد على الأقل في تبويب الحلقات قبل إصدار الرسوم.',
      'receiptInspectorTitle': 'فحص الإيصال',
      'couldNotLoadReceiptImage': 'تعذر تحميل صورة الإيصال',
      'tapToZoomHint': 'اضغط للتكبير',
      'paymentSummaryHeader': 'ملخص الدفع',
      'rejectWithReasonAction': 'رفض مع ذكر السبب',
      'receiptImageTitle': 'صورة الإيصال',
      'enterTuitionMonthError': 'يرجى إدخال شهر الرسوم الدراسية.',
      'enterValidTuitionAmountError': 'يرجى إدخال مبلغ صحيح أكبر من صفر.',
      'tuitionIssuedForMsg': 'تم إصدار الرسوم للطالب {name}.',
      'defaultReceiptNote': 'تم السداد عبر التطبيق البنكي.',
      'receiptSubmittedSuccessMsg': 'تم رفع الإيصال بنجاح. ستتحقق الإدارة منه.',
      'uploadPaymentReceiptTitle': 'رفع إيصال الدفع',
      'studentMonthLine': 'الطالب: {name} ({month})',
      'amountDueLine': 'المبلغ المستحق: \${amount}',
      'paymentChannelLabel': 'طريقة الدفع',
      'selectedFileLabel': 'المحدد: {name}',
      'tapPickReceiptHint': 'اضغط لاختيار صورة الإيصال',
      'tapToChangeImage': 'اضغط لتغيير الصورة',
      'chooseSlipFromGallery': 'اختر إيصال التحويل من المعرض',
      'transactionRefLabel': 'رقم المرجع / الملاحظات',
      'submitReceiptAction': 'إرسال الإيصال',
      'defaultRejectReceiptReason': 'الصورة المرفوعة غير واضحة ولا يمكن قراءة رقم المرجع. يرجى إعادة الرفع.',
      'paymentRejectedSentMsg': 'تم رفض الدفع وإرسال السبب إلى {name}.',
      'rejectPaymentReceiptTitle': 'رفض إيصال الدفع',
      'specifyRejectionReasonMsg': 'اذكر سبب رفض إيصال {name} ليظهر لولي الأمر.',
      'rejectionReasonRequiredLabel': 'سبب الرفض *',
      'rejectionReasonHint': 'مثال: صورة غير واضحة، مبلغ غير مطابق، رقم مرجع مفقود...',
      'confirmRejectionAction': 'تأكيد الرفض',
      'failedSendMsg': 'تعذر إرسال الرسالة: {error}',
      'micPermissionRequiredMsg': 'مطلوب إذن الميكروفون لتسجيل الرسائل الصوتية.',
      'couldNotStartRecordingMsg': 'تعذر بدء التسجيل: {error}',
      'voiceFileUnavailableMsg': 'ملف التسجيل الصوتي لم يعد متوفراً.',
      'voiceExceedsLimitMsg': 'يتجاوز التسجيل الصوتي الحد المسموح 25 ميجابايت.',
      'voiceMessageWithDuration': 'رسالة صوتية ({duration})',
      'failedStopRecordingMsg': 'تعذر إيقاف التسجيل: {error}',
      'failedSendVoiceMsg': 'تعذر إرسال التسجيل الصوتي: {error}',
      'voiceUrlUnavailableMsg': 'رابط التسجيل الصوتي غير متوفر.',
      'offlineVoiceNotFoundMsg': 'ملف التسجيل الصوتي غير موجود محلياً.',
      'couldNotAccessVoiceMsg': 'تعذر تشغيل الرسالة الصوتية.',
      'errorPlayingAudioMsg': 'خطأ أثناء تشغيل الصوت: {error}',
      'imageExceedsLimitMsg': 'يتجاوز حجم الصورة 25 ميجابايت. يرجى اختيار صورة أصغر.',
      'failedUploadImageMsg': 'تعذر رفع الصورة إلى التخزين السحابي.',
      'failedAttachImageMsg': 'تعذر إرفاق الصورة: {error}',
      'videoExceedsLimitMsg': 'يتجاوز حجم الفيديو 25 ميجابايت. يرجى اختيار مقطع أقصر.',
      'failedUploadVideoMsg': 'تعذر رفع الفيديو إلى التخزين السحابي.',
      'failedAttachVideoMsg': 'تعذر إرفاق الفيديو: {error}',
      'docExceedsLimitMsg': 'يتجاوز حجم المستند 25 ميجابايت. يرجى اختيار ملف أصغر.',
      'failedUploadDocMsg': 'تعذر رفع المستند إلى التخزين السحابي.',
      'failedAttachDocMsg': 'تعذر إرفاق المستند: {error}',
      'shareAttachmentSubtitle': 'صور أو فيديو أو ملفات أو آية قرآنية',
      'cameraOption': 'الكاميرا',
      'galleryOption': 'المعرض',
      'videoOption': 'فيديو',
      'ayahQuoteOption': 'اقتباس آية',
      'ayahKahf1810Quote': 'سورة الكهف (18:10): ﴿رَبَّنَا آتِنَا مِن لَّدُنكَ رَحْمَةً وَهَيِّئْ لَنَا مِنْ أَمْرِنَا رَشَدًا﴾',
      'openInBrowserTooltip': 'فتح في المتصفح',
      'failedLoadImagePreview': 'تعذر تحميل معاينة الصورة',
      'failedDeleteMsg': 'تعذر حذف الرسالة: {error}',
      'ustazDirectChannel': 'قناة الأستاذ المباشرة',
      'parentDirectChannel': 'قناة ولي الأمر المباشرة',
      'centerChannel': 'قناة المركز',
      'directSchoolChannel': 'قناة المركز المباشرة',
      'emptyChatPrompt': 'أرسل رسالة أو مستنداً أو صورة أو تسجيلاً صوتياً للبدء.',
      'uploadingAttachmentToCloud': 'جارٍ رفع المرفق إلى السحابة...',
      'recordingVoiceNoteLabel': 'جارٍ تسجيل رسالة صوتية...',
      'editedTag': 'معدّلة ',
      'viewAction': 'عرض',
      'videoFileFallback': 'ملف فيديو',
      'tapToPlayVideo': 'اضغط لتشغيل الفيديو',
      'couldNotOpenDocUrl': 'تعذر فتح رابط المستند.',
      'tapToViewDownload': 'اضغط للعرض أو التنزيل',
      'enterUpdatedMsgHint': 'أدخل الرسالة المعدلة...',
      'failedEditMsg': 'تعذر تعديل الرسالة: {error}',
      'noCirclesCreatedTitle': 'لم تُنشأ حلقات بعد',
      'createFirstCircleDesc': 'أنشئ أول حلقة تحفيظ لتعيين المعلمين وتسجيل الطلاب.',
      'createFirstCircleAction': 'إنشاء أول حلقة',
      'deleteCircleTooltip': 'حذف الحلقة',
      'deleteCircleConfirmTitle': 'حذف الحلقة؟',
      'deleteCircleConfirmBody': 'هل أنت متأكد من حذف "{name}"؟',
      'removedCircleMsg': 'تم حذف حلقة "{name}".',
      'couldNotDeleteCircleMsg': 'تعذر حذف الحلقة: {error}',
      'ustazNameLabel': 'الأستاذ: {name}',
      'defaultCircleSchedule': 'جلسة تلاوة يومية',
      'circleCreatedSuccessMsg': 'تم إنشاء حلقة "{name}" بنجاح.',
      'failedCreateCircleMsg': 'تعذر إنشاء الحلقة: {error}',
      'createStudyCircleTitle': 'إنشاء حلقة تحفيظ',
      'halaqahNameReqLabel': 'اسم الحلقة *',
      'assignTeacherOptionalHint': 'تعيين أستاذ (اختياري)',
      'unassignedAssignLater': 'غير معيّن (تعيين لاحقاً)',
      'scheduleFieldLabel': 'الجدول الزمني',
      'scheduleHint': 'مثال: الإثنين - الجمعة 4:00 - 6:00 مساءً',
      'curriculumFocusLabel': 'ملاحظات الحلقة / المنهج',
      'curriculumFocusHint': 'مثال: حفظ جزء عم ومراجعة المخارج',
      'createCircleAction': 'إنشاء الحلقة',
      'noActiveCodesTitle': 'لا توجد رموز نشطة',
      'generateInviteOnboardingDesc': 'أنشئ رمز دعوة لمعلم أو ولي أمر أعلاه لإضافة أعضاء جدد.',
      'activeCodeReadyTitle': 'الرمز النشط جاهز',
      'liveInvitationCodesTitle': 'رموز الدعوة المباشرة',
      'noInviteCodesGeneratedYet': 'لم يتم إنشاء رموز دعوة بعد.',
      'failedGenerateCodeMsg': 'تعذر إنشاء الرمز',
      'teacherRoleTag': 'أستاذ',
      'parentRoleTag': 'ولي أمر',
      'suspendWord': 'إيقاف',
      'activateWord': 'تفعيل',
      'suspendActivateConfirmTitle': '{action} {name}؟',
      'suspendWarningMsg': 'سيُمنع المستخدمون الموقوفون فوراً من تسجيل الدخول والوصول لبيانات المركز.',
      'activateRestoredMsg': 'ستُستعاد صلاحية الحساب ويُسمح له بتسجيل الدخول.',
      'failedUpdateUserStatusMsg': 'تعذر تحديث حالة المستخدم: {error}',
      'userSuspendedMsg': 'تم إيقاف حساب {name}.',
      'userReactivatedMsg': 'تم تفعيل حساب {name}.',
      'removeUserAccountTitle': 'حذف حساب المستخدم؟',
      'removeUserAccountBody': 'هل أنت متأكد من حذف "{name}" نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
      'removePermanentlyAction': 'حذف نهائي',
      'failedRemoveUserMsg': 'تعذر حذف المستخدم: {error}',
      'failedRemoveUserSimple': 'تعذر حذف المستخدم.',
      'removedUserFromCenterMsg': 'تم حذف {name} من المركز.',
      'createCircleFirstMsg': 'يرجى إنشاء حلقة تحفيظ أولاً.',
      'assignTeacherTitle': 'تعيين {name}',
      'unassignedRemoveFromCircle': 'غير معيّن (إزالة من الحلقة)',
      'studyCircleHalaqahLabel': 'حلقة التحفيظ',
      'failedUpdateAssignmentMsg': 'تعذر تحديث تعيين الحلقة: {error}',
      'profilePhotoUpdatedUserMsg': 'تم تحديث صورة {name}.',
      'couldNotUpdatePhotoMsg': 'تعذر تحديث الصورة: {error}',
      'changeRoleForTitle': 'تغيير صلاحية {name}',
      'selectPermissionsPrompt': 'اختر الصلاحيات ومستوى الوصول لهذا المستخدم:',
      'superadminFullControlTitle': 'المشرف العام (تحكم كامل)',
      'superadminFullControlDesc': 'صلاحية كاملة تشمل المدفوعات والرسوم وترقية أدوار المستخدمين',
      'adminRoleDescTitle': 'مدير المركز',
      'adminRoleDescSubtitle': 'الحلقات والطلاب والحضور والواجبات (دون صلاحية المدفوعات)',
      'teacherRoleDescTitle': 'معلم (أستاذ)',
      'teacherRoleDescSubtitle': 'الحلقة المسندة والحضور وتقييم التلاوة',
      'parentRoleDescSubtitle': 'الأبناء المرتبطون والتقارير الأسبوعية ودفع الرسوم',
      'cannotDemoteSelfNote': 'ملاحظة: لا يمكنك تخفيض صلاحية حسابك النشط كمشرف عام.',
      'failedUpdateRoleMsg': 'تعذر تحديث الصلاحية: {error}',
      'updateRoleAction': 'تحديث الصلاحية',
      'onlyAdminsManageUsersMsg': 'يمكن لمديري المركز فقط إدارة حسابات المستخدمين.',
      'couldNotLoadUsersTitle': 'تعذر تحميل المستخدمين',
      'noUsersFoundTitle': 'لم يتم العثور على {role}',
      'tryModifyingSearchMsg': 'جرّب مسح أو تعديل عبارة البحث.',
      'registeredUsersAppearMsg': 'سيظهر المسجلون كـ {role} هنا.',
      'noContactInfo': 'لا توجد معلومات تواصل',
      'unassignedCircleLabel': 'حلقة غير محددة',
      'promoteChangeRoleAction': 'ترقية / تغيير الصلاحية',
      'assignHalaqahAction': 'تعيين حلقة',
      'reactivateAccountAction': 'إعادة تفعيل الحساب',
      'suspendAccountAction': 'إيقاف الحساب',
      'noMatchingInviteCodes': 'لا توجد رموز دعوة مطابقة',
      'noInviteCodesActive': 'لا توجد رموز دعوة نشطة',
      'generateInviteTopRightHint': 'أنشئ رمز دعوة من الزر في الأعلى.',
      'teacherRegistrationLabel': 'تسجيل أستاذ',
      'parentRegistrationLabel': 'تسجيل ولي أمر',
      'deleteInviteCodeTooltip': 'حذف رمز الدعوة',
      'failedDeleteInviteCodeMsg': 'تعذر حذف رمز الدعوة.',
      'noticesAndActivityTitle': 'الإعلانات والتنبيهات',
      'circularsAndAlertsSubtitle': 'التعاميم والتنبيهات',
      'postShortButton': 'نشر',
      'noAlertsYetTitle': 'لا توجد تنبيهات بعد',
      'noAlertsYetDesc': 'ستظهر هنا تحديثات الحضور اليومي والتقارير الأسبوعية وتنبيهات الرسوم.',
      'markAllReadAction': 'تحديد الكل كمقروء',
      'noNoticesFoundTitle': 'لم يتم العثور على إعلانات',
      'noNoticesFilterDesc': 'لا توجد إعلانات تطابق عامل التصفية المحدد.',
      'openTuitionPaymentsAction': 'فتح الرسوم والمدفوعات',
      'imageUnavailableLabel': 'الصورة غير متوفرة',
      'attachedDocumentFallback': 'مستند مرفق',
      'attachedFileSuccessMsg': 'تم إرفاق "{name}" بنجاح.',
      'attachedPhotoSuccessMsg': 'تم إرفاق الصورة "{name}" بنجاح.',
      'announcementBroadcastedMsg': 'تم بث الإعلان لجميع المستخدمين بنجاح.',
      'broadcastCircularTitle': 'بث تعميم رسمي',
      'pushNoticeSubtitle': 'إرسال إشعار لأولياء الأمور والمعلمين',
      'circularTitleHeader': 'عنوان التعميم',
      'circularTitleHint': 'مثال: جدول ومواعيد التلاوة في رمضان',
      'messageContentHeader': 'محتوى الرسالة',
      'messageContentHint': 'اكتب نص التعميم الكامل هنا...',
      'attachmentHeader': 'المرفق',
      'uploadingAttachmentCloudMsg': 'جارٍ رفع المرفق إلى التخزين السحابي...',
      'attachedFileFallback': 'ملف مرفق',
      'readyStatusTag': 'جاهز',
      'removeAttachmentTooltip': 'إزالة المرفق',
      'attachPhotoAction': 'إرفاق صورة',
      'attachFileAction': 'إرفاق ملف',
      'pinCircularLabel': 'تثبيت هذا التعميم أعلى الشاشة الرئيسية',
      'signInFailedMsg': 'فشل تسجيل الدخول.',
      'invalidInviteCodeMsg': 'رمز الدعوة غير صالح.',
      'registrationFailedMsg': 'فشل إنشاء الحساب.',
      'kheyrukumSupportTitle': 'دعم مركز خيركم',
      'supportAddressSubtitle': 'أديس أبابا، بيتيل / قرب مستشفى بيتيل',
      'telegramOfficialLabel': 'تيليجرام الرسمي',
      'whatsappOfficialLabel': 'واتساب الرسمي',
      'directPhoneSupportLabel': 'الدعم الهاتفي المباشر',
      'needAssistancePrompt': 'هل تحتاج مساعدة من إدارة المركز؟',
      'parentEmailHint': 'parent@kheyrukum.com',
      'exampleEmailHint': 'name@example.com',
      'enterRegCodePrompt': 'أدخل رمز التسجيل المقدم من إدارة المركز.',
      'inviteCodeExampleHint': 'مثال: KHY-TEA-1234',
      'verifiedAsRole': 'تم التحقق كـ {role}',
      'min6CharsHint': '6 أحرف على الأقل',
      'telegramShort': 'تيليجرام',
      'whatsappShort': 'واتساب',
      'contactShort': 'تواصل',
      'beneficiaryLabel': 'المستفيد',
      'payerNameLabel': 'اسم الدافع',
      'amountShort': 'المبلغ',
      'monthShort': 'الشهر',
      'circleParentsGroupName': 'مجموعة أولياء أمور {circle}',
      'halaqahNameHint': 'مثال: حلقة بلال',
      'ustazWillMarkMsg': 'سيسجل الأستاذ الحضور أثناء وقت الحلقة.',
      'activityAlertsTab': 'تنبيهات النشاط',
      'announcementsTab': 'الإعلانات',
      'allNoticesFilter': 'جميع الإشعارات',
      'attachmentsFilter': 'المرفقات',
      'directorRoleShort': 'المدير',
      'couldNotReadSelectedFileMsg': 'تعذر قراءة الملف المحدد من الجهاز.',
      'cloudUploadFailedMsg':
          'فشل الرفع السحابي. يُرجى التحقق من الاتصال بالشبكة والمحاولة مجدداً.',
      'failedSelectFileMsg': 'تعذر اختيار الملف: {error}',
      'failedPickImageMsg': 'تعذر اختيار الصورة: {error}',
      'provideTitleAndContentMsg': 'يُرجى إدخال العنوان ونص التعميم معاً.',
      'broadcastFailedMsg': 'فشل البث. يُرجى التحقق من اتصالك.',
      'unableToConnectCenterServerMsg':
          'تعذر الاتصال بخادم المركز. يُرجى المحاولة مجدداً.',
      'teacherUnassignedCircleMsg': 'تم إلغاء تعيين {name} من الحلقة.',
      'teacherAssignedCircleMsg': 'تم تعيين {name} في {circle}.',
      'userPromotedRoleMsg': 'تمت ترقية {name} إلى {role} بنجاح.',
      'failedUploadImageToStorageMsg': 'تعذر رفع الصورة إلى التخزين.',
      'serverNotConnectedMsg': 'الخادم غير متصل.',
      'suspendedTag': 'موقوف',
      'noTeachersFoundTitle': 'لم يتم العثور على معلمين',
      'noParentsFoundTitle': 'لم يتم العثور على أولياء أمور',
      'noAdminsFoundTitle': 'لم يتم العثور على مديرين',
      'registeredTeachersAppearMsg': 'سيظهر المعلمون المسجلون هنا.',
      'registeredParentsAppearMsg': 'سيظهر أولياء الأمور المسجلون هنا.',
      'registeredAdminsAppearMsg': 'سيظهر المديرون المسجلون هنا.',
      'enterCredsMsg':
          'يُرجى إدخال اسم المستخدم أو البريد الإلكتروني وكلمة المرور.',
      'suspendedInactiveMsg':
          'تم إيقاف حسابك أو تعطيله. يُرجى التواصل مع إدارة المركز.',
      'enterInviteCodeMsg': 'يُرجى إدخال رمز دعوة المدرسة.',
      'completeAllFieldsMsg': 'يُرجى إكمال جميع الحقول.',
      'passwordMin6Msg': 'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل.',
      'accountCreatedVerifyEmailMsg':
          'تم إنشاء الحساب! يُرجى تأكيد بريدك الإلكتروني قبل تسجيل الدخول.',
      'resetPasswordAdminMsg':
          'يُرجى التواصل مع مدير المركز أو الأستاذ لإعادة تعيين كلمة المرور.',
      'failedUploadVoiceCloudMsg':
          'تعذر رفع التسجيل الصوتي إلى التخزين السحابي.',
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
      'openStatus': 'ያልተያዘ',
      'currentJuzMetric': 'የአሁኑ ጁዝ',
      'ayahMetric': 'አንቀጽ',
      'ayahValueLabel': 'አንቀጽ {ayah}',
      'receiptAttachedInspect': 'የደረሰኝ ምስል ተያይዟል • ለመመርመር ይንኩ',
      'studentGender': 'ጾታ',
      'male': 'ወንድ',
      'female': 'ሴት',
      'editStudent': 'የተማሪ መረጃ አስተካክል',
      'studentEnrolledMsg': '"{name}" በተሳካ ሁኔታ ተመዝግቧል።',
      'studentUpdatedMsg': 'የ"{name}" መረጃ በተሳካ ሁኔታ ታድሷል።',
      'enrollmentFailedMsg': 'ምዝገባው አልተሳካም፦ {error}',
      'updateFailedMsg': 'ማዘመን አልተሳካም፦ {error}',
      'noHalaqahsYetMsg': 'እስካሁን ክፍሎች የሉም። መጀመሪያ ክፍል ይፍጠሩ።',
      'parentFallbackWithValue': '{name} ({contact})',
      'portalTagline': 'የወላጆችና የመምህራን የቁርኣን ትብብር ፖርታል',
      'roleGroup': 'ቡድን',
      'userFallback': 'ተጠቃሚ',
      'administratorTitle': 'አስተዳዳሪ',
      'centerDirectorTitle': 'የማዕከሉ ዳይሬክተር',
      'centerAdministrationTitle': 'የማዕከሉ አስተዳደር',
      'assignedUstazTitle': 'የተመደቡ ኡስታዝ',
      'studyCircleFallback': 'የጥናት ክፍል',
      'accessRestrictedTitle': 'መዳረሻ የተገደበ',
      'sessionPermissionsUnverified': 'የክፍለ ጊዜ ፈቃዶችዎን ማረጋገጥ አልተቻለም።',
      'unknownError': 'ያልታወቀ ስህተት',
      'unableToConnectServer': 'ከአገልጋዩ ጋር መገናኘት አልተቻለም።',
      'justNow': 'ልክ አሁን',
      'minutesAgo': 'ከ{count} ደቂቃ በፊት',
      'minutesShort': '{count}ደ',
      'hoursAgo': 'ከ{count} ሰዓት በፊት',
      'amLabel': 'ጥዋት',
      'pmLabel': 'ከሰዓት',
      'reminderTag': 'ማስታወሻ',
      'noticeTag': 'ማሳሰቢያ',
      'timeForPrayerDefault': 'የሰላት ሰዓት ደርሷል',
      'prayerReminderBodyDefault': 'አላህን ለማስታወስ ጸጥ ያለ ጊዜ ይውሰዱ።',
      'adhanPrayerReminderTitle': 'የአዛንና የሰላት ማስታወሻ',
      'understood': 'ገባኝ',
      'savingProgress': 'በማስቀመጥ ላይ...',
      'submittingProgress': 'በመላክ ላይ...',
      'assigningProgress': 'በመመደብ ላይ...',
      'changeAction': 'ቀይር',
      'copyAction': 'ቅዳ',
      'copyCodeTooltip': 'ኮዱን ቅዳ',
      'copiedCodeMsg': '"{code}" ወደ ክሊፕቦርድ ተቀድቷል።',
      'copiedLabelMsg': '{label} ወደ ክሊፕቦርድ ተቀድቷል።',
      'activeTag': 'ንቁ',
      'usedTag': 'ጥቅም ላይ የዋለ',
      'activeLabel': 'ንቁ',
      'reviewAction': 'ገምግም',
      'juzOf30': 'ጁዝ {juz} ከ30',
      'juzShort': 'ጁዝ {juz}',
      'juzSurahAyahSummary': 'ጁዝ {juz} • ሱራ #{surah}፣ አንቀጽ {ayah}',
      'languageEnglishLabel': 'እንግሊዝኛ',
      'languageArabicLabel': 'ዓረብኛ',
      'languageAmharicLabel': 'አማርኛ',
      'studentCountOne': '1 ተማሪ ተመዝግቧል',
      'studentCountMany': '{count} ተማሪዎች ተመዝግበዋል',
      'ustazStudentsMeta': 'ኡስታዝ: {name} • {countLabel}',
      'dailyCurriculumDesc': 'የዕለት ተዕለት ትምህርት፦ ሰበቅ (አዲስ ሐፍዝ)፣ ሰብቂ (የቅርብ ክለሳ) እና መንዚል (ጠቅላላ ክለሳ)። የዕለት ክትትል ይመዝግቡና ወላጆችን ያሳውቁ።',
      'classRosterHeader': 'የክፍሉ ተማሪዎች ዝርዝር',
      'noStudentsCurrentlyAssigned': 'በአሁኑ ጊዜ የተመደቡ ተማሪዎች የሉም።',
      'manageUsersSubtitle': 'መምህራንን፣ ወላጆችን፣ የክፍል ምደባዎችን እና መዳረሻን ያስተዳድሩ',
      'manageCirclesSubtitle': 'ሐለቃዎችን ይፍጠሩ፣ ኡስታዞችን ይመድቡ እና ምዝገባን ይመልከቱ',
      'generateInvitesSubtitle': 'ለመምህራንና ለወላጆች የምዝገባ ኮዶችን ያመንጩ',
      'rosterAndCurriculumMeta': '{circle} • ዝርዝር እና ስርዓተ ትምህርት',
      'broadcastNoticesSubtitle': 'ለወላጆችና ለመምህራን ማስታወቂያዎችን ያሰራጩ',
      'parentFeesSubtitle': 'የባንክ ደረሰኞችን ይስቀሉ እና ወርሃዊ ክፍያ ሁኔታን ይመልከቱ',
      'adminFeesSubtitle': 'ወርሃዊ ክፍያ ይላኩ፣ ደረሰኞችን ያረጋግጡ እና የዘገዩ ማንቂያዎችን ይላኩ',
      'centerSetupTitle': 'የማዕከሉ ዝግጅት',
      'completeOnboardingSubtitle': 'ሁሉንም ክፍሎች ለማስጀመር ዝግጅቱን ያጠናቅቁ',
      'stepsOf3': '{count} ከ3',
      'checklistStep1': 'የጥናት ክፍል (ሐለቃ) ይፍጠሩ',
      'checklistStep2': 'የኡስታዝ መጋበዣ ኮድ ያመንጩ',
      'checklistStep3': 'የመጀመሪያውን ተማሪ ይመዝግቡ',
      'createFirstHalaqahAction': 'የመጀመሪያውን ሐለቃ ይፍጠሩ',
      'generateTeacherCodeAction': 'የመምህር መጋበዣ ኮድ ያመንጩ',
      'enrollFirstStudentAction': 'የመጀመሪያውን ተማሪ ይመዝግቡ',
      'assignedStudyCircleHeader': 'የተመደበ የጥናት ክፍል',
      'studentsBadgeLabel': '{count} ተማሪዎች',
      'studentBadgeOne': '1 ተማሪ',
      'todaysAttendanceLabel': 'የዛሬ ክትትል',
      'markedProgressLabel': '{marked} / {total} ተመዝግቧል',
      'pendingExcusesNoticeOne': '1 በመጠባበቅ ላይ ያለ የመቅረት ይቅርታ ጥያቄ',
      'pendingExcusesNoticeMany': '{count} በመጠባበቅ ላይ ያሉ የመቅረት ይቅርታ ጥያቄዎች',
      'takeAttendanceAction': 'ክትትል ይውሰዱ',
      'homeworkLabel': 'የቤት ሥራ',
      'familyLearningHubHeader': 'የቤተሰብ ትምህርት ማዕከል',
      'welcomeParentFallback': 'እንኳን ደህና መጡ ወላጅ',
      'enrolledCountBadge': '{count} ተመዝግቧል',
      'todayAttBadge': 'ዛሬ፦ {status}',
      'noChildrenLinkedBanner': 'እስካሁን ከመለያዎ ጋር የተገናኙ ልጆች የሉም። እባክዎ የማዕከሉን አስተዳደር ያነጋግሩ።',
      'learningProgressAction': 'የትምህርት እድገት',
      'noAnnouncementsTitle': 'እስካሁን ማስታወቂያዎች የሉም',
      'noAnnouncementsDesc': 'ኦፊሴላዊ መግለጫዎችና የማዕከሉ ማስታወቂያዎች እንደታተሙ እዚህ ይታያሉ።',
      'pinnedTag': 'የተሰካ',
      'centerNoticeTag': 'የማዕከሉ ማስታወቂያ',
      'attachmentFallback': 'አባሪ ፋይል',
      'tapToOpenConvo': 'ውይይቱን ለመክፈት ይንኩ',
      'messageClassParentTitle': 'የክፍሉን ወላጅ ያነጋግሩ',
      'selectParentFromCircle': 'ከ{circle} ክፍል ወላጅ ይምረጡ',
      'noStudentsInClassTitle': 'በክፍሉ ውስጥ ተማሪዎች የሉም',
      'noStudentsInCircleMsg': 'በአሁኑ ጊዜ በክፍልዎ ውስጥ የተመደቡ ተማሪዎች የሉም።',
      'noLinkedParentMsg': '{name} እስካሁን የተገናኘ የወላጅ መለያ የለውም።',
      'couldNotOpenChatMsg': 'ውይይቱን መክፈት አልተቻለም፦ {error}',
      'couldNotStartChatMsg': 'ውይይቱን መጀመር አልተቻለም፦ {error}',
      'adminMessagingHubTitle': 'የአስተዳደር መልእክት ማዕከል',
      'adminMessagingHubSubtitle': 'ቀጥተኛ ውይይት ወይም የክፍል ቡድን ይጀምሩ',
      'messageTeacherOrParent': 'መምህር ወይም ወላጅ ያነጋግሩ',
      'browseActiveContacts': 'ሁሉንም ንቁ መምህራንና ወላጆችን ይመልከቱ',
      'studyCircleParentsGroupFallback': 'የጥናት ክፍል ወላጆች ቡድን',
      'failedToCreateGroupMsg': 'ቡድኑን መፍጠር አልተቻለም፦ {error}',
      'createParentGroupTitle': 'የወላጆች ሐለቃ ቡድን ይፍጠሩ',
      'createParentGroupSubtitle': 'ከክፍሉ ወላጆች ጋር የቡድን ውይይት',
      'studentContactMeta': 'ተማሪ፦ {name} • {phone}',
      'tajweedAndRecitationHeader': 'ተጅዊድ እና ቂርኣት',
      'assignSurahGoalsHint': 'ለክፍልዎ የሱራ ግቦችን እና የተጅዊድ ሕጎችን ይመድቡ፤ ወላጆች የቤት ልምምድ ሲመዘግቡ ይገምግሙ።',
      'noHomeworkFoundTitle': 'ምንም የቤት ሥራ አልተገኘም',
      'noHomeworkForCircleMsg': 'ለ{circle} እስካሁን የቤት ሥራ አልተሰጠም። የመጀመሪያውን የቂርኣት ግብ ለመስጠት "{action}"ን ይንኩ።',
      'practicedAtHomeCount': '{completed} ከ{total} በቤት ተለማምደዋል',
      'noStudentsInHalaqahTitle': 'በክፍሉ ውስጥ ተማሪዎች የሉም',
      'noEnrolledStudentsHalaqahMsg': 'በዚህ ሐለቃ ውስጥ የተመዘገቡ ተማሪዎች አልተገኙም።',
      'reviewedStatus': 'ተገምግሟል',
      'practicedStatus': 'ተለማምዷል',
      'needsPracticeStatus': 'ልምምድ ያስፈልጋል',
      'homeRepetitionsLine': 'የቤት ድግግሞሽ፦ ከወላጅ ጋር {count} ጊዜ ተቀርቷል',
      'parentNoteQuote': 'የወላጅ ማስታወሻ፦ "{note}"',
      'ratingExcellent': 'በጣም ጥሩ',
      'ratingVeryGood': 'በጣም ደህና',
      'ratingGood': 'ጥሩ',
      'ratingNeedsRevision': 'ክለሳ ያስፈልገዋል',
      'ratingFeedbackLine': 'ደረጃ፦ {rating} • "{feedback}"',
      'submissionEndorsedMsg': 'የ{name} ልምምድ ተረጋግጧል።',
      'homeworkAssignedMsg': 'የቤት ሥራው በተሳካ ሁኔታ ተመድቧል።',
      'noLinkedChildrenTitle': 'የተገናኙ ልጆች የሉም',
      'noLinkedChildrenDesc': 'በአሁኑ ጊዜ ከወላጅ መለያዎ ጋር የተገናኙ ልጆች የሉም። ልጆችዎን ለማስመዝገብ የማዕከሉን አስተዳደር ያነጋግሩ።',
      'tasksCountBadge': '{count} ተግባራት',
      'noHomeworkAssignedTitle': 'የተመደበ የቤት ሥራ የለም',
      'ustazNoHomeworkYetMsg': 'ኡስታዝ ለ{name} ክፍል እስካሁን የቤት ሥራ አልለጠፉም።',
      'surahAyahRange': '{surah} (አንቀጾች {from}–{to})',
      'surahAyahWithTeacher': '{surah} (አንቀጾች {from}–{to}) • ኡስታዝ፦ {teacher}',
      'dueDateLabel': 'ማስረከቢያ ቀን፦ {date}',
      'completedRepetitionsLine': 'ተጠናቋል፦ በቤት {count} ጊዜ ተቀርቷል',
      'yourNoteQuote': 'የእርስዎ ማስታወሻ፦ "{note}"',
      'ustazGradeLine': 'የኡስታዝ ደረጃ፦ {rating}',
      'feedbackQuote': 'አስተያየት፦ "{feedback}"',
      'markedPracticedMsg': 'ለ{name} ልምምድ ተመዝግቧል። ኡስታዙ እንዲያውቁት ተደርጓል።',
      'totalAssignmentsMeta': 'በሁሉም ክፍሎች በአጠቃላይ {count} የቤት ሥራዎች',
      'noHomeworkRecordedTitle': 'ምንም የቤት ሥራ አልተመዘገበም',
      'teachersNoHomeworkYetMsg': 'መምህራን በየትኛውም ክፍል እስካሁን የቤት ሥራ አልፈጠሩም።',
      'defaultEndorseFeedback': 'ማሻአላህ በጣም ጥሩ ቂርኣት እና ግልጽ ተጅዊድ።',
      'gradePracticeTitle': 'የ{name}ን ልምምድ ይገምግሙ',
      'recitationRatingLabel': 'የቂርኣት ደረጃ',
      'ustazFeedbackLabel': 'የኡስታዝ አስተያየት / ምክር',
      'ustazFeedbackHint': 'ለወላጅና ለተማሪ መመሪያ ያስገቡ...',
      'failedEndorseMsg': 'ግምገማውን መላክ አልተቻለም፦ {error}',
      'defaultHomeworkTitle': 'የሱራ ሐፍዝ እና ተጅዊድ',
      'defaultTajweedFocus': 'የጉና እና የኢኽፋእ ሕጎች',
      'defaultHomeworkInstructions': 'ትክክለኛውን መድ እና ጉና በመጠበቅ እያንዳንዱን አንቀጽ ቢያንስ 3 ጊዜ ይቅሩ።',
      'circlePrefixLabel': 'ክፍል፦ {circle}',
      'assignmentTitleLabel': 'የቤት ሥራ ርዕስ',
      'assignmentTitleHint': 'ለምሳሌ፦ የሱራ አል-ሙልክ ልምምድ',
      'surahNameLabel': 'የሱራ ስም',
      'fromAyahLabel': 'ከአንቀጽ',
      'toAyahLabel': 'እስከ አንቀጽ',
      'tajweedFocusLabel': 'የተጅዊድ ሕግ ትኩረት',
      'tajweedFocusHint': 'ለምሳሌ፦ ቀልቀላ፣ ጉና፣ መድ',
      'instructionsParentsStudentsLabel': 'ለወላጆችና ለተማሪዎች መመሪያ',
      'changeDateAction': 'ቀን ቀይር',
      'failedAssignHomeworkMsg': 'የቤት ሥራ መመደብ አልተቻለም፦ {error}',
      'defaultPracticeNote': 'ከወላጅ ጋር በጥሩ ሁኔታ ተቀርቷል።',
      'practiceForStudentTitle': 'የ{name} ልምምድ',
      'repetitionsQuestion': 'ልጅዎ በቤት ውስጥ ስንት ጊዜ ቀርቷል?',
      'repetitionsCountLabel': '{count} ድግግሞሽ',
      'parentNotesOptionalLabel': 'የወላጅ ማስታወሻ (አማራጭ)',
      'parentNotesHint': 'ለምሳሌ፦ በቀላሉ አንብቧል፣ አንቀጽ 7 ላይ ትንሽ ተቸግሯል...',
      'failedSavePracticeMsg': 'ልምምዱን ማስቀመጥ አልተቻለም፦ {error}',
      'assignedClassHeader': 'የተመደበ ክፍል',
      'allPresentSuccessMsg': 'ሁሉም የክፍሉ ተማሪዎች በተገኙበት ተመዝግቧል። ወላጆች እንዲያውቁት ተደርጓል።',
      'failedMarkAttendanceMsg': 'ክትትል መመዝገብ አልተቻለም፦ {error}',
      'allPresentAction': 'ሁሉም ተገኝተዋል',
      'pendingAbsenceExcusesTitle': 'በመጠባበቅ ላይ ያሉ የመቅረት ይቅርታዎች ({count})',
      'submittedByParentsSubtitle': 'ለግምገማ በወላጆች የቀረቡ',
      'reasonLabelValue': 'ምክንያት፦ {reason}',
      'absenceExcuseApprovedMsg': 'ለ{name} የመቅረት ይቅርታ ጸድቋል።',
      'failedApproveRequestMsg': 'ጥያቄውን ማጽደቅ አልተቻለም፦ {error}',
      'failedDeclineRequestMsg': 'ጥያቄውን ውድቅ ማድረግ አልተቻለም፦ {error}',
      'classAttendanceSheetTitle': 'የክፍል ክትትል መዝገብ',
      'classAttendanceSheetSubtitle': 'ክትትል ለመመዝገብ ሁኔታ ይንኩ፤ ወላጆች በራስ-ሰር ማሳወቂያ ያገኛሉ።',
      'noStudentsInThisCircleTitle': 'በዚህ ክፍል ውስጥ የተመዘገቡ ተማሪዎች የሉም',
      'studentsAssignedByAdminMsg': 'በአስተዳደሩ ወደ {circle} የተመደቡ ተማሪዎች እዚህ ይታያሉ።',
      'attendanceForDateLabel': 'የ{date} ክትትል',
      'todayDateParens': 'ዛሬ ({date})',
      'messageParentAction': 'ወላጅን ያነጋግሩ',
      'attendanceHistoryTitle': 'የክትትል ታሪክ',
      'studentMarkedStatusMsg': '{name} {status} ተብሎ ተመዝግቧል። ወላጅ እንዲያውቁት ተደርጓል።',
      'failedSaveAttendanceMsg': 'ክትትል ማስቀመጥ አልተቻለም፦ {error}',
      'noChildrenLinkedTitle': 'የተገናኙ ልጆች የሉም',
      'whenAdminEnrollsChildMsg': 'አስተዳደሩ ልጅዎን ሲያስመዘግብና ከመለያዎ ጋር ሲያገናኝ፣ የቁርኣን እድገታቸውና ክትትላቸው እዚህ ይታያል።',
      'myEnrolledChildrenHeader': 'የተመዘገቡ ልጆቼ ({count})',
      'messageUstazAction': 'ኡስታዙን ያነጋግሩ',
      'quranMemorizationProgressTitle': 'የቁርኣን ሐፍዝ እድገት',
      'unrecordedStatus': 'ያልተመዘገበ',
      'declinedStatus': 'ውድቅ የተደረገ',
      'excuseReasonLine': 'ምክንያት፦ {reason}',
      'noAttendanceLoggedTitle': 'እስካሁን የተመዘገበ ክትትል የለም',
      'dailyAttendanceAppearHereMsg': 'በኡስታዝ የተመዘገቡ የዕለት ክትትሎች እዚህ ይታያሉ።',
      'weeklyQuranProgressReportsTitle': 'ሳምንታዊ የቁርኣን እድገት ሪፖርቶች',
      'sabaqSabqiManzilSubtitle': 'የሰበቅ፣ ሰብቂ፣ መንዚል እና የተጅዊድ ግምገማዎች',
      'noWeeklyReportsTitle': 'እስካሁን ሳምንታዊ ሪፖርቶች የሉም',
      'weeklyReportsAppearHereMsg': 'ሳምንታዊ የሐፍዝና የተጅዊድ ግምገማዎች እንደታተሙ እዚህ ይታያሉ።',
      'parentContactLine': 'ወላጅ፦ {name}{contact}',
      'removeStudentConfirmTitle': '{name}ን ያስወግዱ?',
      'removeStudentConfirmBody': 'ይህ ተማሪውንና የተገናኙ መዝገቦችን ከዝርዝሩ በቋሚነት ያስወግዳል።',
      'removeAction': 'አስወግድ',
      'removedStudentMsg': '{name} ከዝርዝሩ ተወግዷል።',
      'failedRemoveStudentPermsMsg': 'ተማሪውን ማስወገድ አልተቻለም። እባክዎ ፈቃዶችን ያረጋግጡ።',
      'failedRemoveStudentMsg': 'ተማሪውን ማስወገድ አልተቻለም፦ {error}',
      'removeStudentMenuLabel': 'ተማሪውን አስወግድ',
      'attendanceShortTab': 'ክትትል',
      'reportShortTab': 'ሪፖርት',
      'messageShortAction': 'መልእክት',
      'attendanceLogTitle': 'የ{name} የክትትል መዝገብ',
      'noAttendanceRecordedYet': 'እስካሁን የተመዘገበ ክትትል የለም።',
      'attendanceRecordedNotifyMsg': 'ክትትል ተመዝግቧል። ወላጅ {name} እንዲያውቁት ተደርጓል።',
      'weeklyReportPostedNotifyMsg': 'ሳምንታዊ ሪፖርት ተልኳል። ወላጅ {name} እንዲያውቁት ተደርጓል።',
      'defaultAttendedOnTime': 'በሰዓቱ በክፍል ተገኝቷል',
      'weekOfDateLabel': 'የ{date} ሳምንት',
      'ustazNotesQuote': 'የኡስታዝ ማስታወሻ፦ "{notes}"',
      'absenceExcuseSubmittedMsg': 'ለ{name} የመቅረት ይቅርታ ቀርቧል። ኡስታዙ እንዲያውቁት ተደርጓል።',
      'reasonMedical': 'ሕመም / የጤና እክል',
      'reasonFamilyEmergency': 'የቤተሰብ አስቸኳይ ጉዳይ',
      'reasonSchoolExam': 'የትምህርት ቤት ፈተና',
      'reasonTravel': 'ጉዞ / ከከተማ ውጭ',
      'reasonPersonal': 'የግል ምክንያት',
      'editRemarksTitle': 'የ{name}ን ማስታወሻ አስተካክል',
      'teacherRemarksLabel': 'የመምህር ማስታወሻ',
      'failedSaveNoteMsg': 'ማስታወሻውን ማስቀመጥ አልተቻለም፦ {error}',
      'saveNoteAction': 'ማስታወሻ አስቀምጥ',
      'dailyAttendanceTitle': 'የ{name} የዕለት ክትትል',
      'statusFieldLabel': 'ሁኔታ',
      'teacherRemarksShortLabel': 'የኡስታዝ ማስታወሻ',
      'saveAndNotifyAction': 'አስቀምጥና አሳውቅ',
      'defaultSabaqSample': 'ሱራ አል-ሙልክ (1-15)',
      'defaultSabqiSample': 'ሱራ አል-ቀለም (1-20)',
      'defaultManzilSample': 'የጁዝ 29 ክለሳ',
      'defaultReportRemarks': 'ወጥ የሆነ የተጅዊድ አነባበብ።',
      'weeklyReportTitle': 'የ{name} ሳምንታዊ ሪፖርት',
      'sabaqNewLessonLabel': 'ሰበቅ (አዲስ ትምህርት)',
      'sabqiRecentRevisionLabel': 'ሰብቂ (የቅርብ ክለሳ)',
      'manzilRetentionLabel': 'መንዚል (አጠቃላይ ክለሳ)',
      'ustazEvaluationNotesLabel': 'የኡስታዝ የግምገማ ማስታወሻ',
      'failedSubmitReportMsg': 'ሪፖርቱን መላክ አልተቻለም፦ {error}',
      'submitAndNotifyAction': 'ላክና አሳውቅ',
      'defaultExcuseNote': 'ጤና ስለተሰማው በቤት ውስጥ እረፍት ያስፈልገዋል።',
      'requestExcuseTitle': 'የመቅረት ይቅርታ ጥያቄ፦ {name}',
      'dateLineLabel': 'ቀን፦ {date}',
      'reasonForAbsenceLabel': 'የመቅረት ምክንያት',
      'parentExplanationLabel': 'የወላጅ ማብራሪያ',
      'parentExplanationHint': 'ለመምህሩ የምክንያቱን ዝርዝር ያስገቡ...',
      'failedSubmitExcuseMsg': 'ይቅርታውን መላክ አልተቻለም፦ {error}',
      'cbeBankName': 'የኢትዮጵያ ንግድ ባንክ',
      'telebirrAccountLabel': 'የቴሌብር ሞባይል መለያ',
      'cbeMobileBanking': 'የንግድ ባንክ ሞባይል ባንኪንግ',
      'telebirrMobile': 'ቴሌብር ሞባይል',
      'cashDepositLabel': 'በጥሬ ገንዘብ ተቀማጭ',
      'cashSlipLabel': 'የጥሬ ገንዘብ ደረሰኝ',
      'paymentVerificationRejectedTitle': 'የክፍያ ማረጋገጫ ውድቅ ተደርጓል',
      'reuploadValidReceiptAction': 'ትክክለኛ ደረሰኝ እንደገና ይስቀሉ',
      'monthlyTuitionHeader': 'ወርሃዊ ክፍያ',
      'studentLineLabel': 'ተማሪ፦ {name}',
      'perMonthlyFeeSuffix': '/ ወርሃዊ ክፍያ',
      'verifiedApprovedByLine': 'በ{name} ተረጋግጦ ጸድቋል።',
      'receiptUploadedVerifyingMsg': 'ደረሰኙ ተስቅሏል። አስተዳደሩ ክፍያዎን እያረጋገጠ ነው።',
      'uploadReceiptScreenshotAction': 'የክፍያ ደረሰኝ ምስል ይስቀሉ',
      'noTuitionDueTitle': 'በአሁኑ ጊዜ የሚከፈል ክፍያ የለም',
      'noTuitionDueDesc': 'አስተዳደሩ ለተማሪዎ ወርሃዊ የትምህርት ክፍያ ሲልክ ደረሰኞችዎ እዚህ ይታያሉ።',
      'paymentHistoryCount': 'የክፍያ ታሪክ ({count})',
      'toReviewTab': 'ለግምገማ',
      'receiptsAwaitingReviewTitle': 'ግምገማ የሚጠብቁ ደረሰኞች ({count})',
      'actionRequiredTag': 'እርምጃ ያስፈልጋል',
      'overdueAccountsTitle': 'ዘግይተው የቆዩ ሂሳቦች ({count})',
      'pastDueTag': 'ጊዜው ያለፈበት',
      'tuitionRecordsTitle': 'የክፍያ መዝገቦች ({count})',
      'plusIssueTuition': '+ ክፍያ ላክ',
      'noTuitionIssuedTitle': 'እስካሁን የተላከ የትምህርት ክፍያ የለም',
      'noTuitionIssuedDesc': 'ወላጆች መክፈልና ደረሰኝ መስቀል እንዲችሉ ለተመዘገቡ ተማሪዎች ወርሃዊ ክፍያ ይላኩ።',
      'issueFirstTuitionAction': 'የመጀመሪያውን ወርሃዊ ክፍያ ይላኩ',
      'parentEmailLine': 'ወላጅ፦ {name} ({email})',
      'overdueUpperTag': 'ጊዜው ያለፈበት',
      'overdueAlertDispatchedMsg': 'ለ{name} የዘገየ ክፍያ ማንቂያ ተልኳል።',
      'sendAlertAction': 'ማንቂያ ላክ',
      'paymentApprovedForMsg': 'ለ{name} ክፍያ ጸድቋል።',
      'rejectAction': 'ውድቅ አድርግ',
      'approveAction': 'አጽድቅ',
      'amountLineLabel': 'መጠን፦ \${amount}',
      'viewReceiptAction': 'ደረሰኝ ተመልከት',
      'rejectionReasonQuote': 'ውድቅ የተደረገበት ምክንያት፦ "{reason}"',
      'noStudentsEnrolledAlertTitle': 'ምንም ተማሪዎች አልተመዘገቡም',
      'addOneStudentBeforeTuitionMsg': 'ክፍያ ከመላክዎ በፊት እባክዎ ቢያንስ አንድ ተማሪ በተማሪዎች ክፍል ያክሉ።',
      'receiptInspectorTitle': 'የደረሰኝ መርማሪ',
      'couldNotLoadReceiptImage': 'የደረሰኙን ምስል መጫን አልተቻለም',
      'tapToZoomHint': 'ለማጉላት ይንኩ',
      'paymentSummaryHeader': 'የክፍያ ማጠቃለያ',
      'rejectWithReasonAction': 'ከምክንያት ጋር ውድቅ አድርግ',
      'receiptImageTitle': 'የደረሰኝ ምስል',
      'enterTuitionMonthError': 'እባክዎ የክፍያውን ወር ያስገቡ።',
      'enterValidTuitionAmountError': 'እባክዎ ትክክለኛ የክፍያ መጠን (> 0) ያስገቡ።',
      'tuitionIssuedForMsg': 'ለ{name} ክፍያ ተልኳል።',
      'defaultReceiptNote': 'ክፍያው በሞባይል ባንኪንግ ተከናውኗል።',
      'receiptSubmittedSuccessMsg': 'ደረሰኙ በተሳካ ሁኔታ ቀርቧል። አስተዳደሩ ያረጋግጠዋል።',
      'uploadPaymentReceiptTitle': 'የክፍያ ደረሰኝ ይስቀሉ',
      'studentMonthLine': 'ተማሪ፦ {name} ({month})',
      'amountDueLine': 'የሚከፈል መጠን፦ \${amount}',
      'paymentChannelLabel': 'የክፍያ መንገድ',
      'selectedFileLabel': 'የተመረጠ፦ {name}',
      'tapPickReceiptHint': 'የደረሰኝ ምስል ለመምረጥ ይንኩ',
      'tapToChangeImage': 'ምስሉን ለመቀየር ይንኩ',
      'chooseSlipFromGallery': 'ከማዕከለ-ስዕላት የክፍያ ደረሰኝ ይምረጡ',
      'transactionRefLabel': 'የግብይት መለያ / ማስታወሻ',
      'submitReceiptAction': 'ደረሰኝ ላክ',
      'defaultRejectReceiptReason': 'የተሰቀለው ምስል የደበዘዘ ስለሆነ የግብይት መለያ ቁጥሩን ማንበብ አልተቻለም። እባክዎ እንደገና ይስቀሉ።',
      'paymentRejectedSentMsg': 'ክፍያው ውድቅ ተደርጓል፤ ምክንያቱም ለ{name} ተልኳል።',
      'rejectPaymentReceiptTitle': 'የክፍያ ደረሰኝ ውድቅ አድርግ',
      'specifyRejectionReasonMsg': 'የ{name} ደረሰኝ ለምን ውድቅ እንደተደረገ ይግለጹ። ይህ ምክንያት ለወላጁ ይታያል።',
      'rejectionReasonRequiredLabel': 'ውድቅ የተደረገበት ምክንያት *',
      'rejectionReasonHint': 'ለምሳሌ፦ የደበዘዘ ምስል፣ የተሳሳተ መጠን፣ የጎደለ መለያ ቁጥር...',
      'confirmRejectionAction': 'ውድቅ ማድረግን አረጋግጥ',
      'failedSendMsg': 'መልእክቱን መላክ አልተቻለም፦ {error}',
      'micPermissionRequiredMsg': 'የድምጽ መልእክት ለመቅዳት የማይክሮፎን ፈቃድ ያስፈልጋል።',
      'couldNotStartRecordingMsg': 'መቅዳት መጀመር አልተቻለም፦ {error}',
      'voiceFileUnavailableMsg': 'የድምጽ ቅጂ ፋይሉ ከአሁን በኋላ አይገኝም።',
      'voiceExceedsLimitMsg': 'የድምጽ ቅጂው ከ25 ሜጋባይት ገደብ በላይ ነው።',
      'voiceMessageWithDuration': 'የድምጽ መልእክት ({duration})',
      'failedStopRecordingMsg': 'ቀረጻውን ማቆም አልተቻለም፦ {error}',
      'failedSendVoiceMsg': 'የድምጽ ቅጂውን መላክ አልተቻለም፦ {error}',
      'voiceUrlUnavailableMsg': 'የድምጽ መልእክት አድራሻው አይገኝም።',
      'offlineVoiceNotFoundMsg': 'ከመስመር ውጭ የተቀዳ የድምጽ ፋይል አልተገኘም።',
      'couldNotAccessVoiceMsg': 'የድምጽ መልእክቱን መክፈት አልተቻለም።',
      'errorPlayingAudioMsg': 'ድምጽ በማጫወት ላይ ስህተት ተፈጥሯል፦ {error}',
      'imageExceedsLimitMsg': 'ምስሉ ከ25 ሜጋባይት ገደብ በላይ ነው። እባክዎ ትንሽ ፋይል ይምረጡ።',
      'failedUploadImageMsg': 'ምስሉን ወደ ክላውድ ማከማቻ መስቀል አልተቻለም።',
      'failedAttachImageMsg': 'ምስሉን ማያያዝ አልተቻለም፦ {error}',
      'videoExceedsLimitMsg': 'ቪዲዮው ከ25 ሜጋባይት ገደብ በላይ ነው። እባክዎ አጭር ክሊፕ ይምረጡ።',
      'failedUploadVideoMsg': 'ቪዲዮውን ወደ ክላውድ ማከማቻ መስቀል አልተቻለም።',
      'failedAttachVideoMsg': 'ቪዲዮውን ማያያዝ አልተቻለም፦ {error}',
      'docExceedsLimitMsg': 'ሰነዱ ከ25 ሜጋባይት ገደብ በላይ ነው። እባክዎ ትንሽ ፋይል ይምረጡ።',
      'failedUploadDocMsg': 'ሰነዱን ወደ ክላውድ ማከማቻ መስቀል አልተቻለም።',
      'failedAttachDocMsg': 'ሰነዱን ማያያዝ አልተቻለም፦ {error}',
      'shareAttachmentSubtitle': 'ፎቶዎች፣ ቪዲዮዎች፣ ፋይሎች ወይም የቁርኣን ጥቅስ',
      'cameraOption': 'ካሜራ',
      'galleryOption': 'ማዕከለ-ስዕላት',
      'videoOption': 'ቪዲዮ',
      'ayahQuoteOption': 'የአንቀጽ ጥቅስ',
      'ayahKahf1810Quote': 'ሱራ አል-ካህፍ (18:10)፦ "ጌታችን ሆይ! ከአንተ ዘንድ እዝነትን ስጠን፤ ከነገራችንም ለእኛ ቅንነትን አዘጋጅልን።"',
      'openInBrowserTooltip': 'በአሳሽ ውስጥ ክፈት',
      'failedLoadImagePreview': 'የምስል ቅድመ-እይታ መጫን አልተቻለም',
      'failedDeleteMsg': 'መልእክቱን ማጥፋት አልተቻለም፦ {error}',
      'ustazDirectChannel': 'የኡስታዝ ቀጥታ መስመር',
      'parentDirectChannel': 'የወላጅ ቀጥታ መስመር',
      'centerChannel': 'የማዕከሉ መስመር',
      'directSchoolChannel': 'ቀጥተኛ የትምህርት ቤት መስመር',
      'emptyChatPrompt': 'ለመጀመር መልእክት፣ ሰነድ፣ ፎቶ ወይም የድምጽ መልእክት ይላኩ።',
      'uploadingAttachmentToCloud': 'አባሪ ፋይሉ ወደ ክላውድ በመሰቀል ላይ...',
      'recordingVoiceNoteLabel': 'የድምጽ መልእክት በመቅዳት ላይ...',
      'editedTag': 'የተስተካከለ ',
      'viewAction': 'ተመልከት',
      'videoFileFallback': 'የቪዲዮ ፋይል',
      'tapToPlayVideo': 'ቪዲዮውን ለማጫወት ይንኩ',
      'couldNotOpenDocUrl': 'የሰነዱን አድራሻ መክፈት አልተቻለም።',
      'tapToViewDownload': 'ለማየት / ለማውረድ ይንኩ',
      'enterUpdatedMsgHint': 'የተስተካከለውን መልእክት ያስገቡ...',
      'failedEditMsg': 'መልእክቱን ማስተካከል አልተቻለም፦ {error}',
      'noCirclesCreatedTitle': 'እስካሁን የጥናት ክፍሎች አልተፈጠሩም',
      'createFirstCircleDesc': 'መምህራንን ለመመደብና ተማሪዎችን ለማስመዝገብ የመጀመሪያውን ሐለቃ ይፍጠሩ።',
      'createFirstCircleAction': 'የመጀመሪያውን ክፍል ይፍጠሩ',
      'deleteCircleTooltip': 'ክፍሉን አጥፋ',
      'deleteCircleConfirmTitle': 'ክፍሉን ያጥፉ?',
      'deleteCircleConfirmBody': '"{name}"ን ማስወገድ እንደሚፈልጉ እርግጠኛ ነዎት?',
      'removedCircleMsg': 'ክፍል "{name}" ተወግዷል።',
      'couldNotDeleteCircleMsg': 'ክፍሉን ማጥፋት አልተቻለም፦ {error}',
      'ustazNameLabel': 'ኡስታዝ፦ {name}',
      'defaultCircleSchedule': 'ዕለታዊ የቂርኣት ክፍለ ጊዜ',
      'circleCreatedSuccessMsg': 'የጥናት ክፍል "{name}" በተሳካ ሁኔታ ተፈጥሯል።',
      'failedCreateCircleMsg': 'ክፍል መፍጠር አልተቻለም፦ {error}',
      'createStudyCircleTitle': 'የጥናት ክፍል ይፍጠሩ',
      'halaqahNameReqLabel': 'የሐለቃ ስም *',
      'assignTeacherOptionalHint': 'መምህር ይመድቡ (አማራጭ)',
      'unassignedAssignLater': 'ያልተመደበ (በኋላ ይመድቡ)',
      'scheduleFieldLabel': 'መርሃ ግብር',
      'scheduleHint': 'ለምሳሌ፦ ከሰኞ-አርብ ከ10:00 - 12:00 ሰዓት',
      'curriculumFocusLabel': 'የክፍሉ ማስታወሻ / ስርዓተ ትምህርት',
      'curriculumFocusHint': 'ለምሳሌ፦ የጁዝ ዓማ ሐፍዝ እና የመኻሪጅ ክለሳ',
      'createCircleAction': 'ክፍል ፍጠር',
      'noActiveCodesTitle': 'ንቁ ኮዶች የሉም',
      'generateInviteOnboardingDesc': 'አዲስ አባላትን ለመቀበል ከላይ የመምህር ወይም የወላጅ መጋበዣ ኮድ ያመንጩ።',
      'activeCodeReadyTitle': 'ንቁ ኮድ ዝግጁ ነው',
      'liveInvitationCodesTitle': 'የቀጥታ መጋበዣ ኮዶች',
      'noInviteCodesGeneratedYet': 'እስካሁን የተፈጠሩ የመጋበዣ ኮዶች የሉም።',
      'failedGenerateCodeMsg': 'ኮድ መፍጠር አልተቻለም',
      'teacherRoleTag': 'መምህር',
      'parentRoleTag': 'ወላጅ',
      'suspendWord': 'አግድ',
      'activateWord': 'አንቃ',
      'suspendActivateConfirmTitle': '{name}ን {action}?',
      'suspendWarningMsg': 'የታገዱ ተጠቃሚዎች ወዲያውኑ ወደ መለያ እንዳይገቡና የማዕከሉን መረጃ እንዳያገኙ ይታገዳሉ።',
      'activateRestoredMsg': 'የተጠቃሚው መለያ ተመልሶ ወደ ውስጥ መግባት ይችላል።',
      'failedUpdateUserStatusMsg': 'የተጠቃሚውን ሁኔታ ማዘመን አልተቻለም፦ {error}',
      'userSuspendedMsg': '{name} ታግዷል።',
      'userReactivatedMsg': '{name} እንደገና ነቅቷል።',
      'removeUserAccountTitle': 'የተጠቃሚ መለያውን ያጥፉ?',
      'removeUserAccountBody': '"{name}"ን በቋሚነት ማጥፋት እንደሚፈልጉ እርግጠኛ ነዎት? ይህ እርምጃ ሊቀለበስ አይችልም።',
      'removePermanentlyAction': 'በቋሚነት አጥፋ',
      'failedRemoveUserMsg': 'ተጠቃሚውን ማጥፋት አልተቻለም፦ {error}',
      'failedRemoveUserSimple': 'ተጠቃሚውን ማጥፋት አልተቻለም።',
      'removedUserFromCenterMsg': '{name} ከማዕከሉ ተወግዷል።',
      'createCircleFirstMsg': 'እባክዎ መጀመሪያ የጥናት ክፍል (ሐለቃ) ይፍጠሩ።',
      'assignTeacherTitle': '{name}ን ይመድቡ',
      'unassignedRemoveFromCircle': 'ያልተመደበ (ከክፍሉ አስወግድ)',
      'studyCircleHalaqahLabel': 'የጥናት ክፍል (ሐለቃ)',
      'failedUpdateAssignmentMsg': 'የክፍል ምደባውን ማዘመን አልተቻለም፦ {error}',
      'profilePhotoUpdatedUserMsg': 'የ{name} መገለጫ ፎቶ ታድሷል።',
      'couldNotUpdatePhotoMsg': 'ፎቶውን ማዘመን አልተቻለም፦ {error}',
      'changeRoleForTitle': 'የ{name}ን ሚና ቀይር',
      'selectPermissionsPrompt': 'ለዚህ ተጠቃሚ ፈቃዶችን እና የመዳረሻ ደረጃ ይምረጡ፦',
      'superadminFullControlTitle': 'ዋና አስተዳዳሪ (ሙሉ ቁጥጥር)',
      'superadminFullControlDesc': 'ክፍያዎችን፣ የትምህርት ክፍያን እና የተጠቃሚ ሚና እድገትን ጨምሮ ሙሉ መዳረሻ',
      'adminRoleDescTitle': 'አስተዳዳሪ (የማዕከሉ አስተዳዳሪ)',
      'adminRoleDescSubtitle': 'የጥናት ክፍሎች፣ ተማሪዎች፣ ክትትል፣ የቤት ሥራ (የክፍያ መዳረሻ የለም)',
      'teacherRoleDescTitle': 'መምህር (ኡስታዝ)',
      'teacherRoleDescSubtitle': 'የተመደበ የጥናት ክፍል፣ ክትትል እና የቂርኣት ግምገማ',
      'parentRoleDescSubtitle': 'የተገናኙ ልጆች፣ ሳምንታዊ ሪፖርቶች እና የክፍያ አፈጻጸም',
      'cannotDemoteSelfNote': 'ማሳሰቢያ፦ የራስዎን ንቁ ዋና አስተዳዳሪ መለያ ደረጃ ዝቅ ማድረግ አይችሉም።',
      'failedUpdateRoleMsg': 'ሚናውን ማዘመን አልተቻለም፦ {error}',
      'updateRoleAction': 'ሚና አዘምን',
      'onlyAdminsManageUsersMsg': 'የማዕከሉ አስተዳዳሪዎች ብቻ የተጠቃሚ መለያዎችን ማስተዳደር ይችላሉ።',
      'couldNotLoadUsersTitle': 'ተጠቃሚዎችን መጫን አልተቻለም',
      'noUsersFoundTitle': 'ምንም {role} አልተገኘም',
      'tryModifyingSearchMsg': 'የፍለጋ ቃልዎን ለማጽዳት ወይም ለመቀየር ይሞክሩ።',
      'registeredUsersAppearMsg': 'የተመዘገቡ {role} እዚህ ይታያሉ።',
      'noContactInfo': 'የመገኛ መረጃ የለም',
      'unassignedCircleLabel': 'ያልተመደበ ክፍል',
      'promoteChangeRoleAction': 'እድገት ስጥ / ሚና ቀይር',
      'assignHalaqahAction': 'ሐለቃ መድብ',
      'reactivateAccountAction': 'መለያውን እንደገና አንቃ',
      'suspendAccountAction': 'መለያውን አግድ',
      'noMatchingInviteCodes': 'ተመሳሳይ የመጋበዣ ኮዶች የሉም',
      'noInviteCodesActive': 'ንቁ የመጋበዣ ኮዶች የሉም',
      'generateInviteTopRightHint': 'ከላይ በቀኝ በኩል ካለው አዝራር መጋበዣ ኮድ ያመንጩ።',
      'teacherRegistrationLabel': 'የመምህር ምዝገባ',
      'parentRegistrationLabel': 'የወላጅ ምዝገባ',
      'deleteInviteCodeTooltip': 'የመጋበዣ ኮድ አጥፋ',
      'failedDeleteInviteCodeMsg': 'የመጋበዣ ኮዱን ማጥፋት አልተቻለም።',
      'noticesAndActivityTitle': 'ማስታወቂያዎች እና እንቅስቃሴ',
      'circularsAndAlertsSubtitle': 'መግለጫዎችና ማንቂያዎች',
      'postShortButton': 'ለጥፍ',
      'noAlertsYetTitle': 'እስካሁን ማንቂያዎች የሉም',
      'noAlertsYetDesc': 'የዕለት ክትትል መረጃዎች፣ ሳምንታዊ ሪፖርቶች እና የክፍያ ማስታወሻዎች እዚህ ይታያሉ።',
      'markAllReadAction': 'ሁሉንም እንደተነበበ ምልክት አድርግ',
      'noNoticesFoundTitle': 'ምንም ማስታወቂያዎች አልተገኙም',
      'noNoticesFilterDesc': 'ከተመረጠው ማጣሪያ ጋር የሚዛመድ ማስታወቂያ የለም።',
      'openTuitionPaymentsAction': 'ክፍያዎችን ይክፈቱ',
      'imageUnavailableLabel': 'ምስሉ አይገኝም',
      'attachedDocumentFallback': 'የተያያዘ ሰነድ',
      'attachedFileSuccessMsg': '"{name}" በተሳካ ሁኔታ ተያይዟል።',
      'attachedPhotoSuccessMsg': 'ፎቶ "{name}" በተሳካ ሁኔታ ተያይዟል።',
      'announcementBroadcastedMsg': 'ማስታወቂያው ለሁሉም ተጠቃሚዎች በተሳካ ሁኔታ ተሰራጭቷል።',
      'broadcastCircularTitle': 'ይፋዊ መግለጫ አሰራጭ',
      'pushNoticeSubtitle': 'ለወላጆችና ለመምህራን ማሳወቂያ ይላኩ',
      'circularTitleHeader': 'የመግለጫ ርዕስ',
      'circularTitleHint': 'ለምሳሌ፦ የረመዳን የቂርኣት መርሃ ግብርና ሰዓታት',
      'messageContentHeader': 'የመልእክቱ ይዘት',
      'messageContentHint': 'ሙሉውን የመግለጫ ጽሑፍ እዚህ ይጻፉ...',
      'attachmentHeader': 'አባሪ',
      'uploadingAttachmentCloudMsg': 'አባሪው ወደ ክላውድ ማከማቻ በመሰቀል ላይ...',
      'attachedFileFallback': 'የተያያዘ ፋይል',
      'readyStatusTag': 'ዝግጁ',
      'removeAttachmentTooltip': 'አባሪውን አስወግድ',
      'attachPhotoAction': 'ፎቶ አያይዝ',
      'attachFileAction': 'ፋይል አያይዝ',
      'pinCircularLabel': 'ይህን መግለጫ በዋናው ገጽ አናት ላይ ይስኩ',
      'signInFailedMsg': 'መግባት አልተቻለም።',
      'invalidInviteCodeMsg': 'ልክ ያልሆነ የመጋበዣ ኮድ።',
      'registrationFailedMsg': 'ምዝገባው አልተቻለም።',
      'kheyrukumSupportTitle': 'የኸይሩኩም ድጋፍ',
      'supportAddressSubtitle': 'አዲስ አበባ፣ ቤቴል / ከቤቴል ሆስፒታል አጠገብ',
      'telegramOfficialLabel': 'ኦፊሴላዊ ቴሌግራም',
      'whatsappOfficialLabel': 'ኦፊሴላዊ ዋትስአፕ',
      'directPhoneSupportLabel': 'ቀጥተኛ የስልክ ድጋፍ',
      'needAssistancePrompt': 'ከማዕከሉ አስተዳደር እገዛ ይፈልጋሉ?',
      'parentEmailHint': 'parent@kheyrukum.com',
      'exampleEmailHint': 'name@example.com',
      'enterRegCodePrompt': 'በማዕከሉ አስተዳደር የተሰጠውን የምዝገባ ኮድ ያስገቡ።',
      'inviteCodeExampleHint': 'ለምሳሌ፦ ኸይሩ-1234',
      'verifiedAsRole': 'እንደ {role} ተረጋግጧል',
      'min6CharsHint': 'ቢያንስ 6 ቁምፊዎች',
      'telegramShort': 'ቴሌግራም',
      'whatsappShort': 'ዋትስአፕ',
      'contactShort': 'ያነጋግሩን',
      'beneficiaryLabel': 'ተቀባይ',
      'payerNameLabel': 'የከፋይ ስም',
      'amountShort': 'መጠን',
      'monthShort': 'ወር',
      'circleParentsGroupName': 'የ{circle} ወላጆች ቡድን',
      'halaqahNameHint': 'ምሳሌ፦ የቢላል ሐለቃ',
      'ustazWillMarkMsg': 'ኡስታዙ በሐለቃ ሰዓት ክትትልን ይመዘግባሉ።',
      'activityAlertsTab': 'የእንቅስቃሴ ማንቂያዎች',
      'announcementsTab': 'ማስታወቂያዎች',
      'allNoticesFilter': 'ሁሉም ማስታወቂያዎች',
      'attachmentsFilter': 'አባሪዎች',
      'directorRoleShort': 'ዳይሬክተር',
      'couldNotReadSelectedFileMsg': 'የተመረጠውን ፋይል ከመሣሪያው ማንበብ አልተቻለም።',
      'cloudUploadFailedMsg':
          'ወደ ደመና ማስገባት አልተቻለም። እባክዎ የኢንተርኔት ግንኙነትዎን አረጋግጠው እንደገና ይሞክሩ።',
      'failedSelectFileMsg': 'ፋይል መምረጥ አልተቻለም፦ {error}',
      'failedPickImageMsg': 'ምስል መምረጥ አልተቻለም፦ {error}',
      'provideTitleAndContentMsg': 'እባክዎ ርዕሱንም ሆነ የማስታወቂያውን ጽሑፍ ያስገቡ።',
      'broadcastFailedMsg': 'ስርጭቱ አልተሳካም። እባክዎ ግንኙነትዎን ያረጋግጡ።',
      'unableToConnectCenterServerMsg':
          'ከማዕከሉ አገልጋይ ጋር መገናኘት አልተቻለም። እባክዎ እንደገና ይሞክሩ።',
      'teacherUnassignedCircleMsg': '{name} ከሐለቃው ተነስቷል።',
      'teacherAssignedCircleMsg': '{name} በ{circle} ተመድቧል።',
      'userPromotedRoleMsg': '{name} ወደ {role} በተሳካ ሁኔታ ተሸጋግሯል።',
      'failedUploadImageToStorageMsg': 'ምስሉን ወደ ማከማቻ መጫን አልተቻለም።',
      'serverNotConnectedMsg': 'አገልጋዩ አልተገናኘም።',
      'suspendedTag': 'ታግዷል',
      'noTeachersFoundTitle': 'ምንም መምህር አልተገኘም',
      'noParentsFoundTitle': 'ምንም ወላጅ አልተገኘም',
      'noAdminsFoundTitle': 'ምንም አስተዳዳሪ አልተገኘም',
      'registeredTeachersAppearMsg': 'የተመዘገቡ መምህራን እዚህ ይታያሉ።',
      'registeredParentsAppearMsg': 'የተመዘገቡ ወላጆች እዚህ ይታያሉ።',
      'registeredAdminsAppearMsg': 'የተመዘገቡ አስተዳዳሪዎች እዚህ ይታያሉ።',
      'enterCredsMsg': 'እባክዎ የተጠቃሚ ስምዎን ወይም ኢሜይልዎን እና የይለፍ ቃልዎን ያስገቡ።',
      'suspendedInactiveMsg':
          'መለያዎ ታግዷል ወይም አይሰራም። እባክዎ የማዕከሉን አስተዳደር ያነጋግሩ።',
      'enterInviteCodeMsg': 'እባክዎ የትምህርት ቤቱን የመጋበዣ ኮድ ያስገቡ።',
      'completeAllFieldsMsg': 'እባክዎ ሁሉንም ክፍተቶች ይሙሉ።',
      'passwordMin6Msg': 'የይለፍ ቃል ቢያንስ 6 ፊደላት ወይም አኃዞች መሆን አለበት።',
      'accountCreatedVerifyEmailMsg':
          'መለያው ተፈጥሯል! እባክዎ ከመግባትዎ በፊት ኢሜይልዎን ያረጋግጡ።',
      'resetPasswordAdminMsg':
          'የይለፍ ቃልዎን ዳግም ለማስጀመር እባክዎ የማዕከሉን አስተዳዳሪ ወይም ኡስታዝን ያነጋግሩ።',
      'failedUploadVoiceCloudMsg': 'የድምፅ መልዕክቱን ወደ ደመና መጫን አልተቻለም።',
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
  String get openStatus => translate('openStatus');

  String tr(String key, [Map<String, String> args = const {}]) {
    var result = translate(key);
    if (args.isNotEmpty) {
      args.forEach((k, v) {
        result = result.replaceAll('{$k}', v);
      });
    }
    return result;
  }

  /// Localized role badge label across Superadmin / Director / Ustaz / Group / Parent / Student.
  String localizedRoleBadge(String role) {
    switch (role.trim().toLowerCase()) {
      case 'superadmin':
        return roleSuperadmin;
      case 'admin':
      case 'director':
        return roleAdmin;
      case 'teacher':
      case 'ustaz':
        return roleTeacher;
      case 'group':
        return roleGroup;
      case 'parent':
        return roleParent;
      case 'student':
        return roleStudent;
      default:
        return roleParent;
    }
  }

  /// Localized student gender ('male' | 'female'), or null when unspecified.
  String? localizedGender(String? gender) {
    switch (gender?.trim().toLowerCase()) {
      case 'male':
        return male;
      case 'female':
        return female;
      default:
        return null;
    }
  }

  /// Localized attendance status label.
  String localizedAttendanceStatus(String status) {
    switch (status.trim().toLowerCase()) {
      case 'present':
        return present;
      case 'late':
        return lateStatus;
      case 'absent':
        return absent;
      case 'excused':
        return excused;
      case 'unrecorded':
        return unrecordedStatus;
      default:
        return status.toUpperCase();
    }
  }

  /// Localized excuse reason label.
  String localizedAbsenceReason(String reason) {
    switch (reason.trim()) {
      case 'illness':
        return reasonMedical;
      case 'family_emergency':
        return reasonFamilyEmergency;
      case 'school_exam':
        return reasonSchoolExam;
      case 'travel':
        return reasonTravel;
      default:
        return reasonPersonal;
    }
  }

  /// Localized Tajweed rating label (maps stored DB English/bilingual string or key).
  String localizedTajweedRating(String rating) {
    switch (rating.trim()) {
      case 'Excellent':
      case 'Mumtaz (ممتاز)':
        return ratingExcellent;
      case 'Very Good':
      case 'Jayyid Jiddan (جيد جداً)':
        return ratingVeryGood;
      case 'Good':
      case 'Jayyid (جيد)':
        return ratingGood;
      case 'Needs Revision':
      case 'Needs Revision (يحتاج مراجعة)':
        return ratingNeedsRevision;
      default:
        return rating;
    }
  }

  /// Relative feed timestamp (Just now, 5m ago, 2h ago, Yesterday, or localized month/day).
  String formatRelativeDate(DateTime dt) {
    const monthsEn = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const monthsAr = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    const monthsAm = [
      'ጃን', 'ፌብ', 'ማር', 'ኤፕ', 'ሜይ', 'ጁን',
      'ጁላ', 'ኦገ', 'ሴፕ', 'ኦክ', 'ኖቬ', 'ዲሴ',
    ];
    final current = DateTime.now();
    final diff = current.difference(dt);
    if (diff.inMinutes < 1) return justNow;
    if (diff.inMinutes < 60) {
      return tr('minutesAgo', {'count': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24 && current.day == dt.day) {
      return tr('hoursAgo', {'count': '${diff.inHours}'});
    }
    final yesterdayDt = current.subtract(const Duration(days: 1));
    if (dt.year == yesterdayDt.year &&
        dt.month == yesterdayDt.month &&
        dt.day == yesterdayDt.day) {
      return yesterday;
    }
    final months = switch (locale.languageCode) {
      'ar' => monthsAr,
      'am' => monthsAm,
      _ => monthsEn,
    };
    return '${months[dt.month - 1]} ${dt.day}';
  }

  /// Localized Today header banner date (e.g. Mon, Nov 24 / الإثنين، نوفمبر 24 / ሰኞ، ኖቬ 24).
  String formatTodayDateBanner() {
    const weekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const weekdaysAr = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    const weekdaysAm = ['ሰኞ', 'ማክሰኞ', 'ረቡዕ', 'ሐሙስ', 'ዓርብ', 'ቅዳሜ', 'እሑድ'];
    const monthsEn = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const monthsAr = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    const monthsAm = [
      'ጃን', 'ፌብ', 'ማር', 'ኤፕ', 'ሜይ', 'ጁን',
      'ጁላ', 'ኦገ', 'ሴፕ', 'ኦክ', 'ኖቬ', 'ዲሴ',
    ];
    final current = DateTime.now();
    final weekdays = switch (locale.languageCode) {
      'ar' => weekdaysAr,
      'am' => weekdaysAm,
      _ => weekdaysEn,
    };
    final months = switch (locale.languageCode) {
      'ar' => monthsAr,
      'am' => monthsAm,
      _ => monthsEn,
    };
    return '${weekdays[current.weekday - 1]}, ${months[current.month - 1]} ${current.day}';
  }

  /// Localized chat list timestamp (Now, 5m, 4:30 PM/ص/ከሰዓት, Yesterday, M/D).
  String formatChatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return now;
    if (diff.inHours < 1) {
      return tr('minutesShort', {'count': '${diff.inMinutes}'});
    }
    if (diff.inDays == 0) {
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? pmLabel : amLabel;
      return '$hour:$min $ampm';
    }
    if (diff.inDays == 1) return yesterday;
    return '${dt.month}/${dt.day}';
  }

  // Student Gender & Polish Getters
  String get studentGender => translate('studentGender');
  String get male => translate('male');
  String get female => translate('female');
  String get editStudent => translate('editStudent');
  String get portalTagline => translate('portalTagline');
  String get roleGroup => translate('roleGroup');
  String get userFallback => translate('userFallback');
  String get administratorTitle => translate('administratorTitle');
  String get centerDirectorTitle => translate('centerDirectorTitle');
  String get centerAdministrationTitle => translate('centerAdministrationTitle');
  String get assignedUstazTitle => translate('assignedUstazTitle');
  String get studyCircleFallback => translate('studyCircleFallback');
  String get accessRestrictedTitle => translate('accessRestrictedTitle');
  String get sessionPermissionsUnverified =>
      translate('sessionPermissionsUnverified');
  String get unknownError => translate('unknownError');
  String get unableToConnectServer => translate('unableToConnectServer');
  String get justNow => translate('justNow');
  String get amLabel => translate('amLabel');
  String get pmLabel => translate('pmLabel');
  String get reminderTag => translate('reminderTag');
  String get noticeTag => translate('noticeTag');
  String get timeForPrayerDefault => translate('timeForPrayerDefault');
  String get prayerReminderBodyDefault =>
      translate('prayerReminderBodyDefault');
  String get adhanPrayerReminderTitle => translate('adhanPrayerReminderTitle');
  String get understood => translate('understood');
  String get savingProgress => translate('savingProgress');
  String get submittingProgress => translate('submittingProgress');
  String get assigningProgress => translate('assigningProgress');
  String get changeAction => translate('changeAction');
  String get copyAction => translate('copyAction');
  String get copyCodeTooltip => translate('copyCodeTooltip');
  String get activeTag => translate('activeTag');
  String get usedTag => translate('usedTag');
  String get activeLabel => translate('activeLabel');
  String get reviewAction => translate('reviewAction');
  String get languageEnglishLabel => translate('languageEnglishLabel');
  String get languageArabicLabel => translate('languageArabicLabel');
  String get languageAmharicLabel => translate('languageAmharicLabel');
  String get adminMessagingHubTitle => translate('adminMessagingHubTitle');
  String get adminMessagingHubSubtitle =>
      translate('adminMessagingHubSubtitle');
  String get messageTeacherOrParent => translate('messageTeacherOrParent');
  String get browseActiveContacts => translate('browseActiveContacts');
  String get createParentGroupTitle => translate('createParentGroupTitle');
  String get createParentGroupSubtitle =>
      translate('createParentGroupSubtitle');
  String get messageClassParentTitle => translate('messageClassParentTitle');
  String get noStudentsInClassTitle => translate('noStudentsInClassTitle');
  String get noStudentsInCircleMsg => translate('noStudentsInCircleMsg');
  String get tapToOpenConvo => translate('tapToOpenConvo');
  String get tajweedAndRecitationHeader =>
      translate('tajweedAndRecitationHeader');
  String get assignSurahGoalsHint => translate('assignSurahGoalsHint');
  String get noHomeworkFoundTitle => translate('noHomeworkFoundTitle');
  String get noStudentsInHalaqahTitle => translate('noStudentsInHalaqahTitle');
  String get noEnrolledStudentsHalaqahMsg =>
      translate('noEnrolledStudentsHalaqahMsg');
  String get reviewedStatus => translate('reviewedStatus');
  String get practicedStatus => translate('practicedStatus');
  String get needsPracticeStatus => translate('needsPracticeStatus');
  String get ratingExcellent => translate('ratingExcellent');
  String get ratingVeryGood => translate('ratingVeryGood');
  String get ratingGood => translate('ratingGood');
  String get ratingNeedsRevision => translate('ratingNeedsRevision');
  String get noLinkedChildrenTitle => translate('noLinkedChildrenTitle');
  String get noLinkedChildrenDesc => translate('noLinkedChildrenDesc');
  String get noHomeworkAssignedTitle => translate('noHomeworkAssignedTitle');
  String get noHomeworkRecordedTitle => translate('noHomeworkRecordedTitle');
  String get teachersNoHomeworkYetMsg => translate('teachersNoHomeworkYetMsg');
  String get unrecordedStatus => translate('unrecordedStatus');
  String get declinedStatus => translate('declinedStatus');
  String get reasonMedical => translate('reasonMedical');
  String get reasonFamilyEmergency => translate('reasonFamilyEmergency');
  String get reasonSchoolExam => translate('reasonSchoolExam');
  String get reasonTravel => translate('reasonTravel');
  String get reasonPersonal => translate('reasonPersonal');

  /// Localized payment status badge/row label while preserving DB enum strings.
  String localizedPaymentStatus(String status) {
    return switch (status.toLowerCase().trim()) {
      'approved' => approved,
      'submitted' => translate('toReviewTab'),
      'rejected' => rejected,
      'overdue' => overdue,
      _ => pending,
    };
  }

  /// Localized month & year string (e.g. January 2026 / يناير 2026 / ጃንዋሪ 2026).
  String formatMonthYear(DateTime dt) {
    const monthsEn = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const monthsAr = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    const monthsAm = [
      'ጃንዋሪ',
      'ፌብሩዋሪ',
      'ማርች',
      'ኤፕሪል',
      'ሜይ',
      'ጁን',
      'ጁላይ',
      'ኦገስት',
      'ሴፕቴምበር',
      'ኦክቶበር',
      'ኖቬምበር',
      'ዲሴምበር',
    ];
    final months = switch (locale.languageCode) {
      'ar' => monthsAr,
      'am' => monthsAm,
      _ => monthsEn,
    };
    return '${months[dt.month - 1]} ${dt.year}';
  }
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
