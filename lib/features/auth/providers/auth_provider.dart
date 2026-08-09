import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/app_models.dart';
import '../../../core/network/api_client.dart';
import '../data/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthRepository? repository})
      : _repository = repository ?? AuthRepository();

  static const _tokenKey = 'tmk_auth_token';
  static const _itsKey = 'tmk_its_id';
  static const _nameKey = 'tmk_user_name';
  static const _canScanKey = 'tmk_can_scan';
  static const _izanLabelKey = 'tmk_izan_label';
  static const _izanHeadingKey = 'tmk_izan_heading';

  final AuthRepository _repository;

  bool isBootstrapping = true;
  bool isLoading = false;
  String? token;
  String? itsId;
  String? userName;
  String? errorMessage;
  bool isDesignPreview = false;
  bool canScan = false;
  String izanLabel = 'Izan';
  String izanHeading = 'Registration for Jaman Izan';

  bool get isAuthenticated =>
      token != null &&
      token!.isNotEmpty &&
      (isDesignPreview || (itsId != null && itsId!.isNotEmpty));

  Future<void> bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString(_tokenKey);
      itsId = prefs.getString(_itsKey);
      userName = prefs.getString(_nameKey);
      canScan = prefs.getBool(_canScanKey) ?? false;
      final savedIzan = prefs.getString(_izanLabelKey)?.trim();
      final savedHeading = prefs.getString(_izanHeadingKey)?.trim();
      if (savedIzan != null && savedIzan.isNotEmpty) {
        izanLabel = savedIzan;
      }
      if (savedHeading != null && savedHeading.isNotEmpty) {
        izanHeading = savedHeading;
      }
      isDesignPreview = token == 'design-preview';
      if (isDesignPreview) {
        canScan = true;
      }

      if (token != null &&
          token!.isNotEmpty &&
          !isDesignPreview &&
          (itsId == null || itsId!.isEmpty)) {
        try {
          final session = await _repository.verifyToken(token!);
          itsId = session.itsId;
          userName = session.user?.itsName;
          await _persistProfile();
        } catch (_) {
          await logout();
        }
      }
    } finally {
      isBootstrapping = false;
      notifyListeners();
    }
  }

  /// Opens ITS OneLogin (same as TMK website login).
  /// Pass [openInAppBrowser] on mobile to keep login inside the app WebView.
  Future<bool> loginWithIts({
    Future<String?> Function(String loginUrl)? openInAppBrowser,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final session = await _repository.loginWithItsOneLogin(
        openInAppBrowser: openInAppBrowser,
      );
      token = session.token;
      itsId = session.itsId;
      userName = session.user?.itsName;
      isDesignPreview = false;
      await _persistProfile();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      return false;
    } catch (e) {
      final message = e.toString();
      if (message.contains('CANCELED') ||
          message.contains('cancelled') ||
          message.contains('CanceledError')) {
        errorMessage = 'ITS login was cancelled.';
      } else {
        errorMessage =
            'Unable to complete ITS login. ${kDebugMode ? e.toString() : 'Check network and try again.'}';
      }
      if (kDebugMode) {
        debugPrint('ITS OneLogin error: $e');
      }
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    token = null;
    itsId = null;
    userName = null;
    canScan = false;
    izanLabel = 'Izan';
    izanHeading = 'Registration for Jaman Izan';
    isDesignPreview = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_itsKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_canScanKey);
    await prefs.remove(_izanLabelKey);
    await prefs.remove(_izanHeadingKey);
    notifyListeners();
  }

  Future<void> enterDesignPreview() async {
    token = 'design-preview';
    itsId = '40405506';
    userName = 'Design Preview';
    canScan = true;
    isDesignPreview = true;
    await _persistProfile();
    notifyListeners();
  }

  void updateFromHome(HomeDetails home) {
    if (home.user.ejamaatId.isNotEmpty) {
      itsId = home.user.ejamaatId;
    }
    if (home.user.itsName.isNotEmpty) {
      userName = home.user.itsName;
    }
    canScan = home.canScan;
    if (home.izanLabel.trim().isNotEmpty) {
      izanLabel = home.izanLabel.trim();
    }
    if (home.izanHeading.trim().isNotEmpty) {
      izanHeading = home.izanHeading.trim();
    }
    _persistProfile();
    notifyListeners();
  }

  void setCanScan(bool value) {
    canScan = value;
    _persistProfile();
    notifyListeners();
  }

  Future<void> _persistProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (token != null) await prefs.setString(_tokenKey, token!);
    if (itsId != null) await prefs.setString(_itsKey, itsId!);
    if (userName != null) await prefs.setString(_nameKey, userName!);
    await prefs.setBool(_canScanKey, canScan);
    await prefs.setString(_izanLabelKey, izanLabel);
    await prefs.setString(_izanHeadingKey, izanHeading);
  }
}
