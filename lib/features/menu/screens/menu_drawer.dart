import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../feedback/screens/feedback_dialog.dart';
import '../../home/providers/home_provider.dart';

class MenuDrawer extends StatelessWidget {
  const MenuDrawer({
    super.key,
    required this.onCalendar,
    this.onSelfScan,
    this.onDues,
    this.onCommittee,
  });

  final VoidCallback onCalendar;
  final VoidCallback? onSelfScan;
  final VoidCallback? onDues;
  final VoidCallback? onCommittee;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final home = context.watch<HomeProvider>().details;
    final name = home?.user.itsName.isNotEmpty == true
        ? home!.user.itsName
        : (auth.userName?.isNotEmpty == true ? auth.userName! : 'TMK Member');
    final its = home?.user.ejamaatId.isNotEmpty == true
        ? home!.user.ejamaatId
        : (auth.itsId ?? '—');
    final sabeel = home?.user.sabeelNo.trim() ?? '';
    final itsLine = sabeel.isNotEmpty ? 'ITS: $its  ·  Sabeel: $sabeel' : 'ITS: $its';

    return Material(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          itsLine,
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDeep,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4CAF50), width: 3),
                    ),
                    child: const Icon(Icons.person_outline, size: 36, color: Color(0xFF4CAF50)),
                  ),
                ],
              ),
            ),
            _MenuTile(
              icon: Icons.calendar_month,
              label: 'Calendar',
              onTap: onCalendar,
            ),
            _MenuTile(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Dues',
              onTap: onDues,
            ),
            _MenuTile(
              icon: Icons.qr_code_2,
              label: 'History Scan',
              onTap: onSelfScan,
            ),
            _MenuTile(
              icon: Icons.groups_outlined,
              label: 'Jamaat Committee Members',
              onTap: onCommittee,
            ),
            _MenuTile(
              icon: Icons.public,
              label: 'TMK Website',
              trailing: Icon(Icons.open_in_new, size: 15, color: AppColors.accent),
              onTap: () async {
                final auth = context.read<AuthProvider>();
                final url = AppConfig.websiteSsoUrl(auth.token);
                await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
            Container(height: 1, color: AppColors.accent),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.palette_outlined, size: 20, color: AppColors.gray500),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text('Color Themes', style: TextStyle(fontSize: 14, color: Color(0xFF374151))),
                  ),
                  ...[
                    (TmkThemeId.dark, const Color(0xFF1A1A2E)),
                    (TmkThemeId.maroon, const Color(0xFF3D1035)),
                    (TmkThemeId.teal, const Color(0xFF2E7D7D)),
                  ].map((item) {
                    final selected = theme.themeId == item.$1;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: InkWell(
                        onTap: () => theme.setTheme(item.$1),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: item.$2,
                            shape: BoxShape.circle,
                            border: Border.all(color: item.$2, width: 2),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: item.$2.withValues(alpha: 0.55),
                                      blurRadius: 0,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            _MenuTile(
              icon: Icons.chat_bubble_outline,
              label: 'Feedback/Report Error',
              onTap: () => showFeedbackDialog(context),
            ),
            _MenuTile(
              icon: Icons.logout,
              label: 'Logout',
              onTap: () => context.read<AuthProvider>().logout(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.gray500),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF374151))),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
