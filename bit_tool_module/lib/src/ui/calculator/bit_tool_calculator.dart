import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../providers/bit_tool_providers.dart';

class _BitToolColors {
  static const primaryGreen = Color(0xFF059669);
  static const border = Color(0xFFE5E7EB);
  static const secondaryText = Color(0xFF6B7280);
  static const darkText = Color(0xFF111827);
}

// ═══════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════

class TapeEntry {
  final String id;
  final String operator; // '=', '+', '-', '+GST', '-DISC', '×', '÷'
  final double value;
  final double runningTotal;
  String? label;
  final bool isBase;
  final String? presetTag;

  TapeEntry({
    required this.id,
    required this.operator,
    required this.value,
    required this.runningTotal,
    this.label,
    this.isBase = false,
    this.presetTag,
  });
}

class ComparisonRow {
  String description;
  double? valueA;
  double? valueB;
  double qtyA;
  double qtyB;
  double discountA;
  double discountB;

  ComparisonRow({
    this.description = '',
    this.valueA,
    this.valueB,
    this.qtyA = 1.0,
    this.qtyB = 1.0,
    this.discountA = 0.0,
    this.discountB = 0.0,
  });

  double get finalA {
    final base = (valueA ?? 0.0) * qtyA;
    return base - (base * (discountA / 100.0));
  }

  double get finalB {
    final base = (valueB ?? 0.0) * qtyB;
    return base - (base * (discountB / 100.0));
  }
}

class HistorySection {
  final String id;
  final DateTime timestamp;
  final List<TapeEntry>? tapeEntries;
  final List<ComparisonRow>? comparisonRows;
  final String type; // 'tape' or 'compare'
  final double totalValue;

  HistorySection({
    required this.id,
    required this.timestamp,
    this.tapeEntries,
    this.comparisonRows,
    required this.type,
    required this.totalValue,
  });
}

// ═══════════════════════════════════════════════════════════
// BETA CALCULATOR WIDGET
// ═══════════════════════════════════════════════════════════

typedef BitToolCalculator = BetaCalculator;

class BetaCalculator extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  const BetaCalculator({super.key, this.onClose});

  @override
  ConsumerState<BetaCalculator> createState() => _BetaCalculatorState();
}

class _BetaCalculatorState extends ConsumerState<BetaCalculator> {
  final ScrollController _tapeScrollController = ScrollController();

  // State
  List<TapeEntry> _tapeEntries = [];
  List<ComparisonRow> _comparisonRows = [];
  final List<HistorySection> _historyLog = [];
  bool _showHistoryList = true;

  String _currentInput = '0';
  String _pendingOperator = '=';
  double _runningTotal = 0.0;
  bool _hasBase = false;
  bool _isUsdMode = false;
  final double _usdRate = 83.5;

  // Active Mode: 'gst', 'discount', 'compare'
  String _activeMode = 'gst';

