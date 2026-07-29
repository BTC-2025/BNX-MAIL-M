import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../theme/neumorphic.dart';

enum CalcMode { gst, discount, currency, compare }

enum CurrencyType { inr, usd }

enum CalculationType { tape, comparison }

class TapeEntry {
  final String id;
  final String operator; // '=', '+', '-', '×', '÷', '+GST', '-DISC'
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

  double getConvertedValue(CurrencyType type, double rate) {
    if (type == CurrencyType.usd) {
      return value / rate;
    }
    return value;
  }

  double getConvertedRunningTotal(CurrencyType type, double rate) {
    if (type == CurrencyType.usd) {
      return runningTotal / rate;
    }
    return runningTotal;
  }
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
  final CalculationType type;
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

class BNXCalculatorWidget extends StatefulWidget {
  final bool isDark;
  const BNXCalculatorWidget({super.key, required this.isDark});

  @override
  State<BNXCalculatorWidget> createState() => _BNXCalculatorWidgetState();
}

class _BNXCalculatorWidgetState extends State<BNXCalculatorWidget> {
  final ScrollController _tapeScrollController = ScrollController();
  final double _usdRate = 83.5;

  List<TapeEntry> _tapeEntries = [];
  List<ComparisonRow> _comparisonRows = [];
  final List<HistorySection> _historySections = [];

  String _currentInput = '0';
  String _pendingOperator = '';
  CalcMode _activeMode = CalcMode.gst;
  CurrencyType _currencyType = CurrencyType.inr;
  bool _showScientific = false;
  bool _showLogs = false;

  final _compDescController = TextEditingController();
  final _compValAController = TextEditingController();
  final _compValBController = TextEditingController();
  final _compQtyAController = TextEditingController(text: '1');
  final _compQtyBController = TextEditingController(text: '1');
  final _compDiscAController = TextEditingController(text: '0');
  final _compDiscBController = TextEditingController(text: '0');

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

  double get _currentRunningTotal {
    if (_tapeEntries.isEmpty) return 0.0;
    return _tapeEntries.last.runningTotal;
  }

  bool get _hasBase => _tapeEntries.any((e) => e.isBase);

  void _enterDigit(String digit) {
    setState(() {
      if (_currentInput == '0') {
        if (digit == '.') {
          _currentInput = '0.';
        } else {
          _currentInput = digit;
        }
      } else {
        if (digit == '.' && _currentInput.contains('.')) {
          // Prevent multiple decimals
          return;
        }
        _currentInput += digit;
      }
    });
  }

  void _backspace() {
    setState(() {
      if (_currentInput.length <= 1) {
        _currentInput = '0';
      } else {
        _currentInput = _currentInput.substring(0, _currentInput.length - 1);
      }
    });
  }

  void _clearAll() {
    setState(() {
      _tapeEntries = [];
      _comparisonRows = [];
      _currentInput = '0';
      _pendingOperator = '';
    });
  }

  void _setOperator(String op) {
    setState(() {
      final inputVal = double.tryParse(_currentInput) ?? 0.0;

      if (!_hasBase) {
        // Set Base amount
        _tapeEntries.add(
          TapeEntry(
            id: DateTime.now().toString(),
            operator: '=',
            value: inputVal,
            runningTotal: inputVal,
            isBase: true,
          ),
        );
        _currentInput = '0';
        _pendingOperator = op;
      } else {
        if (_currentInput != '0') {
          _applyPendingCalculation();
        }
        _pendingOperator = op;
      }
    });
    _scrollTapeToBottom();
  }

  void _applyPendingCalculation() {
    final inputVal = double.tryParse(_currentInput) ?? 0.0;
    if (_pendingOperator.isEmpty) return;

    double newTotal = _currentRunningTotal;
    switch (_pendingOperator) {
      case '+':
        newTotal += inputVal;
        break;
      case '-':
        newTotal -= inputVal;
        break;
      case '×':
        newTotal *= inputVal;
        break;
      case '÷':
        if (inputVal != 0.0) {
          newTotal /= inputVal;
        }
        break;
    }

    _tapeEntries.add(
      TapeEntry(
        id: DateTime.now().toString(),
        operator: _pendingOperator,
        value: inputVal,
        runningTotal: newTotal,
      ),
    );

    _currentInput = '0';
  }

  void _calculate() {
    setState(() {
      if (_pendingOperator.isNotEmpty && _currentInput != '0') {
        _applyPendingCalculation();
        _pendingOperator = '';
      }
    });
    _scrollTapeToBottom();
  }

