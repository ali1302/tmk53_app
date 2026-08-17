import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/home_provider.dart';

/// Opens the ITS52 portal.
///
/// ITS OneLogin (`?OneLogin=KHAITAAN`) only returns a partner token to TMK — it
/// does **not** create an ITS52 website session. So we open the normal portal
/// login, pre-fill the ITS ID from the app session, enable Remember Me, and keep
/// cookies in a persistent WebView profile for the next visit.
class Its52Browser {
  Its52Browser._();

  static const _profileFolderName = 'tmk_its52_webview';

  static Future<void> open(BuildContext context) async {
    final itsId = _resolveItsId(context);

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Its52WebViewScreen(itsId: itsId),
        ),
      );
      return;
    }

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      final ok = await _openDesktopWebView(itsId: itsId);
      if (ok) return;
    }

    await launchUrl(
      Uri.parse(AppConfig.its52Url),
      mode: LaunchMode.externalApplication,
    );
  }

  static String _resolveItsId(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final home = context.read<HomeProvider>().details;
    final fromHome = home?.user.ejamaatId.trim() ?? '';
    if (fromHome.isNotEmpty) return fromHome;
    return auth.itsId?.trim() ?? '';
  }

  static Future<String> _persistentProfilePath() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}${Platform.pathSeparator}$_profileFolderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  static Future<bool> _openDesktopWebView({required String itsId}) async {
    try {
      if (!await WebviewWindow.isWebviewAvailable()) return false;

      final webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          windowWidth: 1280,
          windowHeight: 800,
          title: 'ITS52',
          titleBarTopPadding: Platform.isMacOS ? 24 : 0,
          userDataFolderWindows: await _persistentProfilePath(),
          openMaximized: true,
        ),
      );

      webview.addOnUrlRequestCallback((url) {
        if (_isItsLoginPage(url) && itsId.isNotEmpty) {
          // Fill after the login DOM is ready.
          Future<void>.delayed(const Duration(milliseconds: 700), () async {
            try {
              await webview.evaluateJavaScript(_prefillLoginJs(itsId));
            } catch (_) {}
          });
        }
      });

      // Open login directly so we can prefill; if already cookied, ITS redirects home.
      webview.launch(
        itsId.isEmpty ? AppConfig.its52Url : AppConfig.its52LoginUrl,
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ITS52 desktop webview failed: $e');
      }
      return false;
    }
  }
}

bool _isItsLoginPage(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  if (!host.contains('its52.com')) return false;
  final path = uri.path.toLowerCase();
  return path.contains('login.aspx') || path == '/' || path.isEmpty;
}

String _prefillLoginJs(String itsId) {
  final escaped = itsId
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', '')
      .replaceAll('\r', '');
  return """
(function() {
  var u = document.querySelector('input[name="txtUserName"]');
  if (!u) return;
  if (!u.value) {
    u.value = '$escaped';
    u.dispatchEvent(new Event('input', { bubbles: true }));
    u.dispatchEvent(new Event('change', { bubbles: true }));
  }
  var r = document.querySelector('input[name="chkRememberMe"]');
  if (r) {
    r.checked = true;
    r.dispatchEvent(new Event('change', { bubbles: true }));
  }
  var p = document.querySelector('input[name="txtPassword"]');
  if (p) { try { p.focus(); } catch (e) {} }
})();
""";
}

class Its52WebViewScreen extends StatefulWidget {
  const Its52WebViewScreen({super.key, this.itsId = ''});

  final String itsId;

  @override
  State<Its52WebViewScreen> createState() => _Its52WebViewScreenState();
}

class _Its52WebViewScreenState extends State<Its52WebViewScreen> {
  WebViewController? _controller;
  var _loading = true;
  var _onLoginPage = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _status = null;
            });
          },
          onPageFinished: (url) async {
            if (!mounted) return;
            final login = _isItsLoginPage(url);
            setState(() {
              _loading = false;
              _onLoginPage = login;
            });
            if (login && widget.itsId.isNotEmpty) {
              await _controller?.runJavaScript(_prefillLoginJs(widget.itsId));
            }
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            setState(() => _status = 'Page error: ${error.description}');
          },
        ),
      );

    _enableAndroidCookies().then((_) {
      final start = widget.itsId.isEmpty
          ? AppConfig.its52Url
          : AppConfig.its52LoginUrl;
      _controller?.loadRequest(Uri.parse(start));
    });
  }

  Future<void> _enableAndroidCookies() async {
    final controller = _controller;
    if (controller == null) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      await platform.setMediaPlaybackRequiresUserGesture(false);
      final cookieManager = WebViewCookieManager();
      final androidManager = cookieManager.platform;
      if (androidManager is AndroidWebViewCookieManager) {
        await androidManager.setAcceptThirdPartyCookies(platform, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.accent,
        title: const Text('ITS52'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Open in browser',
            icon: const Icon(Icons.open_in_new, size: 20),
            onPressed: () => launchUrl(
              Uri.parse(AppConfig.its52Url),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      body: controller == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                WebViewWidget(controller: controller),
                if (_loading)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.accent,
                    backgroundColor: Color(0xFFF5EFD8),
                  ),
                if (_onLoginPage)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 16,
                    child: Material(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          widget.itsId.isEmpty
                              ? 'Sign in with your ITS ID and password. Tick Remember Me to stay signed in.'
                              : 'ITS ID ${widget.itsId} is filled. Enter your ITS password once (Remember Me is on).',
                          style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.35),
                        ),
                      ),
                    ),
                  ),
                if (_status != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: _onLoginPage ? 72 : 16,
                    child: Material(
                      color: const Color(0xFF7F1D1D),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          _status!,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
