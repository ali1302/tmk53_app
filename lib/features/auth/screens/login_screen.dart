import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/login_atmosphere_background.dart';
import 'its_login_webview_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enterController;
  late final AnimationController _pulseController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;
  late final Animation<double> _floatY;
  late final Animation<double> _glow;

  /// webview_flutter only ships Android/iOS implementations.
  bool get _supportsInAppWebView {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fadeIn = CurvedAnimation(
      parent: _enterController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _scaleIn = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _floatY = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _glow = Tween<double>(begin: 0.22, end: 0.55).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _enterController.forward().whenComplete(() {
      if (mounted) {
        _pulseController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _enterController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loginWithIts(BuildContext context) async {
    final auth = context.read<AuthProvider>();

    // Quick health check so users don't land on a raw PHP DB error page.
    try {
      final probe = await http
          .get(Uri.parse(AppConfig.itsOneLoginUrl))
          .timeout(const Duration(seconds: 8));
      final body = probe.body.toLowerCase();
      if (probe.statusCode >= 500 ||
          body.contains('database error') ||
          body.contains('unable to connect to your database')) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Login server database is down. Please upload the fixed database.php to Hostinger.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }
    } catch (_) {
      // Continue — network probe is best-effort only.
    }

    Future<String?> Function(String loginUrl)? openInApp;
    if (_supportsInAppWebView) {
      openInApp = (loginUrl) {
        return Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => ItsLoginWebViewScreen(loginUrl: loginUrl),
          ),
        );
      };
    }

    final ok = await auth.loginWithIts(openInAppBrowser: openInApp);
    if (!context.mounted) return;
    if (!ok && auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const LoginAtmosphereBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final logoSize = constraints.maxHeight < 560 ? 140.0 : 180.0;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    16 + bottomInset * 0.15,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 8,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            const SizedBox(height: 8),
                            ClipRect(
                              child: AnimatedBuilder(
                                animation: Listenable.merge(
                                    [_enterController, _pulseController]),
                                builder: (context, child) {
                                  return Opacity(
                                    opacity: _fadeIn.value.clamp(0.0, 1.0),
                                    child: Transform.translate(
                                      offset: Offset(0, _floatY.value),
                                      child: Transform.scale(
                                        scale: _scaleIn.value,
                                        child: child,
                                      ),
                                    ),
                                  );
                                },
                                child: SizedBox(
                                  width: logoSize,
                                  height: logoSize,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      AnimatedBuilder(
                                        animation: _glow,
                                        builder: (context, _) {
                                          return Container(
                                            width: logoSize * 0.82,
                                            height: logoSize * 0.82,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.accent
                                                      .withValues(
                                                          alpha: _glow.value),
                                                  blurRadius: 36,
                                                  spreadRadius: 4,
                                                ),
                                                BoxShadow(
                                                  color: Colors.white
                                                      .withValues(
                                                          alpha:
                                                              _glow.value *
                                                                  0.25),
                                                  blurRadius: 14,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                      Image.asset(
                                        'assets/images/app_icon.png',
                                        width: logoSize * 0.88,
                                        height: logoSize * 0.88,
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.high,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            FadeTransition(
                              opacity: _fadeIn,
                              child: Text(
                                'Taheri Mohalla Jamaat',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color:
                                      Colors.white.withValues(alpha: 0.78),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: auth.isLoading
                                  ? null
                                  : () => _loginWithIts(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    const Color(0xFF2E7D32)
                                        .withValues(alpha: 0.7),
                                minimumSize: const Size.fromHeight(54),
                                elevation: 4,
                                shadowColor: Colors.black45,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: auth.isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Login',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
