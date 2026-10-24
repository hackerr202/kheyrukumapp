import 'package:flutter/material.dart';
import '../../core/models/invitation_code.dart';
import '../../core/services/supabase_service.dart';
import '../../widgets/invite_code_dialog.dart';

/// Clean bottom sheet to generate & manage Teacher and Parent invite codes
class InviteCodesBottomSheet extends StatelessWidget {
  const InviteCodesBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const InviteCodesBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const limeGreen = Color(0xFFC9F24A);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Invite Codes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, size: 20, color: subtextColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Generate registration codes for new teachers to claim halaqahs and parents to link students.',
            style: TextStyle(fontSize: 12.5, color: subtextColor, height: 1.4),
          ),
          const SizedBox(height: 20),

          // Two actions
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      InviteCodeDialog.show(context, initialRole: 'teacher');
                    },
                    icon: const Icon(Icons.school_rounded, size: 18),
                    label: const Text('Teacher Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: limeGreen,
                      foregroundColor: const Color(0xFF0F172A),
                      elevation: 0,
                      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      InviteCodeDialog.show(context, initialRole: 'parent');
                    },
                    icon: Icon(Icons.family_restroom_rounded, size: 18, color: textColor),
                    label: Text('Parent Code', style: TextStyle(color: textColor)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Text(
            'ACTIVE CODES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 10),

          // Stream of active codes
          StreamBuilder<List<InvitationCode>>(
            stream: SupabaseService.instance.streamInviteCodes(),
            builder: (context, snapshot) {
              final codes = (snapshot.data ?? []).where((c) => !c.isUsed).toList();

              if (codes.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'No active invite codes currently pending.',
                      style: TextStyle(fontSize: 12, color: subtextColor),
                    ),
                  ),
                );
              }

              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: codes.take(6).length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = codes[index];
                    final isTeacher = item.role == 'teacher';

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isTeacher ? Icons.school_rounded : Icons.family_restroom_rounded,
                            size: 16,
                            color: limeGreen,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            item.role.toUpperCase(),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: limeGreen),
                          ),
                          const Spacer(),
                          Text(
                            item.code,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
