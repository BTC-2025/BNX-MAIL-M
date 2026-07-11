import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'profile_button.dart';
import '../../data/app_state_provider.dart';
import '../../data/notification_provider.dart';
import '../constants/constants.dart';
import '../theme/colors.dart';
import '../theme/neumorphic.dart';

class TopSearchBar extends ConsumerWidget implements PreferredSizeWidget {
  const TopSearchBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(72.0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;
    final textController = TextEditingController(text: uiState.searchQuery);
    
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    textController.selection = TextSelection.fromPosition(
      TextPosition(offset: textController.text.length),
    );

    return Container(
      color: isDark ? BNXColors.darkBg : BNXColors.lightBg,
      padding: EdgeInsets.only(
        left: isMobile ? 8 : 16,
        right: isMobile ? 8 : 16,
        top: isMobile ? 8 : 0,
        bottom: isMobile ? 8 : 0,
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                final scaffold = Scaffold.maybeOf(context);
                if (scaffold != null && scaffold.hasDrawer) {
                  scaffold.openDrawer();
                } else {
                  ref.read(appUiProvider.notifier).toggleSidebar();
                }
              },
              tooltip: 'Main menu',
            ),
            SizedBox(width: isMobile ? 4 : 8),
            
            Expanded(
              child: NeumorphicContainer(
                height: 48,
                shape: NeumorphicShape.pressed,
                borderRadius: 24,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(

                  children: [
                    const Icon(
                      Icons.search,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: textController,
                        onChanged: (val) {
                          ref.read(appUiProvider.notifier).setSearchQuery(val);
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search in emails',
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (uiState.searchQuery.isNotEmpty) ...[
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          ref.read(appUiProvider.notifier).setSearchQuery('');
                          textController.clear();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            SizedBox(width: isMobile ? 8 : 16),
            
            if (!isMobile) ...[
              const SizedBox(width: 8),
              // Feature 4: Bell icon with live unread badge
              Builder(builder: (ctx) {
                final unreadCount = ref.watch(unreadNotificationsCountProvider);
                return Stack(
                  alignment: Alignment.topRight,
                  children: [
                    IconButton(
                      icon: Icon(
                        uiState.activeRightUtility == 'Notifications'
                            ? Icons.notifications_rounded
                            : Icons.notifications_none_rounded,
                        color: uiState.activeRightUtility == 'Notifications'
                            ? (isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary)
                            : null,
                      ),
                      onPressed: () {
                        ref.read(appUiProvider.notifier).setActiveRightUtility('Notifications');
                      },
                      tooltip: 'Notification Centre',
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: IgnorePointer(
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              unreadCount > 9 ? '9+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              }),
              const SizedBox(width: 8),
              const ProfileButton(),
            ],
          ],
        ),
      ),
    );
  }
}
