import 'package:flutter/material.dart';

/// 3D Kaaba image used for Qibla / Mecca actions.
class KaabaIcon extends StatelessWidget {
  const KaabaIcon({
    super.key,
    this.size = 22,
    // Kept for call-site compatibility; image asset provides its own colors.
    this.color = Colors.white,
    this.accentColor = const Color(0xFFC8982A),
  });

  static const assetPath = 'assets/images/kaaba_3d.png';

  final double size;
  final Color color;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => Icon(
          Icons.mosque_outlined,
          size: size * 0.85,
          color: color,
        ),
      ),
    );
  }
}
