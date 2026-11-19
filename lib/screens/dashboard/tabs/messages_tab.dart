import 'package:flutter/material.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/services/auth_session_service.dart';
import '../../../core/services/halaqah_service.dart';
import '../../../core/services/messaging_service.dart';
import '../../../core/services/student_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/pro_ui_kit.dart';
import '../../messages/chat_screen.dart';

/// Flagship Messages Hub:
/// - Live conversation list with role badges, online indicators, and unread counts
/// - Search filter across titles and previews
/// - Role-tailored quick start buttons & bottom sheets
/// - Elevated Deep Pine "+ New Chat" FAB cleared cleanly above the floating dock
class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await MessagingService.instance.refreshAndSubscribe();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);

    return ValueListenableBuilder<String>(
      valueListenable: AuthSessionService.instance.roleNotifier,
      builder: (context, currentRole, _) {
        final isAdmin = currentRole == 'admin';
        final isTeacher = currentRole == 'teacher';
        final isParent = currentRole == 'parent';
        final currentUserId = AuthSessionService.instance.userId;

        return StreamBuilder<List<Conversation>>(
          stream: MessagingService.instance.conversationsStream,
          initialData: MessagingService.instance.allConversations,
          builder: (context, _) {
            final allConvos = MessagingService.instance.getConversationsForUser(
              currentUserId,
              role: currentRole,
            );

            final filteredConvos = _searchQuery.isEmpty
                ? allConvos
                : allConvos.where((c) {
                    final query = _searchQuery.toLowerCase();
                    return c.title.toLowerCase().contains(query) ||
                        c.lastMessage.toLowerCase().contains(query);
                  }).toList();

            return Scaffold(
              backgroundColor: Colors.transparent,
              body: RefreshIndicator(
                color: p.primary,
                onRefresh: _handleRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
                  children: [
                    Text(
                      isTeacher
                          ? 'Class parents & study circle threads'
                          : (isParent
                              ? 'Direct channels with Ustaz & Director'
                              : 'Direct conversations with Ustazs & parents'),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: p.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sculpted Search Field
                    ProSearchField(
                      controller: _searchCtrl,
                      hintText: 'Search chats, parents or circles...',
                      query: _searchQuery,
                      onChanged: (val) =>
                          setState(() => _searchQuery = val.trim()),
                    ),
                    const SizedBox(height: 14),

                    // Role-specific Quick Actions
                    if (isParent) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuickActionButton(
                              p: p,
                              icon: Icons.menu_book_rounded,
                              label: 'Ustaz Direct',
                              color: p.primary,
                              onTap: () => _startParentDirectChat(context,
                                  role: 'teacher'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildQuickActionButton(
                              p: p,
                              icon: Icons.admin_panel_settings_outlined,
                              label: 'Director Direct',
                              color: p.gold,
                              onTap: () => _startParentDirectChat(context,
                                  role: 'admin'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ] else if (isTeacher) ...[
                      _buildQuickActionButton(
                        p: p,
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Message Class Parent',
                        color: p.primary,
                        onTap: () => _showTeacherMessageParentSheet(context),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Conversation List or Empty State
                    if (filteredConvos.isEmpty)
                      ProEmptyState(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: _searchQuery.isNotEmpty
                            ? 'No chats matching "$_searchQuery"'
                            : 'No conversations yet',
                        message: _searchQuery.isNotEmpty
                            ? 'Check spelling or try searching for another parent, Ustaz, or circle.'
                            : (isTeacher
                                ? 'Reach out to parents of your halaqah students or reply to inquiries.'
                                : (isParent
                                    ? 'Connect directly with your student\'s Ustaz or the Center Director.'
                                    : 'Start a direct 1-on-1 dialogue with a parent or create a circle group.')),
                        actionLabel: _searchQuery.isNotEmpty
                            ? 'Clear Search'
                            : 'Start Conversation',
                        onAction: () {
                          if (_searchQuery.isNotEmpty) {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          } else if (isAdmin) {
                            _showAdminActionSheet(context);
                          } else if (isTeacher) {
                            _showTeacherMessageParentSheet(context);
                          } else {
                            _startParentDirectChat(context, role: 'teacher');
                          }
                        },
                      )
                    else
                      ProCard(
                        padding: EdgeInsets.zero,
                        borderRadius: 20,
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredConvos.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            indent: 72,
                            color: p.border.withOpacity(0.7),
                          ),
                          itemBuilder: (context, index) {
                            final convo = filteredConvos[index];
                            return _buildChatTile(context, convo, p);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              floatingActionButton: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 84,
                ),
                child: FloatingActionButton.extended(
                  onPressed: () {
                    if (isAdmin) {
                      _showAdminActionSheet(context);
                    } else if (isTeacher) {
                      _showTeacherMessageParentSheet(context);
                    } else {
                      _startParentDirectChat(context, role: 'teacher');
                    }
                  },
                  backgroundColor: p.primary,
                  foregroundColor: p.onPrimary,
                  elevation: 4,
                  icon: const Icon(Icons.add_comment_rounded, size: 19),
                  label: const Text(
                    'New Chat',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickActionButton({
    required AppPalette p,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ProCard(
      onTap: onTap,
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
      borderColor: color.withOpacity(0.32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(
      BuildContext context, Conversation convo, AppPalette p) {
    final hasUnread = convo.unreadCount > 0;
    final isGroup = convo.isGroup;
    final badgeInfo = _resolveBadgeInfo(convo, p);

    Widget lastMsgWidget;
    final preview = convo.lastMessage;
    if (preview.startsWith('🎤 Voice') || preview.contains('(0:')) {
      lastMsgWidget = _buildPreviewWithIcon(
          Icons.mic_rounded, p.primary, preview, hasUnread, p);
    } else if (preview.startsWith('📷 Photo')) {
      lastMsgWidget = _buildPreviewWithIcon(
          Icons.photo_rounded, p.info, preview, hasUnread, p);
    } else if (preview.startsWith('📎 Document')) {
      lastMsgWidget = _buildPreviewWithIcon(
          Icons.attach_file_rounded, p.gold, preview, hasUnread, p);
    } else {
      lastMsgWidget = Text(
        preview.isNotEmpty ? preview : 'Tap to open conversation',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          color: hasUnread ? p.ink : p.inkSecondary,
          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
        ),
      );
    }

    return InkWell(
      onTap: () {
        convo.unreadCount = 0;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: convo.id,
              conversationTitle: convo.title,
              targetRole:
                  convo.groupType == 'direct_teacher' ? 'parent' : 'admin',
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                ProAvatar(
                  name: convo.title,
                  radius: 23,
                  color: badgeInfo.$2,
                  icon: isGroup ? Icons.groups_rounded : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: p.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.surface, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                convo.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: p.ink,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeInfo.$2.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badgeInfo.$1,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: badgeInfo.$2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(convo.lastMessageTime),
                        style: TextStyle(
                          fontSize: 11,
                          color: hasUnread ? p.primary : p.inkMuted,
                          fontWeight:
                              hasUnread ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: lastMsgWidget),
                      if (convo.isPinned) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.push_pin_rounded,
                            size: 13, color: p.gold),
                      ],
                      if (hasUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          constraints: const BoxConstraints(
                              minWidth: 20, minHeight: 20),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: p.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            convo.unreadCount > 99
                                ? '99+'
                                : '${convo.unreadCount}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: p.onPrimary,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewWithIcon(
    IconData icon,
    Color iconColor,
    String text,
    bool hasUnread,
    AppPalette p,
  ) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: hasUnread ? p.ink : p.inkSecondary,
              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  void _showTeacherMessageParentSheet(BuildContext context) {
    final p = AppColors.of(context);
    final assignedHalaqah = AuthSessionService.instance.assignedHalaqahName;
    final classStudents = StudentService.instance.getStudentsForHalaqah(
      assignedHalaqah,
      halaqahId: AuthSessionService.instance.assignedHalaqahId,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ProBottomSheetShell(
          title: 'Message Class Parent',
          subtitle: 'Select a parent from $assignedHalaqah',
          icon: Icons.chat_bubble_rounded,
          iconColor: p.primary,
          heightFactor: 0.65,
          child: classStudents.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: ProEmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No students in class',
                    message:
                        'No students are currently assigned to your study circle.',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: classStudents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, idx) {
                    final student = classStudents[idx];
                    return ProCard(
                      onTap: () async {
                        Navigator.pop(ctx);
                        if (student.parentId == null ||
                            student.parentId!.isEmpty) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${student.fullName} does not have a linked parent account yet.',
                                ),
                              ),
                            );
                          }
                          return;
                        }
                        final convo = await MessagingService.instance
                            .startTeacherChatWithParent(
                          teacherId: AuthSessionService.instance.userId,
                          teacherName: AuthSessionService.instance.userName,
                          parentId: student.parentId!,
                          parentName: student.parentName,
                          studentName: student.fullName,
                          halaqahId: student.halaqahId,
                        );

                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversationId: convo.id,
                                conversationTitle: convo.title,
                                targetRole: 'parent',
                              ),
                            ),
                          );
                        }
                      },
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ProAvatar(
                            name: student.parentName,
                            radius: 20,
                            color: p.gold,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.parentName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: p.ink,
                                  ),
                                ),
                                Text(
                                  'Student: ${student.fullName} • ${student.parentPhone}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: p.inkSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 18,
                            color: p.primary,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _startParentDirectChat(BuildContext context,
      {required String role}) async {
    final children = StudentService.instance.getStudentsForParent(
      AuthSessionService.instance.userId,
      parentEmail: AuthSessionService.instance.userEmail,
    );
    final childHalaqah =
        children.isNotEmpty ? children.first.halaqahName : 'Study Circle';
    final halaqahs = HalaqahService.instance.halaqahs;
    final hMatch = halaqahs
        .where((h) => h.name.toLowerCase() == childHalaqah.toLowerCase());
    final teacherName =
        (hMatch.isNotEmpty && hMatch.first.teacherName != 'Unassigned')
            ? hMatch.first.teacherName
            : 'Assigned Ustaz';
    final teacherId = hMatch.isNotEmpty ? hMatch.first.teacherId : null;

    final convo = await MessagingService.instance.startParentChat(
      parentId: AuthSessionService.instance.userId,
      parentName: AuthSessionService.instance.userName,
      targetRole: role,
      targetName: role == 'teacher' ? teacherName : 'Center Director',
      targetId: role == 'teacher' ? teacherId : null,
      halaqahName: childHalaqah,
    );

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: convo.id,
            conversationTitle: convo.title,
            targetRole: role,
          ),
        ),
      );
    }
  }

  void _showAdminActionSheet(BuildContext context) {
    final p = AppColors.of(context);
    final registeredParents = StudentService.instance.getRegisteredParents();
    final halaqahs = HalaqahService.instance.halaqahs;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ProBottomSheetShell(
          title: 'Admin Messaging Hub',
          subtitle: 'Start a private chat or circle group',
          icon: Icons.forum_rounded,
          iconColor: p.primary,
          heightFactor: 0.40,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ProCard(
                onTap: () {
                  Navigator.pop(ctx);
                  _showSelectParentForAdminChat(context, registeredParents);
                },
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: p.gold.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.person_rounded, color: p.gold),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Direct Chat with Parent',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: p.ink,
                            ),
                          ),
                          Text(
                            'Start private 1-on-1 discussion with a parent',
                            style: TextStyle(
                              fontSize: 12,
                              color: p.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: p.inkMuted),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ProCard(
                onTap: () async {
                  Navigator.pop(ctx);
                  final firstHalaqah =
                      halaqahs.isNotEmpty ? halaqahs.first : null;
                  final groupName = firstHalaqah != null
                      ? '${firstHalaqah.name} Parents Group'
                      : 'Study Circle Parents Group';
                  await MessagingService.instance.createGroup(
                    title: groupName,
                    parentIds:
                        registeredParents.map((par) => par['id']!).toList(),
                    parentNames:
                        registeredParents.map((par) => par['name']!).toList(),
                    halaqahId: firstHalaqah?.id,
                  );
                },
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: p.primary.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.groups_rounded, color: p.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Parent Halaqah Group',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: p.ink,
                            ),
                          ),
                          Text(
                            'Group discussion with parents of a circle',
                            style: TextStyle(
                              fontSize: 12,
                              color: p.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: p.inkMuted),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSelectParentForAdminChat(
      BuildContext context, List<Map<String, String>> parents) {
    final p = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ProBottomSheetShell(
          title: 'Select Parent',
          subtitle: 'Start a direct conversation',
          icon: Icons.family_restroom_rounded,
          iconColor: p.gold,
          heightFactor: 0.65,
          child: parents.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: ProEmptyState(
                    icon: Icons.person_off_outlined,
                    title: 'No registered parents found',
                    message:
                        'Invite parents and enroll students first to populate the parent directory.',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: parents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, idx) {
                    final parent = parents[idx];
                    final name = parent['name'] ?? 'Parent';
                    return ProCard(
                      onTap: () async {
                        Navigator.pop(ctx);
                        final convo = await MessagingService.instance
                            .startDirectChatWithParent(
                          parentId: parent['id']!,
                          parentName: name,
                        );
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversationId: convo.id,
                                conversationTitle: convo.title,
                                targetRole: 'parent',
                              ),
                            ),
                          );
                        }
                      },
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ProAvatar(name: name, radius: 20, color: p.gold),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: p.ink,
                                  ),
                                ),
                                Text(
                                  'Children: ${parent['children']} • ${parent['phone']}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: p.inkSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: p.inkMuted),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  (String, Color) _resolveBadgeInfo(Conversation convo, AppPalette p) {
    final lowerTitle = convo.title.toLowerCase();
    if (convo.groupType == 'direct_admin' ||
        lowerTitle.contains('director') ||
        lowerTitle.contains('admin')) {
      return ('Director', p.gold);
    } else if (convo.groupType == 'direct_teacher' ||
        lowerTitle.contains('ustaz') ||
        lowerTitle.contains('teacher')) {
      return ('Ustaz', p.primary);
    } else if (convo.isGroup ||
        convo.groupType == 'parent_group' ||
        convo.groupType == 'broadcast') {
      return ('Circle', p.success);
    } else {
      return ('Parent', p.info);
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24 && now.day == dt.day) {
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute $period';
    }
    if (diff.inDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[dt.weekday - 1];
    }
    return '${dt.month}/${dt.day}';
  }
}
