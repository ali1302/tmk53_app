import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/models/app_models.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/broadcast_provider.dart';
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
                          Text(
                            item.displayBody,
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

  @override
  Widget build(BuildContext context) {
    final url = item.mediaUrl;
    if (url == null) return const SizedBox.shrink();

    if (item.isImage) {
      return _ImageBlock(url: url, compact: compact);
    }
    if (item.isPdf) {
      return _PdfBlock(url: url, compact: compact);
    }
    if (item.isVideo) {
      return _OpenLinkBlock(
        label: compact ? 'Video' : 'Open video',
        icon: Icons.play_circle_outline,
        url: url,
      );
    }
    return const SizedBox.shrink();
  }
}

class _ImageBlock extends StatelessWidget {
  const _ImageBlock({required this.url, required this.compact});

  final String url;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 120.0 : 280.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: height,
          minWidth: double.infinity,
        ),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          width: double.infinity,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              height: height,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
          errorBuilder: (_, error, stackTrace) => _OpenLinkBlock(
            label: 'Open image',
            icon: Icons.image_outlined,
            url: url,
          ),
        ),
      ),
    );
  }
}

class _PdfBlock extends StatefulWidget {
  const _PdfBlock({required this.url, required this.compact});

  final String url;
  final bool compact;

  @override
  State<_PdfBlock> createState() => _PdfBlockState();
}

class _PdfBlockState extends State<_PdfBlock> {
  WebViewController? _controller;
  var _loading = true;
  var _failed = false;

  bool get _canUseWebView {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    if (!_canUseWebView) {
      _loading = false;
      return;
    }
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) {
              setState(() {
                _loading = false;
                _failed = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.compact ? 140.0 : 360.0;

    if (!_canUseWebView || _failed || _controller == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: widget.compact ? 88 : 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf, size: 36, color: Color(0xFFB91C1C)),
                SizedBox(height: 6),
                Text('PDF attachment', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _OpenLinkBlock(
            label: 'View PDF',
            icon: Icons.picture_as_pdf,
            url: widget.url,
          ),
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            WebViewWidget(controller: _controller!),
            if (_loading)
              const ColoredBox(
                color: Colors.white,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          ],
        ),
      ),
    );
  }
}

class _OpenLinkBlock extends StatelessWidget {
  const _OpenLinkBlock({
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
