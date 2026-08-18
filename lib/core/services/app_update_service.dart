import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../models/app_update_info.dart';
import '../network/api_client.dart';
import '../theme/app_theme.dart';

class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  static const _dismissedVersionKey = 'tmk_update_dismissed_version';

  final ApiClient _api = ApiClient();
  bool _dialogVisible = false;

  bool get _isMobileStorePlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  String get _platform => Platform.isIOS ? 'ios' : 'android';

  Future<AppUpdateInfo?> fetchUpdateInfo() async {
    if (!_isMobileStorePlatform) return null;
    try {
      final raw = await _api.get(
        'app_update',
        query: {'platform': _platform},
        legacy: true,
        style: AuthHeaderStyle.none,
      );
      if (raw is! Map) return null;
      final map = raw.map((key, value) => MapEntry('$key', value));
      return AppUpdateInfo.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<AppUpdatePrompt> resolvePrompt({
    required String currentVersion,
    required AppUpdateInfo info,
  }) async {
    if (info.latestVersion.isEmpty && info.minVersion.isEmpty) {
      return AppUpdatePrompt.none;
    }

    if (info.minVersion.isNotEmpty &&
        compareAppVersions(currentVersion, info.minVersion) < 0) {
      return AppUpdatePrompt.required;
    }

    if (info.latestVersion.isEmpty) {
      return AppUpdatePrompt.none;
    }

    if (compareAppVersions(currentVersion, info.latestVersion) >= 0) {
      return AppUpdatePrompt.none;
    }

    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getString(_dismissedVersionKey)?.trim() ?? '';
    if (dismissed == info.latestVersion) {
      return AppUpdatePrompt.none;
    }

    return AppUpdatePrompt.optional;
  }

  Future<void> checkAndPrompt(BuildContext context) async {
    if (!_isMobileStorePlatform || _dialogVisible || !context.mounted) {
      return;
    }

    final info = await fetchUpdateInfo();
    if (info == null || !context.mounted) return;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version.trim();
    if (currentVersion.isEmpty || !context.mounted) return;

    final prompt = await resolvePrompt(
      currentVersion: currentVersion,
      info: info,
    );
    if (prompt == AppUpdatePrompt.none || !context.mounted) return;

    _dialogVisible = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: prompt != AppUpdatePrompt.required,
        builder: (ctx) => _AppUpdateDialog(
          info: info,
          currentVersion: currentVersion,
          latestVersion: info.latestVersion.isNotEmpty
              ? info.latestVersion
              : info.minVersion,
          forceUpdate: prompt == AppUpdatePrompt.required,
          onLater: () async {
            final prefs = await SharedPreferences.getInstance();
            final dismissTarget = info.latestVersion.isNotEmpty
                ? info.latestVersion
                : info.minVersion;
            await prefs.setString(_dismissedVersionKey, dismissTarget);
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
          onUpdate: () => _openStore(info),
        ),
      );
    } finally {
      _dialogVisible = false;
    }
  }

  Future<void> _openStore(AppUpdateInfo info) async {
    var url = info.storeUrl.trim();
    if (url.isEmpty) {
      url = Platform.isIOS ? AppConfig.iosStoreUrl : AppConfig.androidStoreUrl;
    }
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

int compareAppVersions(String a, String b) {
  List<int> parse(String value) {
    final core = value.split('+').first.trim();
    if (core.isEmpty) return const [0, 0, 0];
    return core
        .split('.')
        .map((part) => int.tryParse(part.trim()) ?? 0)
        .toList(growable: true);
  }

  final left = parse(a);
  final right = parse(b);
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final lv = i < left.length ? left[i] : 0;
    final rv = i < right.length ? right[i] : 0;
    if (lv != rv) return lv.compareTo(rv);
  }
  return 0;
}

class _AppUpdateDialog extends StatelessWidget {
  const _AppUpdateDialog({
    required this.info,
    required this.currentVersion,
    required this.latestVersion,
    required this.forceUpdate,
    required this.onLater,
    required this.onUpdate,
  });

  final AppUpdateInfo info;
  final String currentVersion;
  final String latestVersion;
  final bool forceUpdate;
  final Future<void> Function() onLater;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final message = info.updateMessage.isNotEmpty
        ? info.updateMessage
        : 'A new version of ${AppConfig.appName} is available. Please update to continue with the latest features and fixes.';

    return PopScope(
      canPop: !forceUpdate,
      child: AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          forceUpdate ? 'Update required' : 'Update available',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(height: 1.4)),
            const SizedBox(height: 12),
            Text(
              'Installed: v$currentVersion\nLatest: v$latestVersion',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
        actions: [
          if (!forceUpdate)
            TextButton(
              onPressed: () => onLater(),
              child: const Text('Later'),
            ),
          FilledButton(
            onPressed: onUpdate,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
