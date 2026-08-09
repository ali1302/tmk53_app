import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../../../core/services/location_service.dart';
import '../../../core/services/qibla_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/kaaba_icon.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({
    super.key,
    required this.onClose,
    this.locationLabel,
  });

  final VoidCallback onClose;
  final String? locationLabel;

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  final _locationService = LocationService();

  StreamSubscription<CompassEvent>? _compassSub;
  double? _heading;
  double? _qiblaBearing;
  double? _distanceKm;
  String _placeLabel = 'Detecting location…';
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.locationLabel != null &&
        widget.locationLabel!.trim().isNotEmpty &&
        widget.locationLabel != 'Detecting location…' &&
        widget.locationLabel != 'Location unavailable') {
      _placeLabel = widget.locationLabel!.trim();
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final location = await _locationService.getCurrentLocation();
      final bearing = QiblaService.bearingToKaaba(
        location.latitude,
        location.longitude,
      );
      final distance = QiblaService.distanceKm(
        location.latitude,
        location.longitude,
      );

      if (!mounted) return;
      setState(() {
        _qiblaBearing = bearing;
        _distanceKm = distance;
        _placeLabel = location.label;
        _loading = false;
      });

      _listenCompass();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is StateError
            ? e.message
            : 'Unable to determine your location for Qibla.';
      });
    }
  }

  void _listenCompass() {
    if (kIsWeb) return;
    _compassSub?.cancel();
    _compassSub = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
      if (heading == null || !mounted) return;
      setState(() => _heading = (heading + 360) % 360);
    });
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final qibla = _qiblaBearing;
    final heading = _heading;
    final relative = (qibla != null && heading != null)
        ? QiblaService.shortestAngle(heading, qibla)
        : null;
    final aligned = relative != null && relative.abs() <= 8;

    return Material(
      color: AppColors.background,
      child: Column(
        children: [
          Container(
            color: AppColors.primary,
            padding: EdgeInsets.fromLTRB(8, topPad + 4, 16, 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.chevron_left, color: AppColors.accent),
                ),
                const Text(
                  'Qibla Finder',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loading ? null : _bootstrap,
                  icon: const Icon(Icons.refresh, color: AppColors.accent, size: 20),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _bootstrap)
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.cream,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: AppColors.muted,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _placeLabel,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF5A4A30),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            _CompassDial(
                              qiblaBearing: qibla!,
                              deviceHeading: heading,
                              aligned: aligned,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              aligned ? 'Facing Qibla' : 'Rotate to face Qibla',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: aligned
                                    ? AppColors.success
                                    : AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Qibla ${qibla.toStringAsFixed(0)}° '
                              '${QiblaService.cardinalLabel(qibla)}'
                              '${_distanceKm != null ? ' · ${_formatDistance(_distanceKm!)}' : ''}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.gray500,
                              ),
                            ),
                            if (heading != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Device ${heading.toStringAsFixed(0)}°',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.gray400,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Text(
                                kIsWeb
                                    ? 'On web, compass heading may be unavailable. Use the Kaaba marker relative to north, or open this screen on a phone for live compass.'
                                    : 'Hold your phone flat and turn until the Kaaba marker aligns with the top arrow.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: AppColors.gray500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  String _formatDistance(double km) {
    if (km >= 100) return '${km.round()} km';
    if (km >= 10) return '${km.toStringAsFixed(0)} km';
    return '${km.toStringAsFixed(1)} km';
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore_off, size: 40, color: AppColors.gray400),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.gray500),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                final service = LocationService();
                if (message.toLowerCase().contains('blocked') ||
                    message.toLowerCase().contains('permission')) {
                  await service.openAppSettings();
                } else {
                  await service.openLocationSettings();
                }
              },
              child: const Text('Open settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompassDial extends StatelessWidget {
  const _CompassDial({
    required this.qiblaBearing,
    required this.deviceHeading,
    required this.aligned,
  });

  final double qiblaBearing;
  final double? deviceHeading;
  final bool aligned;

  @override
  Widget build(BuildContext context) {
    // Rotate dial so north tracks device; Kaaba stays at absolute bearing.
    final dialRotation =
        deviceHeading != null ? -deviceHeading! * math.pi / 180 : 0.0;
    final kaabaAngle = qiblaBearing * math.pi / 180;
    final arrowColor = aligned ? AppColors.success : AppColors.primary;

    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Fixed top indicator — direction the device is facing
          const Positioned(
            top: 0,
            child: _FacingArrow(),
          ),
          Transform.rotate(
            angle: dialRotation,
            child: Container(
              width: 236,
              height: 236,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: aligned ? AppColors.success : AppColors.accent,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (final entry in const [
                    (0.0, 'N'),
                    (90.0, 'E'),
                    (180.0, 'S'),
                    (270.0, 'W'),
                  ])
                    Transform.rotate(
                      angle: entry.$1 * math.pi / 180,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Transform.rotate(
                            angle: -entry.$1 * math.pi / 180,
                            child: Text(
                              entry.$2,
                              style: TextStyle(
                                fontSize: entry.$2 == 'N' ? 16 : 13,
                                fontWeight: FontWeight.w800,
                                color: entry.$2 == 'N'
                                    ? AppColors.primary
                                    : AppColors.gray500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Tick marks
                  CustomPaint(
                    size: const Size(236, 236),
                    painter: _TickPainter(),
                  ),
                  // Qibla direction arrow (needle from center → Kaaba)
                  Transform.rotate(
                    angle: kaabaAngle,
                    child: CustomPaint(
                      size: const Size(236, 236),
                      painter: _QiblaArrowPainter(color: arrowColor),
                    ),
                  ),
                  // Kaaba marker at qibla bearing
                  Transform.rotate(
                    angle: kaabaAngle,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 22),
                        child: Transform.rotate(
                          angle: -kaabaAngle,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const KaabaIcon(size: 30),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Center pivot
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: arrowColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fixed arrow at the top of the dial = phone facing direction.
class _FacingArrow extends StatelessWidget {
  const _FacingArrow();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(28, 22),
          painter: _TriangleArrowPainter(color: AppColors.primary),
        ),
        Container(
          width: 3,
          height: 8,
          color: AppColors.primary,
        ),
      ],
    );
  }
}

class _TriangleArrowPainter extends CustomPainter {
  _TriangleArrowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _TriangleArrowPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Needle arrow pointing toward Qibla (drawn pointing up; rotate externally).
class _QiblaArrowPainter extends CustomPainter {
  _QiblaArrowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final tipY = 48.0;
    final shaftTop = 62.0;
    final shaftBottom = center.dy - 8;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Arrow head
    final head = Path()
      ..moveTo(center.dx, tipY)
      ..lineTo(center.dx + 14, shaftTop + 6)
      ..lineTo(center.dx - 14, shaftTop + 6)
      ..close();
    canvas.drawPath(head, fill);
    canvas.drawPath(head, stroke);

    // Shaft
    final shaft = RRect.fromRectAndRadius(
      Rect.fromLTRB(center.dx - 4.5, shaftTop + 4, center.dx + 4.5, shaftBottom),
      const Radius.circular(3),
    );
    canvas.drawRRect(shaft, fill);
    canvas.drawRRect(shaft, stroke);

    // Small opposite stub for balance
    final stub = RRect.fromRectAndRadius(
      Rect.fromLTRB(center.dx - 3, center.dy + 8, center.dx + 3, center.dy + 36),
      const Radius.circular(2),
    );
    canvas.drawRRect(
      stub,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _QiblaArrowPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _TickPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1.5;

    for (var i = 0; i < 360; i += 15) {
      final rad = i * math.pi / 180;
      final outer = Offset(
        center.dx + math.sin(rad) * (radius - 10),
        center.dy - math.cos(rad) * (radius - 10),
      );
      final inner = Offset(
        center.dx + math.sin(rad) * (radius - (i % 90 == 0 ? 22 : 16)),
        center.dy - math.cos(rad) * (radius - (i % 90 == 0 ? 22 : 16)),
      );
      canvas.drawLine(inner, outer, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
