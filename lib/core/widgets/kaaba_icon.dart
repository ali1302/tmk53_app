import 'package:flutter/material.dart';

/// Simple Kaaba glyph that renders reliably on all Android devices
/// (emoji 🕋 is often missing on OEM fonts).
class KaabaIcon extends StatelessWidget {
  const KaabaIcon({
    super.key,
    this.size = 18,
    this.color = Colors.white,
    this.accentColor = const Color(0xFFC8982A),
  });

  final double size;
  final Color color;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _KaabaPainter(color: color, accentColor: accentColor),
      ),
    );
  }
}

class _KaabaPainter extends CustomPainter {
  _KaabaPainter({required this.color, required this.accentColor});

  final Color color;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;

    final band = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Main cube body
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.18, h * 0.28, w * 0.64, h * 0.58),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(body, fill);

    // Gold kiswah band
    canvas.drawRect(
      Rect.fromLTWH(w * 0.18, h * 0.38, w * 0.64, h * 0.12),
      band,
    );

    // Door
    final door = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.42, h * 0.58, w * 0.16, h * 0.28),
      Radius.circular(w * 0.03),
    );
    canvas.drawRRect(
      door,
      Paint()
        ..color = accentColor
        ..style = PaintingStyle.fill,
    );

    // Outline for clarity on gold button
    canvas.drawRRect(body, stroke);
  }

  @override
  bool shouldRepaint(covariant _KaabaPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.accentColor != accentColor;
  }
}
