import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/account_provider.dart';
import '../../data/app_state_provider.dart';
import '../router/router.dart';
import 'notification_model.dart';

/// Dedicated NotificationRouter responsible for routing notification tap events
/// to the correct account and opening the email in the existing email detail screen.
class NotificationRouter {
  /// Routes a notification event by selecting the target account (if needed)
  /// and opening the email detail screen reusing existing application navigation.
  static Future<void> routeNotification(
    NotificationEvent event,
    WidgetRef ref,
  ) async {
    try {
      final targetAccount = event.effectiveAccountIdentifier;
      final emailId = event.effectiveEmailId;

      print('[NOTIFICATION] Routing to account: ${targetAccount ?? "current active"}');

      // Step 1: Account Switching (if notification specifies an account)
      if (targetAccount != null && targetAccount.isNotEmpty) {
        final activeAccount = ref.read(activeAccountProvider);
        final currentEmail = activeAccount.email.trim().toLowerCase();
        final currentId = activeAccount.id.trim().toLowerCase();
        final cleanTarget = targetAccount.trim().toLowerCase();

        if (currentEmail != cleanTarget && currentId != cleanTarget) {
          print('[NOTIFICATION] Switching active account to $targetAccount');
          final accounts = ref.read(accountsProvider);
          final matchingAcc = accounts.firstWhere(
            (a) =>
                a.email.trim().toLowerCase() == cleanTarget ||
                a.id.trim().toLowerCase() == cleanTarget,
            orElse: () => activeAccount,
          );

          if (matchingAcc.id.isNotEmpty && matchingAcc.id != 'loading') {
            await ref
                .read(accountsProvider.notifier)
                .switchAccount(matchingAcc.id, ref);
          }
        }
      }

      // Step 2: Email Detail Navigation (reusing existing email detail route)
      if (emailId != null && emailId.isNotEmpty) {
        print('[NOTIFICATION] Opening email: $emailId');
        // Update selected email in app state
        ref.read(appUiProvider.notifier).selectEmail(emailId);

        // Navigate using existing router path /email/:id
        goRouter.go('/email/$emailId');
        print('[NOTIFICATION] Navigation completed');
      } else {
        print('[NOTIFICATION] No email ID provided, opening Inbox');
        ref.read(appUiProvider.notifier).selectFolder('Inbox');
        goRouter.go('/home');
        print('[NOTIFICATION] Navigation completed');
      }
    } catch (e) {
      print('[NOTIFICATION] Routing error (handled gracefully): $e');
    }
  }
}
