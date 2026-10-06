import 'package:flutter/material.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/services/messaging_service.dart';
import '../../../core/services/student_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../messages/chat_screen.dart';

/// Messages Tab:
/// - Admins: Create parent discussion groups, broadcast messages, start direct 1-on-1 chats with parents.
/// - Parents: Access halaqah parent groups, start direct chat with Center Director (Admin) or child's Ustaz/teacher.
class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  bool get _isAdmin {
    final user = SupabaseService.instance.currentUser;
    if (user == null || user.email?.toLowerCase() == 'admin@kheyrukum.com') return true;
    return false;
  }

  String get _currentUserId => _isAdmin ? 'admin-001' : 'par-001';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtextColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final cardBg = isDark ? AppColors.surfaceCard : AppColors.surfaceCardLight;
    final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    return StreamBuilder<List<Conversation>>(
      stream: MessagingService.instance.conversationsStream,
      initialData: MessagingService.instance.allConversations,
      builder: (context, snapshot) {
        final conversations = MessagingService.instance.getConversationsForUser(_currentUserId, isAdmin: _isAdmin);

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: _isAdmin
              ? FloatingActionButton.extended(
                  onPressed: () => _showAdminActionSheet(context),
                  backgroundColor: const Color(0xFFFFA000),
                  foregroundColor: Colors.black,
                  icon: const Icon(Icons.add_comment_rounded, size: 18),
                  label: const Text('New Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                )
              : null,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Messages & Circles',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA000).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${conversations.length} Active',
                      style: const TextStyle(color: Color(0xFFFFA000), fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Action Bar for Parents
              if (!_isAdmin) ...[
                Row(
                  children: [
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
                    const SizedBox(width: 10),
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
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Conversation Items List
              if (conversations.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 40, color: subtextColor),
                        const SizedBox(height: 10),
                        Text('No active conversations yet.', style: TextStyle(color: subtextColor, fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else
                ...conversations.map((convo) => _buildConversationTile(convo, isDark, cardBg, borderColor, textColor, subtextColor)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConversationTile(
    Conversation convo,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtextColor,
  ) {
    final formattedTime = convo.lastMessageTime != null
        ? '${convo.lastMessageTime!.hour.toString().padLeft(2, '0')}:${convo.lastMessageTime!.minute.toString().padLeft(2, '0')}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                conversationId: convo.id,
                conversationTitle: convo.title,
                targetRole: convo.groupType == 'direct_teacher' ? 'teacher' : (convo.isGroup ? 'group' : 'admin'),
              ),
            ),
          );
        },
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: convo.isGroup
              ? const Color(0xFFFFA000).withOpacity(0.2)
              : (convo.groupType == 'direct_teacher' ? const Color(0xFF00BCD4).withOpacity(0.2) : const Color(0xFF10B981).withOpacity(0.2)),
          child: Icon(
            convo.isGroup
                ? Icons.groups_rounded
                : (convo.groupType == 'direct_teacher' ? Icons.school_rounded : Icons.person_rounded),
            color: convo.isGroup
                ? const Color(0xFFFFA000)
                : (convo.groupType == 'direct_teacher' ? const Color(0xFF00BCD4) : const Color(0xFF10B981)),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(formattedTime, style: TextStyle(fontSize: 10, color: subtextColor)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            convo.lastMessage ?? 'No messages yet',
            style: TextStyle(fontSize: 12, color: subtextColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
      ),
    );
  }

  // Admin action bottom sheet to either create a group or message an individual parent
  void _showAdminActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Start Communication', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 14),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFA000),
                  child: Icon(Icons.groups_rounded, color: Colors.black, size: 20),
                ),
                title: const Text('Create Parents Group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Broadcast messages & discussions to circle parents', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateGroupDialog(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF00BCD4),
                  child: Icon(Icons.person_rounded, color: Colors.black, size: 20),
                ),
                title: const Text('Direct 1-on-1 Message to Parent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Send private note or inquiry to a specific parent', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSelectParentDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final titleCtrl = TextEditingController(text: 'Halaqah Parents Circle');
    final halaqahCtrl = TextEditingController(text: 'Halaqah Abu Bakr');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Parent Group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Group Title')),
            const SizedBox(height: 8),
            TextField(controller: halaqahCtrl, decoration: const InputDecoration(labelText: 'Halaqah Name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.isNotEmpty) {
                final convo = await MessagingService.instance.createGroup(
                  title: titleCtrl.text.trim(),
                  parentIds: ['par-001', 'par-002'],
                  parentNames: ['Muhammed Yakut', 'Khalid Al-Mansoor'],
                  halaqahId: 'hal-001',
                );
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      conversationId: convo.id,
                      conversationTitle: convo.title,
                      targetRole: 'group',
                    ),
                  ),
                );
              }
            },
            child: const Text('Create Group'),
          ),
        ],
      ),
    );
  }

  void _showSelectParentDialog(BuildContext context) {
    final students = StudentService.instance.allStudents;
    final uniqueParents = <String, String>{};
    for (final s in students) {
      if (s.parentId != null) {
        uniqueParents[s.parentId!] = s.parentName;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Parent for 1-on-1 Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: uniqueParents.entries.map((entry) {
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person, size: 18)),
                title: Text(entry.value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () async {
                  Navigator.pop(ctx);
                  final convo = await MessagingService.instance.startDirectChatWithParent(
                    parentId: entry.key,
                    parentName: entry.value,
                  );
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
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _startParentDirectChat(BuildContext context, {required String role}) async {
    final title = role == 'admin' ? 'Center Director (Ustaz Muhammed)' : 'Ustaz (Halaqah Abu Bakr)';
    final convo = await MessagingService.instance.startParentChat(
      parentId: 'par-001',
      parentName: 'Muhammed Yakut',
      targetRole: role,
      targetName: title,
    );
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
