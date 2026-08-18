import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/scan_provider.dart';
import '../utils/its_from_qr.dart';

class ScanDetailScreen extends StatefulWidget {
  const ScanDetailScreen({super.key, required this.event, required this.onBack});

  final ScanEvent event;
  final VoidCallback onBack;

  @override
  State<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends State<ScanDetailScreen> {
  static const int _itsLength = 8;

  String _mode = 'Manual Scan';
  final _itsController = TextEditingController();
  final _itsFocus = FocusNode();
  final _successPlayer = AudioPlayer();
  final _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
    autoStart: false,
  );
  bool _autoSubmitting = false;
  bool _scannerStarted = false;
  String? _lastInvalidQr;
  DateTime? _lastInvalidAt;

  bool get _cameraQrSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (!auth.isDesignPreview && auth.token != null) {
        context.read<ScanProvider>().loadDetail(
              token: auth.token!,
              event: widget.event,
            );
      }
      if (_mode == 'Manual Scan') {
        _itsFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _itsController.dispose();
    _itsFocus.dispose();
    _successPlayer.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _setMode(String mode) async {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    if (mode == 'Manual Scan') {
      await _stopScanner();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _itsFocus.requestFocus();
      });
    } else {
      _itsFocus.unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mode == 'QR Code') {
          _startScanner();
        }
      });
    }
  }

  Future<void> _startScanner() async {
    if (!_cameraQrSupported || _scannerStarted) return;
    try {
      await _scannerController.start();
      if (mounted) setState(() => _scannerStarted = true);
    } catch (_) {
      if (mounted) {
        setState(() => _scannerStarted = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open camera. Allow camera permission and try again.'),
          ),
        );
      }
    }
  }

  Future<void> _stopScanner() async {
    if (!_scannerStarted) return;
    try {
      await _scannerController.stop();
    } catch (_) {}
    _scannerStarted = false;
  }

  void _onItsChanged(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final clipped =
        digits.length > _itsLength ? digits.substring(0, _itsLength) : digits;
    if (clipped != value) {
      _itsController.value = TextEditingValue(
        text: clipped,
        selection: TextSelection.collapsed(offset: clipped.length),
      );
    }
    if (clipped.length == _itsLength) {
      _submitIts(clipped, fromAuto: true);
    }
  }

  Future<void> _playSuccessSound() async {
    try {
      await _successPlayer.stop();
      await _successPlayer.play(AssetSource('sounds/scan_success.wav'));
    } catch (_) {
      await SystemSound.play(SystemSoundType.click);
    }
    await HapticFeedback.mediumImpact();
  }

  Future<void> _onQrDetect(BarcodeCapture capture) async {
    if (_mode != 'QR Code') return;
    if (_autoSubmitting || context.read<ScanProvider>().isSubmitting) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim() ?? '';
      if (raw.isEmpty) continue;
      final its = itsFromQrPayload(raw);
      if (its == null || its.length != _itsLength) {
        final now = DateTime.now();
        final isRepeat = _lastInvalidQr == raw &&
            _lastInvalidAt != null &&
            now.difference(_lastInvalidAt!) < const Duration(seconds: 3);
        if (!isRepeat && mounted) {
          _lastInvalidQr = raw;
          _lastInvalidAt = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR does not contain a valid 8-digit ITS.')),
          );
        }
        return;
      }
      await _submitIts(its, fromQr: true);
      return;
    }
  }

  Future<void> _submit({bool fromAuto = false}) async {
    await _submitIts(_itsController.text.trim(), fromAuto: fromAuto);
  }

  Future<void> _submitIts(
    String value, {
    bool fromAuto = false,
    bool fromQr = false,
  }) async {
    if (value.isEmpty) return;
    if ((fromAuto || fromQr) && value.length != _itsLength) return;

    final provider = context.read<ScanProvider>();
    if (provider.isSubmitting || _autoSubmitting) return;

    setState(() => _autoSubmitting = true);
    final auth = context.read<AuthProvider>();
    if (fromQr) {
      try {
        await _scannerController.stop();
      } catch (_) {}
    }
    try {
      final ok = await provider.submitScan(
        token: auth.token ?? '',
        event: widget.event,
        its: value,
      );
      if (!mounted) return;
      final message = provider.lastScanMessage;
      final already = provider.lastScanAlreadyScanned;
      if (ok) {
        setState(() {
          _itsController.clear();
        });
        if (already) {
          await SystemSound.play(SystemSoundType.alert);
          await HapticFeedback.heavyImpact();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message ?? 'ITS is already scanned.'),
                backgroundColor: const Color(0xFFB45309),
              ),
            );
          }
        } else {
          await _playSuccessSound();
        }
        if (mounted && _mode == 'Manual Scan') {
          _itsFocus.requestFocus();
        }
      } else {
        await SystemSound.play(SystemSoundType.alert);
        await HapticFeedback.heavyImpact();
        if (mounted && message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      }
    } finally {
      if (fromQr && _mode == 'QR Code' && mounted) {
        try {
          await _scannerController.start();
          _scannerStarted = true;
        } catch (_) {
          _scannerStarted = false;
        }
      }
      if (mounted) {
        setState(() => _autoSubmitting = false);
      } else {
        _autoSubmitting = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScanProvider>();
    final dates = widget.event.dates.split(' | ');
    final busy = provider.isSubmitting || provider.isRemoving || _autoSubmitting;
    final counts = [
      (label: 'M:', value: provider.counts.male, bg: const Color(0xFF4A90D9)),
      (label: 'F:', value: provider.counts.female, bg: const Color(0xFFF4A0B0)),
      (label: 'C:', value: provider.counts.child, bg: const Color(0xFFC8A0E8)),
      (label: 'M:', value: provider.counts.mehman, bg: const Color(0xFFE8A020)),
      (label: 'N.R:', value: provider.counts.unregistered, bg: const Color(0xFF8B2020)),
      (label: 'All:', value: provider.counts.all, bg: const Color(0xFF4CAF50)),
    ];

    return Column(
      children: [
        Container(
          color: AppColors.primary,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 4,
            left: 8,
            right: 16,
            bottom: 12,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.chevron_left, color: AppColors.accent, size: 28),
              ),
              const Text(
                'Scan Detail',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.event.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month, size: 13, color: AppColors.gray400),
                        const SizedBox(width: 6),
                        Text(
                          dates.isNotEmpty ? dates.first : widget.event.dates,
                          style: const TextStyle(fontSize: 12, color: AppColors.gray500),
                        ),
                        if (dates.length > 1) ...[
                          const SizedBox(width: 24),
                          const Icon(Icons.calendar_month, size: 13, color: AppColors.gray400),
                          const SizedBox(width: 6),
                          Text(dates[1], style: const TextStyle(fontSize: 12, color: AppColors.gray500)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Card(
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Scanning Overview',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline, size: 14, color: AppColors.gray500),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _scanOverviewLabel(widget.event, provider),
                              style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              final auth = context.read<AuthProvider>();
                              context.read<ScanProvider>().loadDetail(
                                    token: auth.token ?? '',
                                    event: widget.event,
                                  );
                            },
                            icon: const Icon(Icons.refresh, size: 16, color: AppColors.gray400),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.event.category == 'Majlis' ||
                  widget.event.category == 'Asbaq') ...[
                const SizedBox(height: 12),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scanned Counts',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: counts.map((c) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: c.bg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person, size: 12, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  '${c.label} ${c.value}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _Card(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    Row(
                      children: ['Manual Scan', 'QR Code'].map((mode) {
                        final selected = _mode == mode;
                        return Expanded(
                          child: InkWell(
                            onTap: busy ? null : () => _setMode(mode),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: selected ? AppColors.accent : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Text(
                                mode,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: selected ? AppColors.accent : const Color(0xFF888888),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (_mode == 'Manual Scan')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          children: [
                            TextField(
                              controller: _itsController,
                              focusNode: _itsFocus,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              maxLength: _itsLength,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(_itsLength),
                              ],
                              onChanged: _onItsChanged,
                              onSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                hintText: 'Enter 8-digit ITS',
                                counterText: '',
                                helperText: 'Auto-submits after 8 digits',
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: busy ? null : () => _submit(),
                              icon: busy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.search, size: 16),
                              label: const Text('Submit'),
                            ),
                          ],
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: _buildQrScannerPane(busy),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Scanned Users (${provider.scannedUsers.length})',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (provider.scannedUsers.isEmpty)
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'No user(s) scanned.',
                                style: TextStyle(fontSize: 13, color: AppColors.gray400),
                              ),
                            )
                          else
                            ...provider.scannedUsers.map((entry) {
                              final colors = _colorsForKind(entry.kind);
                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.bg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: colors.border),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      colors.icon,
                                      size: 18,
                                      color: colors.accent,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.displayName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF1F2937),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'ITS: ${entry.its}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.gray500,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            entry.kindLabel,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: colors.accent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (entry.at != null)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Text(
                                          _formatTime(entry.at!),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.gray400,
                                          ),
                                        ),
                                      ),
                                    IconButton(
                                      tooltip: 'Remove from scanned',
                                      onPressed: busy
                                          ? null
                                          : () => _confirmRemove(entry),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQrScannerPane(bool busy) {
    if (!_cameraQrSupported) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Icon(Icons.qr_code_scanner, size: 48, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              'QR camera scanning works on Android and iPhone.\nUse Manual Scan on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.gray400),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onQrDetect,
                  errorBuilder: (context, error) {
                    return Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        error.errorCode == MobileScannerErrorCode.permissionDenied
                            ? 'Camera permission is required to scan QR codes.\nEnable it in system settings.'
                            : 'Unable to open camera.\n${error.errorDetails?.message ?? error.errorCode.name}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    );
                  },
                ),
                IgnorePointer(
                  child: CustomPaint(
                    painter: _QrFramePainter(),
                  ),
                ),
                if (busy)
                  Container(
                    color: Colors.black45,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          busy ? 'Submitting scan…' : 'Point camera at ITS QR code',
          style: const TextStyle(fontSize: 12, color: AppColors.gray500),
        ),
      ],
    );
  }

  Future<void> _confirmRemove(ScannedUser entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove scan?'),
        content: Text(
          'Remove ${entry.displayName} (ITS: ${entry.its}) from scanned list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final provider = context.read<ScanProvider>();
    final ok = await provider.removeScannedUser(
      token: auth.token ?? '',
      event: widget.event,
      its: entry.its,
    );
    if (!mounted) return;
    final message = provider.lastScanMessage ??
        (ok ? 'ITS removed from scanned list.' : 'Unable to remove scan.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ok ? const Color(0xFF166534) : const Color(0xFFB91C1C),
      ),
    );
    if (mounted) {
      _itsFocus.requestFocus();
    }
  }

  ({Color bg, Color border, Color accent, IconData icon}) _colorsForKind(
    ScanUserKind kind,
  ) {
    switch (kind) {
      case ScanUserKind.mehman:
        return (
          bg: const Color(0xFFFFFBEB),
          border: const Color(0xFFFDE68A),
          accent: const Color(0xFFD97706),
          icon: Icons.person_outline,
        );
      case ScanUserKind.notRegistered:
        return (
          bg: const Color(0xFFFEF2F2),
          border: const Color(0xFFFECACA),
          accent: const Color(0xFFDC2626),
          icon: Icons.warning_amber_rounded,
        );
      case ScanUserKind.registered:
        return (
          bg: const Color(0xFFF0FDF4),
          border: const Color(0xFFBBF7D0),
          accent: const Color(0xFF16A34A),
          icon: Icons.check_circle,
        );
    }
  }

  String _formatTime(DateTime at) {
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    final s = at.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _QrFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.35);
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final cut = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.72,
      height: size.width * 0.72,
    );

    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(cut, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlay);

    const corner = 28.0;
    // Top-left
    canvas.drawLine(cut.topLeft, cut.topLeft + const Offset(corner, 0), stroke);
    canvas.drawLine(cut.topLeft, cut.topLeft + const Offset(0, corner), stroke);
    // Top-right
    canvas.drawLine(cut.topRight, cut.topRight + const Offset(-corner, 0), stroke);
    canvas.drawLine(cut.topRight, cut.topRight + const Offset(0, corner), stroke);
    // Bottom-left
    canvas.drawLine(cut.bottomLeft, cut.bottomLeft + const Offset(corner, 0), stroke);
    canvas.drawLine(cut.bottomLeft, cut.bottomLeft + const Offset(0, -corner), stroke);
    // Bottom-right
    canvas.drawLine(cut.bottomRight, cut.bottomRight + const Offset(-corner, 0), stroke);
    canvas.drawLine(cut.bottomRight, cut.bottomRight + const Offset(0, -corner), stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _scanOverviewLabel(ScanEvent event, ScanProvider provider) {
  switch (event.category) {
    case 'Sabaq':
      return 'Sabaq Users: ${provider.eligibleCount}';
    case 'Asbaq':
      return 'Asbaq Users: ${provider.eligibleCount}';
    case 'Majlis':
      return 'Event Users: ${provider.eligibleCount}';
    default:
      return 'Event: ${event.category}';
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
          ),
        ],
      ),
      child: child,
    );
  }
}
