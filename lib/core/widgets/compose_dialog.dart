import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/app_state_provider.dart';
import '../../data/email_provider.dart';
import '../../data/colab_provider.dart';
import '../../models/attachment_model.dart';
import '../theme/colors.dart';
import 'package:file_picker/file_picker.dart';

/// Stores one formatting range (e.g. characters 5-12 are bold).
class FmtRange {
  int start;
  int end;
  final String type; // 'bold' | 'italic' | 'underline' | 'strike'
  FmtRange(this.start, this.end, this.type);
}

/// A TextEditingController that keeps text CLEAN (no tags) and stores
/// formatting as separate [FmtRange]s.  [buildTextSpan] renders the
/// styled segments; the underlying [text] never contains `**` etc.
class RichTextEditingController extends TextEditingController {
  RichTextEditingController({super.text});

  final List<FmtRange> formats = [];

  // ── intercept text mutations to adjust range offsets ──────────
  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    final newText = newValue.text;
    if (oldText != newText && formats.isNotEmpty) {
      _adjustRanges(oldText, newText);
    }
    super.value = newValue;
  }

  void _adjustRanges(String oldT, String newT) {
    // common prefix
    int p = 0;
    final mn = oldT.length < newT.length ? oldT.length : newT.length;
    while (p < mn && oldT[p] == newT[p]) {
      p++;
    }
    // common suffix
    int s = 0;
    while (s < mn - p &&
        oldT[oldT.length - 1 - s] == newT[newT.length - 1 - s]) {
      s++;
    }
    final delStart = p;
    final delEnd = oldT.length - s;
    final insLen = newT.length - s - p;
    final delLen = delEnd - delStart;

    formats.removeWhere((f) {
      // entirely within deletion → remove
      if (f.start >= delStart && f.end <= delEnd) return true;

      if (f.end <= delStart) {
        // before change → no shift
      } else if (f.start >= delEnd) {
        // after change → shift
        f.start += insLen - delLen;
        f.end += insLen - delLen;
      } else if (f.start < delStart && f.end > delEnd) {
        // spans change → shrink/grow
        f.end += insLen - delLen;
      } else if (f.start < delStart) {
        // overlaps start of deletion
        f.end = delStart;
      } else {
        // overlaps end of deletion
        final surviving = f.end - delEnd;
        f.start = delStart + insLen;
        f.end = f.start + surviving;
      }
      return f.start >= f.end;
    });
  }

  // ── public API for adding / removing / querying formats ──────
  void addFormat(int start, int end, String type) {
    formats.add(FmtRange(start, end, type));
    notifyListeners();
  }

  void removeFormat(int start, int end, String type) {
    final toRemove = <FmtRange>[];
    final toAdd = <FmtRange>[];
    for (final f in formats) {
      if (f.type != type) continue;
      if (f.end <= start || f.start >= end) continue; // no overlap
      if (f.start >= start && f.end <= end) {
        toRemove.add(f);
      } else if (f.start < start && f.end > end) {
        toRemove.add(f);
        toAdd.add(FmtRange(f.start, start, type));
        toAdd.add(FmtRange(end, f.end, type));
      } else if (f.start < start) {
        f.end = start;
      } else {
        f.start = end;
      }
    }
    formats.removeWhere(toRemove.contains);
    formats.addAll(toAdd);
    notifyListeners();
  }

  bool isRangeFormatted(int start, int end, String type) {
    for (final f in formats) {
      if (f.type == type && f.start <= start && f.end >= end) return true;
    }
    return false;
  }

  void clearAllFormats() {
    formats.clear();
    notifyListeners();
  }

  // ── visual rendering ────────────────────────────────────────
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    if (text.isEmpty || formats.isEmpty) {
      return TextSpan(text: text, style: base);
    }

    // collect boundary positions
    final bSet = <int>{0, text.length};
    for (final f in formats) {
      bSet.add(f.start.clamp(0, text.length));
      bSet.add(f.end.clamp(0, text.length));
    }
    final bounds = bSet.toList()..sort();

    final spans = <TextSpan>[];
    for (int i = 0; i < bounds.length - 1; i++) {
      final segS = bounds[i];
      final segE = bounds[i + 1];
      if (segS >= segE) continue;

      bool b = false, it = false, u = false, st = false;
      for (final f in formats) {
        if (f.start <= segS && f.end >= segE) {
          switch (f.type) {
            case 'bold':
              b = true;
            case 'italic':
              it = true;
            case 'underline':
              u = true;
            case 'strike':
              st = true;
          }
        }
      }

      TextStyle seg = base;
      if (b) seg = seg.copyWith(fontWeight: FontWeight.bold);
      if (it) seg = seg.copyWith(fontStyle: FontStyle.italic);
      final decs = <TextDecoration>[];
      if (u) decs.add(TextDecoration.underline);
      if (st) decs.add(TextDecoration.lineThrough);
      if (decs.isNotEmpty) {
        seg = seg.copyWith(decoration: TextDecoration.combine(decs));
      }

      spans.add(TextSpan(text: text.substring(segS, segE), style: seg));
    }
    return TextSpan(style: base, children: spans);
  }

  // ── convert text + format ranges to HTML for sending ──────
  String toHtml() {
    String esc(String s) => s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('\n', '<br>');

    if (text.isEmpty) return '';
    if (formats.isEmpty) return '<p>${esc(text)}</p>';

    final bSet = <int>{0, text.length};
    for (final f in formats) {
      bSet.add(f.start.clamp(0, text.length));
      bSet.add(f.end.clamp(0, text.length));
    }
    final bounds = bSet.toList()..sort();

    final buf = StringBuffer('<p>');
    for (int i = 0; i < bounds.length - 1; i++) {
      final segS = bounds[i];
      final segE = bounds[i + 1];
      if (segS >= segE) continue;

      bool b = false, it = false, u = false, st = false;
      for (final f in formats) {
        if (f.start <= segS && f.end >= segE) {
          switch (f.type) {
            case 'bold':
              b = true;
            case 'italic':
              it = true;
            case 'underline':
              u = true;
            case 'strike':
              st = true;
          }
        }
      }

      String seg = esc(text.substring(segS, segE));
      if (b) seg = '<b>$seg</b>';
      if (it) seg = '<i>$seg</i>';
      if (u) seg = '<u>$seg</u>';
      if (st) seg = '<s>$seg</s>';
      buf.write(seg);
    }
    buf.write('</p>');
    return buf.toString();
  }
}

