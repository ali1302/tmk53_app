import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../features/notifications/data/notification_token_repository.dart';
import '../../firebase_options.dart';
import '../config/app_config.dart';
import 'push_navigation_controller.dart';

/// Background isolate entry — mirrors TMK FMB pattern.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await _initFirebaseSafely();
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
        'Create a new Firebase project, add Android/iOS apps, then fill '
        'lib/firebase_options.dart and native config files.',
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

  final NotificationTokenRepository _tokenRepo = NotificationTokenRepository();

  bool _initialized = false;
  bool _firebaseReady = false;
  String? _lastRegisteredToken;
  String? _pendingItsId;

  bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> initialize() async {
    if (_initialized || !isSupported) return;
    _initialized = true;

    _firebaseReady = await _initFirebaseSafely();
    if (!_firebaseReady) {
      debugPrint('[Push] Firebase is not initialized. Skipping Messaging setup.');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await ensureNotificationPermissions();
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[Push] Foreground message: ${message.messageId}');
    });
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleNotificationOpen(initial);

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      final its = _pendingItsId;
      if (its == null || its.isEmpty) return;
      await _registerResolvedToken(itsId: its, deviceToken: token);
    });

    if (_pendingItsId != null && _pendingItsId!.isNotEmpty) {
      await syncToken(itsId: _pendingItsId!);
    }
    debugPrint('[Push] Service initialization complete');
  }

  Future<void> ensureNotificationPermissions({bool force = false}) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();
      if (force ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (_) {}
  }

  void _handleNotificationOpen(RemoteMessage message) {
    PushNavigationController.instance.requestOpenBroadcast();
    if (kDebugMode) {
      debugPrint('[Push] opened from notification data=${message.data}');
    }
  }

  Future<void> syncToken({required String itsId}) async {
    final cleaned = itsId.trim();
    if (cleaned.isEmpty || cleaned == 'design-preview') return;
    _pendingItsId = cleaned;

    if (!_initialized) await initialize();
    if (!_firebaseReady || !isSupported) return;

    await ensureNotificationPermissions();

    final deviceToken = await _fetchFcmTokenWithRetry();
    if (deviceToken == null || deviceToken.isEmpty) {
      debugPrint('[Push] FCM token is null or empty.');
      return;
    }
    debugPrint('[Push] FCM Token: $deviceToken');
    await _registerResolvedToken(itsId: cleaned, deviceToken: deviceToken);
  }

  Future<String?> _fetchFcmTokenWithRetry({int maxAttempts = 3}) async {
    final messaging = FirebaseMessaging.instance;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await messaging.getToken();
      } on FirebaseException catch (e) {
        final message = (e.message ?? '').toLowerCase();
        final isServiceUnavailable = message.contains('service_not_available');
        if (!isServiceUnavailable || attempt == maxAttempts) return null;
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      } catch (_) {
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
    if (pushToken == _lastRegisteredToken) return;

    try {
      await _tokenRepo.register(itsId: itsId, token: pushToken);
      _lastRegisteredToken = pushToken;
      debugPrint(
        '[Push] registered for ITS $itsId '
        '(${pushToken.startsWith('ExponentPushToken') ? 'Expo' : 'FCM'})',
      );
    } catch (e) {
      debugPrint('[Push] token register failed: $e');
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
