import 'dart:ui';
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
/// Active tab expands smoothly into a tonal Deep Pine pill displaying icon + label;
/// inactive tabs remain clean icons with optional live unread badges.
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
        ? AppColors.surfaceNav.withOpacity(0.88)
        : Colors.white.withOpacity(0.92);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: p.isDark
                ? Colors.black.withOpacity(0.48)
                : const Color(0xFF0A2422).withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 66,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: dockBg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: p.isDark
                    ? Colors.white.withOpacity(0.08)
                    : AppColors.borderSubtleLight.withOpacity(0.95),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isSelected = index == selectedIndex;

                return Flexible(
                  flex: isSelected ? 2 : 1,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (!isSelected) {
                        HapticFeedback.selectionClick();
                      }
                      onTabChanged(index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      height: 50,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSelected ? 12 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (p.isDark
                                ? p.primary.withOpacity(0.20)
                                : p.primary.withOpacity(0.11))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                        border: isSelected
                            ? Border.all(
                                color: p.primary.withOpacity(p.isDark ? 0.35 : 0.20),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                isSelected ? item.activeIcon : item.icon,
                                size: 22,
                                color: isSelected ? p.primary : p.inkMuted,
                              ),
                              if (item.badgeCount > 0)
                                Positioned(
                                  top: -4,
                                  right: -6,
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
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: p.primary,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                          ],
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
