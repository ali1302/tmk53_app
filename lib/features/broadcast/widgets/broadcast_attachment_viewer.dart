import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_theme.dart';

enum BroadcastAttachmentKind { image, pdf }

Future<void> openBroadcastAttachment(
  BuildContext context, {
  required String url,
  required BroadcastAttachmentKind kind,
  String title = '',
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => BroadcastAttachmentViewer(
        url: url,
        kind: kind,
        title: title,
      ),
    ),
  );
}

class BroadcastAttachmentViewer extends StatefulWidget {
  const BroadcastAttachmentViewer({
    super.key,
    required this.url,
    required this.kind,
    this.title = '',
  });

  final String url;
  final BroadcastAttachmentKind kind;
  final String title;

  @override
  State<BroadcastAttachmentViewer> createState() =>
      _BroadcastAttachmentViewerState();
}

class _BroadcastAttachmentViewerState extends State<BroadcastAttachmentViewer> {
  WebViewController? _controller;
  var _loading = true;
  var _failed = false;
  String? _errorMessage;

  bool get _canUseWebView {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  String get _viewerTitle {
    if (widget.title.trim().isNotEmpty) return widget.title.trim();
    return widget.kind == BroadcastAttachmentKind.pdf ? 'PDF' : 'Image';
  }

  /// Prefer Google Docs viewer for raw .pdf files; keep site HTML viewers as-is.
  String get _pdfLoadUrl {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return widget.url;
    final path = uri.path.toLowerCase();
    final isHtmlViewer = path.contains('/pdf/index/');
    final isRawPdf = path.endsWith('.pdf');
    if (!isHtmlViewer && isRawPdf) {
      return Uri.https(
        'docs.google.com',
        '/gview',
        {'embedded': 'true', 'url': widget.url},
      ).toString();
    }
    return widget.url;
  }

  @override
  void initState() {
    super.initState();
    if (widget.kind == BroadcastAttachmentKind.pdf) {
      _initPdfWebView();
    } else {
      _loading = false;
    }
  }

  void _initPdfWebView() {
    if (!_canUseWebView) {
      _loading = false;
      _failed = true;
      _errorMessage = 'PDF viewer is not available on this device.';
      return;
    }
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _loading = true;
                _failed = false;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _loading = false;
                _failed = true;
                _errorMessage = error.description.isNotEmpty
                    ? error.description
                    : 'Unable to load PDF.';
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_pdfLoadUrl));
    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.kind == BroadcastAttachmentKind.image
          ? Colors.black
          : Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.accent,
        title: Text(
          _viewerTitle,
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.accent),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: widget.kind == BroadcastAttachmentKind.image
          ? _buildImageBody()
          : _buildPdfBody(),
    );
  }

  Widget _buildImageBody() {
    return Stack(
      fit: StackFit.expand,
      children: [
        InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Center(
            child: Image.network(
              widget.url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
              errorBuilder: (_, error, stackTrace) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Unable to load image.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPdfBody() {
    if (_failed || _controller == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf, size: 48, color: Color(0xFFB91C1C)),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Unable to open PDF in the app.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _failed = false;
                    _loading = true;
                    _errorMessage = null;
                  });
                  _initPdfWebView();
                  setState(() {});
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
        if (_loading)
          const ColoredBox(
            color: Colors.white,
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
