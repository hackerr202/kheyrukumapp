import 'package:flutter/material.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/services/auth_session_service.dart';
import '../../../core/services/messaging_service.dart';
import '../../../core/services/student_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../messages/chat_screen.dart';

/// Messages Tab with role-based communication:
/// - Admin: Broadcast groups, parent groups, and direct 1-on-1 parent chats.
/// - Teacher: Direct 1-on-1 chats with parents of his class students.
/// - Parent: Direct chats with child's Ustaz and Center Director.
class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
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

        return StreamBuilder<List<Conversation>>(
          stream: MessagingService.instance.conversationsStream,
          initialData: MessagingService.instance.allConversations,
          builder: (context, snapshot) {
            final conversations = MessagingService.instance.getConversationsForUser(
              currentUserId,
              role: currentRole,
            );

            return Scaffold(
              backgroundColor: Colors.transparent,
              body: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                children: [
                  // Header Row with Role-Appropriate Title and Action Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isTeacher
                                ? 'Class Parent Messages'
                                : (isParent ? 'Messages & Ustaz' : 'Messages & Circles'),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isTeacher
                                ? 'Communicate with parents of your class students'
                                : (isParent ? 'Direct chats with Ustaz and Director' : 'Admin communication hub'),
                            style: TextStyle(fontSize: 11, color: subtextColor),
                          ),
                        ],
                      ),

                      // Action Button for Admin
                      if (isAdmin)
                        ElevatedButton.icon(
                          onPressed: () => _showAdminActionSheet(context),
                          icon: const Icon(Icons.add_comment_rounded, size: 15),
                          label: const Text('New Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFA000),
                            foregroundColor: Colors.black,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),

                      // Action Button for Teacher (Start Chat with Class Parent)
                      if (isTeacher)
                        ElevatedButton.icon(
                          onPressed: () => _showTeacherMessageParentSheet(context),
                          icon: const Icon(Icons.chat_bubble_rounded, size: 14),
                          label: const Text('Message Parent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentTeal,
                            foregroundColor: Colors.black,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Action Buttons for Parents
                  if (isParent) ...[
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _startParentDirectChat(context, role: 'teacher'),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00BCD4).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.4)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.menu_book_rounded, size: 18, color: Color(0xFF00BCD4)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Message Ustaz',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF00BCD4)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => _startParentDirectChat(context, role: 'admin'),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFA000).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFFFA000).withOpacity(0.4)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.shield_outlined, size: 18, color: Color(0xFFFFA000)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Message Director',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFFFFA000)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Conversation Items List
                  if (conversations.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 44, color: AppColors.accentTeal.withOpacity(0.7)),
                            const SizedBox(height: 12),
                            Text('No Active Conversations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                            const SizedBox(height: 6),
                            Text(
                              isTeacher
                                  ? 'Tap "Message Parent" above to start a conversation with any parent of your class students.'
                                  : (isParent
                                      ? 'Tap "Message Ustaz" to contact your child\'s recitation teacher.'
                                      : 'Start private chats with parents or create a discussion group.'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: subtextColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...conversations.map((convo) {
                      final hasUnread = false;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: hasUnread ? AppColors.accentTeal.withOpacity(0.5) : borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: (convo.isGroup ? AppColors.accentEmerald : AppColors.accentTeal).withOpacity(0.2),
                            child: Icon(
                              convo.isGroup ? Icons.groups_rounded : Icons.person_rounded,
                              color: convo.isGroup ? AppColors.accentEmerald : AppColors.accentTeal,
                              size: 22,
                            ),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  convo.title,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                _formatTime(convo.lastMessageTime),
                                style: TextStyle(fontSize: 10.5, color: subtextColor),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              convo.lastMessage.isNotEmpty ? convo.lastMessage : 'No messages yet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: subtextColor,
                                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                          onTap: () {
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
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
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
    final convo = await MessagingService.instance.startParentChat(
      parentId: AuthSessionService.instance.userId,
      parentName: AuthSessionService.instance.userName,
      targetRole: role,
      targetName: role == 'teacher' ? 'Ustaz Ibrahim Bilal' : 'Ustaz Muhammed Yakut',
      halaqahName: 'Halaqah Abu Bakr (حلقة أبي بكر)',
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
                  await MessagingService.instance.createGroup(
                    title: 'Halaqah Abu Bakr Parents Group',
                    parentIds: registeredParents.map((p) => p['id']!).toList(),
                    parentNames: registeredParents.map((p) => p['name']!).toList(),
                    halaqahId: 'halaqah-001',
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
