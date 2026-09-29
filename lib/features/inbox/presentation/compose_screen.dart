import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/app_state_provider.dart';
import '../../../core/widgets/compose_dialog.dart';

class ComposeScreen extends ConsumerWidget {
  const ComposeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kIsWeb && Platform.isMacOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(appUiProvider.notifier).setComposeStatus(ComposeStatus.normal);
        if (context.mounted && GoRouterState.of(context).uri.toString() == '/compose') {
          context.go('/home');
        }
      });
      return const Scaffold(body: SizedBox.shrink());
    }
    return const Scaffold(body: ComposeDialog());
  }
}
