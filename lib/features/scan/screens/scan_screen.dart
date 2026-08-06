import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/scan_provider.dart';
import 'scan_detail_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  ScanEvent? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (!auth.isDesignPreview && auth.token != null) {
        context.read<ScanProvider>().loadEvents(auth.token!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      return ScanDetailScreen(
        event: _selected!,
        onBack: () => setState(() => _selected = null),
      );
    }

    final provider = context.watch<ScanProvider>();
    final auth = context.watch<AuthProvider>();

    return Column(
      children: [
        _Header(title: 'Scan', onBack: widget.onBack),
        Expanded(
          child: auth.isDesignPreview
              ? const Center(child: Text('Design preview — login for live scan events.'))
              : provider.isLoading && provider.events.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => provider.loadEvents(auth.token ?? ''),
                      child: provider.errorMessage != null && provider.events.isEmpty
                          ? ListView(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(provider.errorMessage!, textAlign: TextAlign.center),
                                ),
                              ],
                            )
                          : provider.events.isEmpty
                              ? ListView(
                                  children: const [
                                    Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text('No active scan events.', textAlign: TextAlign.center),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: provider.events.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                                  itemBuilder: (context, index) {
                                    final event = provider.events[index];
                                    return InkWell(
                                      onTap: () => setState(() => _selected = event),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
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
                                        child: Column(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    event.category,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.accent,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          event.title,
                                                          style: const TextStyle(
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w700,
                                                            color: AppColors.text,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          event.description,
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            color: AppColors.gray400,
                                                            height: 1.4,
                                                          ),
                                                        ),
                                                        if (event.dates.isNotEmpty) ...[
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            event.dates,
                                                            style: const TextStyle(
                                                              fontSize: 12,
                                                              color: AppColors.gray400,
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  const Icon(
                                                    Icons.chevron_right,
                                                    size: 16,
                                                    color: AppColors.gray400,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Divider(height: 1, color: Color(0xFFF3F4F6)),
                                            const SizedBox(height: 48),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left, color: AppColors.accent, size: 28),
          ),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
