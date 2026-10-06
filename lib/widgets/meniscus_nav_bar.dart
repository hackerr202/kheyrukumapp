import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'meniscus_painter.dart';

/// Navigation Tab Item Model with specific accent color
class MeniscusNavItem {
  final IconData icon;
  final String label;
  final Color accentColor;

  const MeniscusNavItem({
    required this.icon,
    required this.label,
    required this.accentColor,
  });
}

/// Floating Meniscus Navigation Bar exactly matching the reference visual:
///
/// - High-contrast floating bead resting half-submerged in the smooth socket bowl
/// - Neon rim highlight tracing ONLY the socket bowl directly below the bead
/// - Active tab label positioned inside the dock directly beneath the bead
/// - Clean, minimal inactive icons with NO text labels
/// - Fluid spring-snapping physics
class MeniscusNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final List<MeniscusNavItem> items;

  const MeniscusNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
    required this.items,
  }) : assert(items.length >= 2, 'At least 2 tabs required');

  @override
  State<MeniscusNavBar> createState() => _MeniscusNavBarState();
}

class _MeniscusNavBarState extends State<MeniscusNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _springController;

  double _beadX = 0.0;
  double _currentVelocity = 0.0;
  bool _isDragging = false;
  double _dragStartX = 0.0;
  double _dragInitialBeadX = 0.0;
  double _barWidth = 0.0;
  DateTime? _lastDragTime;
  double _lastDragX = 0.0;

  final SpringDescription _springDescription = const SpringDescription(
    mass: 1.0,
    stiffness: 380.0,
    damping: 24.0,
  );

  @override
  void initState() {
    super.initState();
    _springController = AnimationController.unbounded(vsync: this);
    _springController.addListener(_onSpringUpdate);
    _springController.addStatusListener(_onSpringStatus);
  }

  void _onSpringUpdate() {
    final prevX = _beadX;
    setState(() {
      _beadX = _springController.value;
      _currentVelocity = (_beadX - prevX) * 60.0;
    });
  }

  void _onSpringStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        _currentVelocity = 0.0;
      });
      final nearestIndex = _getNearestTabIndex(_beadX);
      if (nearestIndex != widget.selectedIndex) {
        widget.onTabChanged(nearestIndex);
      }
    }
  }

  @override
  void didUpdateWidget(covariant MeniscusNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex && !_isDragging) {
      _snapToIndex(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _springController.removeListener(_onSpringUpdate);
    _springController.removeStatusListener(_onSpringStatus);
    _springController.dispose();
    super.dispose();
  }

  double _getSidePadding(double totalWidth) {
    // Provides room for dock rounded corners (20px) + shoulder reach (~31px)
    return (totalWidth * 0.15).clamp(50.0, 56.0);
  }

  double _getTabCenterX(int index, double totalWidth) {
    if (widget.items.length <= 1) return totalWidth / 2;
    final sidePadding = _getSidePadding(totalWidth);
    final availableTrack = totalWidth - (sidePadding * 2);
    final step = availableTrack / (widget.items.length - 1);
    return sidePadding + (step * index);
  }

  int _getNearestTabIndex(double x) {
    if (_barWidth <= 0) return widget.selectedIndex;
    int nearest = 0;
    double minDiff = double.infinity;
    for (int i = 0; i < widget.items.length; i++) {
      final cx = _getTabCenterX(i, _barWidth);
      final diff = (cx - x).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = i;
      }
    }
    return nearest;
  }


  void _snapToIndex(int targetIndex, {double velocity = 0.0}) {
    if (_barWidth <= 0) return;
    final targetX = _getTabCenterX(targetIndex, _barWidth);

    _springController.stop();
    final simulation = SpringSimulation(
      _springDescription,
      _beadX,
      targetX,
      velocity,
    );
    _springController.animateWith(simulation);
  }

  void _onPanStart(DragStartDetails details) {
    _springController.stop();
    setState(() {
      _isDragging = true;
      _dragStartX = details.localPosition.dx;
      _dragInitialBeadX = _beadX;
      _lastDragTime = DateTime.now();
      _lastDragX = details.localPosition.dx;
      _currentVelocity = 0.0;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_barWidth <= 0) return;
    final now = DateTime.now();
    final currentTouchX = details.localPosition.dx;
    final dx = currentTouchX - _dragStartX;
    final newX = _dragInitialBeadX + dx;

    final minX = _getTabCenterX(0, _barWidth);
    final maxX = _getTabCenterX(widget.items.length - 1, _barWidth);

    if (_lastDragTime != null) {
      final dt = (now.difference(_lastDragTime!).inMicroseconds) / 1000000.0;
      if (dt > 0.005) {
        _currentVelocity = (currentTouchX - _lastDragX) / dt;
        _lastDragTime = now;
        _lastDragX = currentTouchX;
      }
    }

    setState(() {
      _beadX = newX.clamp(minX, maxX);
    });

    final nearest = _getNearestTabIndex(_beadX);
    if (nearest != widget.selectedIndex) {
      widget.onTabChanged(nearest);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    final velocity = details.velocity.pixelsPerSecond.dx;
    int targetIndex = _getNearestTabIndex(_beadX);

    if (velocity.abs() > 300) {
      if (velocity > 0 && targetIndex < widget.items.length - 1) {
        targetIndex++;
      } else if (velocity < 0 && targetIndex > 0) {
        targetIndex--;
      }
    }

    _snapToIndex(targetIndex, velocity: velocity);
  }

  void _onTabTapped(int index) {
    if (_isDragging) return;
    widget.onTabChanged(index);
    _snapToIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    const double dockHeight = 58.0;
    const double beadRadius = 18.0;
    const double beadDiameter = beadRadius * 2;
    const double topOverflow = 22.0;
    const double totalHeight = dockHeight + topOverflow;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        if (_barWidth != totalWidth) {
          _barWidth = totalWidth;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isDragging) {
              setState(() {
                _beadX = _getTabCenterX(widget.selectedIndex, totalWidth);
              });
            }
          });
        }

        final currentBeadX = _beadX > 0
            ? _beadX
            : _getTabCenterX(widget.selectedIndex, totalWidth);

        final activeItem = widget.items[widget.selectedIndex];
        final activeColor = activeItem.accentColor;

        return SizedBox(
          width: totalWidth,
          height: totalHeight,
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. DOCK CONTAINER WITH EXACT MENISCUS NOTCH
                Positioned(
                  top: topOverflow,
                  left: 0,
                  right: 0,
                  height: dockHeight,
                  child: CustomPaint(
                    painter: MeniscusPainter(
                      beadX: currentBeadX,
                      beadY: 1.0,           // 1px below dock top edge
                      bowlRadius: 22.0,     // 22px bowl (4px clearance around bead)
                      shoulderRadius: 10.0, // 10px smooth shoulder
                      velocityX: _currentVelocity,
                      dockFillColor: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF161927)
                          : const Color(0xFFFFFFFF),
                      accentColor: activeColor,
                      cornerRadius: 20.0,
                    ),
                  ),
                ),

                // 2. INACTIVE TAB ICONS (Positioned at exact tabCenterX coordinates)
                ...List.generate(widget.items.length, (index) {
                  final item = widget.items[index];
                  final tabCenterX = _getTabCenterX(index, totalWidth);
                  final distFromBead = (currentBeadX - tabCenterX).abs();

                  // Fade out icon completely when active or near bead
                  final iconOpacity = (distFromBead / 32.0).clamp(0.0, 1.0);

                  return Positioned(
                    left: tabCenterX - 24,
                    top: topOverflow,
                    width: 48,
                    height: dockHeight,
                    child: InkWell(
                      onTap: () => _onTabTapped(index),
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Opacity(
                            opacity: iconOpacity * 0.7,
                            child: Icon(
                              item.icon,
                              size: 22,
                              color: const Color(0xFF8E8E9F),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),


                // 3. ACTIVE TAB LABEL (Directly underneath the bead inside the dock)
                Positioned(
                  left: currentBeadX - 45,
                  top: topOverflow + 39,
                  width: 90,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: activeColor,
                        fontFamily: 'Poppins',
                        letterSpacing: 0.2,
                      ),
                      child: Text(
                        activeItem.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),

                // 4. FLOATING GLOWING BEAD (Elevated, resting inside the socket)
                Positioned(
                  left: currentBeadX - beadRadius,
                  top: topOverflow + 1.0 - beadRadius,
                  child: IgnorePointer(
                    child: SizedBox(
                      width: beadDiameter,
                      height: beadDiameter,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Soft diffuse outer glow
                          Container(
                            width: beadDiameter,
                            height: beadDiameter,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: activeColor.withOpacity(_isDragging ? 0.8 : 0.6),
                                  blurRadius: _isDragging ? 20 : 14,
                                  spreadRadius: _isDragging ? 3 : 1,
                                ),
                              ],
                            ),
                          ),

                          // Clean solid luminous circular bead
                          Container(
                            width: beadDiameter,
                            height: beadDiameter,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: activeColor,
                            ),
                          ),

                          // Active icon inside the bead in dark slate
                          Icon(
                            activeItem.icon,
                            size: 19,
                            color: const Color(0xFF111827),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
