import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/app_state_provider.dart';

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

  // Ticket Form Controllers
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _explanationController = TextEditingController();
  String _selectedPriority = 'Medium - Performance/Glitch';
  String? _attachedFileName;

  // Active submitted tickets log
  final List<SupportTicketItem> _tickets = [];

  // FAQ Expanded items (item index 2 is expanded by default to match screenshot)
  final Set<int> _expandedFaqIndices = {2};

  final List<Map<String, String>> _faqs = [
    {
      'question': 'How do I reset my password?',
      'answer':
          'To reset your password, navigate to Settings > Security, select "Change Password", and follow the authentication prompts. If you cannot access your account, use the "Forgot Password" link on the login page.',
    },
    {
      'question': 'Is my data secure?',
      'answer':
          'Yes, BNX Mail uses end-to-end encryption for all email transmissions and zero-knowledge storage vault protocols to ensure your communications remain confidential.',
    },
    {
      'question': 'Can I use the app offline?',
      'answer':
          'Currently, the application requires an active internet connection to sync data in real-time. An offline mode is planned for future updates.',
    },
    {
      'question': 'How do I export my emails?',
      'answer':
          'You can export your emails by going to Mail Backup in the sidebar, choosing your desired date range and format (EML, MBOX, or PST), and clicking "Download Archive".',
    },
  ];

  final GlobalKey _ticketFormKey = GlobalKey();
  final GlobalKey _channelsKey = GlobalKey();
  final GlobalKey _supportLogKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    _topSearchController.dispose();
    _subjectController.dispose();
    _explanationController.dispose();
    super.dispose();
  }

  void _scrollToKey(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
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
        const SnackBar(
          content: Text('Please enter an issue subject and detailed explanation.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
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
        content: Text('Ticket ${newTicket.id} submitted successfully!'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );

    _scrollToKey(_supportLogKey);
  }

  Future<void> _openPortal() async {
    final uri = Uri.parse('https://beta-softnet.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening beta-softnet.com in browser...')),
        );
      }
    }
  }

  void _emailSupport() {
    ref.read(appUiProvider.notifier).updateComposeDraft(
          to: 'support@beta-softnet.com',
          subject:
              'Support Request - ${_subjectController.text.isNotEmpty ? _subjectController.text : "Inquiry"}',
          body: 'Hello Support Team,\n\n',
        );
    context.push('/compose');
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;

    final String query = _topSearchController.text.trim().toLowerCase();
    final filteredFaqs = _faqs.where((f) {
      if (query.isEmpty) return true;
      return f['question']!.toLowerCase().contains(query) ||
          f['answer']!.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── TOP HEADER BAR (Pinned at top of canvas) ──────────────────────
          _buildTopNavBar(context, isDark),

          // ── MAIN CONTENT (Scrollable, Two Columns matching screenshot) ───
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1360),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth > 860;
                      if (isDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── LEFT COLUMN ───────────────────────────────
                            Expanded(
                              flex: 1,
                              child: Column(
                                children: [
                                  _buildRaiseTicketCard(context, isDark),
                                  const SizedBox(height: 20),
                                  _buildSupportLogCard(context, isDark),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            // ── RIGHT COLUMN ──────────────────────────────
                            Expanded(
                              flex: 1,
                              child: Column(
                                children: [
                                  _buildFaqCard(context, isDark, filteredFaqs),
                                  const SizedBox(height: 20),
                                  _buildDirectSupportChannelsCard(context, isDark),
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      // Mobile / Narrow Stacked Layout
                      return Column(
                        children: [
                          _buildRaiseTicketCard(context, isDark),
                          const SizedBox(height: 20),
                          _buildFaqCard(context, isDark, filteredFaqs),
                          const SizedBox(height: 20),
                          _buildSupportLogCard(context, isDark),
                          const SizedBox(height: 20),
                          _buildDirectSupportChannelsCard(context, isDark),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. TOP HEADER BAR (Exact Match to Screenshot) ──────────────────────────
  Widget _buildTopNavBar(BuildContext context, bool isDark) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Logo & Help Center title
          InkWell(
            onTap: () {
              ref.read(appUiProvider.notifier).selectFolder('Inbox');
              context.go('/home');
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Stylized Purple Kite / Plane Icon
                  Transform.rotate(
                    angle: -0.22,
                    child: const Icon(
                      Icons.send_rounded,
                      color: Color(0xFF5C59E8),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'BNX Mail',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  Container(
                    height: 16,
                    width: 1.2,
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                  ),
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
            ),
          ),

          const Spacer(),

          // Top Search Pill
          LayoutBuilder(
            builder: (context, constraints) {
              final double screenWidth = MediaQuery.of(context).size.width;
              if (screenWidth < 640) {
                return const SizedBox.shrink();
              }
              return Container(
                width: screenWidth < 900 ? 210 : 280,
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _topSearchController,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search articles, topics or keywords...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onChanged: (val) {
                          setState(() {});
                        },
                      ),
                    ),
                    Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 14),

          // Contact Support Pill Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _scrollToKey(_channelsKey),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF5C59E8),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5C59E8).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.headset_mic_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'Contact Support',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. LEFT COLUMN: TICKET SUBMISSION CARD (Direct Inputs, No Title) ───────
  Widget _buildRaiseTicketCard(BuildContext context, bool isDark) {
    return Container(
      key: _ticketFormKey,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Issue Subject Input
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _subjectController,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'e.g. Unable to send emails',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 2. PRIORITY Label
          _buildFieldLabel('PRIORITY', isDark),
          const SizedBox(height: 6),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPriority,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF94A3B8),
                  size: 19,
                ),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w500,
                ),
                items: [
                  'Low - General Inquiry',
                  'Medium - Performance/Glitch',
                  'High - Service Disruption',
                  'Critical - Account Lockout',
                ].map((String val) {
                  return DropdownMenuItem<String>(
                    value: val,
                    child: Text(val),
                  );
                }).toList(),
                onChanged: (newVal) {
                  if (newVal != null) {
                    setState(() {
                      _selectedPriority = newVal;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 3. DETAILED EXPLANATION Label
          _buildFieldLabel('DETAILED EXPLANATION', isDark),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _explanationController,
              maxLines: 4,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText:
                    'Please describe exactly what you were doing, what went wrong, and how our support specialists can assist you.',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  height: 1.45,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 4. Action Buttons Row: [Attach file] + [Submit Ticket]
          LayoutBuilder(
            builder: (context, constraints) {
              final isVeryNarrow = constraints.maxWidth < 360;

              final attachButton = InkWell(
                onTap: _pickAttachment,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.attach_file_rounded,
                        size: 15,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 130),
                        child: Text(
                          _attachedFileName ?? 'Attach file (optional)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_attachedFileName != null) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => setState(() => _attachedFileName = null),
                          child: const Icon(Icons.close_rounded, size: 14, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              );

              final submitButton = Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _submitTicket,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5C59E8),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5C59E8).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.send_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Submit Ticket',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              if (isVeryNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    attachButton,
                    const SizedBox(height: 10),
                    submitButton,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  attachButton,
                  submitButton,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.white60 : const Color(0xFF94A3B8),
        letterSpacing: 0.8,
      ),
    );
  }

  // ── 3. LEFT COLUMN: MY SUPPORT LOG CARD ────────────────────────────────────
  Widget _buildSupportLogCard(BuildContext context, bool isDark) {
    return Container(
      key: _supportLogKey,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.16)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.article_outlined,
                  color: Color(0xFF3B82F6),
                  size: 19,
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
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Track the status of your submitted tickets.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // "0 LOGGED" Capsule Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_tickets.length} LOGGED',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Log Content: Empty State vs Ticket Items
          if (_tickets.isEmpty)
            CustomPaint(
              painter: _DashedRectPainter(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                strokeWidth: 1.2,
                gap: 5.0,
                radius: 14.0,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A).withValues(alpha: 0.5)
                      : const Color(0xFFFAFAFC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.mail_outline_rounded,
                        size: 22,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No filed tickets detected in your system history.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () => _scrollToKey(_ticketFormKey),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'View All Tickets',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _tickets.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final ticket = _tickets[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5C59E8).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ticket.id,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5C59E8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ticket.subject,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              ticket.explanation,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          ticket.status,
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
              },
            ),
        ],
      ),
    );
  }

  // ── 4. RIGHT COLUMN: FAQS CARD (4 Accordions without separate header) ──────
  Widget _buildFaqCard(
    BuildContext context,
    bool isDark,
    List<Map<String, String>> filteredFaqs,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: filteredFaqs.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No articles match your search query.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredFaqs.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                thickness: 0.8,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              ),
              itemBuilder: (context, index) {
                final faq = filteredFaqs[index];
                final isExpanded = _expandedFaqIndices.contains(index);

                return Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    key: Key('faq_$index'),
                    initiallyExpanded: isExpanded,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                    childrenPadding: const EdgeInsets.only(bottom: 12),
                    iconColor: isDark ? Colors.white70 : const Color(0xFF94A3B8),
                    collapsedIconColor: isDark ? Colors.white70 : const Color(0xFF94A3B8),
                    title: Text(
                      faq['question']!,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    onExpansionChanged: (expanded) {
                      setState(() {
                        if (expanded) {
                          _expandedFaqIndices.add(index);
                        } else {
                          _expandedFaqIndices.remove(index);
                        }
                      });
                    },
                    children: [
                      Text(
                        faq['answer']!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : const Color(0xFF64748B),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ── 5. RIGHT COLUMN: DIRECT SUPPORT CHANNELS (Dark Navy Card) ──────────────
  Widget _buildDirectSupportChannelsCard(BuildContext context, bool isDark) {
    return Container(
      key: _channelsKey,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1D), // Dark Navy Background matching image
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.headset_mic_outlined,
                  color: Color(0xFFCBD5E1),
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Direct Support Channels',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Get in touch directly via our channels below.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Subtitle Paragraph
          const Text(
            'Need instant answers or have specialized billing queries? Get in touch directly via our channels below.',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF94A3B8),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),

          // Channel Tile 1: EMAIL SUPPORT
          InkWell(
            onTap: _emailSupport,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF131B2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF1E293B),
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
                      Icons.email_outlined,
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
                      color: const Color(0xFF1E1E38),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
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
                color: const Color(0xFF131B2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF1E293B),
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
        final length = (distance + gap < metric.length) ? gap : metric.length - distance;
        dashPath.addPath(metric.extractPath(distance, distance + length), Offset.zero);
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
