import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/login_brand_background.dart';
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
  late final AnimationController _shimmerController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;
  late final Animation<double> _floatY;

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
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(
      parent: _enterController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );
    _scaleIn = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: const Interval(0.0, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _floatY = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _enterController.forward().whenComplete(() {
      if (!mounted) return;
      _pulseController.repeat(reverse: true);
      _shimmerController.repeat();
    });
  }

  @override
  void dispose() {
    _enterController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loginWithIts(BuildContext context) async {
    final auth = context.read<AuthProvider>();

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
    } catch (_) {}

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

  /// Logo scales with screen width; keeps full crest + text readable.
  double _logoWidth(BoxConstraints constraints) {
    final maxW = constraints.maxWidth;
    if (!maxW.isFinite || maxW <= 0) return 280;
    return maxW.clamp(240.0, 360.0);
  }

  static const double _logoAspect = 250 / 89;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const LoginBrandBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final logoWidth = _logoWidth(constraints);
                final logoHeight = logoWidth / _logoAspect;
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    math.max(8, topInset * 0.1),
                    20,
                    16 + bottomInset * 0.2,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: AnimatedBuilder(
                            animation: Listenable.merge([
                              _enterController,
                              _pulseController,
                              _shimmerController,
                            ]),
                            builder: (context, _) {
                              return Opacity(
                                opacity: _fadeIn.value.clamp(0.0, 1.0),
                                child: Transform.translate(
                                  offset: Offset(0, _floatY.value),
                                  child: Transform.scale(
                                    scale: _scaleIn.value,
                                    child: _LoginBrandLogo(
                                      width: logoWidth,
                                      height: logoHeight,
                                      shimmer: _shimmerController.value,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      FadeTransition(
                        opacity: _fadeIn,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: auth.isLoading
                                  ? null
                                  : () => _loginWithIts(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppColors.primary.withValues(alpha: 0.7),
                                minimumSize: const Size.fromHeight(54),
                                elevation: 6,
                                shadowColor:
                                    AppColors.primary.withValues(alpha: 0.35),
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
                                      'Login with ITS',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _LoginBrandLogo extends StatelessWidget {
  const _LoginBrandLogo({
    required this.width,
    required this.height,
    required this.shimmer,
  });

  final double width;
  final double height;
  final double shimmer;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppConfig.loginLogoAsset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                AppConfig.appIconAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              );
            },
          ),
          IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Align(
                alignment: Alignment(-1.4 + shimmer * 2.8, 0),
                child: Container(
                  width: width * 0.22,
                  height: height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.18),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
