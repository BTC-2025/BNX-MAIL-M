import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../network/token_service.dart';
import '../../data/repositories/user_repository.dart';
import 'notification_model.dart';
import 'notification_router.dart';

/// Top-level background message handler required by Firebase Messaging
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    print(
      '[NOTIFICATION] FCM Background message received: ${message.messageId}',
    );
  } catch (e) {
    print('[NOTIFICATION] FCM Background handler error: $e');
  }
}

/// Dedicated NotificationService for managing system notification channels,
/// displaying Android notifications, FCM Cloud Messaging, and handling tap routing.
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  static const MethodChannel _platformChannel = MethodChannel(
    'com.bnxmail.app/notifications',
  );

  bool _isInitialized = false;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  /// Initializes Android notification functionality, channel configuration,
  /// and sets up Firebase Cloud Messaging (FCM) push notification listeners.
  Future<void> initialize([WidgetRef? ref]) async {
    if (_isInitialized) return;
    try {
      print('[NOTIFICATION] Service initializing...');
      await _platformChannel.invokeMethod('createNotificationChannel');

      // Initialize Firebase App if needed
      try {
        await Firebase.initializeApp();
        print('[NOTIFICATION] Firebase Core initialized successfully');

        // Configure FCM
        final messaging = FirebaseMessaging.instance;

        // Request notification permission on Android 13+ / iOS
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        print(
          '[NOTIFICATION] FCM Permission status: ${settings.authorizationStatus}',
        );

        // Register background handler
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );

        // Fetch & Log Device FCM Token for Backend Targeting
        _fcmToken = await messaging.getToken();
        print(
          '================================================================',
        );
        print('[FCM TOKEN] YOUR DEVICE FCM TOKEN:');
        print('$_fcmToken');
        print(
          '================================================================',
        );

        if (_fcmToken != null && _fcmToken!.isNotEmpty) {
          final hasToken = await TokenService.hasToken();
          if (hasToken) {
            UserRepository.registerDeviceToken(_fcmToken!).catchError((_) {});
          }
        }

        // Listen to token refreshes
        messaging.onTokenRefresh.listen((newToken) async {
          _fcmToken = newToken;
          print('[NOTIFICATION] FCM Token refreshed: $_fcmToken');
          final hasToken = await TokenService.hasToken();
          if (hasToken) {
            UserRepository.registerDeviceToken(newToken).catchError((_) {});
          }
        });

        // 1. Foreground Message Listener
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          print(
            '[NOTIFICATION] FCM Foreground message received: ${message.messageId}',
          );
          final event = _parseRemoteMessage(message);
          showNotification(event);
        });

        // 2. Notification Tap Listener (App in background)
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          print('[NOTIFICATION] FCM Notification opened from background');
          final event = _parseRemoteMessage(message);
          if (ref != null) {
            handleNotificationTap(event, ref);
          }
        });

        // 3. Notification Tap Listener (App was terminated)
        final initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null) {
          print('[NOTIFICATION] FCM App launched from terminated notification');
          final event = _parseRemoteMessage(initialMessage);
          if (ref != null) {
            handleNotificationTap(event, ref);
          }
        }
      } catch (fcmError) {
        print('[NOTIFICATION] Firebase FCM setup notice: $fcmError');
      }

      _isInitialized = true;
      print('[NOTIFICATION] Service initialized completely');
      print('[NOTIFICATION] Channel configured: bnx_mail_new_email (BNX Mail)');
    } catch (e) {
      print('[NOTIFICATION] Initialization status (handled gracefully): $e');
      _isInitialized = true;
    }
  }

  /// Parses a Firebase RemoteMessage into our internal NotificationEvent model
  NotificationEvent _parseRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final notification = message.notification;

    return NotificationEvent(
      type: data['type'] ?? 'new_email',
      notificationId: message.messageId ?? data['notificationId'],
      accountEmail: data['accountEmail'] ?? data['account_email'],
      accountId: data['accountId'] ?? data['account_id'],
      emailId: data['emailId'] ?? data['email_id'],
      uid: data['uid'],
      messageId: message.messageId ?? data['messageId'],
      senderName: data['senderName'] ?? notification?.title,
      senderEmail: data['senderEmail'] ?? data['from'],
      subject: data['subject'] ?? notification?.title ?? 'New email',
      preview:
          data['preview'] ??
          notification?.body ??
          'You have received a new email.',
      timestamp: message.sentTime ?? DateTime.now(),
    );
  }

  /// Displays a real Android system notification for the given NotificationEvent.
  Future<void> showNotification(NotificationEvent event) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      print('[NOTIFICATION] Incoming event received');
      print('[NOTIFICATION] Event type: ${event.type ?? "new_email"}');
      print(
        '[NOTIFICATION] Account: ${event.effectiveAccountIdentifier ?? "active"}',
      );
      print('[NOTIFICATION] Email ID: ${event.effectiveEmailId ?? "N/A"}');

      final title = event.formattedSender;
      final subject = event.formattedSubject;
      final preview = event.formattedPreview;
      final notifId = event.deterministicNotificationId;

      try {
        await _platformChannel.invokeMethod('showNotification', {
          'id': notifId,
          'title': title,
          'subject': subject,
          'preview': preview,
          'emailId': event.effectiveEmailId ?? '',
          'accountEmail': event.effectiveAccountIdentifier ?? '',
        });
        print('[NOTIFICATION] Notification displayed (ID: $notifId)');
      } on PlatformException catch (e) {
        print('[NOTIFICATION] Platform channel log: $e');
        print('[NOTIFICATION] Notification event processed: $title - $subject');
      }
    } catch (e) {
      print('[NOTIFICATION] Failed to display notification: $e');
    }
  }

  /// Handles notification tap and forwards the event to the notification router.
  Future<void> handleNotificationTap(
    NotificationEvent event,
    WidgetRef ref,
  ) async {
    print('[NOTIFICATION] Notification tapped');
    await NotificationRouter.routeNotification(event, ref);
  }

  /// Receives an incoming notification event (from future API or test trigger) and processes it.
  Future<void> handleIncomingEvent(
    NotificationEvent event,
    WidgetRef ref,
  ) async {
    await showNotification(event);
  }
}

/// Provider for accessing NotificationService
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});
