import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/announcement.dart';
import '../../../core/models/invitation_code.dart';
import '../../../core/services/announcement_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/invite_code_dialog.dart';
import '../../announcements/announcements_sheet.dart';
import '../../announcements/post_announcement_dialog.dart';

/// Home Tab with:
/// 1. Real-time Announcements feed directly on the home page
/// 2. Admin Realtime Invitation Code Generator for Teachers and Parents
/// 3. Hifz track progress and live halaqah management
/// 4. Full theme adaptability for Light and Dark modes
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await SupabaseService.instance.getUserProfile();
    if (mounted) {
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    }
  }

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

    final userName = _userProfile?['full_name'] ?? 'Ustaz Muhammed';
    final userRole = (_userProfile?['role'] ?? 'Admin').toString().toUpperCase();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // Parent / Teacher Welcome Header
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
                  _isLoading ? 'Loading...' : userName,
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
                border: Border.all(color: AppColors.accentAmber, width: 2),
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

        // Quran Memorization / Portal Status Card
        Container(
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
            border: Border.all(color: AppColors.accentTeal.withOpacity(0.3)),
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
                      color: AppColors.accentAmber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user_rounded, color: AppColors.accentAmber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '$userRole PORTAL',
                          style: const TextStyle(
                            color: AppColors.accentAmber,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'Real-Time Synced',
                    style: TextStyle(color: AppColors.accentTeal, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              const Text(
                'Quranic Hifz & Recitation Track',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                'Live database connected. Ready for student enrollments, daily Sabaq records, and Halaqah milestones.',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12.5, height: 1.4),
              ),

              const SizedBox(height: 18),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: 0.0,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentTeal),
                ),
              ),

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '0 Students Enrolled',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                  ),
                  const Text(
                    'Ready for Real Data',
                    style: TextStyle(color: AppColors.accentAmber, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // =====================================================================
        // REQUIREMENT 1: ANNOUNCEMENTS DIRECTLY ON THE HOME PAGE
        // =====================================================================
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
                InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => const PostAnnouncementDialog(),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                InkWell(
                  onTap: () => AnnouncementsSheet.show(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

        // Real-Time Stream of Announcements on the Home Page
        StreamBuilder<List<Announcement>>(
          stream: AnnouncementService.instance.streamAnnouncements(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

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

            // Display top 3 announcements on home page
            final displayList = announcements.take(3).toList();

            return Column(
              children: displayList.map((ann) {
                Color badgeBg = AppColors.accentTeal.withOpacity(0.15);
                Color badgeText = AppColors.accentTeal;
                if (ann.category == 'urgent') {
                  badgeBg = const Color(0xFFFF4B72).withOpacity(0.15);
                  badgeText = const Color(0xFFFF4B72);
                } else if (ann.category == 'event') {
                  badgeBg = AppColors.accentAmber.withOpacity(0.15);
                  badgeText = AppColors.accentAmber;
                } else if (ann.category == 'quran_halaqah') {
                  badgeBg = AppColors.accentEmerald.withOpacity(0.15);
                  badgeText = AppColors.accentEmerald;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: ann.isPinned ? AppColors.accentAmber.withOpacity(0.6) : borderColor,
                      width: ann.isPinned ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () => AnnouncementsSheet.show(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    ann.category.toUpperCase(),
                                    style: TextStyle(
                                      color: badgeText,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                if (ann.isPinned) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentAmber.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.push_pin_rounded, size: 10, color: AppColors.accentAmber),
                                        SizedBox(width: 3),
                                        Text(
                                          'PINNED',
                                          style: TextStyle(
                                            color: AppColors.accentAmber,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              _formatDate(ann.createdAt),
                              style: TextStyle(fontSize: 10.5, color: subtextColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          ann.title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ann.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: subtextColor,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person_pin_rounded, size: 13, color: subtextColor),
                                const SizedBox(width: 4),
                                Text(
                                  ann.authorName,
                                  style: TextStyle(fontSize: 10.5, color: subtextColor),
                                ),
                              ],
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, size: 11, color: subtextColor),
                          ],
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

        // =====================================================================
        // REQUIREMENT 3: ADMIN REALTIME INVITATION CODE GENERATOR ON HOME PAGE
        // =====================================================================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.vpn_key_rounded, size: 16, color: AppColors.accentTeal),
                const SizedBox(width: 6),
                Text(
                  'Signup Invite Codes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: 0.2,
                  ),
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

        // Invite Code Generation & Live Hub Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
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

              // Action Buttons: Generate Teacher Code & Generate Parent Code
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => InviteCodeDialog.show(context),
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
                      onPressed: () => InviteCodeDialog.show(context),
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

              // Live Stream of generated invitation codes
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

                  // Show first 2 codes inline with 1-tap copy
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

        const SizedBox(height: 24),

        // Halaqah Management Status
        Text(
          'Halaqah Management',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Icon(Icons.menu_book_rounded, size: 38, color: AppColors.accentTeal.withOpacity(0.7)),
              const SizedBox(height: 10),
              Text(
                'Student Memorization Circles Active',
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              const SizedBox(height: 4),
              Text(
                'Students and teachers linked via realtime codes will have daily Sabaq recitation progress logged here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: subtextColor, fontSize: 11.5, height: 1.4),
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
