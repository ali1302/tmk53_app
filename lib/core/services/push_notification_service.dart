import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../features/notifications/data/notification_token_repository.dart';
import '../../firebase_options.dart';
import '../../main.dart';
import '../config/app_config.dart';
import 'push_navigation_controller.dart';

/// Background isolate entry — handles FCM messages when app is terminated/backgrounded.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    debugPrint('[Push] Background message received: ${message.messageId}, data: ${message.data}');

    // Read stored ITS ID and ensure token is synced with API even from background isolate
    final prefs = await SharedPreferences.getInstance();
    final itsId = (prefs.getString('tmk_its_id') ??
            prefs.getString('tmk_push_registered_its') ??
            '')
        .trim();
    if (itsId.isNotEmpty && itsId != 'design-preview') {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        final savedToken = prefs.getString('tmk_push_registered_token');
        if (savedToken != token) {
          final repo = NotificationTokenRepository();
          await repo.register(itsId: itsId, token: token);
          await prefs.setString('tmk_push_registered_token', token);
          await prefs.setString('tmk_push_registered_its', itsId);
          debugPrint('[Push] Background handler updated token in API for ITS $itsId');
        }
      }
    }
  } catch (e) {
    debugPrint('[Push] Background handler error: $e');
  }
}

Future<bool> _initFirebaseSafely() async {
  try {
    if (Firebase.apps.isNotEmpty) return true;
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return true;
  } catch (e) {
    if (kDebugMode) {
      debugPrint(
        '[Push] Firebase init skipped ($e). '
        'Verify lib/firebase_options.dart and native config files.',
      );
    }
    return false;
  }
}

