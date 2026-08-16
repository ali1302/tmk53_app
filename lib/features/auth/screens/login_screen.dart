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
  late final Animation<double> _glow;
  late final Animation<double> _ringPulse;

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
    _glow = Tween<double>(begin: 0.18, end: 0.48).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _ringPulse = Tween<double>(begin: 0.92, end: 1.08).animate(
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

  /// Logo scales with shortest screen side so it stays sharp on phone / tablet.
  double _logoExtent(BoxConstraints constraints) {
    final shortest = math.min(constraints.maxWidth, constraints.maxHeight);
    if (!shortest.isFinite || shortest <= 0) return 160.0;
    final preferred = math.min(
      constraints.maxWidth * 0.78,
      constraints.maxHeight * 0.46,
    );
    final maxSize = shortest * 0.78;
    final minSize = math.min(160.0, maxSize);
    return preferred.clamp(minSize, maxSize).toDouble();
  }

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
                final logoSize = _logoExtent(constraints);
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
                                    child: _DynamicLogo(
                                      size: logoSize,
                                      glow: _glow.value,
                                      ringScale: _ringPulse.value,
                                      shimmer: _shimmerController.value,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      FadeTransition(
                        opacity: _fadeIn,
                        child: Text(
                          'Taheri Mohalla Jamaat',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cormorantGaramond(
                            color: AppColors.primary.withValues(alpha: 0.85),
                            fontSize: constraints.maxWidth < 360 ? 22 : 26,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                            height: 1.15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FadeTransition(
                        opacity: _fadeIn,
                        child: Text(
                          'Khaitan · Kuwait',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: AppColors.primary.withValues(alpha: 0.55),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.4,
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

class _DynamicLogo extends StatelessWidget {
  const _DynamicLogo({
    required this.size,
    required this.glow,
    required this.ringScale,
    required this.shimmer,
  });

  final double size;
  final double glow;
  final double ringScale;
  final double shimmer;

  @override
  Widget build(BuildContext context) {
    final ringSize = size * 1.08;

    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer breathing gold ring
          Transform.scale(
            scale: ringScale,
            child: Container(
              width: size * 0.98,
              height: size * 0.98,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.22 + glow * 0.25),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: glow),
                    blurRadius: 42,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: glow * 0.55),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          // Soft disc behind crest
          Container(
            width: size * 0.92,
            height: size * 0.92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.55),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
          ),
          // Crest with resolution-aware scaling + light shimmer sweep
          SizedBox(
            width: size * 0.86,
            height: size * 0.86,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/app_icon_foreground.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, error, stackTrace) {
                    return Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    );
                  },
                ),
                IgnorePointer(
                  child: ClipOval(
                    child: Align(
                      alignment: Alignment(-1.4 + shimmer * 2.8, -0.15),
                      child: Container(
                        width: size * 0.28,
                        height: size,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.28),
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
          ),
        ],
      ),
    );
  }
}
