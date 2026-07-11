import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/neumorphic.dart';
import '../../../data/app_state_provider.dart';

class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, String>> _faqs = [
    {
      'question': 'How do I enable Multi-Factor Authentication (MFA)?',
      'answer': 'Go to Settings > Security & Login, and toggle "Two-Factor Authentication" to active. Follow the on-screen instructions to link your mobile authenticator app.'
    },
    {
      'question': 'Can I retrieve emails after permanently deleting them?',
      'answer': 'Emails in the Trash folder are kept for 30 days before permanent deletion. Once deleted from Trash, they cannot be recovered by standard means.'
    },
    {
      'question': 'How do email templates work?',
      'answer': 'Click the Templates section in the left sidebar to view preloaded layouts. Select any card and click "Use Template" to automatically populate a new draft.'
    },
    {
      'question': 'What are collaborative group chats?',
      'answer': 'The Colab tab lets you chat with your project members in real-time. Join any workspace card to view shared documents and open chat rooms.'
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;
    final theme = Theme.of(context);

    final filteredFaqs = _faqs.where((faq) {
      final query = _searchQuery.toLowerCase();
      return faq['question']!.toLowerCase().contains(query) ||
          faq['answer']!.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? BNXColors.darkBg : BNXColors.lightBg,
      appBar: AppBar(
        title: const Text(
          'Help & Support',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: isDark ? BNXColors.darkBg : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            ref.read(appUiProvider.notifier).selectFolder('Inbox');
            context.go('/');
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Search Section
            NeumorphicContainer(
              height: 48,
              shape: NeumorphicShape.pressed,
              borderRadius: 24,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  icon: const Icon(Icons.search_rounded, color: Colors.grey),
                  hintText: 'Search help articles, FAQS...',
                  border: InputBorder.none,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 2. Categories Grid
            const Text(
              'Quick Support Topics',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildCategoryCard(
                  icon: Icons.vpn_key_outlined,
                  color: Colors.blue,
                  title: 'Security & Login',
                  desc: 'MFA, passwords, access logs',
                ),
                _buildCategoryCard(
                  icon: Icons.dashboard_customize_outlined,
                  color: Colors.orange,
                  title: 'Templates & Layout',
                  desc: 'Manage presets & sidebar configs',
                ),
                _buildCategoryCard(
                  icon: Icons.contact_support_outlined,
                  color: Colors.green,
                  title: 'Troubleshooting',
                  desc: 'Mail delivery & sync issues',
                ),
                _buildCategoryCard(
                  icon: Icons.receipt_long_outlined,
                  color: Colors.purple,
                  title: 'Legal & Policy',
                  desc: 'Terms of service & privacy',
                ),
              ],
            ),
            const SizedBox(height: 28),

            // 3. FAQ Section
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (filteredFaqs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No articles match your search query.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredFaqs.length,
                itemBuilder: (context, index) {
                  final faq = filteredFaqs[index];
                  return NeumorphicContainer(
                    margin: const EdgeInsets.only(bottom: 10),
                    borderRadius: 12,
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    child: ExpansionTile(
                      shape: const Border(),
                      title: Text(
                        faq['question']!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                          child: Text(
                            faq['answer']!,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 32),

            // 4. Submit Ticket / Footer Section
            NeumorphicContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Still need help?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Our professional support staff is available to solve your account and mail delivery concerns 24/7.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: NeumorphicButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Support ticket creator is being loaded...')),
                            );
                          },
                          borderRadius: 10,
                          color: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.support_agent_rounded, size: 16, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Submit Ticket',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: NeumorphicButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Opening email app... (support@bnxmail.com)')),
                            );
                          },
                          borderRadius: 10,
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.email_outlined, size: 16, color: isDark ? Colors.white70 : Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Email Support',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    final uiState = ref.read(appUiProvider);
    final isDark = uiState.isDarkMode;

    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening articles for "$title"...')),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: NeumorphicContainer(
        padding: const EdgeInsets.all(12),
        borderRadius: 12,
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
