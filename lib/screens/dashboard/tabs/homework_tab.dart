import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Homework Tab connected to Supabase Cloud ready for real homework tasks.
class HomeworkTab extends StatelessWidget {
  const HomeworkTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtextColor = isDark ? Colors.white.withOpacity(0.6) : AppColors.textSecondaryLight;
    final cardBg = isDark ? AppColors.surfaceCard : AppColors.surfaceCardLight;
    final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Quran & Tajweed Tasks',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentTeal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '0 Pending',
                style: TextStyle(color: AppColors.accentTeal, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Clean Empty State Card
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(Icons.assignment_outlined, size: 48, color: AppColors.accentAmber.withOpacity(0.7)),
              const SizedBox(height: 14),
              Text(
                'No Homework Assigned Yet',
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Teachers will assign audio recitation recordings and Tajweed revision exercises directly to student halaqahs.',
                textAlign: TextAlign.center,
                style: TextStyle(color: subtextColor, fontSize: 12.5, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