/// Push registration for Android/iOS (FCM). Desktop/Windows skips Messaging.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const _deviceIdKey = 'tmk_push_device_id';
  static const _savedTokenKey = 'tmk_push_registered_token';
  static const _savedItsKey = 'tmk_push_registered_its';

  final NotificationTokenRepository _tokenRepo = NotificationTokenRepository();

  Completer<bool>? _initCompleter;
  bool _firebaseReady = false;
  String? _lastRegisteredToken;
  String? _pendingItsId;

  bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Initializes Firebase and FCM listeners in an async-safe manner.
  Future<bool> initialize() async {
    if (!isSupported) return false;
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    final completer = Completer<bool>();
    _initCompleter = completer;

    try {
      _firebaseReady = await _initFirebaseSafely();
      if (!_firebaseReady) {
        debugPrint('[Push] Firebase is not initialized. Skipping Messaging setup.');
        completer.complete(false);
        return false;
      }

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await ensureNotificationPermissions();
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen((message) {
        debugPrint(
          '[Push] Foreground message: ${message.messageId}, '
          'title: ${message.notification?.title}, '
          'body: ${message.notification?.body}, '
          'data: ${message.data}',
        );

        final title = message.notification?.title ?? message.data['title']?.toString();
        final body = message.notification?.body ?? message.data['body']?.toString();

        if (title != null && title.isNotEmpty) {
          rootScaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF3D1035),
              duration: const Duration(seconds: 6),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  if (body != null && body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
              action: SnackBarAction(
                label: 'VIEW',
                textColor: const Color(0xFFD4AF37),
                onPressed: () {
                  PushNavigationController.instance.requestOpenBroadcast();
                },
              ),
            ),
          );
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _handleNotificationOpen(initial);
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        debugPrint('\n=================== REFRESHED FCM TOKEN ===================');
        debugPrint(token);
        debugPrint('===========================================================\n');
        final its = _pendingItsId;
        if (its == null || its.isEmpty) return;
        await _registerResolvedToken(itsId: its, deviceToken: token);
      });

      // Fetch and log initial FCM token
      final token = await _fetchFcmTokenWithRetry();
      if (token != null && token.isNotEmpty) {
        debugPrint('\n=================== FCM TOKEN ===================');
        debugPrint(token);
        debugPrint('=================================================\n');
      } else {
        debugPrint('[Push] Could not retrieve FCM token on startup.');
      }

      if (_pendingItsId != null && _pendingItsId!.isNotEmpty) {
        await syncToken(itsId: _pendingItsId!);
      }

      debugPrint('[Push] Service initialization complete');
      completer.complete(true);
      return true;
    } catch (e) {
      debugPrint('[Push] Error initializing PushNotificationService: $e');
      completer.complete(false);
      return false;
    }
  }

  Future<void> ensureNotificationPermissions({bool force = false}) async {
    if (!isSupported) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();
      if (force ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined ||
          settings.authorizationStatus == AuthorizationStatus.denied) {
        final newSettings = await messaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
        debugPrint(
          '[Push] Notification authorization status: ${newSettings.authorizationStatus}',
        );
      }
    } catch (e) {
      debugPrint('[Push] Error requesting notification permissions: $e');
    }
  }

  void _handleNotificationOpen(RemoteMessage message) {
    debugPrint('[Push] Opened from notification data: ${message.data}');
    PushNavigationController.instance.requestOpenBroadcast();
  }

  Future<void> syncToken({required String itsId}) async {
    final cleaned = itsId.trim();
    if (cleaned.isEmpty || cleaned == 'design-preview') return;
    _pendingItsId = cleaned;

    final ready = await initialize();
    if (!ready || !isSupported) {
      debugPrint('[Push] Cannot sync token: Firebase not ready or platform unsupported.');
      return;
    }

    final deviceToken = await _fetchFcmTokenWithRetry();
    if (deviceToken == null || deviceToken.isEmpty) {
      debugPrint('[Push] FCM token is null or empty.');
      return;
    }
    debugPrint('[Push] FCM Token: $deviceToken');
    await _registerResolvedToken(itsId: cleaned, deviceToken: deviceToken);
  }

  Future<String?> _fetchFcmTokenWithRetry({int maxAttempts = 8}) async {
    final messaging = FirebaseMessaging.instance;

    // iOS: FCM token is invalid until APNs has registered. Simulator never gets APNs.
    if (!kIsWeb && Platform.isIOS) {
      String? apns;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        apns = await messaging.getAPNSToken();
        if (apns != null && apns.isNotEmpty) {
          debugPrint('[Push] APNs token ready');
          break;
        }
        debugPrint('[Push] Waiting for APNs token (attempt $attempt/$maxAttempts)');
        await Future<void>.delayed(Duration(seconds: attempt));
      }
      if (apns == null || apns.isEmpty) {
        debugPrint(
          '[Push] No APNs token. Use a physical iOS device, '
          'enable Push Notifications capability, and upload an APNs key in Firebase Console.',
        );
        return null;
      }
    }

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await messaging.getToken();
      } on FirebaseException catch (e) {
        final message = (e.message ?? '').toLowerCase();
        final isServiceUnavailable = message.contains('service_not_available') ||
            message.contains('apns-token-not-set');
        if (!isServiceUnavailable || attempt == maxAttempts) {
          debugPrint('[Push] FirebaseException getting FCM token: ${e.code} - ${e.message}');
          return null;
        }
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      } catch (e) {
        debugPrint('[Push] Error getting FCM token: $e');
        return null;
      }
    }
    return null;
  }

  Future<void> _registerResolvedToken({
    required String itsId,
    required String deviceToken,
  }) async {
    final pushToken = await _resolveExpoPushToken(deviceToken) ?? deviceToken;

    // Check in-memory and persistent cache to avoid duplicate network calls
    if (pushToken == _lastRegisteredToken) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_savedTokenKey);
      final savedIts = prefs.getString(_savedItsKey);
      if (savedToken == pushToken && savedIts == itsId) {
        _lastRegisteredToken = pushToken;
        debugPrint('[Push] Token already registered for ITS $itsId');
        return;
      }

      await _tokenRepo.register(itsId: itsId, token: pushToken);
      _lastRegisteredToken = pushToken;
      await prefs.setString(_savedTokenKey, pushToken);
      await prefs.setString(_savedItsKey, itsId);

      debugPrint(
        '[Push] Successfully registered token for ITS $itsId '
        '(${pushToken.startsWith('ExponentPushToken') ? 'Expo' : 'FCM'})',
      );
    } catch (e) {
      debugPrint('[Push] Token register failed: $e');
    }
  }

  Future<String?> _resolveExpoPushToken(String deviceToken) async {
    final projectId = AppConfig.expoProjectId.trim();
    if (projectId.isEmpty) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      var deviceId = prefs.getString(_deviceIdKey);
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = const Uuid().v4();
        await prefs.setString(_deviceIdKey, deviceId);
      }

      final response = await http.post(
        Uri.parse('https://exp.host/--/api/v2/push/getExpoPushToken'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'deviceId': deviceId,
          'appId': Platform.isIOS
              ? AppConfig.iosBundleId
              : AppConfig.androidApplicationId,
          'deviceToken': deviceToken,
          'type': 'fcm',
          'development': kDebugMode && Platform.isIOS,
          'projectId': projectId,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '[Push] Expo exchange HTTP ${response.statusCode}: ${response.body}',
        );
        return null;
      }

      final decoded = jsonDecode(response.body);
      final data = decoded is Map ? decoded['data'] : null;
      final expoToken = data is Map ? data['expoPushToken']?.toString() : null;
      if (expoToken != null && expoToken.startsWith('ExponentPushToken')) {
        return expoToken;
      }
    } catch (e) {
      debugPrint('[Push] Expo token exchange failed: $e');
    }
    return null;
  }
}
