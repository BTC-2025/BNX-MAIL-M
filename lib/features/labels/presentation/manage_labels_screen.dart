import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/token_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/create_label_dialog.dart';
import '../../../data/app_state_provider.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../models/label_model.dart';

class ManageLabelsScreen extends ConsumerStatefulWidget {
  const ManageLabelsScreen({super.key});

  @override
  ConsumerState<ManageLabelsScreen> createState() => _ManageLabelsScreenState();
}

class _ManageLabelsScreenState extends ConsumerState<ManageLabelsScreen> {
  // System labels visibility
  final Map<String, bool> _systemListVis = {
    'Inbox': true,
    'Starred': true,
    'Snoozed': true,
    'Sent': true,
    'Scheduled': true,
    'Drafts': true,
    'All Mail': true,
    'Spam': true,
    'Trash': true,
  };

  final Map<String, bool> _systemImapVis = {
    'Inbox': true,
    'Starred': true,
    'Snoozed': true,
    'Sent': true,
    'Scheduled': true,
    'Drafts': true,
    'All Mail': true,
    'Spam': true,
    'Trash': true,
  };

  // Categories visibility
  final Map<String, bool> _categoriesListVis = {
    'Purchases': true,
    'Social': true,
    'Updates': true,
    'Promotions': true,
    'Job': true,
    'Important': true,
  };

  final Map<String, bool> _categoriesMessageVis = {
    'Purchases': true,
    'Social': true,
    'Updates': true,
    'Promotions': true,
    'Job': true,
    'Important': true,
  };

