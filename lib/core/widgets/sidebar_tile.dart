import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/neumorphic.dart';

class SidebarTile extends StatefulWidget {
  final IconData icon;
  final IconData? selectedIcon;
  final String title;
  final bool isSelected;
  final bool isCollapsed;
  final String? badgeText;
  final VoidCallback onTap;

  const SidebarTile({
    super.key,
    required this.icon,
    this.selectedIcon,
    required this.title,
    this.isSelected = false,
    this.isCollapsed = false,
    this.badgeText,
    required this.onTap,
  });

  @override
  State<SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<SidebarTile>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine colors based on states
    final Color iconColor = widget.isSelected
        ? (isDark
              ? const Color.fromARGB(255, 54, 129, 250)
              : BNXColors.lightPrimary)
        : (isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary);
    final Color textColor = widget.isSelected
        ? (isDark ? Colors.white : BNXColors.lightTextPrimary)
        : (isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary);
    final FontWeight fontWeight = widget.isSelected
        ? FontWeight.w700
        : FontWeight.w500;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: NeumorphicContainer(
          shape: widget.isSelected
              ? NeumorphicShape.pressed
              : (_isHovered ? NeumorphicShape.convex : NeumorphicShape.flat),
          borderRadius: 24,
          depth: widget.isSelected ? 0 : (_isHovered ? 3.0 : 0.0),
          color: widget.isSelected
              ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB))
              : (_isHovered ? null : Colors.transparent),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isCollapsed ? 0 : 16,
          ),
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
          height: 48,
          child: Container(
            alignment: Alignment.center,
            child: widget.isCollapsed
                ? _buildCollapsed(iconColor)
                : _buildExpanded(iconColor, textColor, fontWeight, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsed(Color iconColor) {
    return Tooltip(
      message: widget.title,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(
            widget.isSelected
                ? (widget.selectedIcon ?? widget.icon)
                : widget.icon,
            color: iconColor,
            size: 22,
          ),
          if (widget.badgeText != null)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpanded(
    Color iconColor,
    Color textColor,
    FontWeight fontWeight,
    bool isDark,
  ) {
    return Row(
      children: [
        Icon(
          widget.isSelected
              ? (widget.selectedIcon ?? widget.icon)
              : widget.icon,
          color: iconColor,
          size: 20,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontWeight: fontWeight,
              fontSize: 14,
            ),
          ),
        ),
        if (widget.badgeText != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? (isDark ? Colors.black26 : Colors.white24)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              widget.badgeText!,
              style: TextStyle(
                color: widget.isSelected
                    ? (isDark ? Colors.white : BNXColors.lightPrimary)
                    : textColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}
