import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/app_state_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/neumorphic.dart';
import '../../../core/constants/constants.dart';

class BNXTemplate {
  final String title;
  final String category; // 'Business', 'Out of Office', 'Personal'
  final String type; // 'DEFAULT' or 'CUSTOM'
  final String subject;
  final String body;

  const BNXTemplate({
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
  final List<BNXTemplate> _customTemplates = [];

  final List<BNXTemplate> _defaultTemplates = const [
    BNXTemplate(
      title: 'Meeting Request',
      category: 'Business',
      type: 'DEFAULT',
      subject: 'Meeting Request: Discussion on Project Updates',
      body: 'Hi [Name],\n\nI hope you are doing well. I would like to schedule a brief meeting with you to discuss our progress on the project. Could you please let me know your availability for a 15-minute call sometime this week?\n\nLooking forward to hearing from you.\n\nBest regards,\n[Your Name]',
    ),
    BNXTemplate(
      title: 'Follow-Up Discussion',
      category: 'Business',
      type: 'DEFAULT',
      subject: 'Following up on our recent discussion',
      body: 'Hi [Name],\n\nI hope this email finds you well. I wanted to follow up on our discussion last week regarding [Topic]. Please let me know if you\'ve had a chance to review the details or if you have any questions.\n\nThanks,\n[Your Name]',
    ),
    BNXTemplate(
      title: 'Out of Office',
      category: 'Out of Office',
      type: 'DEFAULT',
      subject: 'Out of Office: [Your Name] - [Start Date] to [End Date]',
      body: 'Hello,\n\nThank you for your email. I am currently out of the office with limited access to my email. I will return on [Date]. If your request is urgent, please contact [Alternative Contact Name/Email]. Otherwise, I will reply to your message as soon as possible upon my return.\n\nBest regards,\n[Your Name]',
    ),
    BNXTemplate(
      title: 'Thank You Note',
      category: 'Personal',
      type: 'DEFAULT',
      subject: 'Thank you for [Reason]',
      body: 'Hi [Name],\n\nThank you so much for [Reason]. I really appreciate your help and support on this.\n\nBest,\n[Your Name]',
    ),
    BNXTemplate(
      title: 'Request for Feedback',
      category: 'Business',
      type: 'DEFAULT',
      subject: 'Request for Feedback: [Project/Topic]',
      body: 'Hi [Name],\n\nCould you please take a look at the draft of the project and share your feedback by [Date]? I want to ensure we align before final submission.\n\nThanks,\n[Your Name]',
    ),
  ];

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
            t.body.toLowerCase().contains(q);
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header Row
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderTitle(isDark),
                    const SizedBox(height: 16),
                    _buildAddTemplateButton(context, isDark),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _buildHeaderTitle(isDark)),
                    const SizedBox(width: 16),
                    _buildAddTemplateButton(context, isDark),
                  ],
                ),
        ),

        const Divider(height: 1),

        // 2. Filter tabs and search bar row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTabsRow(isDark),
                    const SizedBox(height: 16),
                    _buildSearchBar(isDark),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTabsRow(isDark),
                    SizedBox(
                      width: 300,
                      child: _buildSearchBar(isDark),
                    ),
                  ],
                ),
        ),

        // 3. Grid area
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(isDark)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = 3;
                    if (constraints.maxWidth < 650) {
                      crossAxisCount = 1;
                    } else if (constraints.maxWidth < 1100) {
                      crossAxisCount = 2;
                    }
                    
                    return GridView.builder(
                      padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 260, // Fixed height for neat cards
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return _buildTemplateCard(filtered[index], isDark);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHeaderTitle(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.assignment_rounded,
              color: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary,
              size: 26,
            ),
            const SizedBox(width: 12),
            Text(
              'Templates',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : BNXColors.lightTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Choose a quick mail template or build your own to speed up your messaging.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildAddTemplateButton(BuildContext context, bool isDark) {
    return NeumorphicButton(
      onPressed: () => _showAddTemplateDialog(context, isDark),
      borderRadius: 24,
      color: BNXColors.lightPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 18, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'Add Template',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsRow(bool isDark) {
    Widget tabButton(String name) {
      final isSelected = _activeTab == name;
      return GestureDetector(
        onTap: () => setState(() => _activeTab = name),
        child: NeumorphicContainer(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          borderRadius: 16,
          depth: isSelected ? 2.0 : 0.0,
          shape: isSelected ? NeumorphicShape.convex : NeumorphicShape.flat,
          color: isSelected 
              ? (isDark ? const Color(0xFF1E293B) : Colors.white)
              : Colors.transparent,
          child: Text(
            name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? (isDark ? Colors.white : BNXColors.lightPrimary)
                  : (isDark ? Colors.white54 : BNXColors.lightTextSecondary),
            ),
          ),
        ),
      );
    }

    return NeumorphicContainer(
      padding: const EdgeInsets.all(4),
      borderRadius: 20,
      shape: NeumorphicShape.pressed,
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEAF1FB),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          tabButton('All'),
          tabButton('Default'),
          tabButton('Custom'),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return NeumorphicContainer(
      height: 40,
      borderRadius: 20,
      shape: NeumorphicShape.pressed,
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEAF1FB),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          hintText: 'Search templates...',
          hintStyle: TextStyle(fontSize: 13),
          prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
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
                      ? (isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.shade50)
                      : (isDark ? Colors.purple.withValues(alpha: 0.15) : Colors.purple.shade50),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  template.type,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isDefault ? Colors.blue.shade700 : Colors.purple.shade700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  template.category,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                ),
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
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
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
                color: isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary,
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
              
              // Navigate to Inbox first so the compose button/FAB becomes visible
              ref.read(appUiProvider.notifier).selectFolder('Inbox');
              
              // Open the compose dialog
              ref.read(appUiProvider.notifier).setComposeStatus(ComposeStatus.normal);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Starting new mail with "${template.title}" template.')),
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
                  color: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Use Template',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary,
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
          Icon(Icons.assignment_late_outlined, size: 48, color: isDark ? Colors.white24 : Colors.grey),
          const SizedBox(height: 16),
          const Text('No templates found', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Try adjusting your search query or tab filters.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  void _showAddTemplateDialog(BuildContext context, bool isDark) {
    final titleController = TextEditingController();
    final categoryController = TextEditingController(text: 'Business');
    final subjectController = TextEditingController();
    final bodyController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom Template'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Template Title (e.g. Weekly Report)'),
                ),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category (Business, Out of Office, Personal)'),
                ),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: 'Default Email Subject'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Template Message Body',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && bodyController.text.isNotEmpty) {
                setState(() {
                  _customTemplates.add(
                    BNXTemplate(
                      title: titleController.text,
                      category: categoryController.text,
                      type: 'CUSTOM',
                      subject: subjectController.text,
                      body: bodyController.text,
                    ),
                  );
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Custom template added successfully.')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
