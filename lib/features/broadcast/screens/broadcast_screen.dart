import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/broadcast_provider.dart';
import '../widgets/broadcast_detail_sheet.dart';

class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (!auth.isDesignPreview && auth.itsId != null) {
        context.read<BroadcastProvider>().load(auth.itsId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BroadcastProvider>();
    final auth = context.watch<AuthProvider>();

    return Column(
      children: [
        _SubHeader(title: 'Broadcast', onBack: widget.onBack),
        Expanded(
          child: auth.isDesignPreview
              ? const Center(child: Text('Design preview — login for live broadcasts.'))
              : provider.isLoading && provider.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => provider.load(auth.itsId ?? ''),
                      child: provider.errorMessage != null && provider.items.isEmpty
                          ? ListView(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(provider.errorMessage!, textAlign: TextAlign.center),
                                ),
                              ],
                            )
                          : ListView.separated(
                              itemCount: provider.items.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                color: AppColors.accent.withValues(alpha: 0.3),
                              ),
                              itemBuilder: (context, index) {
                                final item = provider.items[index];
                                return InkWell(
                                  onTap: () => showBroadcastDetailSheet(context, item),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppColors.cream,
                                                border: Border.all(color: AppColors.accent, width: 2),
                                              ),
                                              child: Text(
                                                'TMK',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Text(
                                                        'TMK Broadcast',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                      if (!provider.isRead(item.id)) ...[
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: AppColors.success,
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: const Text(
                                                            'NEW',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w700,
                                                              color: Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    item.date,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: AppColors.gray400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (item.isPdf)
                                              const Icon(Icons.picture_as_pdf, color: Color(0xFFB91C1C), size: 22)
                                            else if (item.isImage)
                                              const Icon(Icons.image_outlined, color: AppColors.gray400, size: 22)
                                            else if (item.isVideo)
                                              const Icon(Icons.play_circle_outline, color: AppColors.gray400, size: 22),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        BroadcastBodyText(
                                          text: item.displayBody,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF374151),
                                            height: 1.4,
                                          ),
                                        ),
                                        if (item.hasMedia) ...[
                                          const SizedBox(height: 10),
                                          BroadcastMediaView(item: item, compact: true),
                                        ],
                                        if (item.hasLink) ...[
                                          const SizedBox(height: 10),
                                          BroadcastLinkButton(item: item),
                                        ],
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

class _SubHeader extends StatelessWidget {
  const _SubHeader({required this.title, required this.onBack});
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
