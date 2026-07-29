import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/theme.dart';
import 'core/router/router.dart';
import 'data/app_state_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(appUiProvider);

    return MaterialApp.router(
      title: 'BNX mail',
      debugShowCheckedModeBanner: false,
      themeMode: uiState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: BNXTheme.lightTheme,
      darkTheme: BNXTheme.darkTheme,
      routerConfig: goRouter,
    );
  }
}