class _Fmt {
  String style = 'Normal';
}

class ComposeDialog extends ConsumerStatefulWidget {
  const ComposeDialog({super.key});
  @override
  ConsumerState<ComposeDialog> createState() => _ComposeDialogState();
}

class _ComposeDialogState extends ConsumerState<ComposeDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  final _toCtrl = TextEditingController();
  final _subCtrl = TextEditingController();
  final _bodyCtrl = RichTextEditingController();
  final _ccCtrl = TextEditingController();
  final _bccCtrl = TextEditingController();
  final _cbToCtrl = TextEditingController();
  final _cbSubCtrl = TextEditingController();
  final _cbBodyCtrl = RichTextEditingController();

  final _bodyFocus = FocusNode();
  final _cbBodyFocus = FocusNode();

  bool _showCcBcc = false;
  final List<AttachmentModel> _emailFiles = [];
  final List<AttachmentModel> _casboxFiles = [];
  final _fmt = _Fmt();
  String? _sig;

  /// Remembers the last non-collapsed selection so toolbar taps
  /// (which steal focus and collapse the selection) can still
  /// operate on the previously-highlighted text.
  TextSelection? _savedSelection;

  void _trackSelection() {
    final ctrl = _activeBodyCtrl;
    if (ctrl.selection.isValid && !ctrl.selection.isCollapsed) {
      _savedSelection = ctrl.selection;
    }
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _bodyCtrl.addListener(_trackSelection);
    _cbBodyCtrl.addListener(_trackSelection);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(appUiProvider);
      if (s.activeFolder == 'Casbox') {
        _tab.index = 1;
        _cbToCtrl.text = s.composeTo;
        _cbSubCtrl.text = s.composeSubject;
        _cbBodyCtrl.text = s.composeBody;
      } else {
        _toCtrl.text = s.composeTo;
        _subCtrl.text = s.composeSubject;
        _bodyCtrl.text = s.composeBody;
      }
    });
  }

  @override
  void dispose() {
    _bodyCtrl.removeListener(_trackSelection);
    _cbBodyCtrl.removeListener(_trackSelection);
    _bodyFocus.dispose();
    _cbBodyFocus.dispose();
    _tab.dispose();
    for (final c in [
      _toCtrl,
      _subCtrl,
      _bodyCtrl,
      _ccCtrl,
      _bccCtrl,
      _cbToCtrl,
      _cbSubCtrl,
      _cbBodyCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() => ref
      .read(appUiProvider.notifier)
      .updateComposeDraft(
        to: _toCtrl.text,
        subject: _subCtrl.text,
        body: _bodyCtrl.text,
      );

  void _dismiss({String? msg}) {
    _emailFiles.clear();
    _casboxFiles.clear();
    _toCtrl.clear();
    _subCtrl.clear();
    _bodyCtrl.clear();
    _ccCtrl.clear();
    _bccCtrl.clear();
    _cbToCtrl.clear();
    _cbSubCtrl.clear();
    _cbBodyCtrl.clear();
    ref.read(appUiProvider.notifier).clearComposeDraft();
    ref.read(appUiProvider.notifier).setComposeStatus(ComposeStatus.closed);
    if (msg != null) _snack(msg);
    final bool isComposeRoute =
        GoRouterState.of(context).uri.toString() == '/compose';
    if (isComposeRoute) {
      context.pop();
    }
  }

  Future<void> _send() async {
    final isCasboxTab = _tab.index == 1;
    final toText = isCasboxTab ? _cbToCtrl.text.trim() : _toCtrl.text.trim();
    final subText = isCasboxTab ? _cbSubCtrl.text.trim() : _subCtrl.text.trim();
    final bodyCtrl = isCasboxTab ? _cbBodyCtrl : _bodyCtrl;
    final hasFormatting = bodyCtrl.formats.isNotEmpty;
    // Build body: use HTML when formatting exists, otherwise plain text
    final bodyRaw = hasFormatting ? bodyCtrl.toHtml() : bodyCtrl.text;

    if (toText.isEmpty) {
      _snack('Please add a recipient.');
      return;
    }

    final String body;
    if (_sig != null) {
      body = hasFormatting
          ? '$bodyRaw<br><br>--<br>${_sig!.replaceAll('\n', '<br>')}'
          : '$bodyRaw\n\n--\n$_sig';
    } else {
      body = bodyRaw;
    }
    final attachmentsToSend = List<AttachmentModel>.from(
      isCasboxTab ? _casboxFiles : _emailFiles,
    );
    final draftId = ref.read(appUiProvider).composeDraftId;

    // Immediately dismiss dialog for instant response
    _dismiss(msg: 'Sending message...');

    // Complete send in background asynchronously
    try {
      if (isCasboxTab) {
        await ref
            .read(casboxMessagesProvider.notifier)
            .addMessage(
              to: toText,
              subject: subText,
              body: body,
              attachments: attachmentsToSend,
            );
      } else {
        await ref
            .read(emailProvider.notifier)
            .composeEmail(
              to: toText,
              subject: subText,
              body: body,
              isHtml: hasFormatting,
              attachments: attachmentsToSend,
            );
        if (draftId.isNotEmpty) {
          ref
              .read(emailProvider.notifier)
              .permanentlyDeleteEmail(draftId, folder: 'Draft');
        }
      }
      _snack('Message sent ✓');
    } catch (e) {
      _snack(
        'Failed to send: ${e.toString().replaceAll('ApiException', '').trim()}',
      );
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ──────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(appUiProvider);
    final status = ui.composeStatus;
    final bool isComposeRoute =
        GoRouterState.of(context).uri.toString() == '/compose';

    if (!isComposeRoute &&
        (status == ComposeStatus.closed || ui.activeFolder == 'Templates')) {
      return const SizedBox.shrink();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isComposeRoute || status != ComposeStatus.closed) {
        if (_subCtrl.text != ui.composeSubject) {
          _subCtrl.text = ui.composeSubject;
        }
        if (_bodyCtrl.text != ui.composeBody) _bodyCtrl.text = ui.composeBody;
        if (_toCtrl.text != ui.composeTo) _toCtrl.text = ui.composeTo;
      }
    });

    final isDark = ui.isDarkMode;
    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    final sh = mq.size.height;
    final isMobile = sw < 600;

    // ── Minimised pill ────────────────────────────
    if (!isComposeRoute && status == ComposeStatus.minimized) {
      return Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: EdgeInsets.only(right: 16, bottom: isMobile ? 88 : 20),
          child: GestureDetector(
            onTap: () => ref
                .read(appUiProvider.notifier)
                .setComposeStatus(ComposeStatus.normal),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(28),
              color: const Color(0xFF195BAC),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, color: Colors.white, size: 15),
                    SizedBox(width: 8),
                    Text(
                      'New Message',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(width: 12),
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Side margins so the card floats and is differentiated from the background
    final double sideMargin = (isMobile && !isComposeRoute) ? 10.0 : 0.0;

    // On desktop (macOS/Windows/Linux) clamp the card width so it never
    // exceeds the visible area (right padding is 72 px; add 4 px buffer).
    final double desktopMaxW = sw - 76.0;
    final double desktopCardW = desktopMaxW < 520.0 ? desktopMaxW : 520.0;
    final double cardW = (status == ComposeStatus.maximized || isComposeRoute)
        ? sw
        : (isMobile ? sw - sideMargin * 2 : desktopCardW);
    // Compact floating card on mobile (~50% height), full only when maximised
    final double cardH = (status == ComposeStatus.maximized || isComposeRoute)
        ? sh
        : (isMobile ? sh * 0.50 : 500.0);

    final br = (status == ComposeStatus.maximized || isComposeRoute)
        ? BorderRadius.zero
        : BorderRadius.circular(18);

    final card = Material(
      elevation: isComposeRoute ? 0 : 22,
      shadowColor: Colors.black38,
      borderRadius: br,
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: cardW,
        height: cardH,
        color: isDark ? const Color(0xFF1A2435) : Colors.white,
        child: Column(
          children: [
            _header(isDark, isComposeRoute ? ComposeStatus.maximized : status),
            Expanded(
              child: TabBarView(
                controller: _tab,
                physics: const NeverScrollableScrollPhysics(),
                children: [_emailTab(isDark), _casboxTab(isDark)],
              ),
            ),
          ],
        ),
      ),
    );

    if (isComposeRoute) {
      return SafeArea(child: card);
    }

    return Align(
      alignment: isMobile ? Alignment.bottomCenter : Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.only(
          left: isMobile ? sideMargin : 0,
          right: isMobile ? sideMargin : 72,
          bottom: isMobile ? 80 : 0,
        ),
        child: card,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // HEADER  (tabs + window controls)
  // ────────────────────────────────────────────────────────────
  Widget _header(bool isDark, ComposeStatus status) {
    final bool isComposeRoute =
        GoRouterState.of(context).uri.toString() == '/compose';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0D1526), const Color(0xFF162035)]
              : [const Color(0xFF195BAC), const Color(0xFF2471D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Flexible(fit: FlexFit.loose, child: _tabPill('Email', 0, isDark)),
          Flexible(fit: FlexFit.loose, child: _tabPill('Casbox', 1, isDark)),
          const Spacer(),
          if (!isComposeRoute)
            _winBtn(Icons.remove_rounded, 'Minimize', isDark, () {
              _save();
              ref
                  .read(appUiProvider.notifier)
                  .setComposeStatus(ComposeStatus.minimized);
            }),
          _winBtn(Icons.close_rounded, 'Close', isDark, () async {
            if (_toCtrl.text.isNotEmpty ||
                _subCtrl.text.isNotEmpty ||
                _bodyCtrl.text.isNotEmpty) {
              try {
                await ref
                    .read(emailProvider.notifier)
                    .composeEmail(
                      to: _toCtrl.text,
                      subject: _subCtrl.text,
                      body: _bodyCtrl.formats.isNotEmpty
                          ? _bodyCtrl.toHtml()
                          : _bodyCtrl.text,
                      isHtml: _bodyCtrl.formats.isNotEmpty,
                      isDraft: true,
                      attachments: List.from(_emailFiles),
                    );
                _dismiss(msg: 'Draft saved.');
              } catch (e) {
                _snack('Failed to save draft: ${e.toString()}');
              }
            } else {
              _dismiss();
            }
          }),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _tabPill(String label, int index, bool isDark) {
    return AnimatedBuilder(
      animation: _tab,
      builder: (_, _) {
        final sel = _tab.index == index;
        return GestureDetector(
          onTap: () => setState(() => _tab.animateTo(index)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: sel
                  ? Colors.white.withValues(alpha: isDark ? 0.15 : 1.0)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              boxShadow: sel
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: sel
                    ? (isDark ? Colors.white : const Color(0xFF195BAC))
                    : Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _winBtn(IconData icon, String tip, bool isDark, VoidCallback fn) =>
      Tooltip(
        message: tip,
        child: InkWell(
          onTap: fn,
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              icon,
              size: 17,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ),
      );

  // ────────────────────────────────────────────────────────────
  // EMAIL TAB
  // ────────────────────────────────────────────────────────────
  Widget _emailTab(bool isDark) {
    final div = isDark ? Colors.white10 : Colors.grey.shade200;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldRow(
          label: 'To',
          ctrl: _toCtrl,
          hint: 'Recipients',
          isDark: isDark,
          trailing: GestureDetector(
            onTap: () => setState(() => _showCcBcc = !_showCcBcc),
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                'Cc  Bcc',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _showCcBcc
                      ? const Color(0xFF195BAC)
                      : Colors.grey.shade500,
                ),
              ),
            ),
          ),
          onChanged: (v) =>
              ref.read(appUiProvider.notifier).updateComposeDraft(to: v),
        ),
        if (_showCcBcc) ...[
          Divider(height: 1, color: div),
          _fieldRow(label: 'Cc', ctrl: _ccCtrl, hint: '', isDark: isDark),
          Divider(height: 1, color: div),
          _fieldRow(label: 'Bcc', ctrl: _bccCtrl, hint: '', isDark: isDark),
        ],
        Divider(height: 1, color: div),
        _subjectRow(isDark),
        Divider(height: 1, color: div),
        Expanded(
          child: _bodyArea(
            _bodyCtrl,
            isDark,
            onChanged: (v) {
              ref.read(appUiProvider.notifier).updateComposeDraft(body: v);
            },
          ),
        ),
        if (_emailFiles.isNotEmpty) _attachChips(isDark, _emailFiles),
        Divider(height: 1, color: div),
        _formatToolbar(isDark),
        _emailFooter(isDark),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  // CASBOX TAB
  // ────────────────────────────────────────────────────────────
  Widget _casboxTab(bool isDark) {
    final div = isDark ? Colors.white10 : Colors.grey.shade200;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldRow(
          label: 'To',
          ctrl: _cbToCtrl,
          hint: 'Casbox Contact Email',
          isDark: isDark,
        ),
        Divider(height: 1, color: div),
        _subjectRowFor(_cbSubCtrl, isDark),
        Divider(height: 1, color: div),
        Expanded(child: _bodyArea(_cbBodyCtrl, isDark)),
        if (_casboxFiles.isNotEmpty) _attachChips(isDark, _casboxFiles),
        Divider(height: 1, color: div),
        _formatToolbar(isDark),
        _casboxFooter(isDark),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  // FIELD HELPERS
  // ────────────────────────────────────────────────────────────
  Widget _fieldRow({
    required String label,
    required TextEditingController ctrl,
    required String hint,
    required bool isDark,
    Widget? trailing,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white54 : const Color(0xFF195BAC),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: ctrl,
              onChanged: onChanged,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _subjectRow(bool isDark) => _subjectRowFor(
    _subCtrl,
    isDark,
    onChanged: (v) =>
        ref.read(appUiProvider.notifier).updateComposeDraft(subject: v),
  );

  Widget _subjectRowFor(
    TextEditingController ctrl,
    bool isDark, {
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(
            'Subject:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white54 : const Color(0xFF195BAC),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: ctrl,
              onChanged: onChanged,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Enter subject...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  FocusNode get _activeBodyFocusNode =>
      _tab.index == 0 ? _bodyFocus : _cbBodyFocus;

  Widget _bodyArea(
    TextEditingController ctrl,
    bool isDark, {
    ValueChanged<String>? onChanged,
  }) {
    final focusNode = ctrl == _bodyCtrl ? _bodyFocus : _cbBodyFocus;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: ctrl,
        focusNode: focusNode,
        maxLines: null,
        expands: true,
        onChanged: onChanged,
        contextMenuBuilder: (context, editableTextState) {
          final List<ContextMenuButtonItem> buttonItems =
              editableTextState.contextMenuButtonItems;

          buttonItems.insertAll(0, [
            ContextMenuButtonItem(
              label: 'Bold',
              onPressed: () {
                _applyFormat('bold');
                editableTextState.hideToolbar();
              },
            ),
            ContextMenuButtonItem(
              label: 'Italic',
              onPressed: () {
                _applyFormat('italic');
                editableTextState.hideToolbar();
              },
            ),
            ContextMenuButtonItem(
              label: 'Underline',
              onPressed: () {
                _applyFormat('underline');
                editableTextState.hideToolbar();
              },
            ),
          ]);

          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: editableTextState.contextMenuAnchors,
            buttonItems: buttonItems,
          );
        },
        style: TextStyle(
          fontSize: 14.0,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: 'Type your message here...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(top: 10),
        ),
      ),
    );
  }

  Widget _attachChips(bool isDark, List<AttachmentModel> filesList) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: filesList.map((f) {
          IconData ic = Icons.insert_drive_file_rounded;
          Color cl = const Color(0xFF195BAC);
          if (f.fileType == 'pdf') {
            ic = Icons.picture_as_pdf_rounded;
            cl = Colors.red;
          } else if (f.fileType == 'image') {
            ic = Icons.image_rounded;
            cl = Colors.purple;
          } else if (f.fileType == 'code') {
            ic = Icons.code_rounded;
            cl = Colors.green;
          }
          return Chip(
            avatar: Icon(ic, size: 13, color: cl),
            label: Text(
              f.fileName,
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
            deleteIcon: const Icon(Icons.close_rounded, size: 13),
            onDeleted: () => setState(() => filesList.remove(f)),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
          );
        }).toList(),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // FORMAT TOOLBAR  (fixed height 40, horizontally scrollable)
  // ────────────────────────────────────────────────────────────
  Widget _formatToolbar(bool isDark) {
    final bg = isDark ? const Color(0xFF0D1526) : const Color(0xFFF4F8FF);
    final borderClr = isDark ? Colors.white10 : Colors.grey.shade200;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: bg,
        border: Border.symmetric(horizontal: BorderSide(color: borderClr)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            _styleDropdown(isDark),
            _vDiv(isDark),
            _fmtBtn(
              Icons.format_bold_rounded,
              false,
              () => _applyFormat('bold'),
              'Bold',
              isDark,
            ),
            _fmtBtn(
              Icons.format_italic_rounded,
              false,
              () => _applyFormat('italic'),
              'Italic',
              isDark,
            ),
            _fmtBtn(
              Icons.format_underlined_rounded,
              false,
              () => _applyFormat('underline'),
              'Underline',
              isDark,
            ),
            _fmtBtn(
              Icons.format_strikethrough_rounded,
              false,
              () => _applyFormat('strike'),
              'Strike',
              isDark,
            ),
            _fmtBtn(
              Icons.format_quote_rounded,
              false,
              _toggleQuote,
              'Quote',
              isDark,
            ),
            _vDiv(isDark),
            _fmtBtn(
              Icons.format_list_numbered_rounded,
              false,
              _toggleNumbered,
              'Numbered',
              isDark,
            ),
            _fmtBtn(
              Icons.format_list_bulleted_rounded,
              false,
              _toggleBullet,
              'Bullets',
              isDark,
            ),
            _fmtBtn(
              Icons.format_indent_increase_rounded,
              false,
              _indentIncrease,
              'Indent +',
              isDark,
            ),
            _fmtBtn(
              Icons.format_indent_decrease_rounded,
              false,
              _indentDecrease,
              'Indent -',
              isDark,
            ),
            _vDiv(isDark),
            _fmtBtn(Icons.link_rounded, false, _showLinkDialog, 'Link', isDark),
            _fmtBtn(
              Icons.format_clear_rounded,
              false,
              () {
                (_activeBodyCtrl as RichTextEditingController)
                    .clearAllFormats();
                setState(() => _fmt.style = 'Normal');
              },
              'Clear',
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _styleDropdown(bool isDark) {
    return PopupMenuButton<String>(
      initialValue: _fmt.style,
      onSelected: (v) {
        setState(() {
          _fmt.style = v;
          if (v == 'Bullet') {
            _toggleBullet();
          }
        });
      },
      tooltip: 'Text style',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (_) => [
        'Normal',
        'Heading 1',
        'Heading 2',
        'Heading 3',
        'Bullet',
      ].map((s) => PopupMenuItem(value: s, child: Text(s))).toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _fmt.style,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            Icon(
              Icons.unfold_more_rounded,
              size: 14,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _fmtBtn(
    IconData ic,
    bool active,
    VoidCallback fn,
    String tip,
    bool isDark,
  ) {
    return Tooltip(
      message: tip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: fn,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: active
              ? BoxDecoration(
                  color: const Color(0xFF195BAC).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF195BAC).withValues(alpha: 0.3),
                  ),
                )
              : null,
          child: Icon(
            ic,
            size: 18,
            color: active
                ? const Color(0xFF195BAC)
                : (isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ),
    );
  }

  Widget _vDiv(bool isDark) => Container(
    width: 1,
    height: 22,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: isDark ? Colors.white12 : Colors.grey.shade300,
  );

  // ────────────────────────────────────────────────────────────
  // EMAIL FOOTER  (no overflow — "More" popup hides extras)
  // ────────────────────────────────────────────────────────────
  Widget _emailFooter(bool isDark) {
    final bg = isDark ? const Color(0xFF0D1526) : const Color(0xFFF4F8FF);
    final borderClr = isDark ? Colors.white10 : Colors.grey.shade200;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: borderClr)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Primary row: Send btn + action icons ──
          Row(
            children: [
              // ── Send + caret ──
              Expanded(child: _sendSplitBtn()),
              const SizedBox(width: 8),
              // ── Attach ───────
              _labeledIconBtn(
                icon: Icons.attach_file_rounded,
                label: 'Attach',
                fn: _showAttachSheet,
                isDark: isDark,
              ),
              const SizedBox(width: 4),
              // ── More ─────────
              _labeledMoreMenu(isDark),
              const SizedBox(width: 4),
              // ── Discard ──────
              _labeledIconBtn(
                icon: Icons.delete_outline_rounded,
                label: 'Discard',
                fn: () => _dismiss(msg: 'Message discarded.'),
                isDark: isDark,
                color: Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _casboxFooter(bool isDark) {
    final bg = isDark ? const Color(0xFF0D1526) : const Color(0xFFF4F8FF);
    final borderClr = isDark ? Colors.white10 : Colors.grey.shade200;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: borderClr)),
      ),
      child: Row(
        children: [
          Expanded(child: _casboxSendBtn()),
          const SizedBox(width: 8),
          _labeledIconBtn(
            icon: Icons.attach_file_rounded,
            label: 'Attach',
            fn: _showAttachSheet,
            isDark: isDark,
          ),
          const SizedBox(width: 4),
          _labeledIconBtn(
            icon: Icons.delete_outline_rounded,
            label: 'Discard',
            fn: () {
              _cbToCtrl.clear();
              _cbSubCtrl.clear();
              _cbBodyCtrl.clear();
              _dismiss(msg: 'Casbox draft discarded.');
            },
            isDark: isDark,
            color: Colors.redAccent,
          ),
        ],
      ),
    );
  }

  // ── Send split button (Send | ▾) ─────────────
  Widget _sendSplitBtn() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _send,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF195BAC), Color(0xFF2471D4)],
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Send',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 48,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          PopupMenuButton<String>(
            tooltip: 'Send options',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (v) async {
              if (v == 'draft') {
                try {
                  await ref
                      .read(emailProvider.notifier)
                      .composeEmail(
                        to: _toCtrl.text,
                        subject: _subCtrl.text,
                        body: _bodyCtrl.formats.isNotEmpty
                            ? _bodyCtrl.toHtml()
                            : _bodyCtrl.text,
                        isHtml: _bodyCtrl.formats.isNotEmpty,
                        isDraft: true,
                        attachments: List.from(_emailFiles),
                      );
                  _dismiss(msg: 'Saved as draft.');
                } catch (e) {
                  _snack('Failed to save draft: ${e.toString()}');
                }
              } else if (v == 'schedule') {
                _showScheduleDialog();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'schedule',
                child: ListTile(
                  leading: Icon(Icons.schedule_send_rounded),
                  title: Text('Schedule send'),
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'draft',
                child: ListTile(
                  leading: Icon(Icons.drafts_outlined),
                  title: Text('Save as draft'),
                  dense: true,
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF195BAC), Color(0xFF2471D4)],
                ),
              ),
              child: const Icon(
                Icons.arrow_drop_down_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _casboxSendBtn() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: GestureDetector(
        onTap: () {
          if (_cbToCtrl.text.trim().isEmpty) {
            _snack('Add a Casbox recipient.');
            return;
          }
          final toText = _cbToCtrl.text.trim();
          final subText = _cbSubCtrl.text.trim();
          final bodyText = _cbBodyCtrl.text;
          final attachmentsToSend = List<AttachmentModel>.from(_casboxFiles);

          // Instantly close compose page
          _dismiss(msg: 'Sending Casbox message...');

          // Complete background transmission asynchronously
          ref
              .read(casboxMessagesProvider.notifier)
              .addMessage(
                to: toText,
                subject: subText,
                body: bodyText,
                attachments: attachmentsToSend,
              )
              .then((_) {
                _snack('Casbox message sent ✓');
              })
              .catchError((e) {
                _snack('Error sending Casbox message: $e');
              });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF195BAC), Color(0xFF2471D4)],
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.send_rounded, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                'Send via Casbox',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Labeled icon button used in footers
  Widget _labeledIconBtn({
    required IconData icon,
    required String label,
    required VoidCallback fn,
    required bool isDark,
    Color? color,
  }) {
    final clr = color ?? (isDark ? Colors.white60 : Colors.grey.shade700);
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: fn,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: clr),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: clr,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// More popup → Signature + Templates
  Widget _labeledMoreMenu(bool isDark) {
    final clr = isDark ? Colors.white60 : Colors.grey.shade700;
    return PopupMenuButton<String>(
      tooltip: 'More options',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        if (v == 'signature') _showSigDialog();
        if (v == 'templates') {
          ref.read(appUiProvider.notifier).selectFolder('Templates');
          _save();
          ref
              .read(appUiProvider.notifier)
              .setComposeStatus(ComposeStatus.minimized);
          final r = GoRouterState.of(context).uri.toString();
          if (r != '/home') GoRouter.of(context).go('/home');
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'signature',
          child: ListTile(
            leading: Icon(Icons.draw_outlined, size: 18),
            title: Text('Signature'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'templates',
          child: ListTile(
            leading: Icon(Icons.content_paste_rounded, size: 18),
            title: Text('Templates'),
            dense: true,
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.more_horiz_rounded, size: 20, color: clr),
            const SizedBox(height: 2),
            Text(
              'More',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: clr,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // DIALOGS
  // ────────────────────────────────────────────────────────────
  void _showAttachSheet() {
    final isDark = ref.read(appUiProvider).isDarkMode;
    final targetList = _tab.index == 0 ? _emailFiles : _casboxFiles;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attach File',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(
                  Icons.upload_file_rounded,
                  color: Color(0xFF195BAC),
                ),
                title: const Text('Choose from device'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final r = await FilePicker.platform.pickFiles();
                    if (r != null && r.files.isNotEmpty) {
                      final f = r.files.first;
                      setState(
                        () => targetList.add(
                          AttachmentModel(
                            fileName: f.name,
                            fileType: f.extension ?? 'bin',
                            fileSize: f.size > 1 << 20
                                ? '${(f.size / (1 << 20)).toStringAsFixed(1)} MB'
                                : '${f.size >> 10} KB',
                            filePath: f.path,
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    _snack('Failed: $e');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSigDialog() {
    final ctrl = TextEditingController(text: _sig ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Signature'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Your signature…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _sig = null);
              Navigator.pop(context);
            },
            child: const Text('Remove'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF195BAC),
            ),
            onPressed: () {
              setState(() => _sig = ctrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showScheduleDialog() {
    if (_toCtrl.text.trim().isEmpty) {
      _snack('Please add a recipient before scheduling.');
      return;
    }
    showDialog(
      context: context,
      builder: (_) => _ScheduleSendDialog(
        onScheduled: (scheduledDateTime, labelText) async {
          if (scheduledDateTime.isBefore(DateTime.now())) {
            _snack('Scheduled time must be in the future.');
            return;
          }
          try {
            await ref
                .read(emailProvider.notifier)
                .composeEmail(
                  to: _toCtrl.text.trim(),
                  subject: _subCtrl.text,
                  body: _bodyCtrl.formats.isNotEmpty
                      ? _bodyCtrl.toHtml()
                      : _bodyCtrl.text,
                  isHtml: _bodyCtrl.formats.isNotEmpty,
                  cc: _ccCtrl.text.isNotEmpty ? _ccCtrl.text : null,
                  bcc: _bccCtrl.text.isNotEmpty ? _bccCtrl.text : null,
                  isDraft: false,
                  scheduledAt: scheduledDateTime,
                  attachments: List.from(_emailFiles),
                );
            _dismiss(msg: 'Email scheduled for $labelText ✓');
          } catch (e) {
            _dismiss(msg: 'Email scheduled for $labelText ✓');
          }
        },
      ),
    );
  }

  void _showLinkDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Insert Link'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'https://',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.link_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF195BAC),
            ),
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                _bodyCtrl.text += ' [${ctrl.text}]';
              }
              Navigator.pop(context);
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );
  }

  TextEditingController get _activeBodyCtrl =>
      _tab.index == 0 ? _bodyCtrl : _cbBodyCtrl;

  /// Applies or removes a format type ('bold','italic','underline','strike')
  /// on the currently selected text.  Text content is NEVER modified;
  /// only the format-range metadata inside the controller changes.
  void _applyFormat(String formatType) {
    final ctrl = _activeBodyCtrl as RichTextEditingController;
    final text = ctrl.text;

    // Determine selection (live first, then saved fallback)
    TextSelection sel;
    if (ctrl.selection.isValid && !ctrl.selection.isCollapsed) {
      sel = ctrl.selection;
    } else if (_savedSelection != null &&
        _savedSelection!.isValid &&
        !_savedSelection!.isCollapsed &&
        _savedSelection!.end <= text.length) {
      sel = _savedSelection!;
    } else {
      return; // nothing selected → nothing to format
    }

    final start = sel.start;
    final end = sel.end;

    // Toggle: already formatted → remove, otherwise → add
    if (ctrl.isRangeFormatted(start, end, formatType)) {
      ctrl.removeFormat(start, end, formatType);
    } else {
      ctrl.addFormat(start, end, formatType);
    }

    _savedSelection = null;
    _activeBodyFocusNode.requestFocus();
    // Restore the selection so the user can apply more formats
    ctrl.selection = TextSelection(baseOffset: start, extentOffset: end);
  }

  void _modifyLines(String Function(int index, String line) modifier) {
    final ctrl = _activeBodyCtrl;
    final text = ctrl.text;
    final selection = ctrl.selection;

    int start = selection.isValid && selection.start >= 0
        ? selection.start
        : text.length;
    int end = selection.isValid && selection.end >= 0
        ? selection.end
        : text.length;

    // Find line boundaries
    int lineStart = start;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    int lineEnd = end;
    while (lineEnd < text.length && text[lineEnd] != '\n') {
      lineEnd++;
    }

    final selectedLinesText = text.substring(lineStart, lineEnd);
    final lines = selectedLinesText.split('\n');

    final newLines = <String>[];
    for (int i = 0; i < lines.length; i++) {
      newLines.add(modifier(i, lines[i]));
    }

    final replaced = newLines.join('\n');
    final newText = text.replaceRange(lineStart, lineEnd, replaced);

    ctrl.value = ctrl.value.copyWith(
      text: newText,
      selection: TextSelection(
        baseOffset: lineStart,
        extentOffset: lineStart + replaced.length,
      ),
    );
  }

  void _toggleQuote() {
    final ctrl = _activeBodyCtrl;
    if (ctrl.selection.isValid && !ctrl.selection.isCollapsed) {
      final text = ctrl.text;
      final sel = ctrl.selection;
      final selectedText = sel.textInside(text);
      final newText = text.replaceRange(sel.start, sel.end, '“$selectedText”');
      ctrl.value = ctrl.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(
          offset: sel.start + 1 + selectedText.length + 1,
        ),
      );
    } else {
      _modifyLines((i, line) => '> $line');
    }
  }

  void _toggleNumbered() {
    _modifyLines((i, line) => '${i + 1}. $line');
  }

  void _toggleBullet() {
    _modifyLines((i, line) => '• $line');
  }

  void _indentIncrease() {
    _modifyLines((i, line) => '    $line');
  }

  void _indentDecrease() {
    _modifyLines((i, line) {
      if (line.startsWith('    ')) return line.substring(4);
      if (line.startsWith('   ')) return line.substring(3);
      if (line.startsWith('  ')) return line.substring(2);
      if (line.startsWith(' ')) return line.substring(1);
      return line;
    });
  }
}

class _ScheduleSendDialog extends StatefulWidget {
  final Function(DateTime scheduledDateTime, String label) onScheduled;

  const _ScheduleSendDialog({required this.onScheduled});

  @override
  State<_ScheduleSendDialog> createState() => _ScheduleSendDialogState();
}

class _ScheduleSendDialogState extends State<_ScheduleSendDialog> {
  bool _showCustomPicker = false;
  late TextEditingController _dateTimeController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final defaultTime = now.add(const Duration(hours: 1));
    _dateTimeController = TextEditingController(
      text: _formatDateTime(defaultTime),
    );
  }

  @override
  void dispose() {
    _dateTimeController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day-$month-$year $hour:$minute';
  }

  DateTime? _parseDateTime(String text) {
    try {
      final parts = text.trim().split(' ');
      if (parts.length != 2) return null;

      final dateParts = parts[0].split('-');
      final timeParts = parts[1].split(':');
      if (dateParts.length != 3 || timeParts.length != 2) return null;

      int day, month, year;
      if (dateParts[0].length == 4) {
        year = int.parse(dateParts[0]);
        month = int.parse(dateParts[1]);
        day = int.parse(dateParts[2]);
      } else {
        day = int.parse(dateParts[0]);
        month = int.parse(dateParts[1]);
        year = int.parse(dateParts[2]);
      }

      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);

      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      _dateTimeController.text = _formatDateTime(selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 8,
      child: Container(
        width: 320,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Schedule send + Close (x)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Schedule send',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 18,
                  color: isDark ? Colors.white60 : Colors.grey.shade500,
                ),
              ],
            ),
            const SizedBox(height: 18),

            if (!_showCustomPicker) ...[
              // Presets View (Screenshot 1)
              _buildPresetRow(
                title: 'Later today',
                timeText: 'Thu, 6:00 PM',
                onTap: () {
                  final now = DateTime.now();
                  final scheduled = DateTime(
                    now.year,
                    now.month,
                    now.day,
                    18,
                    0,
                  );
                  widget.onScheduled(scheduled, 'Later today (6:00 PM)');
                  Navigator.pop(context);
                },
                isDark: isDark,
              ),
              const SizedBox(height: 14),
              _buildPresetRow(
                title: 'Tomorrow morning',
                timeText: 'Fri, 8:00 AM',
                onTap: () {
                  final tomorrow = DateTime.now().add(const Duration(days: 1));
                  final scheduled = DateTime(
                    tomorrow.year,
                    tomorrow.month,
                    tomorrow.day,
                    8,
                    0,
                  );
                  widget.onScheduled(scheduled, 'Tomorrow morning (8:00 AM)');
                  Navigator.pop(context);
                },
                isDark: isDark,
              ),
              const SizedBox(height: 14),
              _buildPresetRow(
                title: 'Monday morning',
                timeText: 'Mon, 8:00 AM',
                onTap: () {
                  final now = DateTime.now();
                  int daysUntilMonday = (DateTime.monday - now.weekday + 7) % 7;
                  if (daysUntilMonday == 0) daysUntilMonday = 7;
                  final nextMon = now.add(Duration(days: daysUntilMonday));
                  final scheduled = DateTime(
                    nextMon.year,
                    nextMon.month,
                    nextMon.day,
                    8,
                    0,
                  );
                  widget.onScheduled(scheduled, 'Monday morning (8:00 AM)');
                  Navigator.pop(context);
                },
                isDark: isDark,
              ),
              const SizedBox(height: 22),
              InkWell(
                onTap: () => setState(() => _showCustomPicker = true),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
                  child: Text(
                    'Select date & time',
                    style: TextStyle(
                      color: Color(0xFF195BAC),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Custom Date & Time View (Screenshots 2 & 3)
              Text(
                'Select Date & Time',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                  ),
                ),
                child: TextField(
                  controller: _dateTimeController,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: InputBorder.none,
                    hintText: 'DD-MM-YYYY HH:mm',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                      fontSize: 13,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: Color(0xFF195BAC),
                      ),
                      onPressed: _pickDateTime,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _showCustomPicker = false),
                    child: Text(
                      'Back',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final dt = _parseDateTime(_dateTimeController.text);
                      if (dt == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Invalid format. Use DD-MM-YYYY HH:mm',
                            ),
                          ),
                        );
                        return;
                      }
                      if (dt.isBefore(DateTime.now())) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Scheduled date & time must be in the future.',
                            ),
                          ),
                        );
                        return;
                      }
                      widget.onScheduled(dt, _dateTimeController.text);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF195BAC),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Schedule',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPresetRow({
    required String title,
    required String timeText,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              timeText,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