  void _applyGstPreset(double percent) {
    setState(() {
      final base = _currentRunningTotal;
      if (base == 0.0) return;

      final gstVal = base * (percent / 100.0);
      final newTotal = base + gstVal;

      _tapeEntries.add(
        TapeEntry(
          id: DateTime.now().toString(),
          operator: '+GST',
          value: gstVal,
          runningTotal: newTotal,
          presetTag: '${percent.toInt()}% GST',
        ),
      );
    });
    _scrollTapeToBottom();
  }

  void _applyDiscountPreset(double percent) {
    setState(() {
      final base = _currentRunningTotal;
      if (base == 0.0) return;

      final discVal = base * (percent / 100.0);
      final newTotal = base - discVal;

      _tapeEntries.add(
        TapeEntry(
          id: DateTime.now().toString(),
          operator: '-DISC',
          value: discVal,
          runningTotal: newTotal,
          presetTag: '${percent.toInt()}% Disc',
        ),
      );
    });
    _scrollTapeToBottom();
  }

  void _saveCurrentToHistory() {
    if (_activeMode == CalcMode.compare) {
      if (_comparisonRows.isEmpty) return;
      double totalA = 0;
      for (var r in _comparisonRows) {
        if (r.valueA != null) totalA += r.finalA;
      }
      setState(() {
        _historySections.add(
          HistorySection(
            id: DateTime.now().toString(),
            timestamp: DateTime.now(),
            comparisonRows: List.from(_comparisonRows),
            type: CalculationType.comparison,
            totalValue: totalA,
          ),
        );
      });
    } else {
      if (_tapeEntries.isEmpty) return;
      setState(() {
        _historySections.add(
          HistorySection(
            id: DateTime.now().toString(),
            timestamp: DateTime.now(),
            tapeEntries: List.from(_tapeEntries),
            type: CalculationType.tape,
            totalValue: _currentRunningTotal,
          ),
        );
      });
    }
  }

  void _restoreHistory(HistorySection sec) {
    setState(() {
      if (sec.type == CalculationType.comparison) {
        _activeMode = CalcMode.compare;
        _comparisonRows = List.from(sec.comparisonRows!);
      } else {
        _activeMode = CalcMode.gst;
        _tapeEntries = List.from(sec.tapeEntries!);
      }
      _showLogs = false;
    });
  }

  void _deleteHistory(String id) {
    setState(() {
      _historySections.removeWhere((s) => s.id == id);
    });
  }

  String _formatNumber(double val) {
    if (val == val.toInt()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2);
  }

  String _getTapeSummaryText() {
    final buffer = StringBuffer();
    buffer.writeln('--- BETA CALC LOG ---');
    for (var entry in _tapeEntries) {
      if (entry.isBase) {
        buffer.writeln('BASE: ${_formatNumber(entry.value)}');
      } else {
        buffer.writeln(
          '${entry.operator} ${_formatNumber(entry.value)} (Total: ${_formatNumber(entry.runningTotal)})',
        );
      }
      if (entry.label != null && entry.label!.isNotEmpty) {
        buffer.writeln('   [Label: ${entry.label}]');
      }
    }
    buffer.writeln('FINAL TOTAL: ${_formatNumber(_currentRunningTotal)}');
    return buffer.toString();
  }

  Widget _headerAction(
    IconData icon,
    String tooltip,
    VoidCallback onTap,
    bool isDark,
  ) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Icon(
            icon,
            size: 15,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primaryColor = isDark
        ? BNXColors.darkPrimary
        : BNXColors.lightPrimary;
    final onSurface = isDark ? Colors.white : BNXColors.lightTextPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header actions
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: primaryColor, size: 14),
                const SizedBox(width: 4),
                Text(
                  'BETA CALC',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                _headerAction(
                  Icons.save_alt_rounded,
                  'Save Session',
                  _saveCurrentToHistory,
                  isDark,
                ),
                const SizedBox(width: 4),
                _headerAction(
                  _showLogs
                      ? Icons.history_toggle_off_rounded
                      : Icons.history_rounded,
                  'Logs',
                  () => setState(() => _showLogs = !_showLogs),
                  isDark,
                ),
                const SizedBox(width: 4),
                _headerAction(Icons.share_outlined, 'Share logs', () {
                  final summary = _getTapeSummaryText();
                  Clipboard.setData(ClipboardData(text: summary));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Logs copied to clipboard'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }, isDark),
                const SizedBox(width: 4),
                _headerAction(Icons.delete_outline, 'Clear', _clearAll, isDark),
              ],
            ),
          ],
        ),

