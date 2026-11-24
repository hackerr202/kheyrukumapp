import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';

/// Item descriptor for [KheyrukumNavBar].
class KheyrukumNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badgeCount;

  const KheyrukumNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount = 0,
  });
}

/// Floating frosted-glass bottom navigation dock.
/// Displays a balanced 5-column layout with unified icons and compact labels
/// across every destination, highlighted with a subtle tonal capsule.
class KheyrukumNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final List<KheyrukumNavItem> items;

  const KheyrukumNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
    required this.items,
  }) : assert(items.length >= 2, 'At least 2 tabs required');

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final dockBg = p.isDark
        ? AppColors.surfaceNav.withOpacity(0.90)
        : Colors.white.withOpacity(0.94);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: p.isDark
                  ? Colors.black.withOpacity(0.45)
                  : const Color(0xFF0A2422).withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Container(
            height: 66,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: dockBg,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: p.isDark
                    ? Colors.white.withOpacity(0.08)
                    : AppColors.borderSubtleLight.withOpacity(0.95),
                width: 1,
              ),
            ),
            child: Row(
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isSelected = index == selectedIndex;

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (!isSelected) {
                        HapticFeedback.selectionClick();
                      }
                      onTabChanged(index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? p.primary.withOpacity(p.isDark ? 0.22 : 0.11)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                isSelected ? item.activeIcon : item.icon,
                                size: 21,
                                color: isSelected ? p.primary : p.inkMuted,
                              ),
                              if (item.badgeCount > 0)
                                PositionedDirectional(
                                  top: -4,
                                  end: -7,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 15,
                                      minHeight: 15,
                                    ),
                                    decoration: BoxDecoration(
                                      color: p.danger,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: p.surface,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        item.badgeCount > 9
                                            ? '9+'
                                            : '${item.badgeCount}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          height: 1.1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected ? p.primary : p.inkMuted,
                              letterSpacing: -0.1,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
