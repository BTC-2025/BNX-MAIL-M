import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// BNX Mail – Central Animation Utilities
// ---------------------------------------------------------------------------

/// Standard duration constants
class BNXDurations {
  BNXDurations._();
  static const Duration instant = Duration(milliseconds: 0);
  static const Duration micro = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 350);
}

/// Standard curves
class BNXCurves {
  BNXCurves._();
  static const Curve standard = Curves.easeOutCubic;
  static const Curve enter = Curves.fastOutSlowIn;
  static const Curve exit = Curves.easeInCubic;
  static const Curve smooth = Curves.easeInOutCubic;
}

// ---------------------------------------------------------------------------
// PAGE TRANSITIONS
// ---------------------------------------------------------------------------

/// Smooth fade + subtle upward slide — used for most screen pushes.
class FadeSlidePageRoute<T> extends PageRouteBuilder<T> {
  FadeSlidePageRoute({required Widget child, super.settings, double slideOffset = 20.0})
      : super(
          transitionDuration: BNXDurations.normal,
          reverseTransitionDuration: BNXDurations.fast,
          pageBuilder: (ctx, a1, a2) => child,
          transitionsBuilder: (context, animation, secondaryAnim, child) {
            if (MediaQuery.of(context).disableAnimations) return child;
            final fade = CurvedAnimation(parent: animation, curve: BNXCurves.enter);
            final slide = Tween<Offset>(
              begin: Offset(0, slideOffset / 300),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: BNXCurves.enter));
            return FadeTransition(opacity: fade, child: SlideTransition(position: slide, child: child));
          },
        );
}

/// Horizontal slide — used for email open/close.
class HorizontalSlidePageRoute<T> extends PageRouteBuilder<T> {
  HorizontalSlidePageRoute({required Widget child, super.settings})
      : super(
          transitionDuration: BNXDurations.normal,
          reverseTransitionDuration: BNXDurations.fast,
          pageBuilder: (ctx, a1, a2) => child,
          transitionsBuilder: (context, animation, secondaryAnim, child) {
            if (MediaQuery.of(context).disableAnimations) return child;
            final slide = Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: BNXCurves.enter));
            final fade = CurvedAnimation(parent: animation, curve: BNXCurves.enter);
            return FadeTransition(opacity: fade, child: SlideTransition(position: slide, child: child));
          },
        );
}

// ---------------------------------------------------------------------------
// SECTION SWITCHER
// ---------------------------------------------------------------------------

/// Fade + slight Y slide for folder/tab switching.
class BNXSectionSwitcher extends StatelessWidget {
  const BNXSectionSwitcher({super.key, required this.child, this.duration = BNXDurations.normal});
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: BNXCurves.enter,
      switchOutCurve: BNXCurves.exit,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: BNXCurves.enter));
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// SKELETON / SHIMMER LOADING
// ---------------------------------------------------------------------------

class ShimmerBox extends StatefulWidget {
  const ShimmerBox({super.key, this.width, this.height = 14, this.borderRadius = 6, this.isDark = false});
  final double? width;
  final double height;
  final double borderRadius;
  final bool isDark;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, child) {
        final base = widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
        final highlight = widget.isDark ? const Color(0xFF334155) : Colors.white;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + _anim.value * 3, 0),
              end: Alignment(-0.5 + _anim.value * 3, 0),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

class EmailSkeletonTile extends StatelessWidget {
  const EmailSkeletonTile({super.key, this.isDark = false});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ShimmerBox(width: 36, height: 36, borderRadius: 18, isDark: isDark),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              ShimmerBox(width: 110, height: 11, isDark: isDark),
              ShimmerBox(width: 42, height: 10, isDark: isDark),
            ]),
            const SizedBox(height: 6),
            ShimmerBox(width: double.infinity, height: 11, isDark: isDark),
            const SizedBox(height: 5),
            ShimmerBox(width: 180, height: 10, isDark: isDark),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// PRESS FEEDBACK
// ---------------------------------------------------------------------------

class PressScaleEffect extends StatefulWidget {
  const PressScaleEffect({
    super.key, required this.child,
    this.scaleFactor = 0.96, this.duration = BNXDurations.micro,
    this.onTap, this.onLongPress,
  });
  final Widget child;
  final double scaleFactor;
  final Duration duration;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<PressScaleEffect> createState() => _PressScaleEffectState();
}

class _PressScaleEffectState extends State<PressScaleEffect> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration, value: 1.0);
    _scale = Tween<double>(begin: 1.0, end: widget.scaleFactor)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return GestureDetector(onTap: widget.onTap, onLongPress: widget.onLongPress, child: widget.child);
    }
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

// ---------------------------------------------------------------------------
// FADE-IN WIDGET
// ---------------------------------------------------------------------------

class FadeInWidget extends StatefulWidget {
  const FadeInWidget({super.key, required this.child, this.duration = BNXDurations.medium, this.delay = Duration.zero, this.slideOffset = 8.0});
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double slideOffset;

  @override
  State<FadeInWidget> createState() => _FadeInWidgetState();
}

class _FadeInWidgetState extends State<FadeInWidget> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _ctrl, curve: BNXCurves.enter);
    _slide = Tween<Offset>(begin: Offset(0, widget.slideOffset / 300), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: BNXCurves.enter));
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () { if (mounted) _ctrl.forward(); });
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return FadeTransition(opacity: _fade, child: SlideTransition(position: _slide, child: widget.child));
  }
}

// ---------------------------------------------------------------------------
// ROTATING ICON (expand/collapse chevrons)
// ---------------------------------------------------------------------------

class RotatingIcon extends StatelessWidget {
  const RotatingIcon({
    super.key, required this.isExpanded, required this.icon,
    this.size, this.color, this.beginTurns = 0.0, this.endTurns = 0.25,
    this.duration = BNXDurations.fast,
  });
  final bool isExpanded;
  final IconData icon;
  final double? size;
  final Color? color;
  final double beginTurns;
  final double endTurns;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: isExpanded ? endTurns : beginTurns,
      duration: duration,
      curve: BNXCurves.standard,
      child: Icon(icon, size: size, color: color),
    );
  }
}

// ---------------------------------------------------------------------------
// ANIMATED STAR ICON
// ---------------------------------------------------------------------------

class AnimatedStarIcon extends StatefulWidget {
  const AnimatedStarIcon({super.key, required this.isStarred, this.size = 20.0});
  final bool isStarred;
  final double size;

  @override
  State<AnimatedStarIcon> createState() => _AnimatedStarIconState();
}

class _AnimatedStarIconState extends State<AnimatedStarIcon> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _prev = false;

  @override
  void initState() {
    super.initState();
    _prev = widget.isStarred;
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.88), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(AnimatedStarIcon old) {
    super.didUpdateWidget(old);
    if (widget.isStarred != _prev) { _prev = widget.isStarred; _ctrl.forward(from: 0); }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
        child: Icon(
          widget.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
          key: ValueKey(widget.isStarred),
          size: widget.size,
          color: widget.isStarred ? const Color(0xFFF59E0B) : null,
        ),
      ),
    );
  }
}
