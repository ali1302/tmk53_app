import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';

/// In-app ITS OneLogin browser. Captures `app_auth_done?token=` without leaving the app.
class ItsLoginWebViewScreen extends StatefulWidget {
  const ItsLoginWebViewScreen({super.key, required this.loginUrl});

  final String loginUrl;

  @override
  State<ItsLoginWebViewScreen> createState() => _ItsLoginWebViewScreenState();
}

class _ItsLoginWebViewScreenState extends State<ItsLoginWebViewScreen> {
  WebViewController? _controller;
  var _loading = true;
  var _completed = false;
  String? _status;
  var _unsupported = false;

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    if (!_isSupportedPlatform) {
      _unsupported = true;
      _loading = false;
      _status = 'In-app login is not supported on this platform. Use browser login instead.';
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _status = null;
            });
            _maybeComplete(url);
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() => _loading = false);
            _maybeComplete(url);
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url != null) {
              _maybeComplete(url);
            }
          },
          onNavigationRequest: (request) {
            if (_isAuthCallback(request.url)) {
              _maybeComplete(request.url);
              return NavigationDecision.prevent;
            }
            // Block leaving to custom scheme after we already captured HTTPS callback.
            if (request.url.startsWith('${AppConfig.authCallbackScheme}:')) {
              _maybeComplete(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            if (kDebugMode) {
              debugPrint('ITS WebView error: ${error.description}');
            }
            if (!mounted) return;
            setState(() {
              _status = 'Page error: ${error.description}';
            });
          },
        ),
      );

    _enableAndroidCookies().then((_) {
      _controller?.loadRequest(Uri.parse(widget.loginUrl));
    });
  }

  Future<void> _enableAndroidCookies() async {
    final controller = _controller;
    if (controller == null) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(kDebugMode);
      await platform.setMediaPlaybackRequiresUserGesture(false);
      final cookieManager = WebViewCookieManager();
      final androidManager = cookieManager.platform;
      if (androidManager is AndroidWebViewCookieManager) {
        await androidManager.setAcceptThirdPartyCookies(platform, true);
      }
    }
  }

  bool _isAuthCallback(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    if (uri.scheme == AppConfig.authCallbackScheme) {
      return true;
    }

    final path = uri.path.toLowerCase();
    final isDonePage = path.contains('app_auth_done') || path.endsWith('/auth.html');
    final hasToken = (uri.queryParameters['token']?.isNotEmpty ?? false) ||
        uri.fragment.contains('token=');
    return isDonePage && hasToken;
  }

  void _maybeComplete(String url) {
    if (_completed) return;
    if (!_isAuthCallback(url)) return;

    final token = _extractToken(url);
    if (token == null || token.isEmpty) {
      // Custom-scheme link without parseable token — ignore and wait for HTTPS URL.
      if (url.startsWith('${AppConfig.authCallbackScheme}:')) {
        return;
      }
      return;
    }

    _completed = true;
    if (!mounted) return;
    Navigator.of(context).pop(url);
  }

  String? _extractToken(String resultUrl) {
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

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.accent,
        title: const Text('ITS Login'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _unsupported || controller == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _status ?? 'In-app login is not available on this platform.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
                ),
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: controller),
                if (_loading)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.accent,
                    backgroundColor: Color(0xFFF5EFD8),
                  ),
                if (_status != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 16,
                    child: Material(
                      color: AppColors.primary,
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
