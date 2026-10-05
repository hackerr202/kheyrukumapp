import 'package:flutter/material.dart';
import '../core/models/announcement.dart';

/// Animated In-App Notification Toast Banner that drops down from the top
/// whenever a new announcement is broadcast via Supabase Realtime.
class AnnouncementBanner extends StatelessWidget {
  final Announcement announcement;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const AnnouncementBanner({
    super.key,
    required this.announcement,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor = const Color(0xFF00BCD4);
    String badgeText = 'General';

    switch (announcement.category) {
      case 'urgent':
        badgeColor = const Color(0xFFFF4B72);
        badgeText = 'URGENT';
        break;
      case 'event':
        badgeColor = const Color(0xFFFFA000);
        badgeText = 'EVENT';
        break;
      case 'quran_halaqah':
        badgeColor = const Color(0xFF10B981);
        badgeText = 'HALAQAH';
        break;
      case 'holiday':
        badgeColor = const Color(0xFFC9F24A);
        badgeText = 'HOLIDAY';
        break;
    }

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: badgeColor.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: badgeColor.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Glowing Icon Indicator
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.campaign_rounded,
                    color: badgeColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            announcement.authorName,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        announcement.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        announcement.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Close Button
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xFF64748B), size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