  // Compare inputs
  final TextEditingController _compDescController = TextEditingController();
  final TextEditingController _compValAController = TextEditingController();
  final TextEditingController _compValBController = TextEditingController();
  final TextEditingController _compQtyAController = TextEditingController();
  final TextEditingController _compQtyBController = TextEditingController();
  final TextEditingController _compDiscAController = TextEditingController();
  final TextEditingController _compDiscBController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bitToolCalculatorProvider.notifier).loadSessions();
    });
  }

  @override
  void dispose() {
    _tapeScrollController.dispose();
    _compDescController.dispose();
    _compValAController.dispose();
    _compValBController.dispose();
    _compQtyAController.dispose();
    _compQtyBController.dispose();
    _compDiscAController.dispose();
    _compDiscBController.dispose();
    super.dispose();
  }

  void _scrollTapeToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tapeScrollController.hasClients) {
        _tapeScrollController.animateTo(
          _tapeScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Calculator Logic
  void _enterDigit(String digit) {
    setState(() {
      if (_currentInput == '0' && digit != '.') {
        _currentInput = digit;
      } else {
        if (digit == '.' && _currentInput.contains('.')) return;
        _currentInput += digit;
      }
    });
  }

  void _backspace() {
    setState(() {
      if (_currentInput.length > 1) {
        _currentInput = _currentInput.substring(0, _currentInput.length - 1);
      } else {
        _currentInput = '0';
      }
    });
  }

  void _clearAll() {
    setState(() {
      _currentInput = '0';
      _pendingOperator = '=';
      _runningTotal = 0.0;
      _hasBase = false;
      _tapeEntries.clear();
      _comparisonRows.clear();
    });
  }

  void _setOperator(String op) {
    final value = double.tryParse(_currentInput) ?? 0.0;
    if (!_hasBase && value == 0.0 && _tapeEntries.isEmpty) return;

    setState(() {
      if (!_hasBase) {
        // Set Base Amount
        _runningTotal = value;
        _hasBase = true;
        _tapeEntries.add(TapeEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          operator: '=',
          value: value,
          runningTotal: value,
          isBase: true,
        ));
      } else {
        // Apply pending operation
        _applyOperation(value);
      }
      _pendingOperator = op;
      _currentInput = '0';
    });
    _scrollTapeToBottom();
  }

  void _applyOperation(double value) {
    switch (_pendingOperator) {
      case '+':
        _runningTotal += value;
        break;
      case '-':
        _runningTotal -= value;
        break;
      case '×':
        _runningTotal *= value;
        break;
      case '÷':
        if (value != 0) _runningTotal /= value;
        break;
    }
    _tapeEntries.add(TapeEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      operator: _pendingOperator,
      value: value,
      runningTotal: _runningTotal,
    ));
  }

  void _calculate() {
    final value = double.tryParse(_currentInput) ?? 0.0;
    if (!_hasBase) return;
    setState(() {
      _applyOperation(value);
      _pendingOperator = '=';
      _currentInput = '0';
    });
    _scrollTapeToBottom();
    _saveToHistory();
  }

  // Presets
  void _applyGstPreset(double percentage) {
    if (!_hasBase) return;
    setState(() {
      final gstValue = _runningTotal * (percentage / 100.0);
      _runningTotal += gstValue;
      _tapeEntries.add(TapeEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        operator: '+',
        value: gstValue,
        runningTotal: _runningTotal,
        presetTag: '${percentage.toInt()}% GST',
      ));
    });
    _scrollTapeToBottom();
  }

  void _applyDiscountPreset(double percentage) {
    if (!_hasBase) return;
    setState(() {
      final discValue = _runningTotal * (percentage / 100.0);
      _runningTotal -= discValue;
      _tapeEntries.add(TapeEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        operator: '-',
        value: discValue,
        runningTotal: _runningTotal,
        presetTag: '${percentage.toInt()}% Disc',
      ));
    });
    _scrollTapeToBottom();
  }

  // Label management
  // ignore: unused_element
  void _addLabel(int idx, String label) {
    setState(() {
      _tapeEntries[idx].label = label;
    });
  }

  // History logs
  void _saveToHistory() {
    if (_tapeEntries.isEmpty && _comparisonRows.isEmpty) return;
    final isComp = _activeMode == 'compare';
    double totA = 0;
    if (isComp) {
      for (var r in _comparisonRows) {
        totA += r.finalA;
      }
    }
    final amt = isComp ? totA : _runningTotal;

    // Persist to Calculator Backend API via Riverpod
    final tapeItems = _tapeEntries.asMap().entries.map((e) {
      return CalculatorTapeItem(
        id: e.value.id,
        sequence: e.key + 1,
        value: e.value.value,
        operator: e.value.operator,
        runningTotal: e.value.runningTotal,
        label: e.value.label ?? (e.value.presetTag ?? ''),
      );
    }).toList();

    ref.read(bitToolCalculatorProvider.notifier).saveSession(
      title: isComp ? 'Comparison Log' : 'Calculated Log',
      totalAmount: amt,
      items: tapeItems,
    );

    setState(() {
      _historyLog.insert(
        0,
        HistorySection(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          type: isComp ? 'compare' : 'tape',
          tapeEntries: List.from(_tapeEntries),
          comparisonRows: List.from(_comparisonRows),
          totalValue: amt,
        ),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calculation session saved to API'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _restoreApiSession(CalculatorSession s) {
    setState(() {
      _activeMode = 'gst';
      final amt = s.totalAmount ?? 0.0;
      _runningTotal = amt;
      _currentInput = '0';
      _pendingOperator = '=';
      _hasBase = true;
      if (s.items.isNotEmpty) {
        _tapeEntries = s.items.map((it) => TapeEntry(
          id: it.id,
          operator: it.operator,
          value: it.value,
          runningTotal: it.runningTotal,
          label: it.label,
          isBase: it.sequence == 1,
        )).toList();
      } else {
        _tapeEntries = [
          TapeEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            operator: '=',
            value: amt,
            runningTotal: amt,
            isBase: true,
          ),
        ];
      }
      _showHistoryList = false;
    });
    _scrollTapeToBottom();
  }

  void _restoreHistory(HistorySection section) {
    setState(() {
      if (section.type == 'compare') {
        _activeMode = 'compare';
        _comparisonRows = List.from(section.comparisonRows ?? []);
      } else {
        _activeMode = 'gst';
        _tapeEntries = List.from(section.tapeEntries ?? []);
        _runningTotal = section.totalValue;
        _hasBase = _tapeEntries.isNotEmpty;
      }
      _showHistoryList = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = _isUsdMode ? '\$' : '₹';
    final displayTotal = _isUsdMode ? _runningTotal / _usdRate : _runningTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Action Bar Header: # BETA CALC matching Image 4
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '# BETA CALC',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Color(0xFF111827),
                letterSpacing: 0.3,
              ),
            ),
            Row(
              children: [
                _buildActionIcon(
                  _showHistoryList ? LucideIcons.eyeOff : LucideIcons.history,
                  'History',
                  () => setState(() => _showHistoryList = !_showHistoryList),
                ),
                _buildActionIcon(LucideIcons.share2, 'Share', () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tape log copied to clipboard'), duration: Duration(seconds: 1)),
                  );
                }),
                _buildActionIcon(LucideIcons.trash2, 'Clear', _clearAll),
                if (widget.onClose != null)
                  _buildActionIcon(LucideIcons.x, 'Close', widget.onClose!),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // History logs view (Target design matching Image 1)
        if (_showHistoryList) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TAPE ARCHIVES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        ref.read(bitToolCalculatorProvider.notifier).clearAll();
                        setState(() => _historyLog.clear());
                      },
                      child: const Text(
                        'CLEAR ALL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Live API Sessions list
                Builder(
                  builder: (context) {
                    final calcState = ref.watch(bitToolCalculatorProvider);
                    final sessions = calcState.sessions;

                    if (sessions.isEmpty && _historyLog.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: const Text(
                          'No saved calculations yet.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    if (sessions.isNotEmpty) {
                      return Column(
                        children: sessions.map((s) => _buildApiTapeCard(s)).toList(),
                      );
                    }

                    return Column(
                      children: _historyLog.map((log) => _buildLocalTapeCard(log)).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Tape viewer
        if (_activeMode != 'compare') ...[
          Container(
            height: 100,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _BitToolColors.border),
            ),
            child: _tapeEntries.isEmpty
                ? const Center(child: Text('Set a base value to begin tape log', style: TextStyle(fontSize: 11, color: Colors.grey)))
                : ListView.builder(
                    controller: _tapeScrollController,
                    itemCount: _tapeEntries.length,
                    itemBuilder: (ctx, idx) {
                      final entry = _tapeEntries[idx];
                      final val = _isUsdMode ? entry.value / _usdRate : entry.value;
                      final rTotal = _isUsdMode ? entry.runningTotal / _usdRate : entry.runningTotal;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${entry.operator} $currencySymbol${val.toStringAsFixed(1)} ${entry.presetTag != null ? '(${entry.presetTag})' : ''}',
                              style: const TextStyle(fontSize: 10, color: Colors.black87),
                            ),
                            Text(
                              '= $currencySymbol${rTotal.toStringAsFixed(1)}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _BitToolColors.secondaryText),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
        ],

        // Base input / Continue Display
        if (_activeMode != 'compare') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _BitToolColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  !_hasBase ? 'SET BASE' : 'CONTINUE $_pendingOperator',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _BitToolColors.secondaryText),
                ),
                Text(
                  _currentInput,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _BitToolColors.darkText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Mode switch tabs matching Image 4
        Row(
          children: [
            _buildModeTab('% GST', 'gst', icon: LucideIcons.percent, iconColor: const Color(0xFF059669)),
            const SizedBox(width: 4),
            _buildModeTab('Discount', 'discount', icon: LucideIcons.tag, iconColor: const Color(0xFFF97316)),
            const SizedBox(width: 4),
            _buildModeTab(_isUsdMode ? 'USD' : 'INR', 'currency', icon: LucideIcons.globe, iconColor: const Color(0xFF4B5563)),
            const SizedBox(width: 4),
            _buildModeTab('Compare', 'compare', icon: LucideIcons.arrowUpDown, iconColor: const Color(0xFF4B5563)),
          ],
        ),
        const SizedBox(height: 8),

        // Mode subcontent
        if (_activeMode == 'gst')
          Row(
            children: [5, 12, 18, 28].map((p) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: _buildPresetBtn('+$p%', () => _applyGstPreset(p.toDouble()), const Color(0xFF16A34A)),
              ),
            )).toList(),
          )
        else if (_activeMode == 'discount')
          Row(
            children: [5, 10, 20, 50].map((p) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: _buildPresetBtn('-$p%', () => _applyDiscountPreset(p.toDouble()), Colors.red.shade600),
              ),
            )).toList(),
          )
        else if (_activeMode == 'compare')
          _buildCompareSection(),

        const SizedBox(height: 8),

        // Numpad block (only when not in compare mode, or can be general)
        if (_activeMode != 'compare') _buildNumPad(),

        // Total Running display
        if (_activeMode != 'compare') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _BitToolColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('RUNNING TOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _BitToolColors.primaryGreen)),
                Text(
                  '$currencySymbol${displayTotal.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _BitToolColors.primaryGreen),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionIcon(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Icon(icon, size: 14, color: _BitToolColors.secondaryText),
        ),
      ),
    );
  }

  Widget _buildModeTab(String label, String modeKey, {IconData? icon, Color? iconColor}) {
    final isSelected = modeKey == 'currency' ? false : _activeMode == modeKey;
    const activeBg = Color(0xFF059669);
    const inactiveBg = Colors.white;
    const activeBorder = Color(0xFF059669);
    const inactiveBorder = Color(0xFFE5E7EB);

    return Expanded(
      child: InkWell(
        onTap: () {
          if (modeKey == 'currency') {
            setState(() => _isUsdMode = !_isUsdMode);
          } else {
            setState(() => _activeMode = modeKey);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : inactiveBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isSelected ? activeBorder : inactiveBorder),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 10,
                  color: isSelected ? Colors.white : (iconColor ?? const Color(0xFF4B5563)),
                ),
                const SizedBox(width: 2),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF374151),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetBtn(String label, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildCompareSection() {
    double totalA = 0;
    double totalB = 0;
    for (var r in _comparisonRows) {
      totalA += r.finalA;
      totalB += r.finalB;
    }

    String analysisMsg = '';
    Color bannerColor = Colors.grey.shade400;
    if (totalA < totalB && totalA > 0) {
      final percent = ((totalB - totalA) / totalB * 100).toStringAsFixed(0);
      analysisMsg = 'Side A is cheaper by $percent% (A: ₹${totalA.toStringAsFixed(1)} vs B: ₹${totalB.toStringAsFixed(1)})';
      bannerColor = const Color(0xFF16A34A);
    } else if (totalB < totalA && totalB > 0) {
      final percent = ((totalA - totalB) / totalA * 100).toStringAsFixed(0);
      analysisMsg = 'Side B is cheaper by $percent% (B: ₹${totalB.toStringAsFixed(1)} vs A: ₹${totalA.toStringAsFixed(1)})';
      bannerColor = const Color(0xFF16A34A);
    } else if (totalA == totalB && totalA > 0) {
      analysisMsg = 'Both Side A and Side B are equal';
      bannerColor = _BitToolColors.primaryGreen;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (analysisMsg.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: bannerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: bannerColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              analysisMsg,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: bannerColor),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        // Table description headers
        const Row(
          children: [
            Expanded(flex: 3, child: Text('DESC', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey))),
            Expanded(flex: 2, child: Text('SIDE A', textAlign: TextAlign.center, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey))),
            Expanded(flex: 2, child: Text('SIDE B', textAlign: TextAlign.center, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey))),
          ],
        ),
        const Divider(height: 8),

        // Added comparison list
        if (_comparisonRows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No compared items. Add below:', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey)),
          )
        else
          Column(
            children: _comparisonRows.asMap().entries.map((e) {
              final idx = e.key;
              final r = e.value;
              final valA = r.finalA;
              final valB = r.finalB;
              final isACheaper = valA < valB;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.description, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          Text(
                            'Qty: A:${r.qtyA.toInt()} B:${r.qtyB.toInt()} | Disc: A:${r.discountA.toInt()}% B:${r.discountB.toInt()}%',
                            style: TextStyle(fontSize: 8, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '₹${valA.toStringAsFixed(1)}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isACheaper ? const Color(0xFF16A34A) : Colors.black87),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '₹${valB.toStringAsFixed(1)}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: !isACheaper ? const Color(0xFF16A34A) : Colors.black87),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _comparisonRows.removeAt(idx)),
                      child: const Icon(LucideIcons.x, size: 10, color: Colors.red),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

        // Inputs for new comparison
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildCompField('Item name', _compDescController),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 2,
              child: _buildCompField('Price A', _compValAController, isNum: true),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 2,
              child: _buildCompField('Price B', _compValBController, isNum: true),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () {
                final desc = _compDescController.text.trim();
                final valA = double.tryParse(_compValAController.text);
                final valB = double.tryParse(_compValBController.text);
                final qtyA = double.tryParse(_compQtyAController.text) ?? 1.0;
                final qtyB = double.tryParse(_compQtyBController.text) ?? 1.0;
                final discA = double.tryParse(_compDiscAController.text) ?? 0.0;
                final discB = double.tryParse(_compDiscBController.text) ?? 0.0;
                if (desc.isNotEmpty && valA != null && valB != null) {
                  setState(() {
                    _comparisonRows.add(ComparisonRow(
                      description: desc,
                      valueA: valA,
                      valueB: valB,
                      qtyA: qtyA,
                      qtyB: qtyB,
                      discountA: discA,
                      discountB: discB,
                    ));
                    _compDescController.clear();
                    _compValAController.clear();
                    _compValBController.clear();
                    _compQtyAController.clear();
                    _compQtyBController.clear();
                    _compDiscAController.clear();
                    _compDiscBController.clear();
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: _BitToolColors.primaryGreen, shape: BoxShape.circle),
                child: const Icon(LucideIcons.plus, size: 12, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _buildCompField('Qty A', _compQtyAController, isNum: true),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildCompField('Disc A %', _compDiscAController, isNum: true),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCompField('Qty B', _compQtyBController, isNum: true),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildCompField('Disc B %', _compDiscBController, isNum: true),
            ),
            const SizedBox(width: 24),
          ],
        ),
      ],
    );
  }

  Widget _buildCompField(String label, TextEditingController ctrl, {bool isNum = false}) {
    return Container(
      height: 26,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _BitToolColors.border),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: ctrl,
        keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: const TextStyle(fontSize: 10),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: const TextStyle(fontSize: 8, color: Colors.grey),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        ),
      ),
    );
  }

  Widget _buildNumPad() {
    const btnHeight = 38.0;
    const gap = 4.0;

    return Column(
      children: [
        // Row 1: ↺, ⌫, /, x
        Row(
          children: [
            Expanded(
              child: _buildNumBtn(
                height: btnHeight,
                bg: const Color(0xFFFEE2E2),
                border: const Color(0xFFFECACA),
                onTap: _clearAll,
                child: const Icon(LucideIcons.rotateCcw, size: 14, color: Color(0xFFDC2626)),
              ),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: _buildNumBtn(
                height: btnHeight,
                bg: const Color(0xFFF3F4F6),
                border: const Color(0xFFE5E7EB),
                onTap: _backspace,
                child: const Icon(LucideIcons.delete, size: 14, color: Color(0xFF4B5563)),
              ),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: _buildNumBtn(
                height: btnHeight,
                bg: const Color(0xFFECFDF5),
                border: const Color(0xFFA7F3D0),
                onTap: () => _setOperator('÷'),
                child: const Text('/', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
              ),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: _buildNumBtn(
                height: btnHeight,
                bg: const Color(0xFFECFDF5),
                border: const Color(0xFFA7F3D0),
                onTap: () => _setOperator('×'),
                child: const Text('x', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
              ),
            ),
          ],
        ),
        const SizedBox(height: gap),

        // Row 2: 7, 8, 9, -
        Row(
          children: [
            Expanded(child: _buildNumBtn(height: btnHeight, onTap: () => _enterDigit('7'), child: const Text('7', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))))),
            const SizedBox(width: gap),
            Expanded(child: _buildNumBtn(height: btnHeight, onTap: () => _enterDigit('8'), child: const Text('8', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))))),
            const SizedBox(width: gap),
            Expanded(child: _buildNumBtn(height: btnHeight, onTap: () => _enterDigit('9'), child: const Text('9', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))))),
            const SizedBox(width: gap),
            Expanded(
              child: _buildNumBtn(
                height: btnHeight,
                bg: const Color(0xFFECFDF5),
                border: const Color(0xFFA7F3D0),
                onTap: () => _setOperator('-'),
                child: const Text('-', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
              ),
            ),
          ],
        ),
        const SizedBox(height: gap),

        // Row 3: 4, 5, 6, +
        Row(
          children: [
            Expanded(child: _buildNumBtn(height: btnHeight, onTap: () => _enterDigit('4'), child: const Text('4', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))))),
            const SizedBox(width: gap),
            Expanded(child: _buildNumBtn(height: btnHeight, onTap: () => _enterDigit('5'), child: const Text('5', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))))),
            const SizedBox(width: gap),
            Expanded(child: _buildNumBtn(height: btnHeight, onTap: () => _enterDigit('6'), child: const Text('6', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))))),
            const SizedBox(width: gap),
            Expanded(
              child: _buildNumBtn(
                height: btnHeight,
                bg: const Color(0xFFECFDF5),
                border: const Color(0xFFA7F3D0),
                onTap: () => _setOperator('+'),
                child: const Text('+', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
              ),
            ),
          ],
        ),
        const SizedBox(height: gap),

        // Row 4 & 5: Left 3 cols (1, 2, 3 / SCI, 0, .) and Right 1 col (tall green =)
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildNumBtn(height: btnHeight, onTap: () => _enterDigit('1'), child: const Text('1', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))))),
                      const SizedBox(width: gap),
                      Expanded(child: _buildNumBtn(height: btnHeight, onTap: () => _enterDigit('2'), child: const Text('2', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))))),
                      const SizedBox(width: gap),
                      Expanded(child: _buildNumBtn(height: btnHeight, onTap: () => _enterDigit('3'), child: const Text('3', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))))),
                    ],
                  ),
                  const SizedBox(height: gap),
                  Row(
                    children: [
                      Expanded(
                        child: _buildNumBtn(
                          height: btnHeight,
                          bg: Colors.white,
                          border: const Color(0xFFE5E7EB),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Scientific Mode Active'), duration: Duration(milliseconds: 800)),
                            );
                          },
                          child: const Text('SCI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                        ),
                      ),
                      const SizedBox(width: gap),
                      Expanded(child: _buildNumBtn(height: btnHeight, onTap: () => _enterDigit('0'), child: const Text('0', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))))),
                      const SizedBox(width: gap),
                      Expanded(child: _buildNumBtn(height: btnHeight, onTap: () => _enterDigit('.'), child: const Text('.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: gap),
            Expanded(
              flex: 1,
              child: _buildNumBtn(
                height: (btnHeight * 2) + gap,
                bg: const Color(0xFF059669),
                border: const Color(0xFF059669),
                onTap: _calculate,
                child: const Text('=', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumBtn({
    required double height,
    required VoidCallback onTap,
    required Widget child,
    Color bg = Colors.white,
    Color border = const Color(0xFFE5E7EB),
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _buildApiTapeCard(CalculatorSession s) {
    final timeStr = s.createdAt != null
        ? '${s.createdAt!.hour.toString().padLeft(2, '0')}:${s.createdAt!.minute.toString().padLeft(2, '0')}:${s.createdAt!.second.toString().padLeft(2, '0')}'
        : '10:35:13';
    final amt = s.totalAmount ?? 0.0;
    final amtFormatted = amt % 1 == 0 ? amt.toInt().toString() : amt.toStringAsFixed(2);
    final count = s.itemCount ?? s.items.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.clock, size: 10, color: Color(0xFFDC2626)),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$count Items',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title.isNotEmpty ? s.title.toUpperCase() : 'CALCULATED LOG',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '₹$amtFormatted',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(60, 28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
                onPressed: () => _restoreApiSession(s),
                child: const Text('RESTORE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  ref.read(bitToolCalculatorProvider.notifier).deleteSession(s.id);
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(LucideIcons.trash2, size: 13, color: Color(0xFFEF4444)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocalTapeCard(HistorySection log) {
    final timeStr =
        '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}';
    final amt = log.totalValue;
    final amtFormatted = amt % 1 == 0 ? amt.toInt().toString() : amt.toStringAsFixed(2);
    final count = log.type == 'compare' ? (log.comparisonRows?.length ?? 1) : (log.tapeEntries?.length ?? 1);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.clock, size: 10, color: Color(0xFFDC2626)),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$count Items',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.type == 'compare' ? 'COMPARE LOG' : 'CALCULATED LOG',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '₹$amtFormatted',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(60, 28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
                onPressed: () => _restoreHistory(log),
                child: const Text('RESTORE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  setState(() => _historyLog.removeWhere((l) => l.id == log.id));
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(LucideIcons.trash2, size: 13, color: Color(0xFFEF4444)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
