import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/announcement.dart';
import '../../../core/models/invitation_code.dart';
import '../../../core/models/student.dart';
import '../../../core/services/announcement_service.dart';
import '../../../core/services/auth_session_service.dart';
import '../../../core/services/student_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/invite_code_dialog.dart';
import '../../announcements/announcements_sheet.dart';
import '../../announcements/post_announcement_dialog.dart';

/// Home Tab with role-tailored experiences:
/// - Admin: Center statistics, announcements (+ Post notice), and live Invite Codes generator.
/// - Teacher: Assigned class overview, today's attendance summary, and halaqah milestones.
/// - Parent: Enrolled children progress, today's attendance status, and halaqah announcements.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied "$code" to clipboard!'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.accentTeal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtextColor = isDark ? Colors.white.withOpacity(0.7) : AppColors.textSecondaryLight;
    final cardBg = isDark ? AppColors.surfaceCard : AppColors.surfaceCardLight;
    final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    return ValueListenableBuilder<String>(
      valueListenable: AuthSessionService.instance.roleNotifier,
      builder: (context, currentRole, _) {
        final isAdmin = currentRole == 'admin';
        final isTeacher = currentRole == 'teacher';
        final isParent = currentRole == 'parent';

        final userName = AuthSessionService.instance.userName;
        final userRole = currentRole.toUpperCase();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            // Welcome Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Assalamu Alaikum',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.accentTeal.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('👋', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                // User Role Avatar Badge
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isTeacher
                          ? AppColors.accentTeal
                          : (isParent ? AppColors.accentAmber : const Color(0xFFFF4B72)),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: isDark ? AppColors.surfaceLight : const Color(0xFFF1F5F9),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'K',
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Top Status Hero Card tailored to Role
            _buildRoleHeroCard(
              isDark: isDark,
              isAdmin: isAdmin,
              isTeacher: isTeacher,
              isParent: isParent,
              userRole: userRole,
            ),

            const SizedBox(height: 24),

            // =================================================================
            // ANNOUNCEMENTS SECTION (Admin can + Post, Teacher & Parent view only)
            // =================================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.accentEmerald,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentEmerald.withOpacity(0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Center Announcements',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // ONLY ADMIN CAN POST ANNOUNCEMENTS
                    if (isAdmin) ...[
                      InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => const PostAnnouncementDialog(),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Text(
                            '+ Post',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentAmber,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    InkWell(
                      onTap: () => AnnouncementsSheet.show(context),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentTeal,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Announcements Stream
            StreamBuilder<List<Announcement>>(
              stream: AnnouncementService.instance.streamAnnouncements(),
              builder: (context, snapshot) {
                final announcements = snapshot.data ?? [];
                if (announcements.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.campaign_outlined, size: 36, color: subtextColor),
                        const SizedBox(height: 8),
                        Text(
                          'No Announcements Yet',
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Official circulars, reminders, and halaqah notices will appear here in real time.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: subtextColor, fontSize: 11),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: announcements.take(2).map((ann) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: ann.isPinned ? AppColors.accentAmber.withOpacity(0.6) : borderColor,
                          width: ann.isPinned ? 1.5 : 1.0,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => AnnouncementsSheet.show(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentTeal.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    ann.category.toUpperCase(),
                                    style: const TextStyle(
                                      color: AppColors.accentTeal,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatDate(ann.createdAt),
                                  style: TextStyle(fontSize: 10.5, color: subtextColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ann.title,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ann.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: subtextColor, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 20),

            // =================================================================
            // ROLE-SPECIFIC LOWER SECTION:
            // Admin: Signup Invite Codes Generator
            // Teacher: Assigned Class Quick Attendance Summary
            // Parent: Enrolled Children Today Attendance Summary
            // =================================================================
            if (isAdmin)
              _buildAdminInviteCodesSection(
                context: context,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textColor: textColor,
                subtextColor: subtextColor,
              )
            else if (isTeacher)
              _buildTeacherClassSection(
                context: context,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textColor: textColor,
                subtextColor: subtextColor,
              )
            else
              _buildParentChildrenSection(
                context: context,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textColor: textColor,
                subtextColor: subtextColor,
              ),
          ],
        );
      },
    );
  }

  // Hero Card adapting to user role
  Widget _buildRoleHeroCard({
    required bool isDark,
    required bool isAdmin,
    required bool isTeacher,
    required bool isParent,
    required String userRole,
  }) {
    String title;
    String subtitle;
    String badgeText;
    Color badgeColor;
    String statText;

    if (isTeacher) {
      final className = AuthSessionService.instance.assignedHalaqahName;
      final classStudents = StudentService.instance.getStudentsForHalaqah(className);
      title = className;
      subtitle = 'Assigned Class Ustaz • Daily attendance marking & parent updates active.';
      badgeText = 'TEACHER CLASS PORTAL';
      badgeColor = AppColors.accentTeal;
      statText = '${classStudents.length} Students in your class';
    } else if (isParent) {
      final children = StudentService.instance.getStudentsForParent(
        AuthSessionService.instance.userId,
        parentEmail: AuthSessionService.instance.userEmail,
      );
      title = 'Quranic Hifz & Tajweed Progress';
      subtitle = 'Monitor your children\'s attendance, daily Sabaq, and teacher evaluations.';
      badgeText = 'PARENT PORTAL';
      badgeColor = AppColors.accentAmber;
      statText = '${children.length} Enrolled ${children.length == 1 ? 'Child' : 'Children'}';
    } else {
      final allStudents = StudentService.instance.allStudents;
      title = 'Center Administration & Halaqahs';
      subtitle = 'Live database connected. Manage circles, student enrollments, and tuition fees.';
      badgeText = 'ADMIN PORTAL';
      badgeColor = const Color(0xFFFF4B72);
      statText = '${allStudents.length} Total Students Enrolled';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F2B48)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF0F2B48), Color(0xFF1E3A5F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: badgeColor.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_rounded, color: badgeColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Real-Time Synced',
                style: TextStyle(color: AppColors.accentEmerald, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                statText,
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                isTeacher ? 'Attendance Ready' : 'Active Term',
                style: TextStyle(color: badgeColor, fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Teacher Class Attendance Section on Home Tab
  Widget _buildTeacherClassSection({
    required BuildContext context,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    final className = AuthSessionService.instance.assignedHalaqahName;
    final classStudents = StudentService.instance.getStudentsForHalaqah(className);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.accentTeal),
                const SizedBox(width: 6),
                Text(
                  'My Class Attendance Today',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentTeal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${classStudents.length} Students',
                style: const TextStyle(color: AppColors.accentTeal, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Attendance Responsibility',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 4),
              Text(
                'As the assigned Ustaz of $className, mark your students\' attendance daily. Linked parents receive real-time notifications.',
                style: TextStyle(fontSize: 11.5, color: subtextColor, height: 1.4),
              ),
              const SizedBox(height: 14),
              ...classStudents.map((s) {
                final todayAtt = StudentService.instance.getTodayAttendanceForStudent(s.id);
                final status = todayAtt?.status ?? 'unmarked';

                Color pillBg = Colors.grey.withOpacity(0.15);
                Color pillColor = Colors.grey;
                if (status == 'present') {
                  pillBg = AppColors.accentEmerald.withOpacity(0.15);
                  pillColor = AppColors.accentEmerald;
                } else if (status == 'late') {
                  pillBg = const Color(0xFFFFA000).withOpacity(0.15);
                  pillColor = const Color(0xFFFFA000);
                } else if (status == 'absent') {
                  pillBg = const Color(0xFFEF4444).withOpacity(0.15);
                  pillColor = const Color(0xFFEF4444);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.accentTeal.withOpacity(0.2),
                            child: Text(
                              s.fullName[0],
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accentTeal),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            s.fullName,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(color: pillColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // Parent Children Section on Home Tab
  Widget _buildParentChildrenSection({
    required BuildContext context,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    final children = StudentService.instance.getStudentsForParent(
      AuthSessionService.instance.userId,
      parentEmail: AuthSessionService.instance.userEmail,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.family_restroom_rounded, size: 16, color: AppColors.accentAmber),
                const SizedBox(width: 6),
                Text(
                  'My Enrolled Children',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${children.length} Enrolled',
                style: const TextStyle(color: AppColors.accentAmber, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children.map((child) {
          final todayAtt = StudentService.instance.getTodayAttendanceForStudent(child.id);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      child.fullName,
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (todayAtt?.status == 'present' ? AppColors.accentEmerald : const Color(0xFFFFA000)).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        (todayAtt?.status ?? 'Unmarked').toUpperCase(),
                        style: TextStyle(
                          color: todayAtt?.status == 'present' ? AppColors.accentEmerald : const Color(0xFFFFA000),
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${child.halaqahName} • Juz ${child.currentJuz}, Surah #${child.currentSurah}',
                  style: TextStyle(fontSize: 11.5, color: subtextColor),
                ),
                if (todayAtt?.teacherRemarks != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Ustaz: "${todayAtt!.teacherRemarks}"',
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.accentTeal),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  // Admin Invite Codes Section (ADMIN ONLY)
  Widget _buildAdminInviteCodesSection({
    required BuildContext context,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.vpn_key_rounded, size: 16, color: AppColors.accentTeal),
                const SizedBox(width: 6),
                Text(
                  'Signup Invite Codes (Admin)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentTeal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'REALTIME',
                style: TextStyle(
                  color: AppColors.accentTeal,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Generate Teacher & Parent Codes',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 4),
              Text(
                'Instant secure registration codes for new teachers to claim halaqahs and parents to link students.',
                style: TextStyle(fontSize: 11.5, color: subtextColor, height: 1.4),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => InviteCodeDialog.show(context, initialRole: 'teacher'),
                      icon: const Icon(Icons.school_rounded, size: 14, color: Colors.black),
                      label: const Text(
                        'Teacher Code',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentTeal,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => InviteCodeDialog.show(context, initialRole: 'parent'),
                      icon: const Icon(Icons.family_restroom_rounded, size: 14, color: Colors.black),
                      label: const Text(
                        'Parent Code',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentAmber,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: borderColor),
              const SizedBox(height: 10),
              StreamBuilder<List<InvitationCode>>(
                stream: SupabaseService.instance.streamInviteCodes(),
                builder: (context, snapshot) {
                  final codes = snapshot.data ?? [];
                  if (codes.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No invitation codes active. Tap above to generate one.',
                        style: TextStyle(fontSize: 11, color: subtextColor),
                      ),
                    );
                  }

                  return Column(
                    children: codes.take(2).map((item) {
                      final isTeacher = item.role == 'teacher';
                      return Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: item.isUsed
                                ? borderColor.withOpacity(0.5)
                                : (isTeacher ? AppColors.accentTeal.withOpacity(0.3) : AppColors.accentAmber.withOpacity(0.3)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isTeacher ? AppColors.accentTeal : AppColors.accentAmber).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                isTeacher ? 'TEACHER' : 'PARENT',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: isTeacher ? AppColors.accentTeal : AppColors.accentAmber,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.code,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: item.isUsed ? subtextColor : textColor,
                                  decoration: item.isUsed ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            Text(
                              item.isUsed ? 'USED' : 'ACTIVE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: item.isUsed ? Colors.grey : AppColors.accentEmerald,
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => _copyCode(item.code),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.copy_rounded, size: 14, color: subtextColor),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return diff.inMinutes <= 1 ? 'Just now' : '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${dt.month}/${dt.day}';
    }
  }
}
