import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/account_provider.dart';
import '../../../data/app_state_provider.dart';
import '../../../data/repositories/template_repository.dart';
import '../../../core/theme/colors.dart';

class BNXTemplate {
  final String id;
  final String title;
  final String category; // 'Business', 'Out of Office', 'Personal', 'General'
  final String type; // 'DEFAULT' or 'CUSTOM'
  final String subject;
  final String body;

  const BNXTemplate({
    required this.id,
    required this.title,
    required this.category,
    required this.type,
    required this.subject,
    required this.body,
  });

  BNXTemplate copyWith({
    String? id,
    String? title,
    String? category,
    String? type,
    String? subject,
    String? body,
  }) {
    return BNXTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      type: type ?? this.type,
      subject: subject ?? this.subject,
      body: body ?? this.body,
    );
  }

  static const List<BNXTemplate> defaultTemplates = [
    BNXTemplate(
      id: 'def_1',
      title: 'Meeting Request',
      category: 'Business',
      type: 'DEFAULT',
      subject: 'Meeting Request: Discussion on Project Updates',
      body:
          'Hi [Name],\n\nI hope you are doing well. I would like to schedule a brief meeting with you to discuss our progress on the project. Could you please let me know your availability for a 15-minute call sometime this week?\n\nLooking forward to hearing from you.\n\nBest regards,\n[Your Name]',
    ),
    BNXTemplate(
      id: 'def_2',
      title: 'Follow-Up Discussion',
      category: 'Business',
      type: 'DEFAULT',
      subject: 'Following up on our recent discussion',
      body:
          'Hi [Name],\n\nI hope this email finds you well. I wanted to follow up on our discussion last week regarding [Topic]. Please let me know if you\'ve had a chance to review the details or if you have any questions.\n\nThanks,\n[Your Name]',
    ),
    BNXTemplate(
      id: 'def_3',
      title: 'Out of Office',
      category: 'Out of Office',
      type: 'DEFAULT',
      subject: 'Out of Office: [Your Name] - [Start Date] to [End Date]',
      body:
          'Hello,\n\nThank you for your email. I am currently out of the office with limited access to my email. I will return on [Date]. If your request is urgent, please contact [Alternative Contact Name/Email]. Otherwise, I will reply to your message as soon as possible upon my return.\n\nBest regards,\n[Your Name]',
    ),
    BNXTemplate(
      id: 'def_4',
      title: 'Thank You Note',
      category: 'Personal',
      type: 'DEFAULT',
      subject: 'Thank you for your support',
      body:
          'Hi [Name],\n\nI wanted to send a quick note to say thank you for your help with [Task/Project]. I really appreciate your time and support.\n\nBest regards,\n[Your Name]',
    ),
    BNXTemplate(
      id: 'def_5',
      title: 'Request for Feedback',
      category: 'Business',
      type: 'DEFAULT',
      subject: 'Request for Feedback: [Project/Topic]',
      body:
          'Hi [Name],\n\nI hope you\'re having a great week. Could you please share your feedback on [Project/Topic]? I want to make sure we\'re fully aligned before moving forward.\n\nThanks,\n[Your Name]',
    ),
  ];
}

class TemplatesView extends ConsumerStatefulWidget {
  const TemplatesView({super.key});

  @override
  ConsumerState<TemplatesView> createState() => _TemplatesViewState();
}

class _TemplatesViewState extends ConsumerState<TemplatesView> {
  String _activeTab = 'All'; // 'All', 'Default', 'Custom'
  String _selectedCategory = 'All Categories';
  String _searchQuery = '';
  bool _isLoading = false;
  final List<BNXTemplate> _customTemplates = [];
  final TextEditingController _searchCtrl = TextEditingController();

