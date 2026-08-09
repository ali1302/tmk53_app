import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/calendar/misri_calendar.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/history_repository.dart';
import '../providers/history_scan_provider.dart';

class HistoryScanScreen extends StatefulWidget {
  const HistoryScanScreen({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<HistoryScanScreen> createState() => _HistoryScanScreenState();
}

class _HistoryScanScreenState extends State<HistoryScanScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (!auth.isDesignPreview && auth.token != null) {
        context.read<HistoryScanProvider>().loadAll(auth.token!);
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final auth = context.read<AuthProvider>();
    if (auth.token == null) return;
    await context.read<HistoryScanProvider>().loadAll(auth.token!);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final history = context.watch<HistoryScanProvider>();

    return Material(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            color: AppColors.primary,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 4,
              left: 8,
              right: 8,
              bottom: 0,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.chevron_left, color: AppColors.accent, size: 28),
                    ),
                    const Text(
                      'History Scan',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                TabBar(
                  controller: _tabs,
                  indicatorColor: AppColors.accent,
                  labelColor: AppColors.accent,
                  unselectedLabelColor: Colors.white70,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Sabaq'),
                    Tab(text: 'Miqaat'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: auth.isDesignPreview
                ? const Center(child: Text('Design preview — login for history.'))
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _HistoryList(
                        items: history.asbaqItems,
                        isLoading: history.isLoadingAsbaq,
                        error: history.asbaqError,
                        emptyText: 'No Sabaq scan history found.',
                        onRefresh: _refresh,
                      ),
                      _HistoryList(
                        items: history.majlisItems,
                        isLoading: history.isLoadingMajlis,
                        error: history.majlisError,
                        emptyText: 'No Miqaat scan history found.',
                        onRefresh: _refresh,
                        useMisriDate: true,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.items,
    required this.isLoading,
    required this.emptyText,
    required this.onRefresh,
    this.error,
    this.useMisriDate = false,
  });

  final List<HistoryItem> items;
  final bool isLoading;
  final String? error;
  final String emptyText;
  final Future<void> Function() onRefresh;
  final bool useMisriDate;

  @override
  Widget build(BuildContext context) {
    if (isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          if (error != null && items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            )
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                emptyText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.gray500, fontWeight: FontWeight.w600),
              ),
            )
          else
            for (final item in items) ...[
              _HistoryCard(item: item, useMisriDate: useMisriDate),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item, this.useMisriDate = false});

  final HistoryItem item;
  final bool useMisriDate;

  Color get _statusColor {
    switch (item.status) {
      case HistoryStatus.attended:
        return const Color(0xFF15803D);
      case HistoryStatus.notAttended:
        return const Color(0xFFB45309);
      case HistoryStatus.registered:
        return const Color(0xFF1D4ED8);
      case HistoryStatus.notRegistered:
        return AppColors.gray500;
      case HistoryStatus.unknown:
        return AppColors.gray500;
    }
  }

  String get _dateLine {
    final misri = useMisriDate
        ? (MisriDate.labelFromGregorianString(item.date) ?? item.hijriDate)
        : item.hijriDate;
    return [
      if (item.date.isNotEmpty) item.date,
      if (misri.isNotEmpty) misri,
    ].join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title.isEmpty ? 'Event' : item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.statusLabel.isEmpty ? item.status.name : item.statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (_dateLine.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _dateLine,
              style: const TextStyle(fontSize: 12, color: AppColors.gray500),
            ),
          ],
          if (item.subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ],
      ),
    );
  }
}
