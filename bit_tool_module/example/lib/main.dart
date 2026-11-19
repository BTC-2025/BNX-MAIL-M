import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bit_tool_module/bit_tool_module.dart';

void main() {
  runApp(
    const ProviderScope(
      child: BitToolExampleApp(),
    ),
  );
}

class BitToolExampleApp extends ConsumerWidget {
  const BitToolExampleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Bit Tool Module Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF065F46)),
        useMaterial3: true,
      ),
      home: const BitToolDemoScreen(),
    );
  }
}

class BitToolDemoScreen extends ConsumerStatefulWidget {
  const BitToolDemoScreen({super.key});

  @override
  ConsumerState<BitToolDemoScreen> createState() => _BitToolDemoScreenState();
}

class _BitToolDemoScreenState extends ConsumerState<BitToolDemoScreen> {
  @override
  void initState() {
    super.initState();
    // Simulate setting up authentication & active account from host app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bitToolTokenProvider.notifier).state = () async {
        // Return host app's active JWT or session token here:
        return 'mock-host-session-token';
      };

      ref.read(bitToolActiveAccountProvider.notifier).state = const BitToolHostAccount(
        id: 'user_101',
        email: 'developer@bittool.dev',
        name: 'Lead Developer',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Host Application Workspace'),
        backgroundColor: const Color(0xFF065F46),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // 1. Host Application Main Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.dashboard_customize_rounded, size: 64, color: Color(0xFF065F46)),
                const SizedBox(height: 16),
                const Text(
                  'Your Host Application Content',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Click any tool on the right utility rail to open slide-out panels.',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // Switch host active account example
                    ref.read(bitToolActiveAccountProvider.notifier).state = const BitToolHostAccount(
                      id: 'user_202',
                      email: 'sarah@enterprise.com',
                      name: 'Sarah Enterprise',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Switched to sarah@enterprise.com')),
                    );
                  },
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Simulate Account Switch'),
                ),
              ],
            ),
          ),

          // 2. Standalone Bit Tool Right Utility Rail
          const Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: BitToolRightUtilityRail(),
          ),
        ],
      ),
    );
  }
}
