import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/app_state_provider.dart';
import '../../models/label_model.dart';

class CreateLabelDialog extends ConsumerStatefulWidget {
  final LabelModel? labelToEdit;

  const CreateLabelDialog({super.key, this.labelToEdit});

  static Future<void> show(BuildContext context, {LabelModel? labelToEdit}) {
    return showDialog(
      context: context,
      builder: (context) => CreateLabelDialog(labelToEdit: labelToEdit),
    );
  }

  @override
  ConsumerState<CreateLabelDialog> createState() => _CreateLabelDialogState();
}

class _CreateLabelDialogState extends ConsumerState<CreateLabelDialog> {
  final TextEditingController _nameController = TextEditingController();
  String _parentLabel = 'Top level (no parent)';
  late Color _selectedColor;

  final List<Color> _colorOptions = const [
    Color(0xFF2563EB), // Blue
    Color(0xFFEF4444), // Red
    Color(0xFF10B981), // Emerald Green
    Color(0xFFF59E0B), // Amber/Yellow
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
    Color(0xFF64748B), // Slate/Grey
    Color(0xFF3B82F6), // Royal Blue
  ];

  @override
  void initState() {
    super.initState();
    if (widget.labelToEdit != null) {
      _nameController.text = widget.labelToEdit!.name;
      _selectedColor = widget.labelToEdit!.color;
    } else {
      _selectedColor = const Color(0xFF2563EB);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveLabel() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    if (widget.labelToEdit != null) {
      ref.read(customLabelsProvider.notifier).editLabel(
            widget.labelToEdit!.id,
            name,
            _selectedColor,
          );
    } else {
      ref.read(customLabelsProvider.notifier).addLabel(name, _selectedColor);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(appUiProvider).isDarkMode;
    final customLabels = ref.watch(customLabelsProvider);
    final isEditing = widget.labelToEdit != null;

    final List<String> parentOptions = [
      'Top level (no parent)',
      ...customLabels
          .where((l) => widget.labelToEdit == null || l.id != widget.labelToEdit!.id)
          .map((l) => l.name),
    ];

    if (!parentOptions.contains(_parentLabel)) {
      _parentLabel = 'Top level (no parent)';
    }

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 22.0),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Title & Close Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit label' : 'New label',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: isDark ? Colors.white60 : Colors.black45,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Field 1: Label Name
                Text(
                  'Please enter a new label name:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Finance, Projects, Work',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFFAFAFA),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF2563EB),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Field 2: Label color
                Text(
                  'Label color:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _colorOptions.map((c) {
                      final isSelected = c.toARGB32() == _selectedColor.toARGB32();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedColor = c),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: c.withValues(alpha: 0.4),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 18),

                // Field 3: Nest label under
                Text(
                  'Nest label under: (optional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _parentLabel,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFFAFAFA),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF2563EB),
                        width: 1.5,
                      ),
                    ),
                  ),
                  items: parentOptions
                      .map(
                        (opt) => DropdownMenuItem(
                          value: opt,
                          child: Text(opt),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _parentLabel = val);
                    }
                  },
                ),
                const SizedBox(height: 26),

                // Actions: Cancel & Create / Save
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        foregroundColor:
                            isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _saveLabel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF88A9DF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        isEditing ? 'Save' : 'Create',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
