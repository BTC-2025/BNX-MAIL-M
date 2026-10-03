import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Renders email bodies with 100% pixel-perfect fidelity across platforms.
///
/// On macOS, iOS, and Android: utilizes [WebViewController] (WKWebView / WebView)
/// to execute full CSS stylesheets, responsive tables, flexbox, inline styling,
/// web fonts, images, and buttons exactly like webmail (Gmail/Outlook).
///
/// On Linux/Windows/Web: falls back to [HtmlWidget] with custom CSS builders.
/// Plain-text emails are styled cleanly with paragraphs and clickable links.
class EmailHtmlView extends StatefulWidget {
  final String html;
  final String text;
  final bool isDark;

  const EmailHtmlView({
    super.key,
    required this.html,
    required this.text,
    required this.isDark,
  });

  static final RegExp _htmlSignature = RegExp(
    r'<\s*(html|body|div|p|span|table|tr|td|th|br|a|img|b|i|u|strong|em|ul|ol|li|h[1-6]|center|font|blockquote|style|section|article)\b',
    caseSensitive: false,
  );

  static bool looksLikeHtml(String s) => _htmlSignature.hasMatch(s);

  @override
  State<EmailHtmlView> createState() => _EmailHtmlViewState();
}

class _EmailHtmlViewState extends State<EmailHtmlView> {
  WebViewController? _controller;
  double _webViewHeight = 450.0;
  bool _useWebView = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initRenderer();
  }

  @override
  void didUpdateWidget(EmailHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html ||
        oldWidget.text != widget.text ||
        oldWidget.isDark != widget.isDark) {
      if (_useWebView && _controller != null) {
        _loadWebViewContent();
      } else {
        _initRenderer();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _initRenderer() {
    final source = widget.html.trim().isNotEmpty ? widget.html : widget.text;
    final isHtml = EmailHtmlView.looksLikeHtml(source);

    // WebView is natively supported on macOS (WKWebView), iOS, and Android
    if (isHtml && !kIsWeb && (Platform.isMacOS || Platform.isIOS || Platform.isAndroid)) {
      try {
        _controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (NavigationRequest request) {
                final url = request.url.trim();
                if (url.startsWith('http://') ||
                    url.startsWith('https://') ||
                    url.startsWith('mailto:') ||
                    url.startsWith('tel:')) {
                  final uri = Uri.tryParse(url);
                  if (uri != null) {
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
              onPageFinished: (_) {
                _pollHeight();
              },
            ),
          )
          ..addJavaScriptChannel(
            'HeightChannel',
            onMessageReceived: (JavaScriptMessage message) {
              if (_isDisposed) return;
              final parsed = double.tryParse(message.message);
              if (parsed != null && parsed > 50 && mounted) {
                setState(() {
                  _webViewHeight = parsed + 24; // safety padding
                });
              }
            },
          );

        _useWebView = true;
        _loadWebViewContent();
      } catch (e) {
        debugPrint('[EmailHtmlView] WebView initialization failed: $e');
        _useWebView = false;
      }
    } else {
      _useWebView = false;
    }
  }

  void _pollHeight() {
    if (_isDisposed || _controller == null) return;
    try {
      _controller?.runJavaScript('''
        (function() {
          var body = document.body;
          var html = document.documentElement;
          var h = Math.max(
            body ? body.scrollHeight : 0,
            body ? body.offsetHeight : 0,
            html ? html.clientHeight : 0,
            html ? html.scrollHeight : 0,
            html ? html.offsetHeight : 0
          );
          if (window.HeightChannel && h > 0) {
            window.HeightChannel.postMessage(h.toString());
          }
        })();
      ''');
    } catch (_) {}
  }

  void _loadWebViewContent() {
    if (_controller == null) return;
    final source = widget.html.trim().isNotEmpty ? widget.html : widget.text;
    final isHtml = EmailHtmlView.looksLikeHtml(source);
    final content = isHtml ? source : _plainTextToHtml(source);

    final htmlDocument = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * {
      box-sizing: border-box;
      -webkit-font-smoothing: antialiased;
    }
    html, body {
      margin: 0;
      padding: 0;
      background-color: transparent;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      font-size: 14px;
      line-height: 1.6;
      color: ${widget.isDark ? '#e2e8f0' : '#1e293b'};
      overflow-x: hidden;
      word-wrap: break-word;
    }
    img {
      max-width: 100% !important;
      height: auto !important;
    }
    table {
      max-width: 100% !important;
    }
    a {
      color: #0969da;
    }
    /* Hide tracking pixels */
    img[width="1"][height="1"],
    img[width="0"][height="0"] {
      display: none !important;
    }
  </style>
</head>
<body>
  $content
  <script>
    function reportHeight() {
      try {
        var body = document.body;
        var html = document.documentElement;
        var h = Math.max(
          body ? body.scrollHeight : 0,
          body ? body.offsetHeight : 0,
          html ? html.clientHeight : 0,
          html ? html.scrollHeight : 0,
          html ? html.offsetHeight : 0
        );
        if (window.HeightChannel && h > 50) {
          window.HeightChannel.postMessage(h.toString());
        }
      } catch (e) {}
    }
    window.addEventListener('load', function() {
      reportHeight();
      setTimeout(reportHeight, 150);
      setTimeout(reportHeight, 500);
      setTimeout(reportHeight, 1200);
      setTimeout(reportHeight, 3000);
    });
    window.addEventListener('resize', reportHeight);
    if (window.ResizeObserver) {
      new ResizeObserver(reportHeight).observe(document.body);
    }
    if (window.MutationObserver) {
      new MutationObserver(reportHeight).observe(document.body, { childList: true, subtree: true, attributes: true });
    }
    // Also trigger on any image load
    var images = document.getElementsByTagName('img');
    for (var i = 0; i < images.length; i++) {
      images[i].addEventListener('load', reportHeight);
    }
  </script>
</body>
</html>
''';

    _controller!.loadHtmlString(htmlDocument);
  }

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String _plainTextToHtml(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    if (normalized.isEmpty) return '';
    final urlRe = RegExp(r'(https?://[^\s<>"]+|www\.[^\s<>"]+)', caseSensitive: false);
    final paragraphs = normalized.split(RegExp(r'\n{2,}'));
    final out = StringBuffer();
    for (final p in paragraphs) {
      final lines = p.split('\n').map((line) {
        final buf = StringBuffer();
        var cursor = 0;
        for (final m in urlRe.allMatches(line)) {
          buf.write(_escape(line.substring(cursor, m.start)));
          var url = m.group(0)!;
          var trailing = '';
          while (url.isNotEmpty && '.,;:!?)]}\'"'.contains(url[url.length - 1])) {
            trailing = url[url.length - 1] + trailing;
            url = url.substring(0, url.length - 1);
          }
          final href = url.toLowerCase().startsWith('www.') ? 'https://$url' : url;
          buf.write('<a href="${_escape(href).replaceAll('"', '&quot;')}">${_escape(url)}</a>');
          buf.write(_escape(trailing));
          cursor = m.end;
        }
        buf.write(_escape(line.substring(cursor)));
        return buf.toString();
      }).join('<br>');
      out.write('<p style="margin:0 0 14px 0">$lines</p>');
    }
    return out.toString();
  }

  Future<bool> _openUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    if (!(uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'mailto' || uri.scheme == 'tel')) {
      return false;
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.html.trim().isNotEmpty ? widget.html : widget.text;
    if (source.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '(No Content)',
          style: TextStyle(color: widget.isDark ? Colors.white54 : Colors.black45),
        ),
      );
    }

    final isHtml = EmailHtmlView.looksLikeHtml(source);

    // 1. Native High-Fidelity WebView Engine (macOS, iOS, Android)
    if (_useWebView && _controller != null) {
      return Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SizedBox(
              width: double.infinity,
              height: _webViewHeight,
              child: WebViewWidget(controller: _controller!),
            ),
          ),
        ),
      );
    }

    // 2. Cross-Platform Fallback Engine (Linux, Windows, Web, or WebView fallback)
    final content = isHtml ? source : _plainTextToHtml(source);
    final textColor = isHtml ? const Color(0xFF1F2937) : (widget.isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937));
    final baseStyle = TextStyle(fontSize: 14, height: 1.55, color: textColor);

    final fallbackWidget = SelectionArea(
      child: HtmlWidget(
        content,
        textStyle: baseStyle,
        onTapUrl: _openUrl,
        renderMode: RenderMode.column,
        customStylesBuilder: (e) {
          if (e.localName == 'a') {
            final style = e.attributes['style'] ?? '';
            if (!RegExp(r'(^|;)\s*color\s*:', caseSensitive: false).hasMatch(style) &&
                e.attributes['color'] == null) {
              return {'color': widget.isDark && !isHtml ? '#8AB4F8' : '#0969da'};
            }
          }
          if (e.localName == 'img') {
            return {'max-width': '100%', 'height': 'auto'};
          }
          if (e.localName == 'table') {
            return {'max-width': '100%'};
          }
          return null;
        },
      ),
    );

    if (!isHtml) {
      return Align(alignment: Alignment.topLeft, child: fallbackWidget);
    }

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: fallbackWidget,
        ),
      ),
    );
  }
}
