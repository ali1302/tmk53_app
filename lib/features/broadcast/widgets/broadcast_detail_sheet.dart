import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/app_models.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/broadcast_provider.dart';
import 'broadcast_attachment_viewer.dart';
import 'package:provider/provider.dart';

Future<void> showBroadcastDetailSheet(
  BuildContext context,
  BroadcastItem item,
) async {
  context.read<BroadcastProvider>().markRead(item.id);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final maxHeight = MediaQuery.of(ctx).size.height * 0.9;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'TMK Broadcast',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                if (item.date.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.date,
                    style: const TextStyle(fontSize: 12, color: AppColors.gray400),
                  ),
                ],
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.displayBody.isNotEmpty)
                          BroadcastBodyText(
                            text: item.displayBody,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF374151),
                              height: 1.45,
                            ),
                          ),
                        if (item.hasMedia) ...[
                          if (item.displayBody.isNotEmpty) const SizedBox(height: 14),
                          BroadcastMediaView(item: item),
                        ],
                        if (item.hasLink) ...[
                          if (item.displayBody.isNotEmpty || item.hasMedia)
                            const SizedBox(height: 14),
                          BroadcastLinkButton(item: item),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class BroadcastMediaView extends StatelessWidget {
  const BroadcastMediaView({super.key, required this.item, this.compact = false});

  final BroadcastItem item;
  final bool compact;

  Future<void> _openInApp(BuildContext context) async {
    final url = item.mediaUrl;
    if (url == null) return;
    if (item.isPdf) {
      await openBroadcastAttachment(
        context,
        url: url,
        kind: BroadcastAttachmentKind.pdf,
        title: 'PDF',
      );
      return;
    }
    if (item.isImage) {
      await openBroadcastAttachment(
        context,
        url: url,
        kind: BroadcastAttachmentKind.image,
        title: 'Image',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = item.mediaUrl;
    if (url == null) return const SizedBox.shrink();

    if (item.isImage) {
      return _AttachmentCard(
        compact: compact,
        icon: Icons.image_outlined,
        iconColor: AppColors.primary,
        title: 'Image attachment',
        buttonLabel: 'View Image',
        preview: compact
            ? null
            : _ImagePreview(
                url: url,
                onTap: () => _openInApp(context),
              ),
        onView: () => _openInApp(context),
      );
    }

    if (item.isPdf) {
      return _AttachmentCard(
        compact: compact,
        icon: Icons.picture_as_pdf,
        iconColor: const Color(0xFFB91C1C),
        title: 'PDF attachment',
        buttonLabel: 'View PDF',
        onView: () => _openInApp(context),
      );
    }

    if (item.isVideo) {
      return _OpenExternalLinkBlock(
        label: compact ? 'Video' : 'Open video',
        icon: Icons.play_circle_outline,
        url: url,
      );
    }

    return const SizedBox.shrink();
  }
}

class BroadcastLinkButton extends StatelessWidget {
  const BroadcastLinkButton({super.key, required this.item});

  final BroadcastItem item;

  @override
  Widget build(BuildContext context) {
    final url = item.linkUrl;
    if (url == null) return const SizedBox.shrink();
    return _OpenExternalLinkBlock(
      label: item.linkLabel,
      icon: Icons.link,
      url: url,
    );
  }
}

class BroadcastBodyText extends StatelessWidget {
  const BroadcastBodyText({
    super.key,
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  static final _urlRegex = RegExp(
    r'(https?:\/\/[^\s<>"{}|\\^`\[\]]+|www\.[^\s<>"{}|\\^`\[\]]+)',
    caseSensitive: false,
  );

  Future<void> _open(String raw) async {
    var value = raw.trim();
    while (value.endsWith('.') || value.endsWith(',') || value.endsWith(')')) {
      value = value.substring(0, value.length - 1);
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final matches = _urlRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(text, style: style);
    }

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final urlText = match.group(0)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => _open(urlText),
            child: Text(
              urlText,
              style: style.copyWith(
                color: const Color(0xFF1D4ED8),
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(TextSpan(style: style, children: spans));
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.compact,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.buttonLabel,
    required this.onView,
    this.preview,
  });

  final bool compact;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String buttonLabel;
  final VoidCallback onView;
  final Widget? preview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (preview != null) ...[
          preview!,
          const SizedBox(height: 10),
        ],
        Material(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onView,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: compact ? 10 : 12,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: onView,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(
                      icon == Icons.picture_as_pdf
                          ? Icons.picture_as_pdf
                          : Icons.visibility_outlined,
                      size: 16,
                    ),
                    label: Text(buttonLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.url, required this.onTap});

  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 220,
              minWidth: double.infinity,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.network(
                  url,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 160,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  },
                  errorBuilder: (_, error, stackTrace) {
                    return Container(
                      height: 120,
                      color: const Color(0xFFF3F4F6),
                      alignment: Alignment.center,
                      child: const Text('Image preview unavailable'),
                    );
                  },
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Tap to view',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpenExternalLinkBlock extends StatelessWidget {
  const _OpenExternalLinkBlock({
    required this.label,
    required this.icon,
    required this.url,
  });

  final String label;
  final IconData icon;
  final String url;

  Future<void> _open() async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _open,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
