import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/account_provider.dart';
import '../../../data/app_state_provider.dart';
import '../../../data/repositories/template_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/neumorphic.dart';

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
}

class TemplatesView extends ConsumerStatefulWidget {
  const TemplatesView({super.key});

  @override
  ConsumerState<TemplatesView> createState() => _TemplatesViewState();
}

class _TemplatesViewState extends ConsumerState<TemplatesView> {
  String _activeTab = 'All'; // 'All', 'Default', 'Custom'
  String _searchQuery = '';
  bool _isLoading = false;
  final List<BNXTemplate> _customTemplates = [];

  final List<BNXTemplate> _defaultTemplates = const [
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
      subject: 'Thank you for [Reason]',
      body:
          'Hi [Name],\n\nThank you so much for [Reason]. I really appreciate your help and support on this.\n\nBest,\n[Your Name]',
    ),
    BNXTemplate(
      id: 'def_5',
      title: 'Request for Feedback',
      category: 'Business',
      type: 'DEFAULT',
      subject: 'Request for Feedback: [Project/Topic]',
      body:
          'Hi [Name],\n\nCould you please take a look at the draft of the project and share your feedback by [Date]? I want to ensure we align before final submission.\n\nThanks,\n[Your Name]',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
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
            _customTemplates.add(BNXTemplate(
              id: t.id,
              title: t.title,
              category: t.category,
              type: 'CUSTOM',
              subject: t.subject,
              body: t.body,
            ));
          }
        });
      }
    } catch (e) {
      print('[TEMPLATES VIEW LOG] Load error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(appUiProvider).isDarkMode;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    // Combine all templates
    final allTemplates = [..._defaultTemplates, ..._customTemplates];

    // Filter by tab
    var filtered = allTemplates.where((t) {
      if (_activeTab == 'Default') return t.type == 'DEFAULT';
      if (_activeTab == 'Custom') return t.type == 'CUSTOM';
      return true;
    }).toList();

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((t) {
        return t.title.toLowerCase().contains(q) ||
            t.subject.toLowerCase().contains(q) ||
            t.category.toLowerCase().contains(q);
      }).toList();
    }

    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEBF3FA),
      width: double.infinity,
      height: double.infinity,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isMobile ? 12 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderTitle(isDark),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildAddTemplateButton(context, isDark),
                        ],
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildHeaderTitle(isDark),
                      _buildAddTemplateButton(context, isDark),
                    ],
                  ),
            const SizedBox(height: 20),

            // Search and Filter Bar Row
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return Column(
                    children: [
                      _buildSearchBar(isDark),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _buildFilterTabs(isDark),
                      ),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(child: _buildSearchBar(isDark)),
                      const SizedBox(width: 16),
                      _buildFilterTabs(isDark),
                    ],
                  );
                }
              },
            ),

            const SizedBox(height: 24),

            // Main Grid / List of Templates
            _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(
                        color: Color(0xFF195BAC),
                      ),
                    ),
                  )
                : filtered.isEmpty
                    ? _buildEmptyState(isDark)
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isMobile ? 1 : (screenWidth < 1100 ? 2 : 3),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: isMobile ? 1.4 : 1.35,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _buildTemplateCard(filtered[index], isDark);
                        },
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderTitle(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 28,
              color: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary,
            ),
            const SizedBox(width: 10),
            Text(
              'Templates',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? BNXColors.darkTextPrimary : BNXColors.lightTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Choose a quick mail template or build your own to speed up your messaging.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildAddTemplateButton(BuildContext context, bool isDark) {
    return NeumorphicButton(
      onPressed: () => _showAddTemplateDialog(context, isDark),
      borderRadius: 12,
      color: const Color(0xFF195BAC), // Same primary blue as rest of app
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, size: 18, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'Add Template',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return NeumorphicContainer(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          icon: Icon(
            Icons.search_rounded,
            color: isDark ? Colors.white38 : Colors.grey.shade400,
            size: 20,
          ),
          border: InputBorder.none,
          hintText: 'Search templates...',
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : Colors.grey.shade400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs(bool isDark) {
    final tabs = ['All', 'Default', 'Custom'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: tabs.map((tab) {
        final isSelected = _activeTab == tab;
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: InkWell(
            onTap: () => setState(() => _activeTab = tab),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF195BAC) // Primary blue
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tab,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTemplateCard(BNXTemplate template, bool isDark) {
    final bool isDefault = template.type == 'DEFAULT';

    return NeumorphicContainer(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: 14,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top pill row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDefault
                      ? (isDark
                          ? Colors.blue.withValues(alpha: 0.15)
                          : Colors.blue.shade50)
                      : (isDark
                          ? Colors.purple.withValues(alpha: 0.15)
                          : Colors.purple.shade50),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  template.type,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isDefault
                        ? Colors.blue.shade700
                        : Colors.purple.shade700,
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      template.category,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (!isDefault) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () async {
                        final activeAccount = ref.read(activeAccountProvider);
                        setState(() {
                          _customTemplates.removeWhere((t) => t.id == template.id);
                        });
                        await TemplateRepository.deleteTemplate(template.id, activeAccount.email);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Template deleted.')),
                          );
                        }
                      },
                      child: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Title
          Text(
            template.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Subject
          Text(
            'Subject: ${template.subject}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Body/Description
          Expanded(
            child: Text(
              template.body,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? BNXColors.darkTextSecondary
                    : BNXColors.lightTextSecondary,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 16),
          // Bottom button
          NeumorphicButton(
            onPressed: () {
              ref.read(appUiProvider.notifier).clearComposeDraft();
              ref.read(appUiProvider.notifier).updateComposeDraft(
                    subject: template.subject,
                    body: template.body,
                  );

              // Navigate directly to full page compose screen
              context.push('/compose');

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Starting new mail with "${template.title}" template.',
                  ),
                ),
              );
            },
            borderRadius: 14,
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.send_rounded,
                  size: 14,
                  color: isDark
                      ? BNXColors.darkPrimary
                      : BNXColors.lightPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Use Template',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? BNXColors.darkPrimary
                        : BNXColors.lightPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_late_outlined,
            size: 48,
            color: isDark ? Colors.white30 : Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'No templates found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try adjusting your search query or tab filters.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ── Professional & Upgraded Add Template Dialog ───────────────────────────
  void _showAddTemplateDialog(BuildContext context, bool isDark) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final subjectController = TextEditingController();
    final bodyController = TextEditingController();
    String selectedCategory = 'Business';
    bool isSaving = false;

    final categories = ['Business', 'Out of Office', 'Personal', 'General'];

    showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            elevation: 12,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.all(20),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Modal Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF195BAC).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.note_add_rounded,
                            color: Color(0xFF195BAC),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create Mail Template',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                'Save reusable templates for quick email responses',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.white54 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Scrollable Fields Body to prevent overflow
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Field 1: Title / Name
                            Text(
                              'Template Title *',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: titleController,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Template title is required';
                                }
                                return null;
                              },
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'e.g. Weekly Status Report',
                                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400, fontSize: 13),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF195BAC), width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Field 2: Category Dropdown
                            Text(
                              'Category',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: selectedCategory,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF195BAC), width: 1.5),
                                ),
                              ),
                              items: categories.map((cat) {
                                return DropdownMenuItem<String>(
                                  value: cat,
                                  child: Text(cat),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() => selectedCategory = val);
                                }
                              },
                            ),
                            const SizedBox(height: 14),

                            // Field 3: Subject
                            Text(
                              'Default Email Subject *',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: subjectController,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Subject line is required';
                                }
                                return null;
                              },
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'e.g. Weekly Progress Update: [Date]',
                                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400, fontSize: 13),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF195BAC), width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Field 4: Body
                            Text(
                              'Template Message Body *',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: bodyController,
                              maxLines: 4,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Template body text is required';
                                }
                                return null;
                              },
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Hi [Name],\n\nHere is the update for this week...',
                                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400, fontSize: 13),
                                contentPadding: const EdgeInsets.all(14),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF195BAC), width: 1.5),
                                ),
                                alignLabelWithHint: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Modal Action Buttons wrapped to prevent overflow
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: isSaving ? null : () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (formKey.currentState?.validate() ?? false) {
                                      setModalState(() => isSaving = true);
                                      final title = titleController.text.trim();
                                      final category = selectedCategory;
                                      final subject = subjectController.text.trim();
                                      final body = bodyController.text.trim();

                                      final activeAccount = ref.read(activeAccountProvider);
                                      final created = await TemplateRepository.createTemplate(
                                        activeAccount.email,
                                        name: title,
                                        subject: subject,
                                        content: body,
                                        category: category,
                                      );

                                      if (mounted) {
                                        setState(() {
                                          _customTemplates.add(
                                            BNXTemplate(
                                              id: created?.id ??
                                                  DateTime.now().millisecondsSinceEpoch.toString(),
                                              title: title,
                                              category: category,
                                              type: 'CUSTOM',
                                              subject: subject,
                                              body: body,
                                            ),
                                          );
                                        });
                                      }
                                      if (ctx.mounted) {
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Custom template saved successfully ✓'),
                                            backgroundColor: Color(0xFF2E7D32),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF195BAC),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.save_rounded, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'Save Template',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
