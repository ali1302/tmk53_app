import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/scan_provider.dart';

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
  bool _autoSubmitting = false;

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
    super.dispose();
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
      _submit(fromAuto: true);
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

  Future<void> _submit({bool fromAuto = false}) async {
    final value = _itsController.text.trim();
    if (value.isEmpty) return;
    if (fromAuto && value.length != _itsLength) return;

    final provider = context.read<ScanProvider>();
    if (provider.isSubmitting || _autoSubmitting) return;

    setState(() => _autoSubmitting = true);
    try {
      final auth = context.read<AuthProvider>();
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
        if (mounted) {
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
                              widget.event.category == 'Sabaq' ||
                                      widget.event.category == 'Asbaq'
                                  ? 'Asbaq Users: ${provider.eligibleCount}'
                                  : 'Event: ${widget.event.category}',
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
                            onTap: () {
                              setState(() => _mode = mode);
                              if (mode == 'Manual Scan') {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  _itsFocus.requestFocus();
                                });
                              }
                            },
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
                        padding: const EdgeInsets.all(16),
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
                            const SizedBox(height: 16),
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
                                return Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFBBF7D0)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        size: 18,
                                        color: Color(0xFF16A34A),
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
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.document_scanner_outlined,
                              size: 48,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Camera QR scanning can be enabled next.\nUse Manual Scan for now.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppColors.gray400),
                            ),
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

  String _formatTime(DateTime at) {
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    final s = at.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
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
