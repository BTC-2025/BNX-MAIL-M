import 'package:flutter/material.dart';

enum NeumorphicShape {
  flat,
  concave,
  convex,
  pressed,
}

class NeumorphicDecoration {
  static Decoration getDecoration({
    required bool isDark,
    NeumorphicShape shape = NeumorphicShape.flat,
    double borderRadius = 12.0,
    Color? color,
    double depth = 6.0,
    BoxShape boxShape = BoxShape.rectangle,
  }) {
    // Base colors matching standard project backgrounds
    final Color baseColor = color ?? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB));
    
    // Light highlight and dark shadow colors
    final Color lightShadow = isDark 
        ? const Color(0xFF1E293B) // Slate 800
        : const Color(0xFFFFFFFF); // Pure white
        
    final Color darkShadow = isDark 
        ? const Color(0xFF070B14) // Deep pitch black/blue
        : const Color(0xFFD1D9E6); // Light soft grey-blue

    if (shape == NeumorphicShape.pressed) {
      // Sunken pressed look using linear gradient simulation + inner highlight borders
      return BoxDecoration(
        shape: boxShape,
        borderRadius: boxShape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
              ? [const Color(0xFF090E1A), const Color(0xFF162035)]
              : [const Color(0xFFE2EAF4), const Color(0xFFFFFFFF)],
        ),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      );
    } else if (shape == NeumorphicShape.concave) {
      return BoxDecoration(
        shape: boxShape,
        borderRadius: boxShape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF070B14), const Color(0xFF1E293B)]
              : [const Color(0xFFE2EAF4), const Color(0xFFFFFFFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: lightShadow,
            offset: Offset(-depth, -depth),
            blurRadius: depth * 2,
          ),
          BoxShadow(
            color: darkShadow,
            offset: Offset(depth, depth),
            blurRadius: depth * 2,
          ),
        ],
      );
    } else if (shape == NeumorphicShape.convex) {
      return BoxDecoration(
        shape: boxShape,
        borderRadius: boxShape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF070B14)]
              : [const Color(0xFFFFFFFF), const Color(0xFFE2EAF4)],
        ),
        boxShadow: [
          BoxShadow(
            color: lightShadow,
            offset: Offset(-depth, -depth),
            blurRadius: depth * 2,
          ),
          BoxShadow(
            color: darkShadow,
            offset: Offset(depth, depth),
            blurRadius: depth * 2,
          ),
        ],
      );
    } else {
      // Flat raised neumorphic design
      return BoxDecoration(
        shape: boxShape,
        color: baseColor,
        borderRadius: boxShape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: lightShadow,
            offset: Offset(-depth, -depth),
            blurRadius: depth * 2,
          ),
          BoxShadow(
            color: darkShadow,
            offset: Offset(depth, depth),
            blurRadius: depth * 2,
          ),
        ],
      );
    }
  }
}

class NeumorphicContainer extends StatelessWidget {
  final Widget? child;
  final NeumorphicShape shape;
  final double borderRadius;
  final double depth;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BoxShape boxShape;
  final Border? border;
  final Clip clipBehavior;

  const NeumorphicContainer({
    super.key,
    this.child,
    this.shape = NeumorphicShape.flat,
    this.borderRadius = 12.0,
    this.depth = 6.0,
    this.color,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.boxShape = BoxShape.rectangle,
    this.border,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final decoration = NeumorphicDecoration.getDecoration(
      isDark: isDark,
      shape: shape,
      borderRadius: borderRadius,
      color: color,
      depth: depth,
      boxShape: boxShape,
    );

    final finalDecoration = decoration is BoxDecoration && border != null
        ? decoration.copyWith(border: border)
        : decoration;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: finalDecoration,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

class NeumorphicButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final double borderRadius;
  final double depth;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BoxShape boxShape;

  const NeumorphicButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.borderRadius = 12.0,
    this.depth = 6.0,
    this.color,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.boxShape = BoxShape.rectangle,
  });

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    NeumorphicShape currentShape = NeumorphicShape.flat;
    if (_isPressed) {
      currentShape = NeumorphicShape.pressed;
    } else if (_isHovered) {
      currentShape = NeumorphicShape.convex;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: NeumorphicContainer(
          shape: currentShape,
          borderRadius: widget.borderRadius,
          depth: widget.depth,
          color: widget.color,
          padding: widget.padding,
          margin: widget.margin,
          width: widget.width,
          height: widget.height,
          boxShape: widget.boxShape,
          child: widget.child,
        ),
      ),
    );
  }
}
