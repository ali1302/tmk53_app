import 'package:flutter/material.dart';
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
  String _mode = 'Manual Scan';
  final _itsController = TextEditingController();
  String? _scannedUser;

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
    });
  }

  @override
  void dispose() {
    _itsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _itsController.text.trim();
    if (value.isEmpty) return;
    final auth = context.read<AuthProvider>();
    final ok = await context.read<ScanProvider>().submitScan(
          token: auth.token ?? '',
          event: widget.event,
          its: value,
        );
    if (!mounted) return;
    if (ok) {
      setState(() {
        _scannedUser = value;
        _itsController.clear();
      });
    }
    final message = context.read<ScanProvider>().lastScanMessage;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScanProvider>();
    final dates = widget.event.dates.split(' | ');
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
                            onTap: () => setState(() => _mode = mode),
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
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(hintText: 'Enter ITS'),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: provider.isSubmitting ? null : _submit,
                              icon: provider.isSubmitting
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
              const SizedBox(height: 12),
              const Text(
                'Scanned User:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                _scannedUser == null
                    ? 'No user(s) scanned.'
                    : 'ITS: $_scannedUser — ${provider.lastScanMessage ?? 'Scanned successfully.'}',
                style: const TextStyle(fontSize: 14, color: AppColors.gray400),
              ),
            ],
          ),
        ),
      ],
    );
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
