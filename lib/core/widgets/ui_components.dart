import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../constants/constants.dart';

class PrimaryButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.backgroundColor,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor =
        widget.backgroundColor ??
        (isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary);

    // Colored Neumorphism shadow styling
    final List<BoxShadow> shadows = _isPressed
        ? []
        : [
            BoxShadow(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.4),
              offset: const Offset(-4, -4),
              blurRadius: 8,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
              offset: const Offset(4, 4),
              blurRadius: 8,
            ),
          ];

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
        child: AnimatedContainer(
          duration: BNXConstants.animationDurationFast,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: _isPressed
                ? defaultColor.withValues(alpha: 0.85)
                : (_isHovered
                      ? defaultColor.withValues(alpha: 0.95)
                      : defaultColor),
            borderRadius: BorderRadius.circular(24),
            boxShadow: shadows,
            border: _isPressed
                ? Border.all(
                    color: Colors.black.withValues(alpha: 0.1),
                    width: 1.5,
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 16, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchBox extends StatelessWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;

  const SearchBox({
    super.key,
    required this.hintText,
    this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? BNXColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? BNXColors.darkBorder : BNXColors.lightBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white54 : BNXColors.lightTextSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Divider(
            color: isDark ? BNXColors.darkBorder : BNXColors.lightBorder,
            thickness: 1,
          ),
        ],
      ),
    );
  }
}
