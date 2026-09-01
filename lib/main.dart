import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/theme.dart';
import 'core/router/router.dart';
import 'data/app_state_provider.dart';
import 'core/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Initialize Notification Service and FCM
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    print('[NOTIFICATION] Pre-launch notification init notice: $e');
  }

  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.initialize(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
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