  final List<BNXTemplate> _defaultTemplates = BNXTemplate.defaultTemplates;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    try {
      final activeAccount = ref.read(activeAccountProvider);
      final email = activeAccount.email;
      final fetched = await TemplateRepository.getTemplates(email);

      if (mounted) {
        setState(() {
          _customTemplates.clear();
          for (final t in fetched) {
            _customTemplates.add(
              BNXTemplate(
                id: t.id,
                title: t.title,
                category: t.category,
                type: 'CUSTOM',
                subject: t.subject,
                body: t.body,
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('[TEMPLATES VIEW LOG] Load error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _useTemplate(BNXTemplate template) {
    final currentDraft = ref.read(appUiProvider);
    final existingTo = currentDraft.composeTo;
    ref.read(appUiProvider.notifier).updateComposeDraft(
          to: existingTo.isNotEmpty ? existingTo : null,
          subject: template.subject,
          body: template.body,
        );

    ref.read(appUiProvider.notifier).setComposeStatus(ComposeStatus.normal);

    if (ref.read(appUiProvider).activeFolder == 'Templates') {
      ref.read(appUiProvider.notifier).selectFolder('All');
    }

    if (kIsWeb || !Platform.isMacOS) {
      context.push('/compose');
    } else {
      final r = GoRouterState.of(context).uri.toString();
      if (r != '/home') GoRouter.of(context).go('/home');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied "${template.title}" template.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(appUiProvider).isDarkMode;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 700;

    // Combine all templates
    final allTemplates = [..._defaultTemplates, ..._customTemplates];

    // Collect all unique categories
    final Set<String> categoriesSet = {
      'All Categories',
      'Business',
      'Out of Office',
      'Personal',
      'General',
    };
    for (final t in allTemplates) {
      if (t.category.trim().isNotEmpty) {
        categoriesSet.add(t.category.trim());
      }
    }
    final categoriesList = categoriesSet.toList();

    // Filter by tab
    var filtered = allTemplates.where((t) {
      if (_activeTab == 'Default') return t.type == 'DEFAULT';
      if (_activeTab == 'Custom') return t.type == 'CUSTOM';
      return true;
    }).toList();

    // Filter by category
    if (_selectedCategory != 'All Categories') {
      filtered = filtered
          .where(
            (t) =>
                t.category.toLowerCase().trim() ==
                _selectedCategory.toLowerCase().trim(),
          )
          .toList();
    }

    // Filter by search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      filtered = filtered.where((t) {
        return t.title.toLowerCase().contains(q) ||
            t.subject.toLowerCase().contains(q) ||
            t.body.toLowerCase().contains(q) ||
            t.category.toLowerCase().contains(q);
      }).toList();
    }

    final panelBg = isDark ? const Color(0xFF131D31) : Colors.white;
    final outerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFEBF3FA);
    final borderClr = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    return Container(
      color: outerBg,
      width: double.infinity,
      height: double.infinity,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isMobile ? 10 : 16),
        child: Container(
          decoration: BoxDecoration(
            color: panelBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderClr),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: EdgeInsets.all(isMobile ? 14 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row ──
              _buildTopHeader(context, isDark, isMobile),
              const SizedBox(height: 14),

              // ── Filter & Search Controls Bar ──
              _buildControlsBar(context, isDark, isMobile, categoriesList),
              const SizedBox(height: 14),

              // ── Templates Grid ──
              _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(60.0),
                        child: CircularProgressIndicator(
                          color: Color(0xFF195BAC),
                        ),
                      ),
                    )
                  : filtered.isEmpty
                      ? _buildEmptyState(isDark)
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            // Responsive column distribution
                            int crossAxisCount = 3;
                            if (constraints.maxWidth < 560) {
                              crossAxisCount = 1;
                            } else if (constraints.maxWidth < 860) {
                              crossAxisCount = 2;
                            } else if (constraints.maxWidth < 1200) {
                              crossAxisCount = 3;
                            } else {
                              crossAxisCount = 4;
                            }

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 185,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                return _buildTemplateCard(
                                  filtered[index],
                                  isDark,
                                );
                              },
                            );
                          },
                        ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. TOP HEADER (Title + Create Button) ──────────────────────────────────
  Widget _buildTopHeader(BuildContext context, bool isDark, bool isMobile) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 21,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            const SizedBox(width: 8),
            Text(
              'Templates',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          'Choose a quick mail template or build your own to speed up your messaging.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
          ),
        ),
      ],
    );

    final createButton = FilledButton.icon(
      onPressed: () => _showCreateTemplateDialog(context, isDark: isDark),
      icon: const Icon(Icons.add_rounded, size: 16),
      label: const Text(
        'Create Custom Template',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF195BAC),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleBlock,
          const SizedBox(height: 14),
          createButton,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: titleBlock),
        const SizedBox(width: 14),
        createButton,
      ],
    );
  }

  // ── 2. FILTER & SEARCH CONTROLS BAR ───────────────────────────────────────
  Widget _buildControlsBar(
    BuildContext context,
    bool isDark,
    bool isMobile,
    List<String> categories,
  ) {
    // Compact segmented tabs: [ All | Default | Custom ]
    final tabs = ['All', 'Default', 'Custom'];
    final tabPills = Container(
      height: 32,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: tabs.map((tab) {
          final isSelected = _activeTab == tab;
          return GestureDetector(
            onTap: () => setState(() => _activeTab = tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? const Color(0xFF334155) : Colors.white)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                tab,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );

    // Compact category dropdown selector
    final borderClr = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final categoryDropdown = Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderClr),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: categories.contains(_selectedCategory)
              ? _selectedCategory
              : 'All Categories',
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 15,
            color: Color(0xFF64748B),
          ),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedCategory = val);
            }
          },
          items: categories.map((cat) {
            return DropdownMenuItem<String>(
              value: cat,
              child: Text(cat),
            );
          }).toList(),
        ),
      ),
    );

    // Compact search bar input
    final searchInput = Container(
      height: 32,
      constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 220),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderClr),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 15,
            color: Color(0xFF94A3B8),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: const Icon(
                    Icons.clear_rounded,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
                )
              : null,
          border: InputBorder.none,
          hintText: 'Search templates...',
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11.5,
          ),
        ),
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              tabPills,
              categoryDropdown,
            ],
          ),
          const SizedBox(height: 8),
          searchInput,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        tabPills,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            categoryDropdown,
            const SizedBox(width: 8),
            searchInput,
          ],
        ),
      ],
    );
  }

  // ── 3. TEMPLATE CARD (Compact size, no Edit button) ───────────────────────
  Widget _buildTemplateCard(BNXTemplate template, bool isDark) {
    final bool isDefault = template.type == 'DEFAULT';
    final borderClr = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderClr),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top pill row: [DEFAULT] or [CUSTOM] and [Category] ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDefault
                      ? (isDark
                          ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                          : const Color(0xFFEBF3FE))
                      : (isDark
                          ? const Color(0xFF581C87).withValues(alpha: 0.3)
                          : const Color(0xFFF3E8FF)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isDefault ? 'DEFAULT' : 'CUSTOM',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isDefault
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF7E22CE),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  template.category,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),

          // ── Title ──
          Text(
            template.title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),

          // ── Subject line ──
          Text(
            'Subject: ${template.subject}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),

          // ── Body snippet ──
          Expanded(
            child: Text(
              template.body,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: isDark
                    ? BNXColors.darkTextSecondary
                    : const Color(0xFF334155),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 5),
          Divider(
            height: 1,
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 5),

          // ── Bottom Action Row: Use Template (left) | Preview (right) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Use Template action
              InkWell(
                onTap: () => _useTemplate(template),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.near_me_rounded,
                        size: 13,
                        color: Color(0xFF195BAC),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Use Template',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF195BAC),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Preview option only (NO Edit button)
              InkWell(
                onTap: () => _showPreviewDialog(context, template, isDark),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  child: Text(
                    'Preview',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 4. EMPTY STATE ────────────────────────────────────────────────────────
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_late_outlined,
              size: 44,
              color: isDark ? Colors.white30 : Colors.grey.shade400,
            ),
            const SizedBox(height: 10),
            Text(
              'No templates found',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try adjusting your search query or category filters.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ── 5. TEMPLATE PREVIEW DIALOG (Matching Image 2 - No Edit Option) ─────────
  void _showPreviewDialog(
    BuildContext context,
    BNXTemplate template,
    bool isDark,
  ) {
    final borderClr = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF334155);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: "Template Preview" + "✕"
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Template Preview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      splashRadius: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: borderClr),
                const SizedBox(height: 18),

                // SUBJECT Section
                const Text(
                  'SUBJECT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  template.subject,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 18),

                // CATEGORY Section
                const Text(
                  'CATEGORY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    template.category,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // CONTENT Section
                const Text(
                  'CONTENT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF131D31)
                        : const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderClr),
                  ),
                  child: Text(
                    template.body,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Footer Buttons: Close | Use Template (NO Edit option)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white60
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _useTemplate(template);
                      },
                      icon: const Icon(Icons.near_me_rounded, size: 14),
                      label: const Text(
                        'Use Template',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF195BAC),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
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

  // ── 6. CREATE TEMPLATE DIALOG (Matching Image 3) ───────────────────────────
  void _showCreateTemplateDialog(
    BuildContext context, {
    required bool isDark,
  }) {
    final formKey = GlobalKey<FormState>();
    final subjectController = TextEditingController();
    final bodyController = TextEditingController();
    String? selectedCategory = 'Business';
    bool isSaving = false;

    final categories = ['Business', 'Out of Office', 'Personal', 'General'];

    final borderClr = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final inputFill = isDark
        ? const Color(0xFF131D31)
        : const Color(0xFFEDF4FD);

    showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header: Title + Close Button ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Create Template',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            IconButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close_rounded, size: 20),
                              color: isDark
                                  ? Colors.white54
                                  : const Color(0xFF64748B),
                              splashRadius: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Divider(height: 1, color: borderClr),
                        const SizedBox(height: 18),

                        // ── 1. SUBJECT Field ──
                        const Text(
                          'SUBJECT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: subjectController,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Subject is required';
                            }
                            return null;
                          },
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter Subject',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white38
                                  : const Color(0xFF94A3B8),
                            ),
                            filled: true,
                            fillColor: inputFill,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: borderClr),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: borderClr),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF195BAC),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // ── 2. SELECT CATEGORY Field ──
                        const Text(
                          'SELECT CATEGORY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: inputFill,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderClr),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedCategory,
                                    hint: Text(
                                      'Select Category',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.white38
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: Color(0xFF64748B),
                                    ),
                                    dropdownColor: isDark
                                        ? const Color(0xFF1E293B)
                                        : Colors.white,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                    items: categories.map((cat) {
                                      return DropdownMenuItem<String>(
                                        value: cat,
                                        child: Text(cat),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setModalState(() => selectedCategory = val);
                                    },
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setModalState(() => selectedCategory = null);
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Clear',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF195BAC),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // ── 3. TEMPLATE CONTENT Field ──
                        const Text(
                          'TEMPLATE CONTENT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Editor Container with Toolbar + Body
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF131D31)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderClr),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Rich Editor Toolbar
                              _buildEditorToolbar(
                                context,
                                bodyController,
                                isDark,
                              ),
                              Divider(height: 1, color: borderClr),

                              // Text Area
                              TextFormField(
                                controller: bodyController,
                                maxLines: 6,
                                minLines: 4,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Template content is required';
                                  }
                                  return null;
                                },
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'Type your prefilled email body here...',
                                  hintStyle: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark
                                        ? Colors.white38
                                        : const Color(0xFF94A3B8),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        // ── Footer: Cancel | Save ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.pop(ctx),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (formKey.currentState?.validate() ??
                                          false) {
                                        setModalState(() => isSaving = true);
                                        final subjectText =
                                            subjectController.text.trim();
                                        final bodyText =
                                            bodyController.text.trim();
                                        final categoryText =
                                            selectedCategory ?? 'Personal';

                                        final activeAccount = ref.read(
                                          activeAccountProvider,
                                        );
                                        final email = activeAccount.email;

                                        try {
                                          final created =
                                              await TemplateRepository.createTemplate(
                                            email,
                                            name: subjectText,
                                            subject: subjectText,
                                            content: bodyText,
                                            category: categoryText,
                                          );

                                          if (mounted) {
                                            setState(() {
                                              _customTemplates.add(
                                                BNXTemplate(
                                                  id: created?.id ??
                                                      DateTime.now()
                                                          .millisecondsSinceEpoch
                                                          .toString(),
                                                  title: subjectText,
                                                  category: categoryText,
                                                  type: 'CUSTOM',
                                                  subject: subjectText,
                                                  body: bodyText,
                                                ),
                                              );
                                            });
                                          }

                                          if (ctx.mounted) {
                                            Navigator.pop(ctx);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Template created successfully ✓',
                                                ),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                backgroundColor:
                                                    Color(0xFF195BAC),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (ctx.mounted) {
                                            setModalState(
                                              () => isSaving = false,
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Failed to save template: $e',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF195BAC),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 11,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Save',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
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
            ),
          );
        },
      ),
    );
  }

  // ── 7. RICH FORMATTING TOOLBAR ────────────────────────────────────────────
  Widget _buildEditorToolbar(
    BuildContext context,
    TextEditingController controller,
    bool isDark,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Arial dropdown
          _buildToolbarPill('Arial', isDark, () {}),
          const SizedBox(width: 4),

          // 12px dropdown
          _buildToolbarPill('12px', isDark, () {}),
          const SizedBox(width: 8),

          // B (Bold)
          _buildToolbarIcon(
            icon: Icons.format_bold_rounded,
            tooltip: 'Bold',
            isDark: isDark,
            onTap: () => _wrapSelection(controller, '**', '**'),
          ),

          // I (Italic)
          _buildToolbarIcon(
            icon: Icons.format_italic_rounded,
            tooltip: 'Italic',
            isDark: isDark,
            onTap: () => _wrapSelection(controller, '*', '*'),
          ),

          // U (Underline)
          _buildToolbarIcon(
            icon: Icons.format_underlined_rounded,
            tooltip: 'Underline',
            isDark: isDark,
            onTap: () => _wrapSelection(controller, '<u>', '</u>'),
          ),

          // S (Strikethrough)
          _buildToolbarIcon(
            icon: Icons.format_strikethrough_rounded,
            tooltip: 'Strikethrough',
            isDark: isDark,
            onTap: () => _wrapSelection(controller, '~~', '~~'),
          ),
          const SizedBox(width: 4),

          // Text Color (A)
          _buildToolbarIcon(
            icon: Icons.format_color_text_rounded,
            tooltip: 'Text Color',
            isDark: isDark,
            onTap: () {},
          ),

          // Highlight / Background Color
          _buildToolbarIcon(
            icon: Icons.format_color_fill_rounded,
            tooltip: 'Background Color',
            isDark: isDark,
            onTap: () {},
          ),
          const SizedBox(width: 4),

          // Alignment
          _buildToolbarIcon(
            icon: Icons.format_align_left_rounded,
            tooltip: 'Align',
            isDark: isDark,
            onTap: () {},
          ),

          // Bullets List
          _buildToolbarIcon(
            icon: Icons.format_list_bulleted_rounded,
            tooltip: 'Bullet List',
            isDark: isDark,
            onTap: () => _insertTextAtCursor(controller, '\n• '),
          ),

          // Numbers List
          _buildToolbarIcon(
            icon: Icons.format_list_numbered_rounded,
            tooltip: 'Numbered List',
            isDark: isDark,
            onTap: () => _insertTextAtCursor(controller, '\n1. '),
          ),
          const SizedBox(width: 4),

          // Link
          _buildToolbarIcon(
            icon: Icons.link_rounded,
            tooltip: 'Insert Link',
            isDark: isDark,
            onTap: () => _wrapSelection(controller, '[', '](https://)'),
          ),

          // Image
          _buildToolbarIcon(
            icon: Icons.image_outlined,
            tooltip: 'Insert Image',
            isDark: isDark,
            onTap: () => _insertTextAtCursor(controller, '[Image]'),
          ),

          // Clear Formatting (Tx)
          _buildToolbarIcon(
            icon: Icons.format_clear_rounded,
            tooltip: 'Clear Formatting',
            isDark: isDark,
            onTap: () {
              final clean = controller.text
                  .replaceAll('**', '')
                  .replaceAll('*', '')
                  .replaceAll('~~', '')
                  .replaceAll('<u>', '')
                  .replaceAll('</u>', '');
              controller.text = clean;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarPill(String label, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 13,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarIcon({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Icon(
            icon,
            size: 16,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  void _wrapSelection(
    TextEditingController controller,
    String prefix,
    String suffix,
  ) {
    final text = controller.text;
    final selection = controller.selection;
    if (!selection.isValid || selection.isCollapsed) {
      final cursor = selection.isValid ? selection.start : text.length;
      final newText = text.replaceRange(cursor, cursor, '$prefix$suffix');
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursor + prefix.length),
      );
    } else {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '$prefix$selectedText$suffix',
      );
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: selection.start + prefix.length,
          extentOffset: selection.end + prefix.length,
        ),
      );
    }
  }

  void _insertTextAtCursor(TextEditingController controller, String insert) {
    final text = controller.text;
    final selection = controller.selection;
    final cursor = selection.isValid ? selection.start : text.length;
    final newText = text.replaceRange(cursor, cursor, insert);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor + insert.length),
    );
  }
}
