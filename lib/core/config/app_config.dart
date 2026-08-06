import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  static const String appName = 'TMK Kuwait';

  /// Local PHP server (router.php on port 7070).
  /// Android emulator: use 10.0.2.2 instead of localhost.
  /// Physical device: use your PC LAN IP.
  static const String localBaseUrl = 'http://localhost:7070';

  /// Live site.
  static const String productionBaseUrl = 'https://tmk53.com';

  /// Flip to true when testing against local PHP.
  static const bool useLocalApi = false;

  /// Native deep-link fallback (used by HTML bridge page).
  static const String authCallbackScheme = 'tmkkuwait';

  static const String authCallbackHost = 'auth';

  static String get baseUrl => useLocalApi ? localBaseUrl : productionBaseUrl;

  static String get apiBaseUrl => '$baseUrl/api/v1';

  static String get legacyApiBaseUrl => '$baseUrl/apis';

  /// Separate Asbaq (Halka) module API — scan events live here.
  static String get asbaqApiBaseUrl => '$baseUrl/asbaq/api/v1';

  static String get websiteUrl => baseUrl;

  /// Where ITS should return after login.
  /// - Chrome/Web: same-origin `/auth.html` (required by flutter_web_auth_2)
  /// - Desktop/Mobile: HTTPS bridge on TMK that the WebView can capture
  static String get authCallbackUrl {
    if (kIsWeb) {
      return '${Uri.base.origin}/auth.html';
    }
    return '$legacyApiBaseUrl/app_auth_done';
  }

  /// Native scheme fallback shown on the HTTPS bridge page.
  static String get nativeAuthCallbackUrl => '$authCallbackScheme://$authCallbackHost';

  /// Starts TMK mobile session then redirects to ITS OneLogin (KHAITAAN).
  static String get itsOneLoginUrl =>
      '$legacyApiBaseUrl/login?redirect_url=${Uri.encodeComponent(authCallbackUrl)}';
}
