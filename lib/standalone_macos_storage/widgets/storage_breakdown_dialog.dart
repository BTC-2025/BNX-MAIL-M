import 'package:flutter/material.dart';
import '../pages/macos_storage_page.dart';

class MacOsStorageBreakdownDialog extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onBetaLogoTap;

  const MacOsStorageBreakdownDialog({
    super.key,
    this.onBack,
    this.onBetaLogoTap,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onBack,
    VoidCallback? onBetaLogoTap,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MacOsStoragePage(
          onBack: onBack,
          onBetaLogoTap: onBetaLogoTap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MacOsStoragePage(
      onBack: onBack,
      onBetaLogoTap: onBetaLogoTap,
    );
  }
}
