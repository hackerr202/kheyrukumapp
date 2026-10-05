import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Messages Tab ready for real parent-teacher communications.
class MessagesTab extends StatelessWidget {
  const MessagesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Messages & Feedback',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '0 Unread',
                style: TextStyle(color: AppColors.accentAmber, fontWeight: FontWeight.w600, fontSize: 12),
              ),
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

        const SizedBox(height: 24),

        // Clean Empty State
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppColors.accentAmber.withOpacity(0.7)),
              const SizedBox(height: 14),
              const Text(
                'No Conversations Yet',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Direct voice notes, audio reviews, and messages between Ustaz and parents will appear here once halaqahs begin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12.5, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
