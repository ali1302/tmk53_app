import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/home_provider.dart';

class DuesScreen extends StatefulWidget {
  const DuesScreen({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<DuesScreen> createState() => _DuesScreenState();
}

class _DuesScreenState extends State<DuesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    final auth = context.read<AuthProvider>();
    final home = context.read<HomeProvider>();
    await home.load(
      token: auth.token ?? '',
      itsId: auth.itsId ?? '',
      preview: auth.isDesignPreview,
    );
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final dues = home.details?.dues ?? const [];

    return Material(
      color: AppColors.background,
      child: Column(
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
                  onPressed: widget.onClose,
                  icon: Icon(Icons.chevron_left, color: AppColors.accent),
                ),
                Text(
                  'Dues',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (home.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    ),
                  )
                else
                  IconButton(
                    onPressed: _reload,
                    icon: Icon(Icons.refresh, color: AppColors.accent, size: 20),
                  ),
              ],
            ),
          ),
          Expanded(
            child: home.isLoading && home.details == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        if (home.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              home.errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DUE AMOUNT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: AppColors.accent,
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (dues.isEmpty)
                                Text(
                                  home.isLoading
                                      ? 'Loading dues…'
                                      : 'No outstanding dues found for your sabeel.',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.gray500,
                                  ),
                                )
                              else
                                for (var i = 0; i < dues.length; i++) ...[
                                  if (i > 0)
                                    const Divider(height: 22, color: Color(0xFFF3F4F6)),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              dues[i].lagaat.isEmpty
                                                  ? 'Lagaat'
                                                  : dues[i].lagaat,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF4B5563),
                                              ),
                                            ),
                                            if (dues[i].lastPaidMonth.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2),
                                                child: Text(
                                                  'Paid up to: ${dues[i].lastPaidMonth}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.gray400,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        dues[i].displayAmount,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'monospace',
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
