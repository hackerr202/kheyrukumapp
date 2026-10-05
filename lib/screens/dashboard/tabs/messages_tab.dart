import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class MessagesTab extends StatelessWidget {
  const MessagesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final chatThreads = [
      {
        'name': 'Sheikh Abdullah Al-Madani',
        'role': 'Tajweed & Hifz Master',
        'lastMsg': '🎙️ Voice Note: Review on Surah Al-Mulk (Ayat 1-10)',
        'time': '10:45 AM',
        'unread': 2,
        'online': true,
      },
      {
        'name': 'Ustadha Fatima Zahra',
        'role': 'Noorani Qaida & Basics',
        'lastMsg': 'Zayd completed the exercises on Makharij Al-Huruf today.',
        'time': 'Yesterday',
        'unread': 0,
        'online': false,
      },
      {
        'name': 'Halaqah Academic Office',
        'role': 'Administration',
        'lastMsg': 'Monthly progress report for Rabi al-Awwal is ready for download.',
        'time': 'Oct 3',
        'unread': 0,
        'online': false,
      },
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Parent-Teacher Messages',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            IconButton(
              icon: const Icon(Icons.mark_chat_read_outlined, color: AppColors.accentTeal),
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Quick Notice Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.accentTeal.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accentTeal.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.accentTeal, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'End-to-end encrypted school communication portal.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Chat List
        ...chatThreads.map((chat) {
          final isUnread = (chat['unread'] as int) > 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isUnread ? const Color(0xFF1E293B) : const Color(0xFF162032),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUnread ? AppColors.accentAmber.withOpacity(0.4) : AppColors.borderSubtle,
              ),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.surfaceLight,
                      child: Text(
                        (chat['name'] as String).substring(0, 1),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (chat['online'] as bool)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.accentEmerald,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.surfaceCard, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            chat['name'] as String,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          Text(
                            chat['time'] as String,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        chat['role'] as String,
                        style: TextStyle(color: AppColors.accentTeal.withOpacity(0.85), fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chat['lastMsg'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isUnread ? Colors.white : AppColors.textSecondary,
                          fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUnread) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentAmber,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${chat['unread']}',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}
