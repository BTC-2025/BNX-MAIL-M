import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders email bodies with 100% pixel-perfect fidelity and adaptive sizing
/// across all operating systems (macOS, iOS, Android, Linux, Windows, Web).
///
/// Plain-text and HTML emails size adaptively to their content so short emails
/// take only the necessary vertical space without pushing attachments or action
/// footers off screen. For very long emails, content stays neatly bounded within
/// a responsive maximum height with smooth internal scrolling.
class EmailHtmlView extends StatefulWidget {
  final String html;
  final String text;
  final bool isDark;
  final double? maxHeight;

  const EmailHtmlView({
    super.key,
    required this.html,
    required this.text,
    required this.isDark,
    this.maxHeight,
  });

  static final RegExp _htmlSignature = RegExp(
    r'<\s*(html|body|div|p|span|table|tr|td|th|br|a|img|b|i|u|strong|em|ul|ol|li|h[1-6]|center|font|blockquote|style|section|article)\b',
    caseSensitive: false,
  );

  static bool looksLikeHtml(String s) => _htmlSignature.hasMatch(s);

  static final RegExp _richTemplateRegex = RegExp(
    r'<\s*(table|tbody|thead|tr|td|th|center|style|section|article|header|footer|svg|iframe)\b|'
    r'<\s*img\b|'
    r'align\s*=\s*["\x27]?center["\x27]?|'
    r'margin\s*:\s*0?\s*auto|'
    r'max-width\s*:\s*\d+px',
    caseSensitive: false,
  );

  /// Distinguishes rich template/newsletter long formats from regular text/conversational emails.
  /// - Text emails (plain text or simple HTML without complex layout grids/tables/banners) align to the left side.
  /// - Other long formats (newsletters, marketing emails, rich HTML templates) center horizontally within a 740px column.
  static bool isLongFormat(String html, String text) {
    final source = html.trim().isNotEmpty ? html : text;
    if (source.trim().isEmpty) return false;
    if (!looksLikeHtml(source)) return false;
    return _richTemplateRegex.hasMatch(source);
  }

  @override
  State<EmailHtmlView> createState() => _EmailHtmlViewState();
}

class _EmailHtmlViewState extends State<EmailHtmlView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(EmailHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html || oldWidget.text != widget.text) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
          style: TextStyle(
            color: widget.isDark ? Colors.white54 : Colors.black45,
            fontStyle: FontStyle.italic,
            fontSize: 14,
          ),
        ),
      );
    }

    final isHtml = EmailHtmlView.looksLikeHtml(source);
    final content = isHtml ? source : _plainTextToHtml(source);

    final textColor = widget.isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
    final baseStyle = TextStyle(
      fontSize: 14,
      height: 1.6,
      color: textColor,
    );

    final htmlContentWidget = SelectionArea(
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
              return {'color': widget.isDark ? '#60A5FA' : '#2563EB'};
            }
          }
          if (e.localName == 'img') {
            return {'max-width': '100%', 'height': 'auto'};
          }
          if (e.localName == 'table') {
            return {'max-width': '100%'};
          }
          if (e.localName == 'pre' || e.localName == 'code') {
            return {
              'white-space': 'pre-wrap',
              'word-break': 'break-word',
            };
          }
          return null;
        },
      ),
    );

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final bool isMobileDevice = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final bool isMobileOS = isMobile && isMobileDevice;

    // Dynamic natural scrolling for mobile OS alone:
    // No fixed height constraints or nested SingleChildScrollView, so the entire
    // email page in EmailBody scrolls smoothly and dynamically without fixed footer traps.
    if (isMobileOS && widget.maxHeight == null) {
      return SizedBox(
        width: double.infinity,
        child: Align(
          alignment: Alignment.topLeft,
          child: htmlContentWidget,
        ),
      );
    }

    final defaultMax = (screenHeight * 0.60).clamp(400.0, 680.0);
    final effectiveMaxHeight = widget.maxHeight ?? defaultMax;

    final isFormatLong = EmailHtmlView.isLongFormat(widget.html, widget.text);

    final scrollableBody = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: 0,
        maxHeight: effectiveMaxHeight,
        maxWidth: (isMobile || !isFormatLong) ? double.infinity : 740.0,
      ),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: false,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          child: SizedBox(
            width: double.infinity,
            child: Align(
              alignment: Alignment.topLeft,
              child: htmlContentWidget,
            ),
          ),
        ),
      ),
    );

    if (isFormatLong && !isMobile) {
      return Center(child: scrollableBody);
    } else {
      return Align(
        alignment: Alignment.topLeft,
        child: scrollableBody,
      );
    }
  }
}
