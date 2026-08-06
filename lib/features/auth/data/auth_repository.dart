import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/app_models.dart';
import '../../../core/network/api_client.dart';

class AuthSession {
  const AuthSession({
    required this.token,
    required this.itsId,
    this.user,
    this.authType = 'member',
  });

  final String token;
  final String itsId;
  final JamaatUser? user;
  final String authType;
}

class AuthRepository {
  AuthRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  /// ITS OneLogin → TMK issues token → returns into the Flutter app.
  ///
  /// On mobile, pass [openInAppBrowser] so login stays inside a WebView.
  /// On web/desktop without a browser opener, falls back to flutter_web_auth_2.
  Future<AuthSession> loginWithItsOneLogin({
    Future<String?> Function(String loginUrl)? openInAppBrowser,
  }) async {
    final String resultUrl;

    if (openInAppBrowser != null) {
      final captured = await openInAppBrowser(AppConfig.itsOneLoginUrl);
      if (captured == null || captured.trim().isEmpty) {
        throw Exception('CANCELED');
      }
      resultUrl = captured;
    } else {
      resultUrl = await _authenticateWithExternalBrowser();
    }

    final token = extractToken(resultUrl);
    if (token == null || token.isEmpty) {
      throw ApiException(
        statusCode: 401,
        message: 'ITS login completed but no token was returned.',
      );
    }

    // Prefer server verify; if Chrome CORS/network blocks it, use ITS from JWT.
    try {
      return await verifyToken(token);
    } catch (e) {
      final itsId = itsIdFromJwt(token);
      if (itsId != null && itsId.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('verifyToken failed ($e); using ITS from JWT: $itsId');
        }
        return AuthSession(token: token, itsId: itsId, authType: 'member');
      }
      rethrow;
    }
  }

  Future<String> _authenticateWithExternalBrowser() async {
    final callbackUri = Uri.parse(AppConfig.authCallbackUrl);

    return FlutterWebAuth2.authenticate(
      url: AppConfig.itsOneLoginUrl,
      callbackUrlScheme: kIsWeb
          ? callbackUri.scheme
          : (callbackUri.hasScheme ? callbackUri.scheme : AppConfig.authCallbackScheme),
      options: FlutterWebAuth2Options(
        preferEphemeral: false,
        httpsHost: callbackUri.host.isEmpty ? null : callbackUri.host,
        httpsPath: callbackUri.path.isEmpty ? null : callbackUri.path,
        useWebview: !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.linux),
      ),
    );
  }

  static String? extractToken(String resultUrl) {
    final callback = Uri.tryParse(resultUrl);
    if (callback == null) return null;
    final fromQuery = callback.queryParameters['token']?.trim();
    if (fromQuery != null && fromQuery.isNotEmpty) {
      return fromQuery;
    }
    if (callback.fragment.isNotEmpty) {
      final fragment = Uri.splitQueryString(callback.fragment);
      final fromFragment = fragment['token']?.trim();
      if (fromFragment != null && fromFragment.isNotEmpty) {
        return fromFragment;
      }
    }
    return null;
  }

  /// Decode ITS id from TMK OneLogin JWT without a network call.
  static String? itsIdFromJwt(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      return null;
    }
    try {
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final raw = utf8.decode(base64.decode(payload));

      final digits = RegExp(r'(\d{8,})').firstMatch(raw);
      if (digits != null) {
        return digits.group(1);
      }

      final decoded = jsonDecode(raw);
      if (decoded is String && RegExp(r'^\d+$').hasMatch(decoded)) {
        return decoded;
      }
      if (decoded is num) {
        return decoded.toString();
      }
      if (decoded is Map) {
        for (final key in ['ejamaat_id', 'its_id', 'its', 'sub']) {
          final value = decoded[key]?.toString();
          if (value != null && RegExp(r'^\d+$').hasMatch(value)) {
            return value;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Verifies the cookie JWT from OneLogin via legacy `/apis/verifyToken`.
  Future<AuthSession> verifyToken(String token) async {
    try {
      final legacy = await _api.post(
        'verifyToken',
        fields: {'token': token},
        legacy: true,
        style: AuthHeaderStyle.none,
        allowPlainText: true,
      );

      final itsId = legacy.toString().trim();
      if (itsId.isNotEmpty && itsId != 'failed' && RegExp(r'^\d+$').hasMatch(itsId)) {
        return AuthSession(
          token: token,
          itsId: itsId,
          authType: 'member',
        );
      }
    } catch (_) {
      // Fall through to v1 verify.
    }

    final response = await _api.post(
      'Auth/verifyToken',
      fields: {'token': token},
      style: AuthHeaderStyle.none,
    );

    if (response is! Map<String, dynamic>) {
      throw ApiException(statusCode: 401, message: 'Unable to verify ITS login token.');
    }

    var itsId = response['its_id']?.toString() ?? '';
    if (itsId.isEmpty) {
      final data = response['data'];
      if (data is String || data is num) {
        itsId = data.toString();
      }
    }
    if (itsId.isEmpty) {
      itsId = itsIdFromJwt(token) ?? '';
    }

    if (itsId.isEmpty || itsId == 'failed') {
      throw ApiException(statusCode: 401, message: 'ITS token is invalid or expired.');
    }

    final userJson = response['user'] is Map<String, dynamic>
        ? response['user'] as Map<String, dynamic>
        : null;

    return AuthSession(
      token: token,
      itsId: itsId,
      user: JamaatUser.fromJson(userJson),
      authType: 'member',
    );
  }
}
