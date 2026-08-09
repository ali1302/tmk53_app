import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Original painted login atmosphere — dusk sky, geometric skyline, soft motion.
class LoginAtmosphereBackground extends StatefulWidget {
  const LoginAtmosphereBackground({super.key});

  @override
  State<LoginAtmosphereBackground> createState() =>
      _LoginAtmosphereBackgroundState();
}

class _LoginAtmosphereBackgroundState extends State<LoginAtmosphereBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
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
          painter: _LoginAtmospherePainter(t: _controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _LoginAtmospherePainter extends CustomPainter {
  _LoginAtmospherePainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.62;

    // Sky gradient
    final sky = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, horizon),
        const [
          Color(0xFF1A0A18),
          Color(0xFF3D1035),
          Color(0xFF5A1A4A),
          Color(0xFF2A1528),
        ],
        const [0.0, 0.35, 0.72, 1.0],
      );
    canvas.drawRect(Offset.zero & size, sky);

    // Soft gold sun glow near horizon (slow breathe)
    final breathe = 0.55 + 0.45 * math.sin(t * math.pi * 2);
    final sunCenter = Offset(w * 0.72, horizon - h * 0.06);
    canvas.drawCircle(
      sunCenter,
      h * 0.18,
      Paint()
        ..shader = ui.Gradient.radial(
          sunCenter,
          h * 0.22,
          [
            AppColors.accent.withValues(alpha: 0.28 * breathe),
            AppColors.accent.withValues(alpha: 0.08 * breathe),
            Colors.transparent,
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    // Floating dust / stars
    final starPaint = Paint()..style = PaintingStyle.fill;
    final rng = math.Random(7);
    for (var i = 0; i < 42; i++) {
      final bx = rng.nextDouble() * w;
      final by = rng.nextDouble() * horizon * 0.9;
      final twinkle =
          0.25 + 0.75 * (0.5 + 0.5 * math.sin((t * 2 * math.pi) + i * 0.7));
      final drift = math.sin(t * math.pi * 2 + i) * 6;
      starPaint.color = Color.lerp(
            Colors.white,
            AppColors.accent,
            i.isEven ? 0.35 : 0.05,
          )!
          .withValues(alpha: 0.15 + 0.45 * twinkle);
      canvas.drawCircle(Offset(bx + drift, by), 1.1 + (i % 3) * 0.5, starPaint);
    }

    // Soft light beams
    final beamPaint = Paint()
      ..blendMode = BlendMode.plus
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 3; i++) {
      final angle = -0.55 + i * 0.22 + math.sin(t * math.pi * 2 + i) * 0.04;
      final path = Path()
        ..moveTo(sunCenter.dx, sunCenter.dy)
        ..lineTo(
          sunCenter.dx + math.cos(angle) * h * 1.1,
          sunCenter.dy + math.sin(angle) * h * 1.1,
        )
        ..lineTo(
          sunCenter.dx + math.cos(angle + 0.08) * h * 1.1,
          sunCenter.dy + math.sin(angle + 0.08) * h * 1.1,
        )
        ..close();
      beamPaint.shader = ui.Gradient.linear(
        sunCenter,
        Offset(sunCenter.dx, h),
        [
          AppColors.accent.withValues(alpha: 0.10),
          AppColors.accent.withValues(alpha: 0.0),
        ],
      );
      canvas.drawPath(path, beamPaint);
    }

    // Water / lower field
    final waterRect = Rect.fromLTWH(0, horizon, w, h - horizon);
    final water = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, horizon),
        Offset(0, h),
        const [
          Color(0xFF24101F),
          Color(0xFF140910),
          Color(0xFF0C060B),
        ],
        const [0.0, 0.45, 1.0],
      );
    canvas.drawRect(waterRect, water);

    // Skyline silhouette (original geometric Kuwait-inspired forms)
    final skyline = _skylinePath(w, horizon, h * 0.22);
    canvas.drawPath(
      skyline,
      Paint()..color = const Color(0xFF0A0408).withValues(alpha: 0.92),
    );
    // Soft rim light on buildings
    canvas.drawPath(
      skyline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.accent.withValues(alpha: 0.22),
    );

    // Reflection (mirrored, faded + shimmer)
    canvas.save();
    canvas.translate(0, horizon);
    canvas.scale(1, -0.55);
    canvas.translate(0, -horizon);
    final reflectPaint = Paint()
      ..colorFilter = ColorFilter.mode(
        Colors.white.withValues(alpha: 0.18),
        BlendMode.modulate,
      );
    canvas.saveLayer(Rect.fromLTWH(0, horizon - h * 0.25, w, h * 0.25), reflectPaint);
    canvas.drawPath(
      skyline,
      Paint()..color = const Color(0xFF1A0C16).withValues(alpha: 0.7),
    );
    canvas.restore();
    canvas.restore();

    // Shimmer lines on water
    final shimmer = Paint()
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 7; i++) {
      final y = horizon + 18.0 + i * 16.0 + math.sin(t * math.pi * 2 + i) * 3;
      final phase = t * w * 0.35 + i * 40;
      shimmer.color = AppColors.accent.withValues(alpha: 0.08 + (i % 3) * 0.03);
      canvas.drawLine(
        Offset((-40 + phase) % (w + 80) - 40, y),
        Offset((-40 + phase) % (w + 80) + 90, y),
        shimmer,
      );
    }

    // Vignette for logo readability
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(w * 0.5, h * 0.28),
          h * 0.75,
          [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.35),
          ],
          const [0.45, 1.0],
        ),
    );

    // Bottom fade under login button
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.72, w, h * 0.28),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, h * 0.72),
          Offset(0, h),
          [
            Colors.transparent,
            const Color(0xFF0A0408).withValues(alpha: 0.75),
          ],
        ),
    );
  }

  Path _skylinePath(double w, double horizon, double maxH) {
    final path = Path()..moveTo(0, horizon);

    void block(double x, double width, double height, {double topCut = 0}) {
      path.lineTo(x, horizon);
      path.lineTo(x, horizon - height);
      if (topCut > 0) {
        path.lineTo(x + width * 0.35, horizon - height - topCut);
        path.lineTo(x + width * 0.65, horizon - height);
      }
      path.lineTo(x + width, horizon - height);
      path.lineTo(x + width, horizon);
    }

    // Left cluster
    block(w * 0.02, w * 0.06, maxH * 0.35);
    block(w * 0.09, w * 0.05, maxH * 0.55);
    block(w * 0.15, w * 0.07, maxH * 0.42);

    // Needle tower (Liberation-inspired)
    final needleX = w * 0.28;
    final needleW = w * 0.035;
    path
      ..lineTo(needleX, horizon)
      ..lineTo(needleX + needleW * 0.35, horizon - maxH * 0.95)
      ..lineTo(needleX + needleW * 0.65, horizon - maxH * 0.95)
      ..lineTo(needleX + needleW, horizon);

    block(w * 0.34, w * 0.08, maxH * 0.48);
    block(w * 0.43, w * 0.06, maxH * 0.62, topCut: maxH * 0.08);
    block(w * 0.50, w * 0.09, maxH * 0.40);

    // Sphere towers (Kuwait Towers-inspired)
    final spheres = [
      (w * 0.66, maxH * 0.72, w * 0.045),
      (w * 0.74, maxH * 0.58, w * 0.038),
      (w * 0.81, maxH * 0.48, w * 0.032),
    ];
    for (final s in spheres) {
      final cx = s.$1;
      final top = horizon - s.$2;
      final r = s.$3;
      path
        ..lineTo(cx - r * 0.35, horizon)
        ..lineTo(cx - r * 0.2, top + r)
        ..arcToPoint(
          Offset(cx + r * 0.2, top + r),
          radius: Radius.circular(r),
          clockwise: true,
        )
        ..lineTo(cx + r * 0.35, horizon);
    }

    block(w * 0.88, w * 0.06, maxH * 0.36);
    block(w * 0.95, w * 0.05, maxH * 0.28);

    path
      ..lineTo(w, horizon)
      ..lineTo(w, horizon + 2)
      ..lineTo(0, horizon + 2)
      ..close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _LoginAtmospherePainter oldDelegate) =>
      oldDelegate.t != t;
}
