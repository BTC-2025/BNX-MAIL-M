import 'package:flutter/material.dart';

/// Professional, modern, fully functional Virtual Keyboard for desktop.
/// Directly types into any active/focused TextField, Search field, or Compose field.
class VirtualKeyboardWidget extends StatefulWidget {
  final VoidCallback onClose;
  final ValueChanged<String>? onKeyTap;

  const VirtualKeyboardWidget({
    super.key,
    required this.onClose,
    this.onKeyTap,
  });

  @override
  State<VirtualKeyboardWidget> createState() => _VirtualKeyboardWidgetState();
}

class _VirtualKeyboardWidgetState extends State<VirtualKeyboardWidget> {
  bool isCapsLock = false;
  bool isShift = false;
  EditableTextState? _lastFocusedEditable;
  String _activeTargetLabel = 'Ready to type';

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureCurrentFocus());
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    _captureCurrentFocus();
  }

  void _captureCurrentFocus() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null || primaryFocus.context == null) return;
    final ctx = primaryFocus.context!;
    EditableTextState? editable;
    if (ctx is StatefulElement && ctx.state is EditableTextState) {
      editable = ctx.state as EditableTextState;
    } else {
      editable = ctx.findAncestorStateOfType<EditableTextState>();
    }

    if (editable != null && mounted) {
      setState(() {
        _lastFocusedEditable = editable;
        _activeTargetLabel = 'Active input field';
      });
    }
  }

  void _handleKey(String key) {
    widget.onKeyTap?.call(key);
    _insertIntoActiveField(key);
  }

  void _insertIntoActiveField(String key) {
    _captureCurrentFocus();
    final editable = _lastFocusedEditable;

    if (editable == null || !editable.mounted) {
      // If no input field has focus, request focus on the primary focus tree or find first editable
      return;
    }

    final value = editable.textEditingValue;
    final text = value.text;
    final selection = value.selection;

    if (key == 'Backspace') {
      if (!selection.isValid) {
        if (text.isNotEmpty) {
          editable.userUpdateTextEditingValue(
            TextEditingValue(
              text: text.substring(0, text.length - 1),
              selection: TextSelection.collapsed(offset: text.length - 1),
            ),
            SelectionChangedCause.keyboard,
          );
        }
        return;
      }
      if (!selection.isCollapsed) {
        final newText = text.replaceRange(selection.start, selection.end, '');
        editable.userUpdateTextEditingValue(
          TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: selection.start),
          ),
          SelectionChangedCause.keyboard,
        );
      } else if (selection.start > 0) {
        final newText = text.replaceRange(selection.start - 1, selection.start, '');
        editable.userUpdateTextEditingValue(
          TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: selection.start - 1),
          ),
          SelectionChangedCause.keyboard,
        );
      }
    } else if (key == 'Space') {
      _insertText(editable, ' ');
    } else if (key == 'Tab') {
      _insertText(editable, '    ');
    } else if (key == 'Enter' || key == '\n') {
      _insertText(editable, '\n');
    } else if (key == 'Esc') {
      FocusManager.instance.primaryFocus?.unfocus();
    } else if (key == 'Caps Lock' || key == 'Shift' || key == 'Ctrl' || key == 'Alt') {
      // Modifiers handled by state
    } else if (key == 'left_arrow') {
      if (selection.isValid && selection.start > 0) {
        final newPos = selection.start - 1;
        editable.userUpdateTextEditingValue(
          value.copyWith(selection: TextSelection.collapsed(offset: newPos)),
          SelectionChangedCause.keyboard,
        );
      }
    } else if (key == 'right_arrow') {
      if (selection.isValid && selection.end < text.length) {
        final newPos = selection.end + 1;
        editable.userUpdateTextEditingValue(
          value.copyWith(selection: TextSelection.collapsed(offset: newPos)),
          SelectionChangedCause.keyboard,
        );
      }
    } else {
      _insertText(editable, key);
      // Auto reset shift after typing a character
      if (isShift) {
        setState(() {
          isShift = false;
        });
      }
    }
  }

  void _insertText(EditableTextState editable, String insert) {
    final value = editable.textEditingValue;
    final text = value.text;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final newText = text.replaceRange(start, end, insert);
    final newPos = start + insert.length;
    editable.userUpdateTextEditingValue(
      TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newPos),
      ),
      SelectionChangedCause.keyboard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final keyBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final keyBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    // Focus widget with canRequestFocus: false ensures clicking keys never steals focus from the active TextField!
    return Focus(
      canRequestFocus: false,
      descendantsAreFocusable: false,
      child: Container(
        width: 488,
        height: 254,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
              blurRadius: 28,
              offset: const Offset(0, 10),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header: Icon + Title + Status + Close Button
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.keyboard_alt_outlined,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Virtual Keyboard',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 10),
                // Active Target Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _lastFocusedEditable != null
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _lastFocusedEditable != null
                              ? const Color(0xFF10B981)
                              : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _activeTargetLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _lastFocusedEditable != null
                              ? const Color(0xFF059669)
                              : subTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? Colors.white10 : Colors.grey.shade100,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 15,
                        color: subTextColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 5 Rows of Keys
            Expanded(
              child: Column(
                children: [
                  // Row 1
                  Expanded(
                    child: Row(
                      children: [
                        _buildKey('Esc', flex: 12, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, fontSize: 9.5),
                        _gap(),
                        _buildDualKey('!', '1', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, subTextColor: subTextColor),
                        _gap(),
                        _buildDualKey('@', '2', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, subTextColor: subTextColor),
                        _gap(),
                        _buildDualKey('#', '3', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, subTextColor: subTextColor),
                        _gap(),
                        _buildDualKey(r'$', '4', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, subTextColor: subTextColor),
                        _gap(),
                        _buildDualKey('%', '5', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, subTextColor: subTextColor),
                        _gap(),
                        _buildDualKey('^', '6', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, subTextColor: subTextColor),
                        _gap(),
                        _buildDualKey('&', '7', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, subTextColor: subTextColor),
                        _gap(),
                        _buildDualKey('*', '8', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, subTextColor: subTextColor),
                        _gap(),
                        _buildDualKey('(', '9', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, subTextColor: subTextColor),
                        _gap(),
                        _buildDualKey(')', '0', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, subTextColor: subTextColor),
                        _gap(),
                        _buildDualKey('_', '-', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, subTextColor: subTextColor),
                        _gap(),
                        _buildDualKey('+', '=', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, subTextColor: subTextColor),
                        _gap(),
                        _buildKey('Backspace', flex: 18, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, fontSize: 9),
                      ],
                    ),
                  ),
                  _rowGap(),

                  // Row 2
                  Expanded(
                    child: Row(
                      children: [
                        _buildKey('Tab', flex: 15, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, fontSize: 9.5),
                        _gap(),
                        _buildLetterKey('Q', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('W', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('E', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('R', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('T', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('Y', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('U', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('I', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('O', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('P', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildDualKey('{', '[', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, subTextColor: subTextColor),
                        _gap(),
                        _buildDualKey('}', ']', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, subTextColor: subTextColor),
                        _gap(),
                        _buildDualKey('|', r'\', flex: 15, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, subTextColor: subTextColor),
                      ],
                    ),
                  ),
                  _rowGap(),

                  // Row 3
                  Expanded(
                    child: Row(
                      children: [
                        _buildCapsLockKey(flex: 18, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('A', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('S', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('D', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('F', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('G', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('H', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('J', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('K', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('L', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildDualKey(':', ';', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, subTextColor: subTextColor),
                        _gap(),
                        _buildDualKey('"', "'", flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, subTextColor: subTextColor),
                        _gap(),
                        // Enter button (Vibrant Blue with gradient)
                        Expanded(
                          flex: 22,
                          child: _buildGradientButtonKey(
                            label: 'Enter',
                            gradientColors: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            borderColor: const Color(0xFF1E40AF),
                            textColor: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            onTap: () => _handleKey('\n'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _rowGap(),

                  // Row 4
                  Expanded(
                    child: Row(
                      children: [
                        // Left Shift (Soft Blue with toggle state)
                        Expanded(
                          flex: 22,
                          child: _buildShiftKey(),
                        ),
                        _gap(),
                        _buildLetterKey('Z', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('X', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('C', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('V', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('B', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('N', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildLetterKey('M', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor),
                        _gap(),
                        _buildDualKey('<', ',', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, subTextColor: subTextColor),
                        _gap(),
                        _buildDualKey('>', '.', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, subTextColor: subTextColor),
                        _gap(),
                        _buildDualKey('?', '/', flex: 10, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, subTextColor: subTextColor),
                        _gap(),
                        // Right Shift (Soft Blue with toggle state)
                        Expanded(
                          flex: 28,
                          child: _buildShiftKey(),
                        ),
                      ],
                    ),
                  ),
                  _rowGap(),

                  // Row 5
                  Expanded(
                    child: Row(
                      children: [
                        _buildKey('Ctrl', flex: 14, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, fontSize: 9.5),
                        _gap(),
                        _buildKey('Alt', flex: 12, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, fontSize: 9.5),
                        _gap(),
                        // Space
                        Expanded(
                          flex: 66,
                          child: _buildButtonKey(
                            label: 'Space',
                            bgColor: keyBg,
                            borderColor: keyBorder,
                            textColor: subTextColor,
                            fontSize: 10,
                            onTap: () => _handleKey('Space'),
                          ),
                        ),
                        _gap(),
                        _buildKey('Alt', flex: 12, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, fontSize: 9.5),
                        _gap(),
                        _buildKey('Ctrl', flex: 14, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, fontSize: 9.5),
                        _gap(),
                        _buildIconKey(Icons.arrow_left, flex: 8, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, onTap: () => _handleKey('left_arrow')),
                        _gap(),
                        _buildIconKey(Icons.arrow_drop_down, flex: 8, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, onTap: () => _handleKey('down_arrow')),
                        _gap(),
                        _buildIconKey(Icons.arrow_drop_up, flex: 8, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, onTap: () => _handleKey('up_arrow')),
                        _gap(),
                        _buildIconKey(Icons.arrow_right, flex: 8, keyBg: keyBg, keyBorder: keyBorder, textColor: textColor, onTap: () => _handleKey('right_arrow')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gap() => const SizedBox(width: 3.5);
  Widget _rowGap() => const SizedBox(height: 3.5);

  Widget _buildKey(
    String label, {
    required int flex,
    required Color keyBg,
    required Color keyBorder,
    required Color textColor,
    double fontSize = 10.5,
  }) {
    return Expanded(
      flex: flex,
      child: _buildButtonKey(
        label: label,
        bgColor: keyBg,
        borderColor: keyBorder,
        textColor: textColor,
        fontSize: fontSize,
        onTap: () => _handleKey(label),
      ),
    );
  }

  Widget _buildLetterKey(
    String letter, {
    required int flex,
    required Color keyBg,
    required Color keyBorder,
    required Color textColor,
  }) {
    final isUpper = isCapsLock ^ isShift;
    final displayChar = isUpper ? letter.toUpperCase() : letter.toLowerCase();

    return Expanded(
      flex: flex,
      child: _buildButtonKey(
        label: displayChar,
        bgColor: keyBg,
        borderColor: keyBorder,
        textColor: textColor,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        onTap: () => _handleKey(displayChar),
      ),
    );
  }

  Widget _buildDualKey(
    String top,
    String bottom, {
    required int flex,
    required Color keyBg,
    required Color keyBorder,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Expanded(
      flex: flex,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _handleKey(isShift ? top : bottom),
          child: Container(
            decoration: BoxDecoration(
              color: keyBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: keyBorder, width: 0.9),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  offset: const Offset(0, 1),
                  blurRadius: 1,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  top,
                  style: TextStyle(
                    fontSize: 7.5,
                    color: isShift ? const Color(0xFF1D4ED8) : subTextColor,
                    fontWeight: isShift ? FontWeight.bold : FontWeight.normal,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 1.5),
                Text(
                  bottom,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: isShift ? FontWeight.normal : FontWeight.w600,
                    color: isShift ? subTextColor : textColor,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShiftKey() {
    final active = isShift;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            isShift = !isShift;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: active ? const Color(0xFFBFDBFE) : const Color(0xFFDBEAFE),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active ? const Color(0xFF2563EB) : const Color(0xFF93C5FD),
              width: active ? 1.4 : 0.9,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: active ? 0.2 : 0.04),
                offset: const Offset(0, 1),
                blurRadius: 1,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.arrow_upward,
                size: 11,
                color: Color(0xFF1D4ED8),
              ),
              SizedBox(width: 3),
              Text(
                'Shift',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCapsLockKey({
    required int flex,
    required Color keyBg,
    required Color keyBorder,
    required Color textColor,
  }) {
    return Expanded(
      flex: flex,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            setState(() {
              isCapsLock = !isCapsLock;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isCapsLock ? const Color(0xFFE0E7FF) : keyBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isCapsLock ? const Color(0xFF6366F1) : keyBorder,
                width: isCapsLock ? 1.4 : 0.9,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  offset: const Offset(0, 1),
                  blurRadius: 1,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isCapsLock) ...[
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
                Text(
                  'Caps Lock',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: isCapsLock ? FontWeight.bold : FontWeight.w500,
                    color: isCapsLock ? const Color(0xFF4338CA) : textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconKey(
    IconData icon, {
    required int flex,
    required Color keyBg,
    required Color keyBorder,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      flex: flex,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: keyBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: keyBorder, width: 0.9),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  offset: const Offset(0, 1),
                  blurRadius: 1,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 13,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonKey({
    required String label,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
    double fontSize = 10,
    FontWeight fontWeight = FontWeight.w500,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor, width: 0.9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                offset: const Offset(0, 1),
                blurRadius: 1,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButtonKey({
    required String label,
    required List<Color> gradientColors,
    required Color borderColor,
    required Color textColor,
    double fontSize = 10,
    FontWeight fontWeight = FontWeight.w500,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor, width: 0.9),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withValues(alpha: 0.3),
                offset: const Offset(0, 1.5),
                blurRadius: 2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
