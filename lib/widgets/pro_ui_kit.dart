import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'islamic_pattern_painter.dart';

/// Clean elevated card matching the Kheyrukum flagship design language.
class ProCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? backgroundColor;
  final Color? accentStripeColor;
  final double borderRadius;

  const ProCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.borderColor,
    this.backgroundColor,
    this.accentStripeColor,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final bg = backgroundColor ?? p.surface;
    final bColor = borderColor ??
        (p.isDark ? p.border : p.border.withOpacity(0.85));

    final content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (accentStripeColor != null)
              Container(width: 4, color: accentStripeColor),
            Expanded(
              child: Padding(padding: padding, child: child),
            ),
          ],
        ),
      ),
    );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: bColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: p.isDark
                ? Colors.black.withOpacity(0.24)
                : const Color(0xFF102322).withOpacity(0.035),
            blurRadius: 12,
            offset: p.isDark ? const Offset(0, 4) : const Offset(0, 3),
          ),
        ],
      ),
      child: onTap != null
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(borderRadius),
                child: content,
              ),
            )
          : content,
    );
  }
}

/// Signature Deep Pine gradient hero card with subtle Islamic lattice backdrop.
class ProHeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double patternOpacity;

  const ProHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.patternOpacity = 0.06,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: p.heroGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: p.isDark
              ? AppColors.pineJade.withOpacity(0.26)
              : AppColors.goldWarm.withOpacity(0.28),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: p.isDark
                ? Colors.black.withOpacity(0.35)
                : AppColors.pineDeep.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            Positioned.fill(
              child: IslamicGeometricPattern(
                color: Colors.white,
                opacity: patternOpacity,
                cellSize: 48,
              ),
            ),
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// Editorial section title with optional subtitle and trailing action.
class ProSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const ProSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                  letterSpacing: -0.25,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: p.inkSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Restrained tonal status pill without noisy emojis.
class ProStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool showDot;
  final bool uppercase;

  const ProStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.showDot = false,
    this.uppercase = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.28), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ] else if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              uppercase ? label.toUpperCase() : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: uppercase ? 0.5 : 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Crisp circular monogram avatar with subtle ring.
class ProAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final Color? color;
  final IconData? icon;
  final bool showGoldRing;
  final String? imageUrl;

  const ProAvatar({
    super.key,
    required this.name,
    this.radius = 20,
    this.color,
    this.icon,
    this.showGoldRing = false,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final tone = color ?? p.primary;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'K';
    final hasValidImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tone.withOpacity(p.isDark ? 0.20 : 0.12),
        border: Border.all(
          color: showGoldRing ? p.gold.withOpacity(0.7) : tone.withOpacity(0.32),
          width: showGoldRing ? 1.8 : 1.2,
        ),
      ),
      child: ClipOval(
        child: hasValidImage
            ? Image.network(
                imageUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: icon != null
                      ? Icon(icon, size: radius * 0.95, color: tone)
                      : Text(
                          initial,
                          style: TextStyle(
                            fontSize: radius * 0.78,
                            fontWeight: FontWeight.w700,
                            color: tone,
                          ),
                        ),
                ),
              )
            : Center(
                child: icon != null
                    ? Icon(icon, size: radius * 0.95, color: tone)
                    : Text(
                        initial,
                        style: TextStyle(
                          fontSize: radius * 0.78,
                          fontWeight: FontWeight.w700,
                          color: tone,
                        ),
                      ),
              ),
      ),
    );
  }
}

/// Sculpted double-ring empty state rendered directly on canvas by default.
class ProEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? accentColor;
  final bool framed;

  const ProEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.accentColor,
    this.framed = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final accent = accentColor ?? p.primary;

    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(0.08),
                border: Border.all(color: accent.withOpacity(0.18)),
              ),
              child: Center(
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withOpacity(0.14),
                  ),
                  child: Icon(icon, size: 25, color: accent),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: p.ink,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: p.inkSecondary,
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );

    if (framed) {
      return ProCard(padding: EdgeInsets.zero, child: body);
    }
    return body;
  }
}

/// Unified bottom sheet wrapper with elevated surface header over a warm canvas body.
class ProBottomSheetShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final Widget child;
  final Widget? trailingAction;
  final double heightFactor;

  const ProBottomSheetShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor,
    required this.child,
    this.trailingAction,
    this.heightFactor = 0.85,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final tone = iconColor ?? p.primary;

    return Container(
      height: MediaQuery.of(context).size.height * heightFactor,
      decoration: BoxDecoration(
        color: p.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: p.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(p.isDark ? 0.4 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          children: [
            Container(
              color: p.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.inkMuted.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 14, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: tone.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: tone.withOpacity(0.24)),
                          ),
                          child: Icon(icon, color: tone, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: p.ink,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (subtitle != null && subtitle!.isNotEmpty) ...[
                                const SizedBox(height: 1),
                                Text(
                                  subtitle!,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: p.inkSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (trailingAction != null) ...[
                          trailingAction!,
                          const SizedBox(width: 4),
                        ],
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: IconButton.styleFrom(
                            backgroundColor: p.surfaceSubtle,
                            minimumSize: const Size(34, 34),
                            padding: EdgeInsets.zero,
                          ),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: p.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: p.border),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Sculpted search input bar matching the Warm Sanctuary / Emerald Night design.
class ProSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final String query;
  final VoidCallback? onClear;

  const ProSearchField({
    super.key,
    this.controller,
    required this.hintText,
    required this.onChanged,
    this.query = '',
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: p.isDark
                ? Colors.black.withOpacity(0.18)
                : const Color(0xFF102322).withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: p.ink, fontSize: 13.5),
        decoration: InputDecoration(
          filled: false,
          isDense: true,
          hintText: hintText,
          hintStyle: TextStyle(color: p.inkMuted, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, size: 19, color: p.inkMuted),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, size: 17, color: p.inkSecondary),
                  onPressed: () {
                    controller?.clear();
                    onClear?.call();
                    onChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

/// Smooth segmented switcher pill for 2 or 3 options.
class ProSegmentedControl extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const ProSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isSelected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected ? p.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(p.isDark ? 0.25 : 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? p.primary : p.inkSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