  // Custom labels message list visibility (show in label list is backed by sidebarLabelVisibility)
  final Map<String, bool> _customLabelsMessageVis = {};

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialSettings();
    });
  }

  Future<void> _loadInitialSettings() async {
    final uiState = ref.read(appUiProvider);
    final vis = uiState.sidebarLabelVisibility;

    // Load from active UI state
    setState(() {
      _systemListVis['Inbox'] = vis['Inbox'] ?? true;
      _systemListVis['Starred'] = vis['Starred'] ?? true;
      _systemListVis['Snoozed'] = vis['Snoozed'] ?? true;
      _systemListVis['Sent'] = vis['Sent'] ?? true;
      _systemListVis['Scheduled'] = vis['Scheduled'] ?? true;
      _systemListVis['Drafts'] = vis['Draft'] ?? vis['Drafts'] ?? true;
      _systemListVis['All Mail'] = vis['All Mail'] ?? true;
      _systemListVis['Spam'] = vis['Spam'] ?? true;
      _systemListVis['Trash'] = vis['Trash'] ?? true;
    });

    // Load stored settings from disk/TokenService
    final email = await TokenService.getUserEmail();
    if (email != null && email.isNotEmpty) {
      final settings = await TokenService.getUserSettings(email);
      if (settings != null) {
        if (settings['systemImapVis'] is Map) {
          final m = settings['systemImapVis'] as Map;
          setState(() {
            for (final entry in m.entries) {
              _systemImapVis[entry.key.toString()] = entry.value == true;
            }
          });
        }
        if (settings['categoriesListVis'] is Map) {
          final m = settings['categoriesListVis'] as Map;
          setState(() {
            for (final entry in m.entries) {
              _categoriesListVis[entry.key.toString()] = entry.value == true;
            }
          });
        }
        if (settings['categoriesMessageVis'] is Map) {
          final m = settings['categoriesMessageVis'] as Map;
          setState(() {
            for (final entry in m.entries) {
              _categoriesMessageVis[entry.key.toString()] = entry.value == true;
            }
          });
        }
        if (settings['customLabelsMessageVis'] is Map) {
          final m = settings['customLabelsMessageVis'] as Map;
          setState(() {
            for (final entry in m.entries) {
              _customLabelsMessageVis[entry.key.toString()] = entry.value == true;
            }
          });
        }
      }
    }
  }

  Future<void> _saveAllSettings() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final email = await TokenService.getUserEmail();
      final uiNotifier = ref.read(appUiProvider.notifier);

      // Build updated sidebar visibility map
      final Map<String, bool> updatedSidebar = {
        'Inbox': _systemListVis['Inbox'] ?? true,
        'Starred': _systemListVis['Starred'] ?? true,
        'Snoozed': _systemListVis['Snoozed'] ?? true,
        'Sent': _systemListVis['Sent'] ?? true,
        'Scheduled': _systemListVis['Scheduled'] ?? true,
        'Draft': _systemListVis['Drafts'] ?? true,
        'Drafts': _systemListVis['Drafts'] ?? true,
        'All Mail': _systemListVis['All Mail'] ?? true,
        'Spam': _systemListVis['Spam'] ?? true,
        'Trash': _systemListVis['Trash'] ?? true,
      };

      // Add custom labels
      final customLabels = ref.read(customLabelsProvider);
      final currentSidebar = ref.read(appUiProvider).sidebarLabelVisibility;
      for (final lbl in customLabels) {
        updatedSidebar[lbl.name] = currentSidebar[lbl.name] ?? true;
      }

      // 1. Update UI state provider
      uiNotifier.setSidebarLabels(updatedSidebar);

      // 2. Persist to TokenService
      if (email != null && email.isNotEmpty) {
        await TokenService.saveUserSettings(email, {
          'sidebarLabels': updatedSidebar,
          'systemImapVis': _systemImapVis,
          'categoriesListVis': _categoriesListVis,
          'categoriesMessageVis': _categoriesMessageVis,
          'customLabelsMessageVis': _customLabelsMessageVis,
        });

        // 3. Best effort sync to backend settings
        try {
          await SettingsRepository.updateSettings({
            'sidebarLabels': updatedSidebar,
          });
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Label preferences saved successfully'),
              ],
            ),
            backgroundColor: const Color(0xFF195BAC),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save preferences'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _confirmDeleteLabel(BuildContext context, LabelModel label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete label',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to remove label "${label.name}"? This action cannot be undone.',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(customLabelsProvider.notifier).deleteLabel(label.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Label "${label.name}" removed'),
                  backgroundColor: const Color(0xFFEF4444),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;
    final customLabels = ref.watch(customLabelsProvider);
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Container(
      color: isDark ? BNXColors.darkBg : const Color(0xFFF1F5F9),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 14.0 : 28.0,
            vertical: 24.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Area ───────────────────────────────────────────────
              _buildHeader(isDark, isMobile),
              const SizedBox(height: 24),

              // ── Section 1: System labels ──────────────────────────────────
              _buildSystemLabelsCard(isDark, isMobile),
              const SizedBox(height: 24),

              // ── Section 2: Categories ─────────────────────────────────────
              _buildCategoriesCard(isDark, isMobile),
              const SizedBox(height: 24),

              // ── Section 3: Labels ─────────────────────────────────────────
              _buildCustomLabelsCard(context, customLabels, isDark, isMobile),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark, bool isMobile) {
    final titleBlock = Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE9F4FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.local_offer_outlined,
            color: Color(0xFF195BAC),
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Label management',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 23,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Create, edit, remove, and manage how labels appear in your BNXmail.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final saveButton = ElevatedButton.icon(
      onPressed: _isSaving ? null : _saveAllSettings,
      icon: _isSaving
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.check_rounded, size: 16),
      label: const Text(
        'Save',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF195BAC),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleBlock,
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: saveButton,
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: titleBlock),
        const SizedBox(width: 16),
        saveButton,
      ],
    );
  }

  // ── Section 1: System labels ──────────────────────────────────────────────
  Widget _buildSystemLabelsCard(bool isDark, bool isMobile) {
    final systemItems = [
      {'name': 'Inbox', 'icon': Icons.inbox_outlined},
      {'name': 'Starred', 'icon': Icons.star_border_rounded},
      {'name': 'Snoozed', 'icon': Icons.access_time_rounded},
      {'name': 'Sent', 'icon': Icons.send_outlined},
      {'name': 'Scheduled', 'icon': Icons.schedule_rounded},
      {'name': 'Drafts', 'icon': Icons.drafts_outlined},
      {'name': 'All Mail', 'icon': Icons.mail_outline_rounded},
      {'name': 'Spam', 'icon': Icons.error_outline_rounded},
      {'name': 'Trash', 'icon': Icons.delete_outline_rounded},
    ];

    return _buildCardContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System labels',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 18),

          LayoutBuilder(
            builder: (context, constraints) {
              final content = Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            'Label',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 6,
                          child: Text(
                            'Show in label list',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Row(
                            children: [
                              Text(
                                'Show in IMAP',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Tooltip(
                                message: 'Show folder in external IMAP client synchronization',
                                child: Icon(
                                  Icons.info_outline_rounded,
                                  size: 14,
                                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Rows
                  ...systemItems.map((item) {
                    final name = item['name'] as String;
                    final icon = item['icon'] as IconData;
                    final isListShown = _systemListVis[name] ?? true;
                    final isImapShown = _systemImapVis[name] ?? true;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Row(
                              children: [
                                Icon(
                                  icon,
                                  size: 18,
                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 6,
                            child: _buildCheckbox(
                              value: isListShown,
                              label: 'Show in label list',
                              isDark: isDark,
                              onChanged: (val) {
                                setState(() => _systemListVis[name] = val);
                                final notifier = ref.read(appUiProvider.notifier);
                                final targetKey = name == 'Drafts' ? 'Draft' : name;
                                notifier.setSidebarLabel(targetKey, val);
                              },
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: _buildCheckbox(
                              value: isImapShown,
                              isDark: isDark,
                              onChanged: (val) {
                                setState(() => _systemImapVis[name] = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );

              if (constraints.maxWidth < 560) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: 560,
                    child: content,
                  ),
                );
              }
              return content;
            },
          ),
        ],
      ),
    );
  }

  // ── Section 2: Categories ─────────────────────────────────────────────────
  Widget _buildCategoriesCard(bool isDark, bool isMobile) {
    final categoryItems = [
      {'name': 'Purchases', 'icon': Icons.shopping_bag_outlined},
      {'name': 'Social', 'icon': Icons.people_outline_rounded},
      {'name': 'Updates', 'icon': Icons.info_outline_rounded},
      {'name': 'Promotions', 'icon': Icons.campaign_outlined},
      {'name': 'Job', 'icon': Icons.work_outline_rounded},
      {'name': 'Important', 'icon': Icons.label_important_outline_rounded},
    ];

    return _buildCardContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categories',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 18),

          LayoutBuilder(
            builder: (context, constraints) {
              final content = Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            'Category',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: Text(
                            'Show in label list',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: Text(
                            'Show in message list',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Rows
                  ...categoryItems.map((item) {
                    final name = item['name'] as String;
                    final icon = item['icon'] as IconData;
                    final isListShown = _categoriesListVis[name] ?? true;
                    final isMessageShown = _categoriesMessageVis[name] ?? true;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Row(
                              children: [
                                Icon(
                                  icon,
                                  size: 18,
                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 5,
                            child: _buildCheckbox(
                              value: isListShown,
                              label: 'Show',
                              isDark: isDark,
                              onChanged: (val) {
                                setState(() => _categoriesListVis[name] = val);
                              },
                            ),
                          ),
                          Expanded(
                            flex: 5,
                            child: _buildCheckbox(
                              value: isMessageShown,
                              label: 'Show',
                              isDark: isDark,
                              onChanged: (val) {
                                setState(() => _categoriesMessageVis[name] = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );

              if (constraints.maxWidth < 560) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: 560,
                    child: content,
                  ),
                );
              }
              return content;
            },
          ),
        ],
      ),
    );
  }

  // ── Section 3: Labels ─────────────────────────────────────────────────────
  Widget _buildCustomLabelsCard(
    BuildContext context,
    List<LabelModel> customLabels,
    bool isDark,
    bool isMobile,
  ) {
    final uiState = ref.watch(appUiProvider);
    final sidebarVis = uiState.sidebarLabelVisibility;

    final createButton = ElevatedButton.icon(
      onPressed: () => CreateLabelDialog.show(context),
      icon: const Icon(Icons.add_rounded, size: 16),
      label: const Text(
        'Create new label',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF195BAC),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    return _buildCardContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Labels',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              createButton,
            ],
          ),
          const SizedBox(height: 18),

          LayoutBuilder(
            builder: (context, constraints) {
              final content = Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 4,
                          child: Text(
                            'Label',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        const Expanded(
                          flex: 3,
                          child: Text(
                            'Show in label list',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        const Expanded(
                          flex: 3,
                          child: Text(
                            'Show in message list',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Actions',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  if (customLabels.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.label_outline_rounded,
                              size: 38,
                              color: isDark ? Colors.white30 : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No custom labels created yet.',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Click "+ Create new label" to categorize emails.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...customLabels.map((lbl) {
                      final isListShown = sidebarVis[lbl.name] ?? true;
                      final isMessageShown = _customLabelsMessageVis[lbl.name] ?? true;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Column 1: Color swatch + Name
                            Expanded(
                              flex: 4,
                              child: Row(
                                children: [
                                  Container(
                                    width: 13,
                                    height: 13,
                                    decoration: BoxDecoration(
                                      color: lbl.color,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      lbl.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Column 2: Show in label list
                            Expanded(
                              flex: 3,
                              child: _buildCheckbox(
                                value: isListShown,
                                label: 'Show',
                                isDark: isDark,
                                onChanged: (val) {
                                  ref.read(appUiProvider.notifier).setSidebarLabel(lbl.name, val);
                                },
                              ),
                            ),

                            // Column 3: Show in message list
                            Expanded(
                              flex: 3,
                              child: _buildCheckbox(
                                value: isMessageShown,
                                label: 'Show',
                                isDark: isDark,
                                onChanged: (val) {
                                  setState(() => _customLabelsMessageVis[lbl.name] = val);
                                },
                              ),
                            ),

                            // Column 4: Actions (Edit & Remove)
                            Expanded(
                              flex: 4,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Wrap(
                                  alignment: WrapAlignment.end,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 12,
                                  children: [
                                    InkWell(
                                      onTap: () => CreateLabelDialog.show(context, labelToEdit: lbl),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.edit_outlined, size: 14, color: Color(0xFF2563EB)),
                                            SizedBox(width: 4),
                                            Text(
                                              'Edit',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF2563EB),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => _confirmDeleteLabel(context, lbl),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                                            SizedBox(width: 4),
                                            Text(
                                              'Remove',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFFEF4444),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              );

              if (constraints.maxWidth < 620) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: 620,
                    child: content,
                  ),
                );
              }
              return content;
            },
          ),

          const SizedBox(height: 20),
          // Save button on bottom right of Labels card
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveAllSettings,
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 16),
              label: const Text(
                'Save',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF195BAC),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable Card Wrapper ─────────────────────────────────────────────────
  Widget _buildCardContainer({
    required Widget child,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── Custom Styled Checkbox ────────────────────────────────────────────────
  Widget _buildCheckbox({
    required bool value,
    required ValueChanged<bool> onChanged,
    String? label,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: value ? const Color(0xFF195BAC) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: value
                      ? const Color(0xFF195BAC)
                      : (isDark ? Colors.white38 : const Color(0xFFCBD5E1)),
                  width: 1.5,
                ),
              ),
              child: value
                  ? const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: Colors.white,
                    )
                  : null,
            ),
            if (label != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
