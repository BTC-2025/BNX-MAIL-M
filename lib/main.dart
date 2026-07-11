import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/theme.dart';
import 'core/router/router.dart';
import 'data/app_state_provider.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MainApp(),
    ),
  );
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(appUiProvider);
    
    return MaterialApp.router(
      title: 'BNXMail Client',
      debugShowCheckedModeBanner: false,
      themeMode: uiState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: BNXTheme.lightTheme,
      darkTheme: BNXTheme.darkTheme,
      routerConfig: goRouter,
    );
  }
}