        const Divider(height: 8),

        // Logs listing
        if (_showLogs) ...[
          if (_historySections.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No logs saved yet.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: Scrollbar(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _historySections.length,
                  itemBuilder: (context, idx) {
                    final sec = _historySections[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sec.type == CalculationType.comparison
                                      ? 'Comparison Log'
                                      : 'Calculated Log',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${_currencyType == CurrencyType.usd ? "\$" : "₹"}${_formatNumber(sec.totalValue)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _restoreHistory(sec),
                            child: const Text(
                              'RESTORE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 14,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _deleteHistory(sec.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          const Divider(height: 12),
        ],

        // Tape entries list
        if (_activeMode != CalcMode.compare && _tapeEntries.isNotEmpty) ...[
          _buildTapeList(isDark, primaryColor),
          const SizedBox(height: 8),
        ],

        // Input / Continue indicator
        if (_activeMode != CalcMode.compare) ...[
          if (!_hasBase)
            NeumorphicContainer(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              borderRadius: 12,
              shape: NeumorphicShape.pressed,
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
              child: Row(
                children: [
                  const Text(
                    'SET BASE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Text(
                          _currentInput,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            NeumorphicContainer(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              borderRadius: 12,
              shape: NeumorphicShape.pressed,
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
              child: Row(
                children: [
                  Text(
                    _pendingOperator.isEmpty ? 'CONTINUE' : _pendingOperator,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Text(
                          _currentInput,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],

        // Mode specific selection tabs
        Row(
          children: [
            _modeButton('GST', CalcMode.gst, isDark, primaryColor),
            const SizedBox(width: 4),
            _modeButton(
              'Disc',
              CalcMode.discount,
              isDark,
              const Color(0xFFEA580C),
            ),
            const SizedBox(width: 4),
            _modeButton(
              _currencyType == CurrencyType.inr ? 'INR' : 'USD',
              CalcMode.currency,
              isDark,
              primaryColor,
            ),
            const SizedBox(width: 4),
            _modeButton('Comp', CalcMode.compare, isDark, primaryColor),
          ],
        ),

        const SizedBox(height: 8),

        // Mode specific view/presets
        _buildModeContent(isDark, primaryColor),

        const SizedBox(height: 8),

        // Scientific functions
        if (_showScientific && _activeMode != CalcMode.compare) ...[
          _buildScientificRow(isDark, primaryColor),
          const SizedBox(height: 6),
        ],

        // Number Pad
        if (_activeMode != CalcMode.compare)
          _buildNumberPad(isDark, primaryColor, onSurface)
        else
          const SizedBox.shrink(),

        // Total display
        if (_activeMode != CalcMode.compare) ...[
          const SizedBox(height: 8),
          NeumorphicContainer(
            padding: const EdgeInsets.all(12),
            borderRadius: 14,
            color: primaryColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Text(
                        '${_currencyType == CurrencyType.usd ? "\$" : "₹"}${_formatNumber(_currencyType == CurrencyType.usd ? _currentRunningTotal / _usdRate : _currentRunningTotal)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _modeButton(
    String label,
    CalcMode mode,
    bool isDark,
    Color activeColor,
  ) {
    final isActive = _activeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (mode == CalcMode.currency) {
            setState(() {
              _currencyType = _currencyType == CurrencyType.inr
                  ? CurrencyType.usd
                  : CurrencyType.inr;
            });
          } else {
            setState(() {
              _activeMode = mode;
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor
                : (isDark ? Colors.white10 : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isActive
                    ? Colors.white
                    : (isDark ? Colors.white60 : Colors.black87),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetRow(List<int> values, bool isGst, Color color) {
    return Row(
      children: values.map((v) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: GestureDetector(
              onTap: () {
                if (isGst) {
                  _applyGstPreset(v.toDouble());
                } else {
                  _applyDiscountPreset(v.toDouble());
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Center(
                  child: Text(
                    isGst ? '+$v%' : '-$v%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildModeContent(bool isDark, Color primaryColor) {
    switch (_activeMode) {
      case CalcMode.gst:
        return _buildPresetRow([5, 12, 18, 28], true, const Color(0xFF16A34A));
      case CalcMode.discount:
        return _buildPresetRow([5, 10, 20, 50], false, const Color(0xFFEA580C));
      case CalcMode.currency:
        return const SizedBox(height: 2);
      case CalcMode.compare:
        return _buildComparisonSection(isDark, primaryColor);
    }
  }

  Widget _buildTapeList(bool isDark, Color primaryColor) {
    _scrollTapeToBottom();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 110),
      child: Scrollbar(
        child: ListView.builder(
          controller: _tapeScrollController,
          shrinkWrap: true,
          itemCount: _tapeEntries.length,
          itemBuilder: (context, i) {
            final entry = _tapeEntries[i];
            final val = _currencyType == CurrencyType.usd
                ? entry.value / _usdRate
                : entry.value;
            final runTot = _currencyType == CurrencyType.usd
                ? entry.runningTotal / _usdRate
                : entry.runningTotal;
            final symbol = _currencyType == CurrencyType.usd ? r'$' : '₹';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                children: [
                  if (entry.isBase)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'BASE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    Text(
                      '${entry.operator} ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(width: 4),
                  if (entry.presetTag != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        entry.presetTag!,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Text(
                          _formatNumber(val),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Text(
                          '$symbol${_formatNumber(runTot)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 12,
                      color: Colors.grey,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _tapeEntries.removeAt(i);
                      });
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildScientificRow(bool isDark, Color primaryColor) {
    Widget sciButton(String label, VoidCallback onTap) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        sciButton('sin', () {
          final val = double.tryParse(_currentInput) ?? 0.0;
          setState(() {
            _currentInput = _formatNumber(math.sin(val));
          });
        }),
        sciButton('cos', () {
          final val = double.tryParse(_currentInput) ?? 0.0;
          setState(() {
            _currentInput = _formatNumber(math.cos(val));
          });
        }),
        sciButton('tan', () {
          final val = double.tryParse(_currentInput) ?? 0.0;
          setState(() {
            _currentInput = _formatNumber(math.tan(val));
          });
        }),
        sciButton('log', () {
          final val = double.tryParse(_currentInput) ?? 0.0;
          if (val > 0) {
            setState(() {
              _currentInput = _formatNumber(math.log(val) / math.ln10);
            });
          }
        }),
        sciButton('√', () {
          final val = double.tryParse(_currentInput) ?? 0.0;
          if (val >= 0) {
            setState(() {
              _currentInput = _formatNumber(math.sqrt(val));
            });
          }
        }),
      ],
    );
  }

  Widget _buildNumberPad(bool isDark, Color primary, Color onSurface) {
    Widget numButton(String label, {Color? textColor, VoidCallback? onTap}) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: NeumorphicButton(
            onPressed: onTap ?? () => _enterDigit(label),
            borderRadius: 10,
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: isDark ? BNXColors.darkSurface : Colors.white,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textColor ?? onSurface,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            numButton(
              'C',
              textColor: const Color(0xFFEA580C),
              onTap: _clearAll,
            ),
            numButton('⌫', textColor: Colors.grey, onTap: _backspace),
            numButton('/', textColor: primary, onTap: () => _setOperator('÷')),
            numButton(
              '×',
              textColor: Colors.redAccent,
              onTap: () => _setOperator('×'),
            ),
          ],
        ),
        Row(
          children: [
            numButton('7'),
            numButton('8'),
            numButton('9'),
            numButton('-', textColor: primary, onTap: () => _setOperator('-')),
          ],
        ),
        Row(
          children: [
            numButton('4'),
            numButton('5'),
            numButton('6'),
            numButton(
              '+',
              textColor: const Color(0xFF16A34A),
              onTap: () => _setOperator('+'),
            ),
          ],
        ),
        Row(
          children: [
            numButton('1'),
            numButton('2'),
            numButton('3'),
            numButton(
              'SCI',
              textColor: primary,
              onTap: () {
                setState(() {
                  _showScientific = !_showScientific;
                });
              },
            ),
          ],
        ),
        Row(
          children: [
            numButton('0'),
            numButton('.'),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: NeumorphicButton(
                  onPressed: _calculate,
                  borderRadius: 10,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: const Color(0xFF16A34A),
                  child: const Center(
                    child: Text(
                      '=',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComparisonSection(bool isDark, Color primaryColor) {
    double totalA = 0;
    double totalB = 0;
    for (var r in _comparisonRows) {
      totalA += r.finalA;
      totalB += r.finalB;
    }

    final diff = (totalA - totalB).abs();
    String analysis = 'No items to compare';
    Color bannerColor = Colors.grey;

    if (_comparisonRows.isNotEmpty) {
      if (totalA < totalB) {
        final pct = totalB > 0 ? (diff / totalB * 100).toStringAsFixed(0) : '0';
        analysis =
            'Side A is cheaper by $pct% (A: ₹${_formatNumber(totalA)} vs B: ₹${_formatNumber(totalB)})';
        bannerColor = const Color(0xFF16A34A);
      } else if (totalB < totalA) {
        final pct = totalA > 0 ? (diff / totalA * 100).toStringAsFixed(0) : '0';
        analysis =
            'Side B is cheaper by $pct% (B: ₹${_formatNumber(totalB)} vs A: ₹${_formatNumber(totalA)})';
        bannerColor = const Color(0xFF16A34A);
      } else {
        analysis = 'Side A and Side B are equal';
        bannerColor = primaryColor;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Banner analysis
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bannerColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: bannerColor.withValues(alpha: 0.2)),
          ),
          child: Text(
            analysis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: bannerColor,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 8),

        // List
        if (_comparisonRows.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: Scrollbar(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _comparisonRows.length,
                itemBuilder: (context, idx) {
                  final r = _comparisonRows[idx];
                  final finalA = r.finalA;
                  final finalB = r.finalB;
                  final isACheaper =
                      r.valueA != null && r.valueB != null && finalA < finalB;
                  final isBCheaper =
                      r.valueA != null && r.valueB != null && finalB < finalA;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.description.isEmpty ? 'Item' : r.description,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Qty: A:${r.qtyA.toInt()} B:${r.qtyB.toInt()} | Disc: A:${r.discountA.toInt()}% B:${r.discountB.toInt()}%',
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'A: ₹${_formatNumber(finalA)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isACheaper
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isACheaper ? const Color(0xFF16A34A) : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'B: ₹${_formatNumber(finalB)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isBCheaper
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isBCheaper ? const Color(0xFF16A34A) : null,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 12,
                            color: Colors.redAccent,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _comparisonRows.removeAt(idx);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

        const SizedBox(height: 8),

        // Inputs row 1 (Item, Price A, Price B)
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _compDescController,
                style: const TextStyle(fontSize: 10),
                decoration: const InputDecoration(
                  hintText: 'Item...',
                  isDense: true,
                  contentPadding: EdgeInsets.all(6),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _compValAController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 10),
                decoration: const InputDecoration(
                  hintText: 'Price A...',
                  isDense: true,
                  contentPadding: EdgeInsets.all(6),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _compValBController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 10),
                decoration: const InputDecoration(
                  hintText: 'Price B...',
                  isDense: true,
                  contentPadding: EdgeInsets.all(6),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            NeumorphicButton(
              onPressed: () {
                final d = _compDescController.text;
                final a = double.tryParse(_compValAController.text);
                final b = double.tryParse(_compValBController.text);
                final qA = double.tryParse(_compQtyAController.text) ?? 1.0;
                final qB = double.tryParse(_compQtyBController.text) ?? 1.0;
                final dA = double.tryParse(_compDiscAController.text) ?? 0.0;
                final dB = double.tryParse(_compDiscBController.text) ?? 0.0;

                if (a != null || b != null) {
                  setState(() {
                    _comparisonRows.add(
                      ComparisonRow(
                        description: d,
                        valueA: a,
                        valueB: b,
                        qtyA: qA,
                        qtyB: qB,
                        discountA: dA,
                        discountB: dB,
                      ),
                    );
                  });
                  _compDescController.clear();
                  _compValAController.clear();
                  _compValBController.clear();
                  _compQtyAController.text = '1';
                  _compQtyBController.text = '1';
                  _compDiscAController.text = '0';
                  _compDiscBController.text = '0';
                }
              },
              borderRadius: 6,
              padding: const EdgeInsets.all(6),
              color: primaryColor,
              child: const Icon(Icons.add, size: 14, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Inputs row 2 (Qty A, Disc A, Qty B, Disc B)
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 26,
                child: TextField(
                  controller: _compQtyAController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 9),
                  decoration: const InputDecoration(
                    labelText: 'Qty A',
                    labelStyle: TextStyle(fontSize: 8),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: SizedBox(
                height: 26,
                child: TextField(
                  controller: _compDiscAController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 9),
                  decoration: const InputDecoration(
                    labelText: 'Disc A %',
                    labelStyle: TextStyle(fontSize: 8),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 26,
                child: TextField(
                  controller: _compQtyBController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 9),
                  decoration: const InputDecoration(
                    labelText: 'Qty B',
                    labelStyle: TextStyle(fontSize: 8),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: SizedBox(
                height: 26,
                child: TextField(
                  controller: _compDiscBController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 9),
                  decoration: const InputDecoration(
                    labelText: 'Disc B %',
                    labelStyle: TextStyle(fontSize: 8),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 28), // balance with add button width
          ],
        ),
      ],
    );
  }
}
