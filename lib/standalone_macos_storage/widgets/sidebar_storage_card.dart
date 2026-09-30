import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../pages/macos_storage_page.dart';

/// A compact, elegant Storage Card widget designed for sidebars, navigation drawers, or status rails.
/// Clicking this card navigates directly to the macOS Storage Page.
class SidebarStorageCard extends StatelessWidget {
  final String title;
  final String usageText;
  final double? progress; // Value between 0.0 and 1.0
  final VoidCallback? onTap;
  final VoidCallback? onBackFromStorage;
  final VoidCallback? onBetaLogoTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const SidebarStorageCard({
    super.key,
    this.title = 'Storage',
    this.usageText = '0 KB of 1.00 GB used',
    this.progress,
    this.onTap,
    this.onBackFromStorage,
    this.onBetaLogoTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    this.margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (onTap != null) {
              onTap!();
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MacOsStoragePage(
                    onBack: onBackFromStorage,
                    onBetaLogoTap: onBetaLogoTap,
                  ),
                ),
              );
            }
          },
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDBEAFE), width: 1),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.cloud,
                  color: Color(0xFF2563EB),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        usageText,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF475569),
                        ),
                      ),
                      if (progress != null) ...[
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress!.clamp(0.0, 1.0),
                            minHeight: 3,
                            backgroundColor: const Color(0xFFDBEAFE),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  LucideIcons.chevronRight,
                  size: 14,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
