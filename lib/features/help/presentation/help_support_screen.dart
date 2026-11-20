import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/app_state_provider.dart';
import '../../../core/theme/colors.dart';

class SupportTicketItem {
  final String id;
  final String subject;
  final String priority;
  final String explanation;
  final String? attachmentName;
  final DateTime createdAt;
  final String status;

  SupportTicketItem({
    required this.id,
    required this.subject,
    required this.priority,
    required this.explanation,
    this.attachmentName,
    required this.createdAt,
    this.status = 'In Review',
  });
}

class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _topSearchController = TextEditingController();
  final TextEditingController _heroSearchController = TextEditingController();

  // Ticket Form Controllers & State
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _explanationController = TextEditingController();
  final FocusNode _subjectFocusNode = FocusNode();
  String _selectedPriority = 'Medium - Performance/Glitch';
  String? _attachedFileName;

  // Active submitted tickets log
  final List<SupportTicketItem> _tickets = [];

  // Expanded FAQ items (Item 5 "Can I use the app offline?" expanded by default as in screenshot 2)
  final Set<int> _expandedFaqIndices = {5};

  String _searchFilter = '';

  // 10 Detailed FAQs matching Screenshots 1 & 2
  final List<Map<String, String>> _allFaqs = [
    {
      'category': 'ACCOUNT & SECURITY',
      'question': 'How do I reset my password?',
      'answer':
          'To reset your password, navigate to Settings > Security, select "Change Password", and follow the authentication prompts. If you cannot access your account, use the "Forgot Password" link on the login page.',
    },
    {
      'category': 'ACCOUNT & SECURITY',
      'question': 'How do I enable Two-Factor Authentication (2FA)?',
      'answer':
          'Navigate to Settings > Security > Two-Factor Authentication. Choose between Authenticator App (TOTP) or SMS verification, scan the provided QR code or confirm your phone number, and enter the 6-digit confirmation code.',
    },
    {
      'category': 'SECURITY & PRIVACY',
      'question': 'Is my data and email content secure?',
      'answer':
          'Yes. All email transmissions in BNX Mail are encrypted using TLS 1.3 in transit and AES-256 at rest. We enforce zero-knowledge vault storage architectures to ensure your sensitive communications and attachments remain strictly private.',
    },
    {
      'category': 'ACCOUNT & SECURITY',
      'question': 'Why does it say \'This mobile number is already registered\'?',
      'answer':
          'Each mobile phone number can only be bound as a primary identity to one BNX Mail account at a time. If you previously created an account with this number, try signing in with it or using the account recovery option.',
    },
    {
      'category': 'STORAGE & LIMITS',
      'question': 'What is my storage limit and how can I free up space?',
      'answer':
          'Standard accounts come with 5 GB of secure cloud ecosystem storage. To free up space, check your Trash, Spam, and large attachments in the Storage Management dashboard, or permanently delete unneeded emails.',
    },
    {
      'category': 'GENERAL & APP',
      'question': 'Can I use the app offline?',
      'answer':
          'Currently, BNX Mail requires an active internet connection to sync data and send emails in real-time. Full offline caching and background draft synchronization are planned for upcoming releases.',
    },
    {
      'category': 'MAIL MANAGEMENT',
      'question': 'How do I export or backup my emails?',
      'answer':
          'You can export your emails by selecting "Mail Backup" from the sidebar navigation. Choose your desired date range and format (EML, MBOX, or PST) and click "Download Archive".',
    },
    {
      'category': 'MAIL MANAGEMENT',
      'question': 'Can I schedule emails to send at a later time?',
      'answer':
          'Yes! In the email compose window, click the dropdown arrow next to the Send button and select "Schedule Send". Choose a recommended preset or pick a custom date and time.',
    },
    {
      'category': 'MAIL MANAGEMENT',
      'question': 'What is the maximum attachment file size?',
      'answer':
          'The maximum direct file attachment limit per email is 25 MB. For larger files up to 500 MB, you can attach files directly via your BNX Storage Vault as secure download links.',
    },
    {
      'category': 'CUSTOMER SUPPORT',
      'question': 'How can I track the status of my support requests?',
      'answer':
          'You can track all submitted tickets under "My Support Log" on this page. Updates and resolutions from our customer support team are also emailed directly to your primary mailbox.',
    },
  ];

  final GlobalKey _ticketFormKey = GlobalKey();
  final GlobalKey _supportLogKey = GlobalKey();
  final GlobalKey _faqKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    _topSearchController.dispose();
    _heroSearchController.dispose();
    _subjectController.dispose();
    _explanationController.dispose();
    _subjectFocusNode.dispose();
    super.dispose();
  }

  void _scrollToKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _applyQuickSearch(String term) {
    setState(() {
      _heroSearchController.text = term;
      _searchFilter = term.toLowerCase();
      // Expand all matching FAQs
      for (int i = 0; i < _allFaqs.length; i++) {
        final q = _allFaqs[i]['question']!.toLowerCase();
        final a = _allFaqs[i]['answer']!.toLowerCase();
        final c = _allFaqs[i]['category']!.toLowerCase();
        if (q.contains(_searchFilter) || a.contains(_searchFilter) || c.contains(_searchFilter)) {
          _expandedFaqIndices.add(i);
        }
      }
    });
    _scrollToKey(_faqKey);
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'log', 'txt', 'zip'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _attachedFileName = result.files.first.name;
        });
      }
    } catch (_) {
      setState(() {
        _attachedFileName = 'diagnostic_screenshot.png';
      });
    }
  }

  void _submitTicket() {
    final subject = _subjectController.text.trim();
    final explanation = _explanationController.text.trim();

    if (subject.isEmpty || explanation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter an issue subject and detailed explanation.'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final newTicket = SupportTicketItem(
      id: '#TK-${(1000 + _tickets.length + 1)}',
      subject: subject,
      priority: _selectedPriority,
      explanation: explanation,
      attachmentName: _attachedFileName,
      createdAt: DateTime.now(),
      status: 'In Review',
    );

    setState(() {
      _tickets.insert(0, newTicket);
      _subjectController.clear();
      _explanationController.clear();
      _attachedFileName = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('Ticket ${newTicket.id} submitted successfully!'),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    _scrollToKey(_supportLogKey);
  }

  Future<void> _openEmailSupport() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@beta-softnet.com',
      queryParameters: {'subject': 'BNX Mail Support Request'},
    );
    try {
      await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _openPortal() async {
    final Uri portalUri = Uri.parse('https://beta-softnet.com');
    try {
      await launchUrl(portalUri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(appUiProvider).isDarkMode;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;
    final isTwoColumn = screenWidth >= 950;

    final filteredFaqs = _searchFilter.isEmpty
        ? _allFaqs
        : _allFaqs.where((f) {
            final q = f['question']!.toLowerCase();
            final a = f['answer']!.toLowerCase();
            final c = f['category']!.toLowerCase();
            return q.contains(_searchFilter) ||
                a.contains(_searchFilter) ||
                c.contains(_searchFilter);
          }).toList();

    return Container(
      color: isDark ? BNXColors.darkBg : const Color(0xFFF1F5F9),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Secondary Sub-Bar (BNX Mail | Help Center + Search + Contact Support) ──
            _buildSubHeaderBar(isDark, isMobile, screenWidth),

            // ── Scrollable Body ──────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 14.0 : 28.0,
                  vertical: 20.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Hero Search Banner
                    _buildHeroBanner(isDark, isMobile),
                    const SizedBox(height: 20),

                    // 2. Quick Action Cards (3 Cards)
                    _buildQuickActionCards(isDark, isMobile),
                    const SizedBox(height: 24),

                    // 3. Two-Column Split (Left: Ticket & Log, Right: FAQ & Channels)
                    if (isTwoColumn)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                _buildRaiseTicketCard(isDark, isMobile),
                                const SizedBox(height: 24),
                                _buildSupportLogCard(isDark, isMobile),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                _buildFaqCard(filteredFaqs, isDark, isMobile),
                                const SizedBox(height: 24),
                                _buildDirectChannelsCard(isDark, isMobile),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildRaiseTicketCard(isDark, isMobile),
                          const SizedBox(height: 24),
                          _buildSupportLogCard(isDark, isMobile),
                          const SizedBox(height: 24),
                          _buildFaqCard(filteredFaqs, isDark, isMobile),
                          const SizedBox(height: 24),
                          _buildDirectChannelsCard(isDark, isMobile),
                        ],
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SUB-HEADER BAR ────────────────────────────────────────────────────────
  Widget _buildSubHeaderBar(bool isDark, bool isMobile, double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 28,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Brand + Help Center
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: -0.4,
                child: const Icon(
                  Icons.send_rounded,
                  color: Color(0xFF4F46E5),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'BNX Mail',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '|',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Help Center',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),

          // Right: Search Input + Contact Support
          if (!isMobile)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (screenWidth >= 880) ...[
                  // Search Input
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260, minWidth: 140),
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: TextField(
                        controller: _topSearchController,
                        onChanged: (val) {
                          setState(() {
                            _searchFilter = val.trim().toLowerCase();
                          });
                        },
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search articles, topics or keywords...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          ),
                          contentPadding: const EdgeInsets.only(left: 14, bottom: 10),
                          border: InputBorder.none,
                          suffixIcon: Icon(
                            Icons.search_rounded,
                            size: 16,
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],

                // Contact Support Button
                ElevatedButton.icon(
                  onPressed: () => _scrollToKey(_ticketFormKey),
                  icon: const Icon(Icons.headset_mic_rounded, size: 16),
                  label: const Text(
                    'Contact Support',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── 1. HERO BANNER ────────────────────────────────────────────────────────
  Widget _buildHeroBanner(bool isDark, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20.0 : 32.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF1E1B4B),
                  Color(0xFF2E1065),
                  Color(0xFF1E293B),
                ]
              : const [
                  Color(0xFFFAF5FF),
                  Color(0xFFF3E8FF),
                  Color(0xFFEFF6FF),
                ],
        ),
        border: Border.all(
          color: isDark
              ? const Color(0xFF4338CA).withValues(alpha: 0.3)
              : const Color(0xFFE9D5FF).withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 3D Floating Mail Graphic (Hidden on mobile < 750px)
          if (!isMobile) ...[
            Stack(
              alignment: Alignment.center,
              children: [
                // Ambient aura
                Container(
                  width: 130,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                // Floating dots
                Positioned(
                  top: 4,
                  right: 10,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC084FC).withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  left: 8,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Main Mail Card
                Container(
                  width: 105,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF8B5CF6),
                        Color(0xFF6366F1),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.mail_outline_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 32),
          ],

          // Main Search & Prompt
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'How can we help you today?',
                        style: TextStyle(
                          fontSize: isMobile ? 20 : 25,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('👋', style: TextStyle(fontSize: 22)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Search our knowledge base or raise a ticket directly to our support team.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 18),

                // Big Search Bar Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: _heroSearchController,
                          onChanged: (val) {
                            setState(() {
                              _searchFilter = val.trim().toLowerCase();
                            });
                          },
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search for help articles, guides or topics...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          if (_heroSearchController.text.isNotEmpty) {
                            _applyQuickSearch(_heroSearchController.text);
                          }
                        },
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4F46E5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.search_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Quick Searches Row
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Quick searches:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                    _buildQuickSearchPill('Reset password', isDark),
                    _buildQuickSearchPill('2FA setup', isDark),
                    _buildQuickSearchPill('Storage limit', isDark),
                    _buildQuickSearchPill('Mobile verification', isDark),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSearchPill(String label, bool isDark) {
    return InkWell(
      onTap: () => _applyQuickSearch(label),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // ── 2. QUICK ACTION CARDS (3 Cards) ───────────────────────────────────────
  Widget _buildQuickActionCards(bool isDark, bool isMobile) {
    final cards = [
      _buildActionTile(
        icon: Icons.chat_bubble_outline_rounded,
        iconBg: const Color(0xFFFAF5FF),
        iconColor: const Color(0xFF9333EA),
        title: 'Raise a Ticket',
        subtitle: 'Report an issue or get help',
        onTap: () => _scrollToKey(_ticketFormKey),
        isDark: isDark,
      ),
      _buildActionTile(
        icon: Icons.assignment_outlined,
        iconBg: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
        title: 'My Tickets',
        subtitle: 'View your support requests (${_tickets.length})',
        onTap: () => _scrollToKey(_supportLogKey),
        isDark: isDark,
      ),
      _buildActionTile(
        icon: Icons.bookmark_outline_rounded,
        iconBg: const Color(0xFFF0FDF4),
        iconColor: const Color(0xFF16A34A),
        title: 'Browse FAQs',
        subtitle: 'Find quick answers (10 topics)',
        onTap: () => _scrollToKey(_faqKey),
        isDark: isDark,
      ),
    ];

    if (isMobile) {
      return Column(
        children: cards
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: c,
                ))
            .toList(),
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 16),
        Expanded(child: cards[1]),
        const SizedBox(width: 16),
        Expanded(child: cards[2]),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? iconColor.withValues(alpha: 0.15) : iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
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

  // ── 3. RAISE A SUPPORT TICKET CARD ────────────────────────────────────────
  Widget _buildRaiseTicketCard(bool isDark, bool isMobile) {
    return Container(
      key: _ticketFormKey,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Color(0xFF9333EA),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Raise a Support Ticket',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Fill in the details and we\'ll get back to you.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Field 1: ISSUE SUBJECT
          _buildFieldLabel('ISSUE SUBJECT', isDark),
          const SizedBox(height: 6),
          TextField(
            controller: _subjectController,
            focusNode: _subjectFocusNode,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            decoration: _inputDecoration(
              hint: 'e.g. Unable to send emails',
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 18),

          // Field 2: PRIORITY
          _buildFieldLabel('PRIORITY', isDark),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedPriority,
            isExpanded: true,
            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            decoration: _inputDecoration(hint: '', isDark: isDark),
            items: const [
              DropdownMenuItem(
                value: 'Low - General Query',
                child: Text('Low - General Query', overflow: TextOverflow.ellipsis),
              ),
              DropdownMenuItem(
                value: 'Medium - Performance/Glitch',
                child: Text('Medium - Performance/Glitch', overflow: TextOverflow.ellipsis),
              ),
              DropdownMenuItem(
                value: 'High - Urgent Issue',
                child: Text('High - Urgent Issue', overflow: TextOverflow.ellipsis),
              ),
              DropdownMenuItem(
                value: 'Critical - Account Access',
                child: Text('Critical - Account Access', overflow: TextOverflow.ellipsis),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedPriority = val);
            },
          ),
          const SizedBox(height: 18),

          // Field 3: DETAILED EXPLANATION
          _buildFieldLabel('DETAILED EXPLANATION', isDark),
          const SizedBox(height: 6),
          TextField(
            controller: _explanationController,
            maxLines: 4,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            decoration: _inputDecoration(
              hint:
                  'Please describe exactly what you were doing, what went wrong, and how our support team can assist you...',
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 22),

          // Form Actions Row
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runAlignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              // Attach file button
              OutlinedButton.icon(
                onPressed: _pickAttachment,
                icon: const Icon(Icons.attach_file_rounded, size: 16),
                label: Text(
                  _attachedFileName == null
                      ? 'Attach file (optional)'
                      : (_attachedFileName!.length > 18
                          ? '${_attachedFileName!.substring(0, 16)}...'
                          : _attachedFileName!),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      isDark ? Colors.white70 : const Color(0xFF475569),
                  side: BorderSide(
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              // Submit Ticket Button
              ElevatedButton.icon(
                onPressed: _submitTicket,
                icon: const Icon(Icons.send_rounded, size: 15),
                label: const Text(
                  'Submit Ticket',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white60 : const Color(0xFF64748B),
        letterSpacing: 0.7,
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, required bool isDark}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13.5,
        color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
      ),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.04)
          : const Color(0xFFFAFAFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Color(0xFF4F46E5),
          width: 1.5,
        ),
      ),
    );
  }

  // ── 4. MY SUPPORT LOG CARD ────────────────────────────────────────────────
  Widget _buildSupportLogCard(bool isDark, bool isMobile) {
    return Container(
      key: _supportLogKey,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with count badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        color: Color(0xFF2563EB),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Support Log',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Track the status of your submitted tickets.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_tickets.length} LOGGED',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Log Content (Empty or List)
          if (_tickets.isEmpty)
            CustomPaint(
              painter: _DashedRectPainter(
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                strokeWidth: 1.2,
                gap: 5.0,
                radius: 14.0,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFF8FAFC),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mail_outline_rounded,
                        size: 22,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No filed tickets detected in your system history.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: () {
                        _scrollToKey(_ticketFormKey);
                        _subjectFocusNode.requestFocus();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF93C5FD)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'Create a Support Ticket',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: _tickets.map((t) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A).withValues(alpha: 0.5)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          t.id,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.subject,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${t.priority.split(' - ').first} • ${t.createdAt.day}/${t.createdAt.month}/${t.createdAt.year}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          t.status,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── 5. FREQUENTLY ASKED QUESTIONS CARD ────────────────────────────────────
  Widget _buildFaqCard(
    List<Map<String, String>> faqs,
    bool isDark,
    bool isMobile,
  ) {
    return Container(
      key: _faqKey,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with View All toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.help_outline_rounded,
                        color: Color(0xFF2563EB),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Frequently Asked Questions',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Find quick answers',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    if (_expandedFaqIndices.length == faqs.length) {
                      _expandedFaqIndices.clear();
                    } else {
                      _expandedFaqIndices.addAll(List.generate(faqs.length, (i) => i));
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    _expandedFaqIndices.length == faqs.length
                        ? 'Collapse all'
                        : 'View all (${faqs.length})',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Accordion items
          ...faqs.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isExpanded = _expandedFaqIndices.contains(index);

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Tag
                  if (item['category'] != null) ...[
                    Text(
                      item['category']!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3B82F6),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Question & Chevron
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedFaqIndices.remove(index);
                        } else {
                          _expandedFaqIndices.add(index);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['question']!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),

                  // Expandable Answer
                  if (isExpanded) ...[
                    const SizedBox(height: 8),
                    Text(
                      item['answer']!,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── 6. DIRECT SUPPORT CHANNELS CARD ───────────────────────────────────────
  Widget _buildDirectChannelsCard(bool isDark, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Dark navy as in Screenshot 3
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.headset_mic_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Direct Support Channels',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Get in touch directly via our channels below.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Explanatory Text
          const Text(
            'Need instant answers or have specialized account queries? Get in touch directly via our channels below.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF94A3B8),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // Channel Tile 1: EMAIL SUPPORT
          InkWell(
            onTap: _openEmailSupport,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF334155),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mail_outline_rounded,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EMAIL SUPPORT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'support@beta-softnet.com',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // "24/7 Support" Pill Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF312E81).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF4338CA).withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      '24/7 Support',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFA5B4FC),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Channel Tile 2: OFFICIAL PORTAL
          InkWell(
            onTap: _openPortal,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF334155),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.language_rounded,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OFFICIAL PORTAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'beta-softnet.com',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // "Visit Portal" Pill Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF064E3B).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF059669).withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'Visit Portal',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF34D399),
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
  }
}

// ── CUSTOM PAINTER FOR DASHED RECTANGLE (Matching screenshot empty log) ───────
class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double radius;

  _DashedRectPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.gap = 5.0,
    this.radius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length =
            (distance + gap < metric.length) ? gap : metric.length - distance;
        dashPath.addPath(
            metric.extractPath(distance, distance + length), Offset.zero);
        distance += gap * 2;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.radius != radius;
  }
}
