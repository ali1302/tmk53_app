import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/contact_us_provider.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthProvider>().token ?? '';
      context.read<ContactUsProvider>().load(token: token);
    });
  }

  Future<void> _launch(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open link.')),
      );
    }
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contact = context.watch<ContactUsProvider>();
    final info = contact.info;

    return Material(
      color: const Color(0xFFF5F5F5),
      child: Column(
        children: [
          Container(
            color: AppColors.primary,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 4,
              left: 8,
              right: 8,
              bottom: 12,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(
                    Icons.chevron_left,
                    color: AppColors.accent,
                    size: 28,
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Contact Us',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (contact.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () {
                final token = context.read<AuthProvider>().token ?? '';
                return context.read<ContactUsProvider>().load(token: token);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  if (contact.errorMessage != null && !info.hasContent)
                    Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Text(
                        contact.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF6B7280)),
                      ),
                    )
                  else ...[
                    _sectionCard(
                      title: 'Jamaat Office',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (info.address.isNotEmpty) ...[
                            const Text(
                              'Address',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.gray500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              info.address,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            if (info.mapLink.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => _launch(Uri.parse(info.mapLink)),
                                icon: const Icon(Icons.map_outlined, size: 18),
                                label: const Text('Open in Maps'),
                              ),
                            ],
                          ] else
                            const Text(
                              'Address not available.',
                              style: TextStyle(color: AppColors.gray500),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionCard(
                      title: 'Phone',
                      child: Column(
                        children: [
                          if (info.phones.isEmpty && info.mobiles.isEmpty)
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'No phone numbers available.',
                                style: TextStyle(color: AppColors.gray500),
                              ),
                            )
                          else ...[
                            ...info.phones.map(
                              (p) => _actionTile(
                                icon: Icons.phone_outlined,
                                label: p,
                                onTap: () => _launch(Uri(scheme: 'tel', path: p.replaceAll(' ', ''))),
                                onLongPress: () => _copy(p, 'Phone'),
                              ),
                            ),
                            ...info.mobiles.map(
                              (p) => _actionTile(
                                icon: Icons.smartphone_outlined,
                                label: p,
                                onTap: () => _launch(Uri(scheme: 'tel', path: p.replaceAll(' ', ''))),
                                onLongPress: () => _copy(p, 'Phone'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionCard(
                      title: 'Email & Website',
                      child: Column(
                        children: [
                          if (info.email.isNotEmpty)
                            _actionTile(
                              icon: Icons.email_outlined,
                              label: info.email,
                              onTap: () => _launch(Uri(scheme: 'mailto', path: info.email)),
                              onLongPress: () => _copy(info.email, 'Email'),
                            ),
                          if (info.website.isNotEmpty)
                            _actionTile(
                              icon: Icons.language,
                              label: info.website,
                              onTap: () {
                                final raw = info.website.trim();
                                final url = raw.startsWith('http') ? raw : 'https://$raw';
                                _launch(Uri.parse(url));
                              },
                              onLongPress: () => _copy(info.website, 'Website'),
                            ),
                          if (info.email.isEmpty && info.website.isEmpty)
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'No email or website available.',
                                style: TextStyle(color: AppColors.gray500),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.gray400, size: 20),
          ],
        ),
      ),
    );
  }
}
