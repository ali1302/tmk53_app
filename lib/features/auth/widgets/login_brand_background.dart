import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Light, full-bleed login backdrop — keeps the dark crest readable.
class LoginBrandBackground extends StatefulWidget {
  const LoginBrandBackground({super.key});

  @override
  State<LoginBrandBackground> createState() => _LoginBrandBackgroundState();
}

class _LoginBrandBackgroundState extends State<LoginBrandBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _LoginBrandPainter(t: _controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _LoginBrandPainter extends CustomPainter {
  _LoginBrandPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final breathe = 0.5 + 0.5 * math.sin(t * math.pi * 2);

    // Soft cream → warm wash (full bleed)
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(w, h),
          const [
            Color(0xFFFFFBF3),
            Color(0xFFF5EFD8),
            Color(0xFFEDE0C4),
            Color(0xFFF8F1E3),
          ],
          const [0.0, 0.35, 0.7, 1.0],
        ),
    );

    // Slow-moving maroon vignette corners
    final corner = Offset(w * (0.15 + 0.02 * breathe), h * 0.08);
    canvas.drawCircle(
      corner,
      h * 0.55,
      Paint()
        ..shader = ui.Gradient.radial(
          corner,
          h * 0.55,
          [
            AppColors.primary.withValues(alpha: 0.10 * breathe),
            Colors.transparent,
          ],
        ),
    );
    final corner2 = Offset(w * 0.88, h * 0.92);
    canvas.drawCircle(
      corner2,
      h * 0.48,
      Paint()
        ..shader = ui.Gradient.radial(
          corner2,
          h * 0.48,
          [
            AppColors.accent.withValues(alpha: 0.14 * breathe),
            Colors.transparent,
          ],
        ),
    );

    // Subtle floating gold motes
    final mote = Paint()..style = PaintingStyle.fill;
    final rng = math.Random(11);
    for (var i = 0; i < 28; i++) {
      final bx = rng.nextDouble() * w;
      final by = rng.nextDouble() * h;
      final drift = math.sin(t * math.pi * 2 + i) * 10;
      final twinkle =
          0.2 + 0.8 * (0.5 + 0.5 * math.sin(t * 2 * math.pi + i * 0.9));
      mote.color = AppColors.accent.withValues(alpha: 0.06 + 0.12 * twinkle);
      canvas.drawCircle(
        Offset(bx + drift, by),
        1.2 + (i % 4) * 0.6,
        mote,
      );
    }

    // Soft center spotlight behind logo
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.38),
      math.min(w, h) * 0.42,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(w * 0.5, h * 0.38),
          math.min(w, h) * 0.42,
          [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
    );

    // Bottom fade for CTA readability
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.7, w, h * 0.3),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, h * 0.7),
          Offset(0, h),
          [
            Colors.transparent,
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.primary.withValues(alpha: 0.18),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _LoginBrandPainter oldDelegate) =>
      oldDelegate.t != t;
}
