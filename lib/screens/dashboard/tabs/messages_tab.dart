import 'package:flutter/material.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/services/auth_session_service.dart';
import '../../../core/services/halaqah_service.dart';
import '../../../core/services/messaging_service.dart';
import '../../../core/services/student_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../messages/chat_screen.dart';

/// Telegram-style Messages Tab:
/// - Sleek pinned/recent chat list with online badges and unread counters
/// - Search filter
/// - Voice note and attachment preview indicators (🎤 Voice, 📷 Photo, 📎 Document)
/// - Clean floating compose button
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtextColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final cardBg = isDark ? AppColors.surfaceCard : AppColors.surfaceCardLight;
    final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    return ValueListenableBuilder<String>(
      valueListenable: AuthSessionService.instance.roleNotifier,
      builder: (context, currentRole, _) {
        final isAdmin = currentRole == 'admin';
        final isTeacher = currentRole == 'teacher';
        final isParent = currentRole == 'parent';
        final currentUserId = AuthSessionService.instance.userId;

        return StreamBuilder<List<ChatMessage>>(
          stream: MessagingService.instance.messagesStream,
          builder: (context, _) {
            final allConvos = MessagingService.instance.getConversationsForUser(
              currentUserId,
              role: currentRole,
            );

            // Filter by search query if any
            final filteredConvos = _searchQuery.isEmpty
                ? allConvos
                : allConvos.where((c) {
                    final query = _searchQuery.toLowerCase();
                    return c.title.toLowerCase().contains(query) ||
                        c.lastMessage.toLowerCase().contains(query);
                  }).toList();

            return Scaffold(
              backgroundColor: Colors.transparent,
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  // Top Header Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chats',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isTeacher
                                ? 'Class Parents & Circles'
                                : (isParent ? 'Direct chats with Ustaz & Director' : 'Center Communication Hub'),
                            style: TextStyle(fontSize: 11.5, color: subtextColor),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.accentEmerald.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.accentEmerald,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentEmerald,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Telegram-style Search Bar
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      style: TextStyle(color: textColor, fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search chats, parents or circles...',
                        hintStyle: TextStyle(color: subtextColor, fontSize: 12.5),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: subtextColor),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Quick Action Chips for Parent / Teacher
                  if (isParent) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionButton(
                            icon: Icons.menu_book_rounded,
                            label: 'Ustaz Direct',
                            color: AppColors.accentTeal,
                            onTap: () => _startParentDirectChat(context, role: 'teacher'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickActionButton(
                            icon: Icons.shield_outlined,
                            label: 'Director Direct',
                            color: const Color(0xFFFFA000),
                            onTap: () => _startParentDirectChat(context, role: 'admin'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ] else if (isTeacher) ...[
                    _buildQuickActionButton(
                      icon: Icons.chat_bubble_rounded,
                      label: 'Message Class Parent',
                      color: AppColors.accentTeal,
                      onTap: () => _showTeacherMessageParentSheet(context),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Conversation List (Telegram card style)
                  if (filteredConvos.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.mark_chat_unread_outlined, size: 44, color: subtextColor.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty ? 'No chats matching "$_searchQuery"' : 'No conversations yet',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isTeacher
                                  ? 'Tap "Message Class Parent" to begin private chats.'
                                  : (isParent
                                      ? 'Tap "Ustaz Direct" to message your child\'s teacher.'
                                      : 'Tap "+ New Chat" to start a direct or circle conversation.'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: subtextColor, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredConvos.length,
                          separatorBuilder: (ctx, i) => Divider(
                            height: 1,
                            thickness: 0.6,
                            indent: 68,
                            color: borderColor.withOpacity(0.5),
                          ),
                          itemBuilder: (context, index) {
                            final convo = filteredConvos[index];
                            return _buildTelegramChatTile(
                              context: context,
                              convo: convo,
                              isDark: isDark,
                              textColor: textColor,
                              subtextColor: subtextColor,
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
              floatingActionButton: isAdmin
                  ? FloatingActionButton.extended(
                      onPressed: () => _showAdminActionSheet(context),
                      backgroundColor: AppColors.accentEmerald,
                      foregroundColor: Colors.black,
                      elevation: 4,
                      icon: const Icon(Icons.edit_note_rounded, size: 22),
                      label: const Text('New Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelegramChatTile({
    required BuildContext context,
    required Conversation convo,
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
  }) {
    final hasUnread = convo.unreadCount > 0;
    final isGroup = convo.isGroup;

    // Last message preview helper with icons
    Widget lastMsgWidget;
    if (convo.lastMessage.startsWith('🎤 Voice') || convo.lastMessage.contains('(0:')) {
      lastMsgWidget = Row(
        children: [
          const Icon(Icons.mic_rounded, size: 14, color: AppColors.accentEmerald),
          const SizedBox(width: 3),
          Expanded(
            child: Text(
              convo.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: subtextColor),
            ),
          ),
        ],
      );
    } else if (convo.lastMessage.startsWith('📷 Photo')) {
      lastMsgWidget = Row(
        children: [
          const Icon(Icons.photo_rounded, size: 14, color: AppColors.accentTeal),
          const SizedBox(width: 3),
          Expanded(
            child: Text(
              convo.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: subtextColor),
            ),
          ),
        ],
      );
    } else if (convo.lastMessage.startsWith('📎 Document')) {
      lastMsgWidget = Row(
        children: [
          const Icon(Icons.attach_file_rounded, size: 14, color: Color(0xFFFFA000)),
          const SizedBox(width: 3),
          Expanded(
            child: Text(
              convo.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: subtextColor),
            ),
          ),
        ],
      );
    } else {
      lastMsgWidget = Text(
        convo.lastMessage.isNotEmpty ? convo.lastMessage : 'Tap to open chat',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: hasUnread ? textColor : subtextColor,
          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
        ),
      );
    }

    return InkWell(
      onTap: () {
        // Mark as read locally
        convo.unreadCount = 0;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: convo.id,
              conversationTitle: convo.title,
              targetRole: convo.groupType == 'direct_teacher' ? 'parent' : 'admin',
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            // Avatar with online / group badge
            Stack(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: isGroup
                      ? AppColors.accentEmerald.withOpacity(0.18)
                      : AppColors.accentTeal.withOpacity(0.18),
                  child: Icon(
                    isGroup ? Icons.groups_rounded : Icons.person_rounded,
                    color: isGroup ? AppColors.accentEmerald : AppColors.accentTeal,
                    size: 22,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: AppColors.accentEmerald,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.surfaceCard : AppColors.surfaceCardLight,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Middle Column (Title + Last message)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          convo.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(convo.lastMessageTime),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: hasUnread ? AppColors.accentEmerald : subtextColor,
                          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(child: lastMsgWidget),
                      if (convo.isPinned) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.push_pin_rounded, size: 13, color: subtextColor),
                      ],
                      if (hasUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentEmerald,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${convo.unreadCount}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
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

  // Teacher Message Parent Sheet (Lists ONLY parents of his class students)
  void _showTeacherMessageParentSheet(BuildContext context) {
    final assignedHalaqah = AuthSessionService.instance.assignedHalaqahName;
    final classStudents = StudentService.instance.getStudentsForHalaqah(assignedHalaqah);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, color: AppColors.accentTeal, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Message Class Parent',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Select a parent from $assignedHalaqah',
                        style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (classStudents.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No students currently assigned to your class.'),
                )
              else
                ...classStudents.map((student) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accentAmber.withOpacity(0.2),
                      child: Text(
                        student.parentName.isNotEmpty ? student.parentName[0] : 'P',
                        style: const TextStyle(color: AppColors.accentAmber, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(student.parentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(
                      'Student: ${student.fullName} • ${student.parentPhone}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    trailing: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.accentTeal),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final convo = await MessagingService.instance.startTeacherChatWithParent(
                        teacherId: AuthSessionService.instance.userId,
                        teacherName: AuthSessionService.instance.userName,
                        parentId: student.parentId ?? 'par-001',
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
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  // Parent starts direct chat with Ustaz or Director
  void _startParentDirectChat(BuildContext context, {required String role}) async {
    final children = StudentService.instance.getStudentsForParent(AuthSessionService.instance.userId);
    final childHalaqah = children.isNotEmpty ? children.first.halaqahName : 'Study Circle';
    final halaqahs = HalaqahService.instance.halaqahs;
    final hMatch = halaqahs.where((h) => h.name.toLowerCase() == childHalaqah.toLowerCase());
    final teacherName = (hMatch.isNotEmpty && hMatch.first.teacherName != 'Unassigned')
        ? hMatch.first.teacherName
        : 'Assigned Ustaz';

    final convo = await MessagingService.instance.startParentChat(
      parentId: AuthSessionService.instance.userId,
      parentName: AuthSessionService.instance.userName,
      targetRole: role,
      targetName: role == 'teacher' ? teacherName : 'Center Director',
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

  // Admin Action Sheet to start chat or group
  void _showAdminActionSheet(BuildContext context) {
    final registeredParents = StudentService.instance.getRegisteredParents();
    final halaqahs = HalaqahService.instance.halaqahs;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Admin Messaging Hub', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFA000),
                  child: Icon(Icons.person_rounded, color: Colors.black),
                ),
                title: const Text('Direct Chat with Parent', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Start private 1-on-1 discussion with a parent'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSelectParentForAdminChat(context, registeredParents);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.accentEmerald,
                  child: Icon(Icons.groups_rounded, color: Colors.black),
                ),
                title: const Text('Create Parent Halaqah Group', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Group discussion with parents of a circle'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final firstHalaqah = halaqahs.isNotEmpty ? halaqahs.first : null;
                  final groupName = firstHalaqah != null ? '${firstHalaqah.name} Parents Group' : 'Study Circle Parents Group';
                  await MessagingService.instance.createGroup(
                    title: groupName,
                    parentIds: registeredParents.map((p) => p['id']!).toList(),
                    parentNames: registeredParents.map((p) => p['name']!).toList(),
                    halaqahId: firstHalaqah?.id,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSelectParentForAdminChat(BuildContext context, List<Map<String, String>> parents) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Parent to Message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (parents.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No registered parents found yet. Add students first to populate parents.'),
                )
              else
                ...parents.map((p) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accentAmber.withOpacity(0.2),
                      child: Text(p['name']![0], style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentAmber)),
                    ),
                    title: Text(p['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Children: ${p['children']} • ${p['phone']}'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final convo = await MessagingService.instance.startDirectChatWithParent(
                        parentId: p['id']!,
                        parentName: p['name']!,
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
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day}';
  }
}
