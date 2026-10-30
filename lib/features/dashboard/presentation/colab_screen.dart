import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../data/app_state_provider.dart';
import '../../../data/account_provider.dart';
import '../../../models/account_model.dart';
import '../../../data/colab_provider.dart';
import '../../../data/email_provider.dart';
import '../../../data/repositories/casbox_repository.dart';
import '../../../models/attachment_model.dart';
import '../../../models/email_model.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../core/widgets/email_body.dart';
import 'package:file_picker/file_picker.dart';

bool checkCasboxMessageSentByMe(
  CasboxMessage m,
  String currentUserEmail,
  List<EmailModel> mailboxEmails,
) {
  final s = m.sender.toLowerCase().trim();
  if (s == 'me' || m.id.startsWith('local_')) return true;
  if (currentUserEmail.isNotEmpty) {
    if (s == currentUserEmail) return true;
    final sHandle = s.contains('@') ? s.split('@').first : s;
    final meHandle = currentUserEmail.contains('@')
        ? currentUserEmail.split('@').first
        : currentUserEmail;
    if (sHandle.isNotEmpty && sHandle == meHandle) return true;
  }
  for (final emailModel in mailboxEmails) {
    for (final clean in [
      emailModel.senderEmail.toLowerCase().trim(),
      emailModel.recipient.toLowerCase().trim(),
    ]) {
      if (clean.isNotEmpty) {
        if (s == clean) return true;
        final sHandle = s.contains('@') ? s.split('@').first : s;
        final mbHandle =
            clean.contains('@') ? clean.split('@').first : clean;
        if (sHandle.isNotEmpty && sHandle == mbHandle) return true;
      }
    }
  }
  return false;
}

(Color, Color) _getCasboxAvatarColors(String name, bool isDark) {
  if (isDark) {
    return (const Color(0xFF1E293B), const Color(0xFF93C5FD));
  }
  final code = name.toLowerCase().hashCode.abs() % 4;
  switch (code) {
    case 0:
      return (
        const Color(0xFFFEF3C7),
        const Color(0xFFD97706),
      ); // amber / orange
    case 1:
      return (const Color(0xFFEDE9FE), const Color(0xFF7C3AED)); // purple
    case 2:
      return (const Color(0xFFEFF6FF), const Color(0xFF2563EB)); // blue
    default:
      return (const Color(0xFFF0FDF4), const Color(0xFF16A34A)); // green
  }
}

class ColabScreen extends ConsumerStatefulWidget {
  const ColabScreen({super.key});

  @override
  ConsumerState<ColabScreen> createState() => _ColabScreenState();
}

class _ColabScreenState extends ConsumerState<ColabScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _colabSearchController = TextEditingController();
  String _colabSearchQuery = '';
  final TextEditingController _archiveSearchController = TextEditingController();
  String _archiveSearchQuery = '';
  final TextEditingController _starSearchController = TextEditingController();
  String _starSearchQuery = '';
  String _archiveFilterTab = 'All';
  String _starFilterTab = 'All';
  Timer? _activeGroupSyncTimer;

  @override
  void initState() {
    super.initState();
    // Fast real-time sync for active open chat (fetches comments & broadcasts every 3s when inside a chat room)
    _activeGroupSyncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final selectedGroupId = ref.read(selectedColabIdProvider);
      if (selectedGroupId != null && selectedGroupId.isNotEmpty) {
        ref
            .read(colabListProvider.notifier)
            .fetchMessagesForGroup(selectedGroupId);
        ref
            .read(colabListProvider.notifier)
            .fetchBroadcastsForGroup(selectedGroupId);
      }
    });
  }

  @override
  void dispose() {
    _activeGroupSyncTimer?.cancel();
    _searchController.dispose();
    _colabSearchController.dispose();
    _archiveSearchController.dispose();
    _starSearchController.dispose();
    super.dispose();
  }

  void _handleBackNavigation() {
    if (_isSearching) {
      setState(() {
        _isSearching = false;
        _searchController.clear();
      });
      ref.read(appUiProvider.notifier).setSearchQuery('');
      return;
    }
    final selectedGroupId = ref.read(selectedColabIdProvider);
    if (selectedGroupId != null) {
      ref.read(selectedColabIdProvider.notifier).state = null;
      return;
    }
    final selectedCasboxThread = ref.read(selectedCasboxThreadProvider);
    if (selectedCasboxThread != null) {
      ref.read(selectedCasboxThreadProvider.notifier).state = null;
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      ref.read(appUiProvider.notifier).selectFolder('Inbox');
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobileDevice =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final bool isMobile =
        isMobileDevice ||
        (screenWidth < 800 &&
            defaultTargetPlatform != TargetPlatform.macOS &&
            defaultTargetPlatform != TargetPlatform.windows);

    Widget content;
    final selectedGroupId = ref.watch(selectedColabIdProvider);
    if (selectedGroupId != null) {
      content = _buildColabDetailView(
        context,
        ref,
        selectedGroupId,
        isDark,
        isMobile,
      );
    } else if (uiState.activeFolder == 'Casbox') {
      content = _buildCasboxView(context, ref, isDark, isMobile);
    } else if (uiState.activeFolder == 'ColabArchive' ||
        uiState.activeFolder == 'Archive') {
      content = _buildColabArchiveView(context, ref, isDark, isMobile);
    } else if (uiState.activeFolder == 'ColabStar' ||
        uiState.activeFolder == 'Star' ||
        uiState.activeFolder == 'Starred') {
      content = _buildColabStarView(context, ref, isDark, isMobile);
    } else {
      content = _buildColabGroupsView(context, ref, isDark, isMobile);
    }

    return PopScope(
      canPop: !isMobile,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: content,
    );
  }

  Widget _buildColabGroupsView(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    bool isMobile,
  ) {
    final allGroups = ref.watch(colabListProvider);
    final activeGroups = allGroups.where((g) => !g.isArchived).toList();

    final query = _colabSearchQuery.trim().toLowerCase();
    final displayedGroups = query.isEmpty
        ? activeGroups
        : activeGroups.where((g) {
            return g.name.toLowerCase().contains(query) ||
                g.desc.toLowerCase().contains(query) ||
                g.lastMessage.toLowerCase().contains(query);
          }).toList();

    return Scaffold(
      backgroundColor: isDark ? BNXColors.darkBg : const Color(0xFFE9F4FF),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: 👥 Colab + Collaborate with your teams + [+ New Colab]
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (isMobile) ...[
                            IconButton(
                              icon: const Icon(Icons.menu_rounded),
                              onPressed: () =>
                                  Scaffold.of(context).openDrawer(),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                          ],
                          const Icon(
                            Icons.people_alt_rounded,
                            color: Color(0xFF195BAC),
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Colab',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Collaborate with your teams',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white60
                                        : const Color(0xFF64748B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showCreateColabDialog(
                        context,
                        ref,
                        isDark,
                      ),
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'New Colab',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF195BAC),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Search Bar: 🔍 Search colab groups...
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        size: 19,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _colabSearchController,
                          decoration: const InputDecoration(
                            hintText: 'Search colab groups...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                          onChanged: (val) =>
                              setState(() => _colabSearchQuery = val),
                        ),
                      ),
                      if (_colabSearchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _colabSearchController.clear();
                            setState(() => _colabSearchQuery = '');
                          },
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Invitation banner if any
                _buildInvitationBanner(context, ref, isDark),

                // Group list or Empty state
                Expanded(
                  child: displayedGroups.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.people_alt_rounded,
                                  size: 60,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No colab groups found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Create a colab group to start collaborating',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white60
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            await ref
                                .read(colabListProvider.notifier)
                                .loadGroups();
                            await ref
                                .read(colabInvitationsProvider.notifier)
                                .loadInvitations();
                          },
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: displayedGroups.map((group) {
                                  return _buildColabGroupCard(
                                    context,
                                    ref,
                                    group,
                                    isDark,
                                    isMobile: isMobile,
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColabArchiveView(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    bool isMobile,
  ) {
    final allGroups = ref.watch(colabListProvider);
    final archivedGroups = allGroups.where((g) => g.isArchived).toList();

    final allCasboxMsgs = ref.watch(casboxMessagesProvider);
    final archivedMsgs = allCasboxMsgs.where((m) => m.isArchived).toList();

    final query = _archiveSearchQuery.trim().toLowerCase();
    final filteredGroups = query.isEmpty
        ? archivedGroups
        : archivedGroups.where((g) {
            return g.name.toLowerCase().contains(query) ||
                g.desc.toLowerCase().contains(query) ||
                g.lastMessage.toLowerCase().contains(query);
          }).toList();

    final filteredMsgs = query.isEmpty
        ? archivedMsgs
        : archivedMsgs.where((m) {
            return m.sender.toLowerCase().contains(query) ||
                m.subject.toLowerCase().contains(query) ||
                m.body.toLowerCase().contains(query);
          }).toList();

    final totalCount = filteredGroups.length + filteredMsgs.length;
    final bool showGroups =
        _archiveFilterTab == 'All' || _archiveFilterTab == 'Colab';
    final bool showMsgs =
        _archiveFilterTab == 'All' || _archiveFilterTab == 'Messages';

    return Scaffold(
      backgroundColor: isDark ? BNXColors.darkBg : const Color(0xFFE9F4FF),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: 📥 Archive + View and manage your archived messages and colab conversations
                Row(
                  children: [
                    if (isMobile) ...[
                      IconButton(
                        icon: const Icon(Icons.menu_rounded),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Icon(
                      Icons.archive_outlined,
                      color: Color(0xFF195BAC),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Archive',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'View and manage your archived messages and colab conversations',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white60
                                  : const Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Search Bar: 🔍 Search archived items...
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        size: 19,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _archiveSearchController,
                          decoration: const InputDecoration(
                            hintText: 'Search archived items...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                          onChanged: (val) =>
                              setState(() => _archiveSearchQuery = val),
                        ),
                      ),
                      if (_archiveSearchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _archiveSearchController.clear();
                            setState(() => _archiveSearchQuery = '');
                          },
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Filter tabs: All ({count}) | Colab Conversations ({count}) | Messages ({count})
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildArchiveFilterChip(
                        label: 'All ($totalCount)',
                        isActive: _archiveFilterTab == 'All',
                        onTap: () => setState(() => _archiveFilterTab = 'All'),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildArchiveFilterChip(
                        label:
                            'Colab Conversations (${filteredGroups.length})',
                        isActive: _archiveFilterTab == 'Colab',
                        onTap: () => setState(() => _archiveFilterTab = 'Colab'),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildArchiveFilterChip(
                        label: 'Messages (${filteredMsgs.length})',
                        isActive: _archiveFilterTab == 'Messages',
                        onTap: () =>
                            setState(() => _archiveFilterTab = 'Messages'),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Content list or empty state
                Expanded(
                  child: totalCount == 0
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.archive_outlined,
                                  size: 60,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No archived items found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Archived colab conversations and messages will appear here',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white60
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          physics: const BouncingScrollPhysics(),
                          children: [
                            if (showGroups && filteredGroups.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'COLAB CONVERSATIONS (${filteredGroups.length})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.topLeft,
                                child: Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: filteredGroups.map(
                                    (g) => _buildColabGroupCard(
                                      context,
                                      ref,
                                      g,
                                      isDark,
                                      isMobile: isMobile,
                                      isArchiveView: true,
                                    ),
                                  ).toList(),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            if (showMsgs && filteredMsgs.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'MESSAGES (${filteredMsgs.length})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.topLeft,
                                child: Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: filteredMsgs.map(
                                    (m) => _buildCasboxArchiveMessageCard(
                                      context,
                                      ref,
                                      m,
                                      isDark,
                                      isMobile: isMobile,
                                    ),
                                  ).toList(),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColabStarView(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    bool isMobile,
  ) {
    final allGroups = ref.watch(colabListProvider);
    final allCasboxMsgs = ref.watch(casboxMessagesProvider);

    final starredGroups =
        allGroups.where((g) => g.isStarred).toList();
    final starredMsgs =
        allCasboxMsgs.where((m) => m.isStarred).toList();

    final query = _starSearchQuery.trim().toLowerCase();
    final filteredGroups = query.isEmpty
        ? starredGroups
        : starredGroups.where((g) {
            return g.name.toLowerCase().contains(query) ||
                g.desc.toLowerCase().contains(query) ||
                g.lastMessage.toLowerCase().contains(query);
          }).toList();

    final filteredMsgs = query.isEmpty
        ? starredMsgs
        : starredMsgs.where((m) {
            final body = m.body.toLowerCase();
            final subject = m.subject.toLowerCase();
            final sender = m.sender.toLowerCase();
            final to = m.to.toLowerCase();
            return body.contains(query) ||
                subject.contains(query) ||
                sender.contains(query) ||
                to.contains(query);
          }).toList();

    final totalCount = filteredGroups.length + filteredMsgs.length;
    final showGroups = _starFilterTab == 'All' || _starFilterTab == 'Colab';
    final showMsgs = _starFilterTab == 'All' || _starFilterTab == 'Messages';

    return Scaffold(
      backgroundColor: isDark ? BNXColors.darkBg : const Color(0xFFE9F4FF),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: ⭐ Starred + View and manage your starred messages and colab conversations
                Row(
                  children: [
                    if (isMobile) ...[
                      IconButton(
                        icon: const Icon(Icons.menu_rounded),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF59E0B),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Starred Colab Groups',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'View your starred colab groups',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white60
                                  : const Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Search Bar: 🔍 Search starred items...
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        size: 19,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _starSearchController,
                          decoration: const InputDecoration(
                            hintText: 'Search starred colab groups...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                          onChanged: (val) =>
                              setState(() => _starSearchQuery = val),
                        ),
                      ),
                      if (_starSearchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _starSearchController.clear();
                            setState(() => _starSearchQuery = '');
                          },
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Filter tabs: All ({count}) | Colab Conversations ({count}) | Messages ({count})
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildArchiveFilterChip(
                        label: 'All ($totalCount)',
                        isActive: _starFilterTab == 'All',
                        onTap: () => setState(() => _starFilterTab = 'All'),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildArchiveFilterChip(
                        label:
                            'Colab Conversations (${filteredGroups.length})',
                        isActive: _starFilterTab == 'Colab',
                        onTap: () => setState(() => _starFilterTab = 'Colab'),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildArchiveFilterChip(
                        label: 'Messages (${filteredMsgs.length})',
                        isActive: _starFilterTab == 'Messages',
                        onTap: () =>
                            setState(() => _starFilterTab = 'Messages'),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Content list or Empty state
                Expanded(
                  child: totalCount == 0
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_border_rounded,
                                  size: 60,
                                  color: Color(0xFFF59E0B),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No starred colab groups',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Click the three-dot menu on any group card and select Star to add it here',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white60
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          physics: const BouncingScrollPhysics(),
                          children: [
                            if (showGroups && filteredGroups.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'COLAB CONVERSATIONS (${filteredGroups.length})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.topLeft,
                                child: Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: filteredGroups.map(
                                    (g) => _buildColabGroupCard(
                                      context,
                                      ref,
                                      g,
                                      isDark,
                                      isMobile: isMobile,
                                      isStarView: true,
                                    ),
                                  ).toList(),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            if (showMsgs && filteredMsgs.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'MESSAGES (${filteredMsgs.length})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.topLeft,
                                child: Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: filteredMsgs.map(
                                    (m) => _buildCasboxStarMessageCard(
                                      context,
                                      ref,
                                      m,
                                      isDark,
                                      isMobile: isMobile,
                                    ),
                                  ).toList(),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArchiveFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF195BAC)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xFF195BAC)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  String _formatGroupDate(String rawDate) {
    if (rawDate.isEmpty) {
      final now = DateTime.now();
      return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    }
    try {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) {
        final d = parsed.day.toString().padLeft(2, '0');
        final m = parsed.month.toString().padLeft(2, '0');
        return '$d/$m/${parsed.year}';
      }
    } catch (_) {}
    if (rawDate.contains('T')) {
      final datePart = rawDate.split('T').first;
      final parts = datePart.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    }
    return rawDate;
  }

  Widget _buildColabGroupCard(
    BuildContext context,
    WidgetRef ref,
    ColabGroup group,
    bool isDark, {
    bool isArchiveView = false,
    bool isStarView = false,
    bool isMobile = false,
  }) {
    final String initial =
        group.name.isNotEmpty ? group.name[0].toUpperCase() : 'A';
    final String dateText = _formatGroupDate(group.lastMessageTime);

    return Container(
      width: isMobile ? double.infinity : 330,
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Avatar + Name + GROUP badge + 3 dots menu
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFF6366F1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  group.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  'GROUP',
                  style: TextStyle(
                    color: Color(0xFF1E40AF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              if (group.isArchived) ...[
                Tooltip(
                  message: 'Unarchive group',
                  child: InkWell(
                    onTap: () async {
                      await ref
                          .read(colabListProvider.notifier)
                          .toggleArchiveGroup(group.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Colab group "${group.name}" restored to Colab.'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF195BAC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.unarchive_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Tooltip(
                message: group.isStarred ? 'Unstar group' : 'Star group',
                child: InkWell(
                  onTap: () async {
                    final wasStarred = group.isStarred;
                    await ref
                        .read(colabListProvider.notifier)
                        .toggleStarGroup(group.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            wasStarred
                                ? 'Removed "${group.name}" from starred.'
                                : 'Starred "${group.name}".',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: group.isStarred
                          ? const Color(0xFFFEF3C7)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      group.isStarred
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: group.isStarred
                          ? const Color(0xFFF59E0B)
                          : (isDark
                              ? Colors.white60
                              : const Color(0xFF64748B)),
                      size: 17,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                itemBuilder: (ctx) => [
                  PopupMenuItem<String>(
                    value: group.isArchived ? 'unarchive' : 'archive',
                    child: Row(
                      children: [
                        Icon(
                          group.isArchived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                          size: 16,
                          color: const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Text(group.isArchived ? 'Unarchive' : 'Archive'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: group.isStarred ? 'unstar' : 'star',
                    child: Row(
                      children: [
                        Icon(
                          group.isStarred
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 16,
                          color: group.isStarred
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Text(group.isStarred ? 'Unstar' : 'Star'),
                      ],
                    ),
                  ),
                ],
                onSelected: (val) async {
                  if (val == 'archive' || val == 'unarchive') {
                    final wasArchived = group.isArchived;
                    await ref
                        .read(colabListProvider.notifier)
                        .toggleArchiveGroup(group.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            wasArchived
                                ? 'Colab group "${group.name}" restored to Colab.'
                                : 'Colab group "${group.name}" archived.',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } else if (val == 'star' || val == 'unstar') {
                    final wasStarred = group.isStarred;
                    await ref
                        .read(colabListProvider.notifier)
                        .toggleStarGroup(group.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            wasStarred
                                ? 'Removed "${group.name}" from starred.'
                                : 'Starred "${group.name}".',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Middle row: Last message
          Text(
            group.lastMessage.isNotEmpty
                ? group.lastMessage
                : 'No messages yet',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),

          // Bottom row: Date + Open chat ->
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateText,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () {
                  ref.read(selectedColabIdProvider.notifier).state = group.id;
                  ref.read(colabListProvider.notifier).markAsRead(group.id);
                  ref
                      .read(colabListProvider.notifier)
                      .fetchMessagesForGroup(group.id);
                  ref
                      .read(colabListProvider.notifier)
                      .fetchBroadcastsForGroup(group.id);
                  ref
                      .read(colabListProvider.notifier)
                      .fetchMembersForGroup(group.id);
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Open chat',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF195BAC),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: Color(0xFF195BAC),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCasboxArchiveMessageCard(
    BuildContext context,
    WidgetRef ref,
    CasboxMessage msg,
    bool isDark, {
    bool isMobile = false,
  }) {
    final activeAccount = ref.read(activeAccountProvider);
    final currentUserEmail = activeAccount.email.toLowerCase().trim();
    final mailboxEmails = ref.read(emailProvider).emails;
    final aliases = ref.watch(casboxAliasesProvider);

    final sentByMe = checkCasboxMessageSentByMe(msg, currentUserEmail, mailboxEmails);
    final contactEmail = (sentByMe ? msg.to : msg.sender).trim();
    final rawHandle = contactEmail.contains('@')
        ? contactEmail.split('@').first
        : (contactEmail.isNotEmpty ? contactEmail : 'Unknown');
    final contactName = aliases[rawHandle] ??
        aliases[contactEmail] ??
        (msg.contactDisplayName != null &&
                msg.contactDisplayName!.trim().isNotEmpty
            ? msg.contactDisplayName!.trim()
            : (msg.contactUsername != null &&
                    msg.contactUsername!.trim().isNotEmpty
                ? msg.contactUsername!.trim()
                : rawHandle));

    final initial = contactName.isNotEmpty ? contactName[0].toUpperCase() : 'C';
    final (avatarBg, avatarFg) = _getCasboxAvatarColors(contactName, isDark);
    final dateText = _formatGroupDate(
        '${msg.timestamp.day.toString().padLeft(2, '0')}/${msg.timestamp.month.toString().padLeft(2, '0')}/${msg.timestamp.year}');

    return Container(
      width: isMobile ? double.infinity : 330,
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: avatarBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: avatarFg,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  contactName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: sentByMe
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  sentByMe ? 'SENT' : 'RECEIVED',
                  style: TextStyle(
                    color: sentByMe
                        ? const Color(0xFF15803D)
                        : const Color(0xFF1E40AF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Tooltip(
                message: 'Unarchive message',
                child: InkWell(
                  onTap: () async {
                    final allMsgs = ref.read(casboxMessagesProvider);
                    final targetIds = allMsgs
                        .where((m) =>
                            (msg.subject.trim().isNotEmpty &&
                                m.subject.trim().toLowerCase() ==
                                    msg.subject.trim().toLowerCase()) ||
                            (m.sender == msg.sender && m.to == msg.to) ||
                            m.id == msg.id)
                        .map((m) => m.id)
                        .toList();
                    await ref
                        .read(casboxMessagesProvider.notifier)
                        .batchArchiveMessages(targetIds, false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Message restored to Casbox.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF195BAC),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.unarchive_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                itemBuilder: (ctx) => [
                  const PopupMenuItem<String>(
                    value: 'unarchive',
                    child: Row(
                      children: [
                        Icon(
                          Icons.unarchive_outlined,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        SizedBox(width: 8),
                        Text('Unarchive'),
                      ],
                    ),
                  ),
                ],
                onSelected: (val) async {
                  if (val == 'unarchive') {
                    final allMsgs = ref.read(casboxMessagesProvider);
                    final targetIds = allMsgs
                        .where((m) =>
                            (msg.subject.trim().isNotEmpty &&
                                m.subject.trim().toLowerCase() ==
                                    msg.subject.trim().toLowerCase()) ||
                            (m.sender == msg.sender && m.to == msg.to) ||
                            m.id == msg.id)
                        .map((m) => m.id)
                        .toList();
                    await ref
                        .read(casboxMessagesProvider.notifier)
                        .batchArchiveMessages(targetIds, false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Message restored to Casbox.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            msg.body.isNotEmpty
                ? msg.body
                : (msg.subject.isNotEmpty ? msg.subject : 'No content'),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateText,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () {
                  ref.read(selectedCasboxThreadProvider.notifier).state = msg.id;
                  ref.read(appUiProvider.notifier).selectFolder('Casbox');
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Open chat',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF195BAC),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: Color(0xFF195BAC),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCasboxStarMessageCard(
    BuildContext context,
    WidgetRef ref,
    CasboxMessage msg,
    bool isDark, {
    bool isMobile = false,
  }) {
    final activeAccount = ref.read(activeAccountProvider);
    final currentUserEmail = activeAccount.email.toLowerCase().trim();
    final mailboxEmails = ref.read(emailProvider).emails;
    final aliases = ref.watch(casboxAliasesProvider);

    final sentByMe = checkCasboxMessageSentByMe(msg, currentUserEmail, mailboxEmails);
    final contactEmail = (sentByMe ? msg.to : msg.sender).trim();
    final rawHandle = contactEmail.contains('@')
        ? contactEmail.split('@').first
        : (contactEmail.isNotEmpty ? contactEmail : 'Unknown');
    final contactName = aliases[rawHandle] ??
        aliases[contactEmail] ??
        (msg.contactDisplayName != null &&
                msg.contactDisplayName!.trim().isNotEmpty
            ? msg.contactDisplayName!.trim()
            : (msg.contactUsername != null &&
                    msg.contactUsername!.trim().isNotEmpty
                ? msg.contactUsername!.trim()
                : rawHandle));

    final initial = contactName.isNotEmpty ? contactName[0].toUpperCase() : 'C';
    final (avatarBg, avatarFg) = _getCasboxAvatarColors(contactName, isDark);
    final dateText = _formatGroupDate(
        '${msg.timestamp.day.toString().padLeft(2, '0')}/${msg.timestamp.month.toString().padLeft(2, '0')}/${msg.timestamp.year}');

    return Container(
      width: isMobile ? double.infinity : 330,
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: avatarBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: avatarFg,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  contactName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: sentByMe
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  sentByMe ? 'SENT' : 'RECEIVED',
                  style: TextStyle(
                    color: sentByMe
                        ? const Color(0xFF15803D)
                        : const Color(0xFF1E40AF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Tooltip(
                message: 'Unstar message',
                child: InkWell(
                  onTap: () async {
                    await ref
                        .read(casboxMessagesProvider.notifier)
                        .toggleStar(msg.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Removed from starred.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF59E0B),
                      size: 17,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                itemBuilder: (ctx) => [
                  const PopupMenuItem<String>(
                    value: 'unstar',
                    child: Row(
                      children: [
                        Icon(
                          Icons.star_border_rounded,
                          size: 16,
                          color: Color(0xFFF59E0B),
                        ),
                        SizedBox(width: 8),
                        Text('Unstar'),
                      ],
                    ),
                  ),
                ],
                onSelected: (val) async {
                  if (val == 'unstar') {
                    await ref
                        .read(casboxMessagesProvider.notifier)
                        .toggleStar(msg.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Removed from starred.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            msg.body.isNotEmpty
                ? msg.body
                : (msg.subject.isNotEmpty ? msg.subject : 'No content'),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateText,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () {
                  ref.read(selectedCasboxThreadProvider.notifier).state = msg.id;
                  ref.read(appUiProvider.notifier).selectFolder('Casbox');
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Open chat',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF195BAC),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: Color(0xFF195BAC),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationBanner(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
  ) {
    final invitations = ref.watch(colabInvitationsProvider);
    if (invitations.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? BNXColors.lightPrimary.withValues(alpha: 0.15)
            : const Color(0xFFE3F0FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: BNXColors.lightPrimary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: BNXColors.lightPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.group_add_rounded,
              color: BNXColors.lightPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'You have ${invitations.length} pending Colab invitation${invitations.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDark ? Colors.white : BNXColors.lightPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Review your invitations to join new groups.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _showInvitationsDialog(context, ref, isDark),
            style: ElevatedButton.styleFrom(
              backgroundColor: BNXColors.lightPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              elevation: 0,
            ),
            child: const Text(
              'View Invitations',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showInvitationsDialog(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (sCtx, setDialogState) {
            final invitations = ref.watch(colabInvitationsProvider);

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 420,
                  maxHeight: MediaQuery.of(dialogCtx).size.height * 0.6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.group_add_rounded,
                            color: BNXColors.lightPrimary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Pending Invitations',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : BNXColors.lightTextPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    // Invitation list
                    if (invitations.isEmpty)
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 48,
                                color: Colors.green.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No pending invitations',
                                style: TextStyle(
                                  color: isDark ? Colors.white54 : Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: invitations.length,
                          separatorBuilder: (_, _) => const Divider(height: 16),
                          itemBuilder: (_, index) {
                            final inv = invitations[index];
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : const Color(0xFFF7FAFF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    inv.groupName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: isDark
                                          ? Colors.white
                                          : BNXColors.lightTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        'Invited by: ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                      Flexible(
                                        child: Text(
                                          inv.invitedBy,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: BNXColors.lightPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            try {
                                              await ref
                                                  .read(
                                                    colabInvitationsProvider
                                                        .notifier,
                                                  )
                                                  .acceptInvitation(inv.id);
                                              // Refresh groups after accepting
                                              await ref
                                                  .read(
                                                    colabListProvider.notifier,
                                                  )
                                                  .loadGroups();
                                            } catch (e) {
                                              if (dialogCtx.mounted) {
                                                ScaffoldMessenger.of(
                                                  dialogCtx,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Failed to accept invitation: $e',
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                            setDialogState(() {});
                                            if (ref
                                                    .read(
                                                      colabInvitationsProvider,
                                                    )
                                                    .isEmpty &&
                                                dialogCtx.mounted) {
                                              Navigator.of(dialogCtx).pop();
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                BNXColors.lightPrimary,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                          ),
                                          child: const Text(
                                            'Accept',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () async {
                                            try {
                                              await ref
                                                  .read(
                                                    colabInvitationsProvider
                                                        .notifier,
                                                  )
                                                  .rejectInvitation(inv.id);
                                            } catch (e) {
                                              if (dialogCtx.mounted) {
                                                ScaffoldMessenger.of(
                                                  dialogCtx,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Failed to reject invitation: $e',
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                            setDialogState(() {});
                                            if (ref
                                                    .read(
                                                      colabInvitationsProvider,
                                                    )
                                                    .isEmpty &&
                                                dialogCtx.mounted) {
                                              Navigator.of(dialogCtx).pop();
                                            }
                                          },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: isDark
                                                ? Colors.white70
                                                : Colors.grey.shade700,
                                            side: BorderSide(
                                              color: isDark
                                                  ? Colors.white24
                                                  : Colors.grey.shade300,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                          ),
                                          child: const Text(
                                            'Reject',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateColabDialog(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
  ) {
    final nameController = TextEditingController();
    final membersController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          backgroundColor: isDark ? BNXColors.darkSurface : Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(28.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Colab Group',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Colab Group Name',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? BNXColors.darkTextSecondary
                          : BNXColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Project Alpha',
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? BNXColors.darkBorder
                              : BNXColors.lightBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: BNXColors.lightPrimary,
                          width: 2,
                        ),
                      ),
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Member Emails (comma separated)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? BNXColors.darkTextSecondary
                          : BNXColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: membersController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'user1@bnxmail.com, user2@bnxmail.com',
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? BNXColors.darkBorder
                              : BNXColors.lightBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: BNXColors.lightPrimary,
                          width: 2,
                        ),
                      ),
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      // Create Colab button on the left
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BNXColors.lightPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            final name = nameController.text.trim();
                            final membersText = membersController.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a group name'),
                                ),
                              );
                              return;
                            }
                            final membersList = membersText.isEmpty
                                ? <String>[]
                                : membersText
                                      .split(',')
                                      .map((e) => e.trim())
                                      .where((e) => e.isNotEmpty)
                                      .toList();

                            try {
                              final newGroup = await ref
                                  .read(colabListProvider.notifier)
                                  .addGroup(name: name, members: membersList);

                              ref.read(selectedColabIdProvider.notifier).state =
                                  newGroup.id;
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to create group: $e'),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text(
                            'Create Colab',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Cancel button on the right
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark
                                ? Colors.white70
                                : BNXColors.lightTextPrimary,
                            side: BorderSide(
                              color: isDark
                                  ? BNXColors.darkBorder
                                  : BNXColors.lightBorder,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'Cancel',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildColabDetailView(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    bool isDark,
    bool isMobile,
  ) {
    final groups = ref.watch(colabListProvider);
    final group = groups.firstWhere(
      (g) => g.id == groupId,
      orElse: () =>
          ColabGroup(id: '', name: 'Not Found', desc: '', members: []),
    );

    if (group.id.isEmpty) {
      return Scaffold(
        backgroundColor: isDark
            ? BNXColors.darkSurface
            : const Color(0xFFE9F4FF),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Colab Group not found'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(selectedColabIdProvider.notifier).state = null,
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final headerRow = Container(
      color: isDark ? BNXColors.darkSurface : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () =>
                ref.read(selectedColabIdProvider.notifier).state = null,
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showGroupInfoDialog(context, group, isDark),
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFF6366F1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                group.name.isNotEmpty ? group.name[0].toLowerCase() : 'a',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () =>
                          _showGroupInfoDialog(context, group, isDark),
                      borderRadius: BorderRadius.circular(4),
                      child: Text(
                        group.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : BNXColors.lightTextPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF64748B),
                      ),
                      onPressed: () =>
                          _showGroupInfoDialog(context, group, isDark),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Colab Channel Info',
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'GROUP • ONLINE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.print_outlined,
              size: 20,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Colab summary ready for print / export.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Print',
          ),
          IconButton(
            icon: Icon(
              group.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
              size: 20,
              color: group.isStarred
                  ? const Color(0xFFF59E0B)
                  : (isDark ? Colors.white70 : const Color(0xFF64748B)),
            ),
            tooltip: group.isStarred ? 'Unstar Group' : 'Star Group',
            onPressed: () async {
              final wasStarred = group.isStarred;
              await ref
                  .read(colabListProvider.notifier)
                  .toggleStarGroup(group.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      wasStarred
                          ? 'Removed "${group.name}" from starred.'
                          : 'Starred "${group.name}".',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
            onSelected: (value) async {
              if (value == 'info') {
                _showGroupInfoDialog(context, group, isDark);
              } else if (value == 'archive' || value == 'unarchive') {
                final wasArchived = group.isArchived;
                await ref
                    .read(colabListProvider.notifier)
                    .toggleArchiveGroup(group.id);
                if (!wasArchived) {
                  ref.read(selectedColabIdProvider.notifier).state = null;
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        wasArchived
                            ? 'Group "${group.name}" restored from archive.'
                            : 'Group "${group.name}" archived.',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } else if (value == 'star' || value == 'unstar') {
                final wasStarred = group.isStarred;
                await ref
                    .read(colabListProvider.notifier)
                    .toggleStarGroup(group.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        wasStarred
                            ? 'Removed "${group.name}" from starred.'
                            : 'Starred "${group.name}".',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } else if (value == 'leave') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Leave Group'),
                    content: Text(
                      'Are you sure you want to leave "${group.name}"?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Leave',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm != true || !context.mounted) return;
                try {
                  await ref
                      .read(colabListProvider.notifier)
                      .leaveGroup(group.id);
                  ref.read(selectedColabIdProvider.notifier).state = null;
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('You left the group "${group.name}".'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to leave group: $e')),
                    );
                  }
                }
              } else if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Group'),
                    content: Text(
                      'Are you sure you want to delete "${group.name}"? This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm != true || !context.mounted) return;
                try {
                  await ref
                      .read(colabListProvider.notifier)
                      .deleteGroup(group.id);
                  ref.read(selectedColabIdProvider.notifier).state = null;
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Group "${group.name}" has been deleted.',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete group: $e')),
                    );
                  }
                }
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Group Info'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: group.isArchived ? 'unarchive' : 'archive',
                child: Row(
                  children: [
                    Icon(
                      group.isArchived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                      size: 18,
                      color: const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(group.isArchived ? 'Unarchive' : 'Archive'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: group.isStarred ? 'unstar' : 'star',
                child: Row(
                  children: [
                    Icon(
                      group.isStarred
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 18,
                      color: group.isStarred
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(group.isStarred ? 'Unstar' : 'Star'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'leave',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Leave Group', style: TextStyle(color: Colors.orange)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Delete Group',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (isMobile) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: isDark
              ? BNXColors.darkSurface
              : const Color(0xFFF8FAFC),
          body: SafeArea(
            bottom: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  color: isDark ? BNXColors.darkSurface : Colors.white,
                  child: Column(
                    children: [
                      headerRow,
                      TabBar(
                        labelColor: isDark
                            ? BNXColors.darkPrimary
                            : BNXColors.lightPrimary,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: isDark
                            ? BNXColors.darkPrimary
                            : BNXColors.lightPrimary,
                        indicatorSize: TabBarIndicatorSize.tab,
                        tabs: const [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.email_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Broadcasts'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text('Comments'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Padding(
                    padding: isMobile
                        ? const EdgeInsets.only(
                            left: 16.0,
                            right: 16.0,
                            top: 16.0,
                            bottom: 8.0,
                          )
                        : const EdgeInsets.all(16.0),
                    child: TabBarView(
                      children: [
                        _buildBroadcastsPanel(context, ref, group, isDark),
                        CommentsSection(group: group, isDark: isDark, ref: ref),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? BNXColors.darkSurface : const Color(0xFFF8FAFC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headerRow,
          const Divider(height: 1),

          // Two Panels (Professional Broadcasts & Comments)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 11,
                    child: _buildBroadcastsPanel(context, ref, group, isDark),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 9,
                    child: CommentsSection(
                      group: group,
                      isDark: isDark,
                      ref: ref,
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

  Widget _buildCasboxView(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    bool isMobile,
  ) {
    return _CasboxInteractiveWidget(
      isDark: isDark,
      isMobile: isMobile,
      ref: ref,
    );
  }

  void _showGroupInfoDialog(
    BuildContext context,
    ColabGroup group,
    bool isDark,
  ) {
    final active = ref.read(activeAccountProvider);
    final activeEmail = active.email.toLowerCase().trim();

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Row: icon + title + close
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.people_alt_rounded,
                            color: Color(0xFF195BAC),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Colab Channel Info',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Channel identity: Large circle avatar + name + description
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFF195BAC),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          group.name.isNotEmpty ? group.name[0].toUpperCase() : 'A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              group.desc.isNotEmpty
                                  ? group.desc
                                  : 'A collaboration channel for team messaging and email broadcasting.',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Group Members Section
                  Row(
                    children: [
                      const Icon(
                        Icons.group_outlined,
                        size: 16,
                        color: Color(0xFF195BAC),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Group Members (${group.members.length})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Member list container
                  Container(
                    constraints: const BoxConstraints(maxHeight: 240),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      itemCount: group.members.length,
                      separatorBuilder: (context, index) => const Divider(height: 12),
                      itemBuilder: (context, index) {
                        final m = group.members[index];
                        final isMe = activeEmail.isNotEmpty && m.toLowerCase().trim() == activeEmail;
                        final isAdmin = m == group.creatorEmail ||
                            (group.creatorEmail.isEmpty && index == 0);

                        final avatarColors = [
                          const Color(0xFF2563EB),
                          const Color(0xFF7C3AED),
                          const Color(0xFF0891B2),
                          const Color(0xFF9333EA),
                        ];
                        final circleColor = avatarColors[index % avatarColors.length];

                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: circleColor,
                              child: Text(
                                m.isNotEmpty ? m[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                m,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isMe) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Me',
                                  style: TextStyle(
                                    color: Color(0xFF0369A1),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isAdmin
                                    ? const Color(0xFFFEF3C7)
                                    : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isAdmin
                                      ? const Color(0xFFFDE68A)
                                      : (isDark ? Colors.white24 : const Color(0xFFE2E8F0)),
                                ),
                              ),
                              child: Text(
                                isAdmin ? 'Admin' : 'Member',
                                style: TextStyle(
                                  color: isAdmin ? const Color(0xFFD97706) : const Color(0xFF64748B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bottom action: Leave Colab
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        ),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              title: const Text('Leave Colab'),
                              content: Text('Are you sure you want to leave "${group.name}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogCtx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogCtx, true),
                                  child: const Text('Leave', style: TextStyle(color: Colors.redAccent)),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true || !context.mounted) return;
                          try {
                            await ref.read(colabListProvider.notifier).leaveGroup(group.id);
                            ref.read(selectedColabIdProvider.notifier).state = null;
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('You left "${group.name}".')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to leave: $e')),
                              );
                            }
                          }
                        },
                        child: const Text(
                          'Leave Colab',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatBroadcastDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/$year, ${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  Widget _buildBroadcastsPanel(
    BuildContext context,
    WidgetRef ref,
    ColabGroup group,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () =>
                _showComposeBroadcastDialog(context, ref, group, isDark),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.mark_email_read_outlined,
                    color: Color(0xFF195BAC),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Professional Broadcasts',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child:
                !broadcastsLoadedIds.contains(group.id) &&
                    group.broadcasts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF195BAC),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Loading broadcasts...',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? BNXColors.darkTextSecondary
                                : BNXColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : group.broadcasts.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 8.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mail_outline_rounded,
                              size: 32,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No Broadcasts Sent',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white
                                  : BNXColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Send professional email updates to all group members.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? BNXColors.darkTextSecondary
                                  : BNXColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: group.broadcasts.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final b = group.broadcasts[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'From: ${b.sender}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatBroadcastDate(b.timestamp),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              b.subject,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              b.body,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155),
                                height: 1.35,
                              ),
                            ),
                            if (b.attachments.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: b.attachments.map((att) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white10
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white12
                                            : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.attach_file_rounded,
                                          size: 14,
                                          color: Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            att.fileName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                        if (att.fileSize.isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            '(${att.fileSize})',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF195BAC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () =>
                    _showComposeBroadcastDialog(context, ref, group, isDark),
                icon: const Icon(
                  Icons.mail_outline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'Compose New Broadcast',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showComposeBroadcastDialog(
    BuildContext context,
    WidgetRef ref,
    ColabGroup group,
    bool isDark,
  ) {
    final subjectController = TextEditingController();
    final bodyController = TextEditingController();
    List<AttachmentModel> attachedFiles = [];
    String? selectedTemplate;

    final templates = [
      {
        'title': 'Meeting Request',
        'subject': 'Meeting Request: [Topic/Project Name]',
        'body':
            'Hi Team,\n\nI would like to schedule a brief meeting to discuss [Topic/Project Name].\n\nPlease let me know your availability for this week.\n\nBest regards,',
      },
      {
        'title': 'Follow-Up Discussion',
        'subject': 'Follow-Up: Discussion on [Topic]',
        'body':
            'Hi everyone,\n\nFollowing up on our recent conversation regarding [Topic]. Here are the summary points and next steps:\n- Point 1:\n- Point 2:\n\nPlease review and let me know if you have questions.\n\nThanks,',
      },
      {
        'title': 'Out of Office',
        'subject': 'Out of Office: [Your Name] - [Start Date] to [End Date]',
        'body':
            'Hello,\n\nThank you for your email. I am currently out of the office with limited access to my email. I will return on [Date].\n\nFor urgent matters, please contact team@bnxmail.com.\n\nBest regards,',
      },
      {
        'title': 'Thank You Note',
        'subject': 'Thank You - Great Job on [Milestone/Project]',
        'body':
            'Hi Team,\n\nI wanted to take a moment to thank everyone for their hard work and dedication on [Milestone/Project]. The progress we made is fantastic.\n\nKeep up the great work!\n\nBest,',
      },
      {
        'title': 'Request for Feedback',
        'subject': 'Feedback Request: [Document/Proposal Name]',
        'body':
            'Hi All,\n\nCould you please take a few minutes to review the latest update for [Document/Proposal Name] and share your feedback?\n\nPlease submit your notes by [Date].\n\nThank you,',
      },
    ];

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Padding(
                  padding: const EdgeInsets.all(26.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.mail_outline_rounded,
                                  color: Color(0xFF195BAC),
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'New Colab Broadcast',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () => Navigator.of(ctx).pop(),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Send a broadcast announcement to all members of this Colab group',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Section 1: QUICK TEMPLATES (OPTIONAL)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.folder_copy_outlined,
                                    size: 14,
                                    color: Color(0xFF195BAC),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'QUICK TEMPLATES (OPTIONAL)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      color: isDark
                                          ? Colors.white70
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedTemplate,
                                    isExpanded: true,
                                    hint: const Text(
                                      '✓ -- Choose a template to load --',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 20,
                                    ),
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: '',
                                        child: Text(
                                          '✓ -- Choose a template to load --',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                      ...templates.map((tmpl) {
                                        return DropdownMenuItem<String>(
                                          value: tmpl['title'],
                                          child: Text(
                                            tmpl['title']!,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark
                                                  ? Colors.white
                                                  : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                    onChanged: (val) {
                                      if (val == null || val.isEmpty) {
                                        setState(() {
                                          selectedTemplate = null;
                                          subjectController.clear();
                                          bodyController.clear();
                                        });
                                        return;
                                      }
                                      final match = templates.firstWhere(
                                        (t) => t['title'] == val,
                                      );
                                      setState(() {
                                        selectedTemplate = val;
                                        subjectController.text =
                                            match['subject']!;
                                        bodyController.text = match['body']!;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Section 2: SUBJECT *
                        Text(
                          'SUBJECT *',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: subjectController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Q4 Planning Kickoff',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF195BAC),
                                width: 1.5,
                              ),
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Section 3: MESSAGE BODY *
                        Text(
                          'MESSAGE BODY *',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: bodyController,
                                minLines: 5,
                                maxLines: 8,
                                decoration: const InputDecoration(
                                  hintText: 'Write email content here...',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  contentPadding: EdgeInsets.all(14),
                                  border: InputBorder.none,
                                ),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.attach_file_rounded,
                                        size: 20,
                                        color: Color(0xFF64748B),
                                      ),
                                      onPressed: () async {
                                        try {
                                          final result = await FilePicker
                                              .platform
                                              .pickFiles(
                                            allowMultiple: true,
                                          );
                                          if (result != null &&
                                              result.files.isNotEmpty) {
                                            for (final file in result.files) {
                                              String? dataUri;
                                              Uint8List? fileBytes = file.bytes;
                                              if (fileBytes == null &&
                                                  file.path != null) {
                                                try {
                                                  final f = File(file.path!);
                                                  if (f.existsSync()) {
                                                    fileBytes =
                                                        await f.readAsBytes();
                                                  }
                                                } catch (_) {}
                                              }
                                              final ext = (file.extension ?? '')
                                                  .toLowerCase();
                                              final isImg = [
                                                'png',
                                                'jpg',
                                                'jpeg',
                                                'gif',
                                                'webp',
                                              ].contains(ext);
                                              if (isImg && fileBytes != null) {
                                                final mimeExt =
                                                    (ext == 'jpg' ||
                                                            ext == 'jpeg')
                                                        ? 'jpeg'
                                                        : ext;
                                                dataUri =
                                                    'data:image/$mimeExt;base64,${base64Encode(fileBytes)}';
                                              }
                                              setState(() {
                                                attachedFiles.add(
                                                  AttachmentModel(
                                                    fileName: file.name,
                                                    fileType:
                                                        file.extension
                                                            ?.toUpperCase() ??
                                                        'FILE',
                                                    fileSize: file.size >
                                                            1024 * 1024
                                                        ? '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB'
                                                        : '${(file.size / 1024).toStringAsFixed(0)} KB',
                                                    filePath:
                                                        dataUri ?? file.path,
                                                  ),
                                                );
                                              });
                                            }
                                          }
                                        } catch (e) {
                                          print('[BROADCAST FILE PICKER] $e');
                                        }
                                      },
                                      tooltip: 'Attach file',
                                    ),
                                    const Text(
                                      'Max 5MB per file',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Attached chips if any
                        if (attachedFiles.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: attachedFiles
                                .asMap()
                                .entries
                                .map((entry) {
                                  final idx = entry.key;
                                  final att = entry.value;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white10
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.attach_file_rounded,
                                          size: 14,
                                          color: Color(0xFF195BAC),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          att.fileName,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              attachedFiles.removeAt(idx);
                                            });
                                          },
                                          child: const Icon(
                                            Icons.close_rounded,
                                            size: 14,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                })
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Action button: Send Broadcast ➤
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF195BAC),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () async {
                              final subjectText = subjectController.text.trim();
                              final bodyText = bodyController.text.trim();
                              if (subjectText.isEmpty || bodyText.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please enter subject and message body.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              final active = ref.read(activeAccountProvider);
                              final senderName = active.name.isNotEmpty
                                  ? active.name
                                  : active.email;
                              try {
                                await ref
                                    .read(colabListProvider.notifier)
                                    .addBroadcast(
                                      group.id,
                                      sender: senderName,
                                      subject: subjectText,
                                      body: bodyText,
                                      attachments: attachedFiles,
                                    );
                                if (context.mounted) {
                                  Navigator.of(ctx).pop();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to send broadcast: $e',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Send Broadcast',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.near_me_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

enum CasboxFilterOption {
  all,
  receivedOnly,
  sentOnly,
  last1Day,
  last1Week,
  last1Month,
}

class _CasboxInteractiveWidget extends ConsumerStatefulWidget {
  final bool isDark;
  final bool isMobile;
  final WidgetRef ref;

  const _CasboxInteractiveWidget({
    required this.isDark,
    required this.isMobile,
    required this.ref,
  });

  @override
  ConsumerState<_CasboxInteractiveWidget> createState() =>
      _CasboxInteractiveWidgetState();
}

class _CasboxInteractiveWidgetState
    extends ConsumerState<_CasboxInteractiveWidget> {
  final Set<String> _selectedIds = {};
  bool _isRefreshing = false;
  bool _isLoading = true;
  String _activeTab = 'Messages';
  bool _showArchiveTab = false;
  CasboxFilterOption _activeFilter = CasboxFilterOption.all;
  bool _showFilterMenu = false;
  final TextEditingController _casboxSearchController = TextEditingController();
  final TextEditingController _desktopChatInputController =
      TextEditingController();
  final ScrollController _desktopChatScrollController = ScrollController();
  String _casboxSearchQuery = '';
  Timer? _casboxPollingTimer;
  CasboxMessage? _selectedDesktopMessage;
  bool _showConnectionsPopup = false;
  List<String> _authorizedContacts = [];
  final List<String> _blockedUsers = [];
  final Map<String, bool> _contactConnectionStatus = {};

  bool _checkIsSentByMe(
    CasboxMessage m,
    String currentUserEmail,
    List<EmailModel> mailboxEmails,
  ) {
    return checkCasboxMessageSentByMe(m, currentUserEmail, mailboxEmails);
  }

  void _showEditContactNameDialog(String contactId, String currentName) {
    final controller = TextEditingController(text: currentName);
    final sm = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Edit Contact Name',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'Enter custom name',
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF195BAC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  await ref
                      .read(casboxAliasesProvider.notifier)
                      .setAlias(contactId, newName);
                  sm.showSnackBar(
                    SnackBar(
                      content: Text('Updated contact name to "$newName"'),
                    ),
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  String _formatDatePill(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = date.toLocal();
    final dayName = days[local.weekday - 1];
    final monthName = months[local.month - 1];
    return '$dayName, ${local.day} $monthName ${local.year}';
  }

  String _formatDetailDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = date.toLocal();
    final month = months[local.month - 1];
    final day = local.day;
    final year = local.year;
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final hourStr = hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$month $day, $year, $hourStr:$min $ampm';
  }

  (Color, Color) _getAvatarColors(String name, bool isDark) {
    return _getCasboxAvatarColors(name, isDark);
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _startPeriodicPolling();
  }

  void _startPeriodicPolling() {
    _casboxPollingTimer?.cancel();
    _casboxPollingTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      final mailboxEmails = ref.read(emailProvider).emails;
      await ref
          .read(casboxMessagesProvider.notifier)
          .fetchMessages(mailboxEmails);
      if (_selectedDesktopMessage != null) {
        final activeAccount = ref.read(activeAccountProvider);
        final currentUserEmail = activeAccount.email.toLowerCase().trim();
        final isSentByMe = _checkIsSentByMe(
          _selectedDesktopMessage!,
          currentUserEmail,
          mailboxEmails,
        );
        final other = isSentByMe
            ? _selectedDesktopMessage!.to
            : _selectedDesktopMessage!.sender;
        if (other.isNotEmpty) {
          await ref
              .read(casboxMessagesProvider.notifier)
              .fetchThreadMessages(other);
        }
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_desktopChatScrollController.hasClients) {
        _desktopChatScrollController.animateTo(
          _desktopChatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleConnectionsPopup() {
    setState(() {
      _showConnectionsPopup = !_showConnectionsPopup;
    });
    if (_showConnectionsPopup) {
      ref.read(casboxConnectionsProvider.notifier).fetchConnections();
      CasboxRepository.getAuthorizedContacts().then((authContacts) {
        if (mounted && authContacts.isNotEmpty) {
          setState(() {
            _authorizedContacts = authContacts;
            for (final c in authContacts) {
              _contactConnectionStatus[c] = true;
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _casboxPollingTimer?.cancel();
    _casboxSearchController.dispose();
    _desktopChatInputController.dispose();
    _desktopChatScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final hasData = ref.read(casboxMessagesProvider).isNotEmpty;
    if (hasData) {
      if (mounted) setState(() => _isLoading = false);
    } else {
      if (mounted) setState(() => _isLoading = true);
    }

    final mailboxEmails = ref.read(emailProvider).emails;
    await Future.wait([
      ref.read(casboxMessagesProvider.notifier).fetchMessages(mailboxEmails),
      ref.read(casboxBlockedContactsProvider.notifier).loadBlockedContacts(),
      ref.read(casboxConnectionsProvider.notifier).fetchConnections(),
      ref.read(casboxAliasesProvider.notifier).fetchAliases(),
    ]);
    try {
      final authContacts = await CasboxRepository.getAuthorizedContacts();
      if (mounted && authContacts.isNotEmpty) {
        setState(() {
          _authorizedContacts = authContacts;
          for (final c in authContacts) {
            _contactConnectionStatus[c] = true;
          }
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerRefresh() async {
    setState(() {
      _isRefreshing = true;
      _isLoading = true;
    });
    final mailboxEmails = ref.read(emailProvider).emails;
    await Future.wait([
      ref.read(casboxMessagesProvider.notifier).fetchMessages(mailboxEmails),
      ref.read(casboxBlockedContactsProvider.notifier).loadBlockedContacts(),
      ref.read(casboxConnectionsProvider.notifier).fetchConnections(),
      ref.read(casboxAliasesProvider.notifier).fetchAliases(),
    ]);
    try {
      final authContacts = await CasboxRepository.getAuthorizedContacts();
      if (mounted && authContacts.isNotEmpty) {
        setState(() {
          _authorizedContacts = authContacts;
          for (final c in authContacts) {
            _contactConnectionStatus[c] = true;
          }
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isRefreshing = false;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Casbox synchronized!'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildLoadingIndicator(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF195BAC).withValues(alpha: 0.15),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF195BAC)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Syncing Chat Messages...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Fetching latest Casbox conversations',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final allMessages = ref.watch(casboxMessagesProvider);
    final blockedContacts = ref.watch(casboxBlockedContactsProvider);
    final activeAccount = ref.watch(activeAccountProvider);
    final currentUserEmail = activeAccount.email.toLowerCase().trim();
    final mailboxEmails = ref.watch(emailProvider).emails;

    bool isSentByMe(CasboxMessage m) =>
        _checkIsSentByMe(m, currentUserEmail, mailboxEmails);

    final filteredUserMessages = allMessages;

    final messages = filteredUserMessages.where((m) {
      final sLower = m.sender.toLowerCase().trim();
      final toLower = m.to.toLowerCase().trim();
      final sHandle = sLower.contains('@') ? sLower.split('@').first : sLower;
      final toHandle = toLower.contains('@')
          ? toLower.split('@').first
          : toLower;

      if (blockedContacts.contains(sLower) ||
          blockedContacts.contains(toLower) ||
          blockedContacts.contains(sHandle) ||
          blockedContacts.contains(toHandle) ||
          _blockedUsers.contains(m.sender) ||
          _blockedUsers.contains(m.to)) {
        return false;
      }

      final isArchived = m.isArchived;
      if (_activeTab == 'Archive' || _activeTab == 'Archived') {
        if (!isArchived) return false;
      } else if (_activeTab == 'Starred' || _activeTab == 'Star') {
        if (!m.isStarred) return false;
      } else {
        if (isArchived) return false;
        // Filter by active tab
        if (_activeTab == 'Combine' || _activeTab == 'Combined Chat') {
          // Show both Sent and Received messages as in Image 3
        } else if (_activeTab == 'Requests') {
          final s = m.status.toUpperCase();
          if (isSentByMe(m) || (s != 'PENDING' && s != 'REQUEST')) return false;
        } else {
          // 'Messages' or default
          final s = m.status.toUpperCase();
          if (!isSentByMe(m) && (s == 'PENDING' || s == 'REQUEST')) {
            return false;
          }
        }
      }

      // Filter by active filter option
      switch (_activeFilter) {
        case CasboxFilterOption.receivedOnly:
          if (isSentByMe(m)) return false;
          break;
        case CasboxFilterOption.sentOnly:
          if (!isSentByMe(m)) return false;
          break;
        case CasboxFilterOption.last1Day:
          if (DateTime.now().difference(m.timestamp.toLocal()).inHours > 24) {
            return false;
          }
          break;
        case CasboxFilterOption.last1Week:
          if (DateTime.now().difference(m.timestamp.toLocal()).inDays > 7) {
            return false;
          }
          break;
        case CasboxFilterOption.last1Month:
          if (DateTime.now().difference(m.timestamp.toLocal()).inDays > 30) {
            return false;
          }
          break;
        case CasboxFilterOption.all:
          break;
      }

      // Search query filtering
      if (_casboxSearchQuery.trim().isNotEmpty) {
        final q = _casboxSearchQuery.trim().toLowerCase();
        final matchSender = m.sender.toLowerCase().contains(q);
        final matchTo = m.to.toLowerCase().contains(q);
        final matchSubject = m.subject.toLowerCase().contains(q);
        final matchBody = m.body.toLowerCase().contains(q);
        if (!matchSender && !matchTo && !matchSubject && !matchBody) {
          return false;
        }
      }

      return true;
    }).toList();

    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final selectedThreadId = ref.watch(selectedCasboxThreadProvider);
    if (selectedThreadId == null && _selectedDesktopMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedDesktopMessage != null) {
          setState(() {
            _selectedDesktopMessage = null;
          });
        }
      });
    } else if (selectedThreadId != null && _selectedDesktopMessage == null) {
      final matching = allMessages.where((m) => m.id == selectedThreadId);
      if (matching.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedDesktopMessage == null) {
            setState(() {
              _selectedDesktopMessage = matching.first;
            });
          }
        });
      }
    }

    return PopScope(
      canPop: _selectedDesktopMessage == null && !_showConnectionsPopup,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_showFilterMenu) {
          setState(() => _showFilterMenu = false);
          return;
        }
        if (_showConnectionsPopup) {
          setState(() => _showConnectionsPopup = false);
          return;
        }
        if (_selectedDesktopMessage != null) {
          setState(() => _selectedDesktopMessage = null);
          ref.read(selectedCasboxThreadProvider.notifier).state = null;
        }
      },
      child: SafeArea(
        top: widget.isMobile,
        bottom: false,
        child: _buildDesktopCasboxView(
          isDark,
          messages,
          allMessages,
          activeAccount,
        ),
      ),
    );
  }

  Widget _buildDesktopCasboxView(
    bool isDark,
    List<CasboxMessage> messages,
    List<CasboxMessage> allMessages,
    AccountModel activeAccount,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 680;

    if (_selectedDesktopMessage != null) {
      if (_activeTab == 'Combine' || _activeTab == 'Combined Chat') {
        return Container(
          color: isDark ? BNXColors.darkSurface : Colors.white,
          child: _buildCombineChatConversationView(
            isDark,
            _selectedDesktopMessage!,
            allMessages,
            activeAccount,
          ),
        );
      }
      return Container(
        color: isDark ? BNXColors.darkSurface : Colors.white,
        child: _buildDesktopChatConversationView(
          isDark,
          _selectedDesktopMessage!,
          allMessages,
          activeAccount,
        ),
      );
    }

    return Container(
      color: isDark ? BNXColors.darkSurface : Colors.white,
      child: Stack(
        children: [
          Column(
            children: [
              _buildDesktopCasboxHeader(isDark, screenWidth),
              _buildCasboxSearchBar(isDark, screenWidth),
              Expanded(
                child: _buildDesktopMessageList(
                  isDark,
                  messages,
                  isSplit: false,
                ),
              ),
            ],
          ),
          if (_showFilterMenu) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => setState(() => _showFilterMenu = false),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              top: isNarrow ? 104 : 64,
              right: isNarrow ? 12 : 20,
              child: _buildFilterDropdownMenu(isDark, screenWidth),
            ),
          ],
          if (_showConnectionsPopup) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => setState(() => _showConnectionsPopup = false),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              top: isNarrow ? 98 : 52,
              right: isNarrow ? 12 : 80,
              left: isNarrow ? 12 : null,
              child: _buildConnectionsPopup(isDark, screenWidth),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArchiveToggleArrow({
    required bool isExpanded,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: isExpanded ? 'Hide Archive' : 'Show Archive',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Icon(
              isExpanded
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              size: 20,
              color: isExpanded
                  ? const Color(0xFF195BAC)
                  : (isDark ? Colors.white70 : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopCasboxHeader(bool isDark, double screenWidth) {
    final isNarrow = screenWidth < 720;
    final isArchiveVisible =
        _showArchiveTab || _activeTab == 'Archive' || _activeTab == 'Archived';

    if (isNarrow) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? BNXColors.darkSurface : Colors.white,
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
              width: 1,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Open menu',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                Text(
                  'Casbox',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                  ),
                ),
                const Spacer(),
                // Button 1: Connections icon button on mobile
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _toggleConnectionsPopup,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _showConnectionsPopup
                            ? const Color(0xFFDBEAFE)
                            : (isDark
                                  ? Colors.white10
                                  : const Color(0xFFEFF6FF)),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 16,
                        color: Color(0xFF195BAC),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Button 2: Block Users list icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.block_outlined,
                      size: 17,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                    tooltip: 'Blocked Users',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _showBlockedUsersDialog(context, isDark),
                  ),
                ),
                const SizedBox(width: 6),
                // Button 3: Refresh icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  ),
                  child: IconButton(
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF195BAC),
                            ),
                          )
                        : Icon(
                            Icons.refresh_rounded,
                            size: 17,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF475569),
                          ),
                    tooltip: 'Refresh',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _triggerRefresh,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDesktopSegment(
                      'Messages',
                      _activeTab == 'Received' || _activeTab == 'Messages',
                      () {
                        setState(() {
                          _activeTab = 'Messages';
                          _selectedDesktopMessage = null;
                          _clearSelection();
                        });
                        ref.read(selectedCasboxThreadProvider.notifier).state =
                            null;
                      },
                      isDark,
                      isCompact: true,
                    ),
                    _buildDesktopSegment(
                      'Combine',
                      _activeTab == 'Combine' || _activeTab == 'Combined Chat',
                      () {
                        setState(() {
                          _activeTab = 'Combine';
                          _selectedDesktopMessage = null;
                          _clearSelection();
                        });
                        ref.read(selectedCasboxThreadProvider.notifier).state =
                            null;
                      },
                      isDark,
                      isCompact: true,
                    ),
                    _buildDesktopSegment(
                      'Requests',
                      _activeTab == 'Requests',
                      () {
                        setState(() {
                          _activeTab = 'Requests';
                          _selectedDesktopMessage = null;
                          _clearSelection();
                        });
                        ref.read(selectedCasboxThreadProvider.notifier).state =
                            null;
                      },
                      isDark,
                      isCompact: true,
                    ),
                    _buildArchiveToggleArrow(
                      isExpanded: isArchiveVisible,
                      isDark: isDark,
                      onTap: () {
                        setState(() {
                          if (isArchiveVisible) {
                            _showArchiveTab = false;
                            if (_activeTab == 'Archive' ||
                                _activeTab == 'Archived') {
                              _activeTab = 'Messages';
                            }
                          } else {
                            _showArchiveTab = true;
                          }
                        });
                      },
                    ),
                    if (isArchiveVisible) ...[
                      _buildDesktopSegment(
                        'Archive',
                        _activeTab == 'Archive' || _activeTab == 'Archived',
                        () {
                          setState(() {
                            _activeTab = 'Archive';
                            _selectedDesktopMessage = null;
                            _clearSelection();
                          });
                          ref
                              .read(selectedCasboxThreadProvider.notifier)
                              .state =
                              null;
                        },
                        isDark,
                        isCompact: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? BNXColors.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Segmented switcher: Messages / Combine / Requests / Arrow / (Archive)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDesktopSegment(
                  'Messages',
                  _activeTab == 'Received' || _activeTab == 'Messages',
                  () {
                    setState(() {
                      _activeTab = 'Messages';
                      _selectedDesktopMessage = null;
                      _clearSelection();
                    });
                    ref.read(selectedCasboxThreadProvider.notifier).state =
                        null;
                  },
                  isDark,
                ),
                _buildDesktopSegment(
                  'Combine',
                  _activeTab == 'Combine' || _activeTab == 'Combined Chat',
                  () {
                    setState(() {
                      _activeTab = 'Combine';
                      _selectedDesktopMessage = null;
                      _clearSelection();
                    });
                    ref.read(selectedCasboxThreadProvider.notifier).state =
                        null;
                  },
                  isDark,
                ),
                _buildDesktopSegment('Requests', _activeTab == 'Requests', () {
                  setState(() {
                    _activeTab = 'Requests';
                    _selectedDesktopMessage = null;
                    _clearSelection();
                  });
                  ref.read(selectedCasboxThreadProvider.notifier).state = null;
                }, isDark),
                _buildArchiveToggleArrow(
                  isExpanded: isArchiveVisible,
                  isDark: isDark,
                  onTap: () {
                    setState(() {
                      if (isArchiveVisible) {
                        _showArchiveTab = false;
                        if (_activeTab == 'Archive' ||
                            _activeTab == 'Archived') {
                          _activeTab = 'Messages';
                        }
                      } else {
                        _showArchiveTab = true;
                      }
                    });
                  },
                ),
                if (isArchiveVisible) ...[
                  _buildDesktopSegment(
                    'Archive',
                    _activeTab == 'Archive' || _activeTab == 'Archived',
                    () {
                      setState(() {
                        _activeTab = 'Archive';
                        _selectedDesktopMessage = null;
                        _clearSelection();
                      });
                      ref.read(selectedCasboxThreadProvider.notifier).state =
                          null;
                    },
                    isDark,
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          // Button 1: + Connections (Filled blue pill button with white text and icon matching Image 1)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _toggleConnectionsPopup,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF195BAC),
                  borderRadius: BorderRadius.circular(19),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF195BAC).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    SizedBox(width: 7),
                    Text(
                      '+ Connections',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Button 2: Block icon button
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
            ),
            child: IconButton(
              icon: Icon(
                Icons.block_outlined,
                size: 19,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
              tooltip: 'Blocked Users',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _showBlockedUsersDialog(context, isDark),
            ),
          ),
          const SizedBox(width: 10),
          // Button 3: Refresh icon button
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
            ),
            child: IconButton(
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF195BAC),
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      size: 19,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
              tooltip: 'Refresh',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _triggerRefresh,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCasboxSearchBar(bool isDark, double screenWidth) {
    final isNarrow = screenWidth < 680;
    if (_selectedIds.isNotEmpty) {
      final isArchiveTab = _activeTab == 'Archive' || _activeTab == 'Archived';
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isNarrow ? 12 : 16,
          vertical: 8,
        ),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 10 : 16),
          child: Row(
            children: [
              Text(
                '${_selectedIds.length} selected',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () async {
                  final ids = _selectedIds.toList();
                  if (ids.isEmpty) return;
                  final archiveTarget = !isArchiveTab;
                  try {
                    await ref
                        .read(casboxMessagesProvider.notifier)
                        .batchArchiveMessages(ids, archiveTarget);
                    if (mounted) {
                      setState(() {
                        _selectedIds.clear();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            archiveTarget
                                ? '${ids.length} messages archived'
                                : '${ids.length} messages unarchived',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to update archive status: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isArchiveTab
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                        size: 15,
                        color: const Color(0xFF195BAC),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isArchiveTab ? 'Unarchive' : 'Archive',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF195BAC),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => setState(() => _selectedIds.clear()),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 12 : 16,
        vertical: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 19,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _casboxSearchController,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText:
                            (_activeTab == 'Combine' ||
                                _activeTab == 'Combined Chat')
                            ? 'Search all messages...'
                            : 'Search messages...',
                        hintStyle: TextStyle(
                          fontSize: 13.5,
                          color: isDark
                              ? Colors.white38
                              : const Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _casboxSearchQuery = val;
                        });
                      },
                    ),
                  ),
                  if (_casboxSearchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _casboxSearchController.clear();
                          _casboxSearchQuery = '';
                        });
                      },
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: isDark
                            ? Colors.white38
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Filter Funnel Button matching Image 1 & Image 2
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showFilterMenu = !_showFilterMenu;
                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _showFilterMenu
                      ? const Color(0xFFDBEAFE)
                      : (isDark
                            ? const Color(0xFF1E3A5F)
                            : const Color(0xFFEFF6FF)),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.filter_alt_rounded,
                  size: 20,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdownMenu(bool isDark, double screenWidth) {
    return Container(
      width: 210,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFilterMenuItem(
            icon: Icons.mark_as_unread_rounded,
            title: 'All Messages',
            isSelected: _activeFilter == CasboxFilterOption.all,
            onTap: () {
              setState(() {
                _activeFilter = CasboxFilterOption.all;
                _showFilterMenu = false;
              });
            },
            isDark: isDark,
          ),
          _buildFilterMenuItem(
            icon: Icons.arrow_downward_rounded,
            title: 'Received Only',
            isSelected: _activeFilter == CasboxFilterOption.receivedOnly,
            onTap: () {
              setState(() {
                _activeFilter = CasboxFilterOption.receivedOnly;
                _showFilterMenu = false;
              });
            },
            isDark: isDark,
          ),
          _buildFilterMenuItem(
            icon: Icons.arrow_upward_rounded,
            title: 'Sent Only',
            isSelected: _activeFilter == CasboxFilterOption.sentOnly,
            onTap: () {
              setState(() {
                _activeFilter = CasboxFilterOption.sentOnly;
                _showFilterMenu = false;
              });
            },
            isDark: isDark,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Divider(
              height: 1,
              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
            ),
          ),
          _buildFilterMenuItem(
            icon: Icons.calendar_today_outlined,
            title: 'Last 1 Day',
            isSelected: _activeFilter == CasboxFilterOption.last1Day,
            onTap: () {
              setState(() {
                _activeFilter = CasboxFilterOption.last1Day;
                _showFilterMenu = false;
              });
            },
            isDark: isDark,
          ),
          _buildFilterMenuItem(
            icon: Icons.calendar_today_outlined,
            title: 'Last 1 Week',
            isSelected: _activeFilter == CasboxFilterOption.last1Week,
            onTap: () {
              setState(() {
                _activeFilter = CasboxFilterOption.last1Week;
                _showFilterMenu = false;
              });
            },
            isDark: isDark,
          ),
          _buildFilterMenuItem(
            icon: Icons.calendar_month_outlined,
            title: 'Last 1 Month',
            isSelected: _activeFilter == CasboxFilterOption.last1Month,
            onTap: () {
              setState(() {
                _activeFilter = CasboxFilterOption.last1Month;
                _showFilterMenu = false;
              });
            },
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterMenuItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : (isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_rounded,
                size: 16,
                color: Color(0xFF2563EB),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionsPopup(bool isDark, [double? screenWidth]) {
    final isNarrow = screenWidth != null && screenWidth < 680;
    final popupWidth = isNarrow
        ? (screenWidth - 24).clamp(280.0, 430.0)
        : 430.0;

    final apiConnections = ref.watch(casboxConnectionsProvider);
    final activeAccount = ref.read(activeAccountProvider);
    final currentUserEmail = activeAccount.email.toLowerCase().trim();
    final currentHandle = currentUserEmail.contains('@')
        ? currentUserEmail.split('@').first.toLowerCase()
        : currentUserEmail;

    final contactsMap = <String, Map<String, dynamic>>{};

    // 1. Load contacts from apiConnections (API 12 GET /api/connections/accepted)
    for (final c in apiConnections) {
      final email =
          (c['email'] ?? c['contactEmail'] ?? c['id'])
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';
      final handle = (email.contains('@') ? email.split('@').first : email).toLowerCase();
      // Never list current user as a contact to themselves!
      if (handle.isNotEmpty && handle != currentHandle) {
        contactsMap[handle] = Map<String, dynamic>.from(c);
      }
    }

    // 2. If apiConnections is empty, fallback to authorized contacts
    if (contactsMap.isEmpty) {
      for (final email in _authorizedContacts) {
        final clean = email.trim().toLowerCase();
        final handle = (clean.contains('@') ? clean.split('@').first : clean).toLowerCase();
        if (handle.isNotEmpty && handle != currentHandle && !contactsMap.containsKey(handle)) {
          contactsMap[handle] = {
            'id': clean,
            'email': clean,
            'contactEmail': clean,
            'name': handle,
            'handle': '@$handle',
            'letter': handle.isNotEmpty ? handle[0].toUpperCase() : 'U',
            'isPhoto': false,
            'status': 'CONNECTED',
          };
        }
      }
    }

    final contacts = contactsMap.values.toList();
    final connectedCount = contacts.where((c) {
      final cEmail =
          (c['email'] ?? c['contactEmail'] ?? c['id'])
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';
      return _contactConnectionStatus.containsKey(cEmail)
          ? _contactConnectionStatus[cEmail]!
          : (c['status']?.toString().toUpperCase() != 'DISCONNECTED');
    }).length;

    return Container(
      width: popupWidth,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: -2,
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 12 : 18,
        vertical: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 16,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connections',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '$connectedCount accepted contacts',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _showConnectionsPopup = false),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white10 : Colors.transparent,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: isDark ? Colors.white60 : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 10),
          // Contact list items
          ...contacts.map((c) {
            final id =
                (c['connectionId'] ?? c['id'] ?? c['email'])?.toString() ?? '';
            final contactEmail = (c['email'] ?? c['contactEmail'] ?? id)
                .toString()
                .trim()
                .toLowerCase();
            final isConnected =
                _contactConnectionStatus.containsKey(contactEmail)
                ? _contactConnectionStatus[contactEmail]!
                : (c['status']?.toString().toUpperCase() != 'DISCONNECTED');
            final avatarUrl = (c['avatarUrl'] ?? c['avatar'])?.toString();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  // Avatar with real photo support & letter fallback
                  AvatarWidget(
                    name: (c['name'] ?? contactEmail).toString(),
                    avatarUrl: avatarUrl,
                    size: 34,
                    fontSize: 13,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                (c['name'] ?? contactEmail).toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          (c['handle'] ?? '@$contactEmail').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Connected pill button
                  GestureDetector(
                    onTap: () async {
                      if (isConnected) return;
                      setState(() {
                        _contactConnectionStatus[contactEmail] = true;
                        if (!_authorizedContacts.contains(contactEmail)) {
                          _authorizedContacts.add(contactEmail);
                        }
                      });
                      await CasboxRepository.updateAuthorizedContacts(
                        _authorizedContacts,
                      );
                      await ref
                          .read(casboxConnectionsProvider.notifier)
                          .updateConnectionStatus(
                            c['connectionId'] ?? c['id'] ?? contactEmail,
                            'CONNECTED',
                          );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isNarrow ? 5 : 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: isConnected
                            ? (isDark
                                  ? const Color(0xFF064E3B)
                                  : const Color(0xFFF0FDF4))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isConnected
                              ? const Color(0xFF86EFAC)
                              : (isDark
                                    ? Colors.white12
                                    : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isConnected) ...[
                            const Icon(
                              Icons.check,
                              size: 11,
                              color: Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            'Connected',
                            style: TextStyle(
                              fontSize: isNarrow ? 9.5 : 11,
                              fontWeight: isConnected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isConnected
                                  ? const Color(0xFF16A34A)
                                  : (isDark
                                        ? Colors.white38
                                        : Colors.grey.shade500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Disconnected button
                  GestureDetector(
                    onTap: () async {
                      if (!isConnected) return;
                      setState(() {
                        _contactConnectionStatus[contactEmail] = false;
                        _authorizedContacts.remove(contactEmail);
                      });
                      await CasboxRepository.updateAuthorizedContacts(
                        _authorizedContacts,
                      );
                      await ref
                          .read(casboxConnectionsProvider.notifier)
                          .updateConnectionStatus(
                            c['connectionId'] ?? c['id'] ?? contactEmail,
                            'DISCONNECTED',
                          );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isNarrow ? 5 : 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: !isConnected
                            ? (isDark
                                  ? Colors.white10
                                  : const Color(0xFFF1F5F9))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: !isConnected
                              ? const Color(0xFFCBD5E1)
                              : (isDark
                                    ? Colors.white12
                                    : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Text(
                        isNarrow ? 'Disconnect' : 'Disconnected',
                        style: TextStyle(
                          fontSize: isNarrow ? 9.5 : 11,
                          fontWeight: !isConnected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: !isConnected
                              ? (isDark
                                    ? Colors.white
                                    : const Color(0xFF334155))
                              : (isDark
                                    ? Colors.white38
                                    : Colors.grey.shade500),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showBlockedUsersDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (dialogCtx, ref, _) {
            final blockedList = ref.watch(casboxBlockedContactsProvider);
            final combined = {...blockedList, ..._blockedUsers}.toList();
            return Dialog(
              backgroundColor: isDark ? BNXColors.darkSurface : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              elevation: 20,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header: Red block circle + Title + Close icon
                      Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFEF4444),
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.block,
                              size: 15,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Blocked Users',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: isDark
                                  ? Colors.white60
                                  : const Color(0xFF64748B),
                            ),
                            onPressed: () => Navigator.pop(dialogCtx),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (combined.isEmpty) ...[
                        Text(
                          'No blocked users',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        ListView.separated(
                          shrinkWrap: true,
                          itemCount: combined.length,
                          separatorBuilder: (c, i) =>
                              const SizedBox(height: 16),
                          itemBuilder: (c, i) {
                            final u = combined[i];
                            return Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    u,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: () async {
                                    setState(() => _blockedUsers.remove(u));
                                    await ref
                                        .read(
                                          casboxBlockedContactsProvider
                                              .notifier,
                                        )
                                        .unblockContact(u);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark
                                        ? Colors.white70
                                        : const Color(0xFF334155),
                                    side: BorderSide(
                                      color: isDark
                                          ? Colors.white24
                                          : const Color(0xFFCBD5E1),
                                      width: 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Unblock',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDesktopSegment(
    String label,
    bool isSelected,
    VoidCallback onTap,
    bool isDark, {
    bool isCompact = false,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10 : 16,
            vertical: isCompact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF334155) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    width: 0.6,
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 12 : 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? const Color(0xFF195BAC)
                  : (isDark ? Colors.white70 : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageRowPopupMenu({
    required CasboxMessage msg,
    required bool isDark,
    required String contactEmail,
    required String displayName,
  }) {
    final rawHandle = contactEmail.contains('@')
        ? contactEmail.split('@').first
        : contactEmail;
    final isArchivedMsg = msg.isArchived;

    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        size: 16,
        color: isDark ? Colors.white38 : Colors.grey.shade400,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      onSelected: (val) async {
        if (val == 'copy') {
          await Clipboard.setData(ClipboardData(text: msg.body));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Message copied to clipboard')),
            );
          }
        } else if (val == 'edit_name') {
          _showEditContactNameDialog(rawHandle, displayName);
        } else if (val == 'star' || val == 'unstar') {
          final wasStarred = msg.isStarred;
          await ref.read(casboxMessagesProvider.notifier).toggleStar(msg.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  wasStarred ? 'Removed from starred' : 'Added to starred',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else if (val == 'archive') {
          await ref
              .read(casboxMessagesProvider.notifier)
              .archiveMessage(msg.id, true);
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Message archived')));
          }
        } else if (val == 'unarchive') {
          await ref
              .read(casboxMessagesProvider.notifier)
              .archiveMessage(msg.id, false);
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Message unarchived')));
          }
        } else if (val == 'delete') {
          ref.read(casboxMessagesProvider.notifier).deleteMessage(msg.id);
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Message deleted')));
          }
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(
                Icons.copy_rounded,
                size: 16,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
              const SizedBox(width: 10),
              const Text('Copy Text', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'edit_name',
          child: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                size: 16,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
              const SizedBox(width: 10),
              const Text('Edit Name', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: msg.isStarred ? 'unstar' : 'star',
          child: Row(
            children: [
              Icon(
                msg.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                size: 16,
                color: msg.isStarred
                    ? const Color(0xFFF59E0B)
                    : (isDark ? Colors.white70 : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 10),
              Text(
                msg.isStarred ? 'Unstar' : 'Star',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: isArchivedMsg ? 'unarchive' : 'archive',
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isArchivedMsg
                  ? (isDark
                        ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                        : const Color(0xFFEFF6FF))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isArchivedMsg
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  size: 16,
                  color: isArchivedMsg
                      ? const Color(0xFF195BAC)
                      : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 10),
                Text(
                  isArchivedMsg ? 'Unarchive' : 'Archive',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isArchivedMsg
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isArchivedMsg
                        ? const Color(0xFF195BAC)
                        : (isDark ? Colors.white : const Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: const [
              Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
              SizedBox(width: 10),
              Text('Delete', style: TextStyle(fontSize: 13, color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopMessageList(
    bool isDark,
    List<CasboxMessage> messages, {
    required bool isSplit,
  }) {
    if (_isLoading) {
      return _buildLoadingIndicator(isDark);
    }
    if (messages.isEmpty) {
      if (_activeTab == 'Requests') {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.rotate(
                angle: -0.25,
                child: const Icon(
                  Icons.near_me_outlined,
                  size: 48,
                  color: Color(0xFFCBD5E1),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'No message requests',
                style: TextStyle(
                  color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _activeTab == 'Starred' || _activeTab == 'Star'
                  ? Icons.star_border_rounded
                  : (_activeTab == 'Combine' || _activeTab == 'Combined Chat'
                      ? Icons.mark_email_read_outlined
                      : (_activeTab == 'Archive' || _activeTab == 'Archived'
                            ? Icons.archive_outlined
                            : Icons.mail_outline_rounded)),
              size: 40,
              color: (_activeTab == 'Starred' || _activeTab == 'Star')
                  ? const Color(0xFFF59E0B)
                  : (isDark ? Colors.white24 : Colors.grey.shade300),
            ),
            const SizedBox(height: 12),
            Text(
              _activeTab == 'Starred' || _activeTab == 'Star'
                  ? 'No starred messages'
                  : (_activeTab == 'Combine' || _activeTab == 'Combined Chat'
                      ? 'No incoming messages in Combine'
                      : (_activeTab == 'Archive' || _activeTab == 'Archived'
                            ? 'No archived messages'
                            : 'No messages in Casbox')),
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    final activeAccount = ref.read(activeAccountProvider);
    final currentUserEmail = activeAccount.email.toLowerCase().trim();
    final mailboxEmails = ref.read(emailProvider).emails;
    final aliases = ref.watch(casboxAliasesProvider);

    bool isSentByMe(CasboxMessage m) =>
        _checkIsSentByMe(m, currentUserEmail, mailboxEmails);

    String getContactEmail(CasboxMessage m) {
      final target = isSentByMe(m) ? m.to : m.sender;
      return target.trim();
    }

    final sortedMessages = List<CasboxMessage>.from(messages)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 680;
    final isCombineTab =
        _activeTab == 'Combine' || _activeTab == 'Combined Chat';

    return ListView.separated(
      itemCount: sortedMessages.length,
      padding: const EdgeInsets.symmetric(vertical: 2),
      separatorBuilder: (context, idx) => Divider(
        height: 1,
        thickness: 0.6,
        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
      ),
      itemBuilder: (context, idx) {
        final msg = sortedMessages[idx];
        final sentByMe = isSentByMe(msg);
        final isSelected = _selectedDesktopMessage?.id == msg.id;
        final isChecked = _selectedIds.contains(msg.id);
        final contactEmail = getContactEmail(msg);
        final rawHandle = contactEmail.contains('@')
            ? contactEmail.split('@').first
            : (contactEmail.isNotEmpty ? contactEmail : 'Unknown');
        final contactName = aliases[rawHandle] ??
            aliases[contactEmail] ??
            (msg.contactDisplayName != null &&
                    msg.contactDisplayName!.trim().isNotEmpty
                ? msg.contactDisplayName!.trim()
                : (msg.contactUsername != null &&
                        msg.contactUsername!.trim().isNotEmpty
                    ? msg.contactUsername!.trim()
                    : rawHandle));

        final (avatarBg, avatarFg) = _getAvatarColors(contactName, isDark);
        final avatarLetter = contactName.isNotEmpty
            ? contactName[0].toUpperCase()
            : 'C';

        final int hour = msg.timestamp.toLocal().hour;
        final int hour12 = hour % 12 == 0 ? 12 : hour % 12;
        final String ampm = hour >= 12 ? 'PM' : 'AM';
        final timeStr =
            '$hour12:${msg.timestamp.toLocal().minute.toString().padLeft(2, '0')} $ampm';

        final cleanBody = msg.body.replaceAll('\n', ' ').trim();

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: InkWell(
            onTap: () => _openCasboxThreadPage(context, msg, isDark),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 16,
                vertical: isMobile ? 8 : 10,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFEFF6FF))
                    : (isChecked
                          ? (isDark
                                ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                                : const Color(0xFFF8FAFC))
                          : Colors.transparent),
              ),
              child: isMobile
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (!isCombineTab) ...[
                          Transform.scale(
                            scale: 0.85,
                            child: Checkbox(
                              value: isChecked,
                              activeColor: const Color(0xFF2563EB),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white24
                                    : const Color(0xFFCBD5E1),
                                width: 1.2,
                              ),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedIds.add(msg.id);
                                  } else {
                                    _selectedIds.remove(msg.id);
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: avatarBg,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            avatarLetter,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: avatarFg,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      contactName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: sentByMe
                                          ? (isDark
                                                ? const Color(0xFF064E3B)
                                                : const Color(0xFFDCFCE7))
                                          : (isDark
                                                ? const Color(0xFF1E3A5F)
                                                : const Color(0xFFDBEAFE)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      sentByMe ? 'Sent' : 'Received',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: sentByMe
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                  if (sentByMe) ...[
                                    const SizedBox(width: 4),
                                    _buildStatusTick(msg, isDark),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              if (isCombineTab) ...[
                                Text(
                                  cleanBody.isNotEmpty ? cleanBody : 'No text',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xFF334155),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ] else ...[
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: msg.subject.isNotEmpty
                                            ? msg.subject
                                            : 'No Subject',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xFF1E293B),
                                        ),
                                      ),
                                      if (cleanBody.isNotEmpty) ...[
                                        TextSpan(
                                          text: ' — ',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white38
                                                : Colors.grey.shade400,
                                            fontSize: 12,
                                          ),
                                        ),
                                        TextSpan(
                                          text: cleanBody,
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Tooltip(
                          message: msg.isStarred ? 'Unstar' : 'Star',
                          child: InkWell(
                            onTap: () async {
                              final wasStarred = msg.isStarred;
                              await ref
                                  .read(casboxMessagesProvider.notifier)
                                  .toggleStar(msg.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      wasStarred
                                          ? 'Removed from starred'
                                          : 'Added to starred',
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: Icon(
                                msg.isStarred
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 16,
                                color: msg.isStarred
                                    ? const Color(0xFFF59E0B)
                                    : (isDark
                                        ? Colors.white38
                                        : const Color(0xFF94A3B8)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        _buildMessageRowPopupMenu(
                          msg: msg,
                          isDark: isDark,
                          contactEmail: contactEmail,
                          displayName: contactName,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        if (!isCombineTab) ...[
                          Transform.scale(
                            scale: 0.9,
                            child: Checkbox(
                              value: isChecked,
                              activeColor: const Color(0xFF2563EB),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white24
                                    : const Color(0xFFCBD5E1),
                                width: 1.2,
                              ),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedIds.add(msg.id);
                                  } else {
                                    _selectedIds.remove(msg.id);
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: avatarBg,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            avatarLetter,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: avatarFg,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 130,
                          child: Text(
                            contactName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: sentByMe
                                ? (isDark
                                      ? const Color(0xFF064E3B)
                                      : const Color(0xFFDCFCE7))
                                : (isDark
                                      ? const Color(0xFF1E3A5F)
                                      : const Color(0xFFDBEAFE)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            sentByMe ? 'Sent' : 'Received',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: sentByMe
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        if (isCombineTab) ...[
                          Text(
                            '|',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w300,
                              color: isDark
                                  ? Colors.white24
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              cleanBody.isNotEmpty ? cleanBody : 'No text',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: msg.subject.isNotEmpty
                                        ? msg.subject
                                        : 'No Subject',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (cleanBody.isNotEmpty) ...[
                                    TextSpan(
                                      text: ' — ',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.grey.shade400,
                                        fontSize: 13,
                                      ),
                                    ),
                                    TextSpan(
                                      text: cleanBody,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        const SizedBox(width: 16),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade500,
                          ),
                        ),
                        if (sentByMe) ...[
                          const SizedBox(width: 8),
                          _buildStatusTick(msg, isDark),
                        ],
                        const SizedBox(width: 10),
                        Tooltip(
                          message: msg.isStarred ? 'Unstar' : 'Star',
                          child: InkWell(
                            onTap: () async {
                              final wasStarred = msg.isStarred;
                              await ref
                                  .read(casboxMessagesProvider.notifier)
                                  .toggleStar(msg.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      wasStarred
                                          ? 'Removed from starred'
                                          : 'Added to starred',
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: Icon(
                                msg.isStarred
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 16,
                                color: msg.isStarred
                                    ? const Color(0xFFF59E0B)
                                    : (isDark
                                        ? Colors.white38
                                        : const Color(0xFF94A3B8)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        _buildMessageRowPopupMenu(
                          msg: msg,
                          isDark: isDark,
                          contactEmail: contactEmail,
                          displayName: contactName,
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusTick(CasboxMessage msg, bool isDark) {
    final status = msg.status.toUpperCase();
    if (msg.isRead ||
        status == 'SEEN' ||
        status == 'READ' ||
        status == 'ACCEPTED') {
      return const Icon(
        Icons.done_all_rounded,
        size: 16,
        color: Color(0xFF3B82F6), // blue double checkmark
      );
    } else if (status == 'DELIVERED') {
      return Icon(
        Icons.done_all_rounded,
        size: 16,
        color: isDark
            ? Colors.white38
            : Colors.grey.shade400, // grey double checkmark
      );
    } else {
      return Icon(
        Icons.check_rounded,
        size: 16,
        color: isDark
            ? Colors.white38
            : Colors.grey.shade400, // single grey checkmark
      );
    }
  }

  Widget _buildDesktopChatConversationView(
    bool isDark,
    CasboxMessage selectedMsg,
    List<CasboxMessage> allMessages,
    AccountModel activeAccount,
  ) {
    final currentUserEmail = activeAccount.email.toLowerCase().trim();
    final mailboxEmails = ref.read(emailProvider).emails;
    bool isSentByMe(CasboxMessage m) =>
        _checkIsSentByMe(m, currentUserEmail, mailboxEmails);

    final sentByMe = isSentByMe(selectedMsg);
    final otherEmail = sentByMe ? selectedMsg.to : selectedMsg.sender;
    final otherName = otherEmail.contains('@')
        ? otherEmail.split('@').first
        : (otherEmail.isNotEmpty ? otherEmail : 'Contact');

    final senderEmail = sentByMe
        ? (currentUserEmail.isNotEmpty ? currentUserEmail : selectedMsg.sender)
        : otherEmail;
    final senderName = sentByMe
        ? (currentUserEmail.contains('@')
              ? currentUserEmail.split('@').first
              : (currentUserEmail.isNotEmpty ? currentUserEmail : 'Me'))
        : otherName;
    final receiverEmail = sentByMe
        ? otherEmail
        : (currentUserEmail.isNotEmpty ? currentUserEmail : selectedMsg.to);

    final (avatarBg, avatarFg) = _getAvatarColors(senderName, isDark);
    final avatarLetter = senderName.isNotEmpty
        ? senderName[0].toUpperCase()
        : 'C';

    final contactHandle = otherEmail.contains('@')
        ? otherEmail.split('@').first.toLowerCase().trim()
        : otherEmail.toLowerCase().trim();

    final threadMessages = allMessages.where((m) {
      final mOther = (isSentByMe(m) ? m.to : m.sender).toLowerCase().trim();
      final mHandle = mOther.contains('@')
          ? mOther.split('@').first.toLowerCase().trim()
          : mOther;
      return mOther == otherEmail.toLowerCase().trim() ||
          mHandle == contactHandle;
    }).toList();

    threadMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 680;

    final isPendingRequest =
        (_activeTab == 'Requests' ||
            selectedMsg.status.toUpperCase() == 'PENDING' ||
            selectedMsg.status.toUpperCase() == 'REQUEST') &&
        !sentByMe;

    final isArchivedMsg = selectedMsg.isArchived;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Top Navigation Bar matching Image 3 (← Back, Archive, Delete)
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 24,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isDark ? BNXColors.darkSurface : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () {
                  setState(() => _selectedDesktopMessage = null);
                  ref.read(selectedCasboxThreadProvider.notifier).state = null;
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  selectedMsg.isStarred
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 20,
                  color: selectedMsg.isStarred
                      ? const Color(0xFFF59E0B)
                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
                tooltip: selectedMsg.isStarred ? 'Unstar' : 'Star',
                onPressed: () async {
                  final wasStarred = selectedMsg.isStarred;
                  await ref
                      .read(casboxMessagesProvider.notifier)
                      .toggleStar(selectedMsg.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          wasStarred
                              ? 'Conversation unstarred'
                              : 'Conversation starred',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              IconButton(
                icon: Icon(
                  isArchivedMsg
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  size: 20,
                  color: isArchivedMsg
                      ? const Color(0xFF195BAC)
                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
                tooltip: isArchivedMsg ? 'Unarchive' : 'Archive',
                onPressed: () async {
                  final newArchiveState = !isArchivedMsg;
                  final subjectMatches = threadMessages
                      .where((m) =>
                          selectedMsg.subject.trim().isEmpty ||
                          m.subject.trim().toLowerCase() ==
                              selectedMsg.subject.trim().toLowerCase())
                      .map((m) => m.id)
                      .toList();
                  final threadIds = subjectMatches.isNotEmpty
                      ? subjectMatches
                      : [selectedMsg.id];
                  setState(() {
                    _selectedDesktopMessage = null;
                  });
                  ref.read(selectedCasboxThreadProvider.notifier).state = null;
                  await ref
                      .read(casboxMessagesProvider.notifier)
                      .batchArchiveMessages(threadIds, newArchiveState);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          newArchiveState
                              ? 'Archived conversation.'
                              : 'Unarchived conversation.',
                        ),
                      ),
                    );
                  }
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
                tooltip: 'Delete',
                onPressed: () {
                  ref
                      .read(casboxMessagesProvider.notifier)
                      .deleteMessage(selectedMsg.id);
                  setState(() => _selectedDesktopMessage = null);
                  ref.read(selectedCasboxThreadProvider.notifier).state = null;
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),

        // Incoming Request Banner if pending
        if (isPendingRequest)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 24,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : const Color(0xFFBFDBFE),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$otherName wants to connect with you.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF1E3A5F),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref
                        .read(casboxMessagesProvider.notifier)
                        .deleteMessage(selectedMsg.id);
                    setState(() => _selectedDesktopMessage = null);
                    ref.read(selectedCasboxThreadProvider.notifier).state =
                        null;
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Reject',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    ref
                        .read(casboxMessagesProvider.notifier)
                        .acceptRequest(selectedMsg.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Request accepted!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF195BAC),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

        // 2. Scrollable conversation content
        Expanded(
          child: SingleChildScrollView(
            controller: _desktopChatScrollController,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 28,
              vertical: isMobile ? 12 : 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bold Subject Title matching Image 3
                Text(
                  selectedMsg.subject.isNotEmpty
                      ? selectedMsg.subject
                      : 'No Subject',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 26,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Message Card Container matching Image 3
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.2 : 0.03,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card Header: Avatar + Sender + Receiver + Date
                      Padding(
                        padding: EdgeInsets.all(isMobile ? 12 : 18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: avatarBg,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                avatarLetter,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: avatarFg,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isMobile) ...[
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            senderName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: isDark
                                                  ? Colors.white
                                                  : const Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatDetailDate(
                                            selectedMsg.timestamp,
                                          ),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? Colors.white38
                                                : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '<${senderEmail.contains('@') ? senderEmail : "$senderEmail@bnxmail.com"}>',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.white54
                                            : const Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ] else ...[
                                    Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          senderName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '<${senderEmail.contains('@') ? senderEmail : "$senderEmail@bnxmail.com"}>',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: isDark
                                                ? Colors.white54
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 3),
                                  Text(
                                    'To: ${receiverEmail.contains('@') ? receiverEmail : "$receiverEmail@bnxmail.com"}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white38
                                          : const Color(0xFF94A3B8),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (!isMobile) ...[
                              const SizedBox(width: 8),
                              Text(
                                _formatDetailDate(selectedMsg.timestamp),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark
                                      ? Colors.white38
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFF1F5F9),
                      ),
                      // Card Body: Message Text
                      Padding(
                        padding: EdgeInsets.all(isMobile ? 14 : 22),
                        child: Text(
                          selectedMsg.body,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Reply & Forward Pill Buttons matching Image 3
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        // Focus on bottom reply field
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? Colors.white12
                                : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.reply_rounded,
                              size: 16,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF334155),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Reply',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? Colors.white12
                                : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.forward_rounded,
                              size: 16,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF334155),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Forward',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155),
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
        ),

        // 3. Bottom Chat Input Bar with "Type a message..."
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 20,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isDark ? BNXColors.darkSurface : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.sentiment_satisfied_alt_outlined,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                    size: 22,
                  ),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? Colors.white12
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _desktopChatInputController,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          fontSize: 13.5,
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 11,
                        ),
                      ),
                      onSubmitted: (val) => _sendDesktopCasboxMessage(
                        otherEmail,
                        selectedMsg.subject,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _sendDesktopCasboxMessage(
                    otherEmail,
                    selectedMsg.subject,
                  ),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF3B82F6),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCombineChatConversationView(
    bool isDark,
    CasboxMessage selectedMsg,
    List<CasboxMessage> allMessages,
    AccountModel activeAccount,
  ) {
    final currentUserEmail = activeAccount.email.toLowerCase().trim();
    final mailboxEmails = ref.read(emailProvider).emails;
    bool isSentByMe(CasboxMessage m) =>
        _checkIsSentByMe(m, currentUserEmail, mailboxEmails);

    final sentByMe = isSentByMe(selectedMsg);
    final otherEmail = (sentByMe ? selectedMsg.to : selectedMsg.sender).trim();
    final otherHandle = otherEmail.contains('@')
        ? otherEmail.split('@').first
        : (otherEmail.isNotEmpty ? otherEmail : 'Contact');
    final myHandle = currentUserEmail.contains('@')
        ? currentUserEmail.split('@').first
        : (currentUserEmail.isNotEmpty ? currentUserEmail : 'Me');

    final fullOtherEmail = otherEmail;

    final aliases = ref.watch(casboxAliasesProvider);
    final displayName =
        aliases[otherHandle] ??
        aliases[otherEmail] ??
        aliases[fullOtherEmail] ??
        otherHandle;

    final (avatarBg, avatarFg) = _getAvatarColors(displayName, isDark);
    final avatarLetter = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : 'C';

    final blockedContacts = ref.watch(casboxBlockedContactsProvider);
    final isBlocked =
        blockedContacts.contains(otherHandle.toLowerCase()) ||
        blockedContacts.contains(otherEmail.toLowerCase()) ||
        blockedContacts.contains(fullOtherEmail.toLowerCase()) ||
        _blockedUsers.contains(otherHandle) ||
        _blockedUsers.contains(otherEmail);

    final contactHandle = otherEmail.contains('@')
        ? otherEmail.split('@').first.toLowerCase().trim()
        : otherEmail.toLowerCase().trim();

    final threadMessages = allMessages.where((m) {
      final mOther = (isSentByMe(m) ? m.to : m.sender).toLowerCase().trim();
      final mHandle = mOther.contains('@')
          ? mOther.split('@').first.toLowerCase().trim()
          : mOther;
      return mOther == otherEmail.toLowerCase().trim() ||
          mHandle == contactHandle;
    }).toList();

    threadMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 680;

    return Column(
      children: [
        // Top Header matching Image 4
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isDark ? BNXColors.darkSurface : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                onPressed: () {
                  setState(() => _selectedDesktopMessage = null);
                  ref.read(selectedCasboxThreadProvider.notifier).state = null;
                },
                tooltip: 'Back',
              ),
              const SizedBox(width: 4),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatarBg,
                ),
                alignment: Alignment.center,
                child: Text(
                  avatarLetter,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: avatarFg,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fullOtherEmail,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  selectedMsg.isStarred
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 20,
                  color: selectedMsg.isStarred
                      ? const Color(0xFFF59E0B)
                      : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                ),
                tooltip: selectedMsg.isStarred ? 'Unstar' : 'Star',
                onPressed: () async {
                  final wasStarred = selectedMsg.isStarred;
                  await ref
                      .read(casboxMessagesProvider.notifier)
                      .toggleStar(selectedMsg.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          wasStarred
                              ? 'Conversation unstarred'
                              : 'Conversation starred',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              IconButton(
                icon: Icon(
                  selectedMsg.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  size: 20,
                  color: selectedMsg.isArchived
                      ? const Color(0xFF195BAC)
                      : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                ),
                tooltip: selectedMsg.isArchived ? 'Unarchive' : 'Archive',
                onPressed: () async {
                  final newArchiveState = !selectedMsg.isArchived;
                  final subjectMatches = threadMessages
                      .where((m) =>
                          selectedMsg.subject.trim().isEmpty ||
                          m.subject.trim().toLowerCase() ==
                              selectedMsg.subject.trim().toLowerCase())
                      .map((m) => m.id)
                      .toList();
                  final threadIds = subjectMatches.isNotEmpty
                      ? subjectMatches
                      : [selectedMsg.id];
                  setState(() => _selectedDesktopMessage = null);
                  ref.read(selectedCasboxThreadProvider.notifier).state = null;
                  await ref
                      .read(casboxMessagesProvider.notifier)
                      .batchArchiveMessages(threadIds, newArchiveState);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(newArchiveState
                            ? 'Archived conversation.'
                            : 'Unarchived conversation.'),
                      ),
                    );
                  }
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
                tooltip: 'Delete conversation',
                onPressed: () async {
                  await ref
                      .read(casboxMessagesProvider.notifier)
                      .deleteConversation(otherEmail);
                  if (mounted) {
                    setState(() => _selectedDesktopMessage = null);
                    ref.read(selectedCasboxThreadProvider.notifier).state =
                        null;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Conversation deleted')),
                    );
                  }
                },
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
                onSelected: (val) async {
                  if (val == 'edit_name') {
                    _showEditContactNameDialog(otherHandle, displayName);
                  } else if (val == 'block') {
                    await ref
                        .read(casboxBlockedContactsProvider.notifier)
                        .blockContact(otherHandle);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Blocked $otherHandle')),
                      );
                    }
                  } else if (val == 'unblock') {
                    await ref
                        .read(casboxBlockedContactsProvider.notifier)
                        .unblockContact(otherHandle);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Unblocked $otherHandle')),
                      );
                    }
                  } else if (val == 'delete_conversation') {
                    await ref
                        .read(casboxMessagesProvider.notifier)
                        .deleteConversation(otherEmail);
                    if (mounted) {
                      setState(() => _selectedDesktopMessage = null);
                      ref.read(selectedCasboxThreadProvider.notifier).state =
                          null;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Conversation deleted')),
                      );
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'edit_name',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Edit Contact Name',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: isBlocked ? 'unblock' : 'block',
                    child: Row(
                      children: [
                        Icon(
                          Icons.block_outlined,
                          size: 16,
                          color: Colors.red.shade600,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isBlocked ? 'Unblock User' : 'Block User',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete_conversation',
                    child: Row(
                      children: const [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: Colors.red,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Delete Conversation',
                          style: TextStyle(fontSize: 13, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Chat Message Area matching Image 4
        Expanded(
          child: SingleChildScrollView(
            controller: _desktopChatScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date separator pill centered
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      threadMessages.isNotEmpty
                          ? _formatDatePill(threadMessages.first.timestamp)
                          : _formatDatePill(DateTime.now()),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.white60
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),

                // Bubbles stream
                ...threadMessages.map((m) {
                  final byMe = isSentByMe(m);
                  final senderDisplay = byMe ? myHandle : displayName;
                  final (tagBg, tagFg) = _getAvatarColors(
                    senderDisplay,
                    isDark,
                  );
                  final tagLetter = senderDisplay.isNotEmpty
                      ? senderDisplay[0].toUpperCase()
                      : (byMe ? 'R' : 'C');

                  final int hour = m.timestamp.toLocal().hour;
                  final int hour12 = hour % 12 == 0 ? 12 : hour % 12;
                  final String ampm = hour >= 12 ? 'PM' : 'AM';
                  final timeStr =
                      '$hour12:${m.timestamp.toLocal().minute.toString().padLeft(2, '0')} $ampm';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Sender pill badge on the left matching Image 4
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white12
                                      : const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: isDark ? 0.2 : 0.04,
                                    ),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: tagBg,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      tagLetter,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: tagFg,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    senderDisplay,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF22C55E),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Speech bubble
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: byMe
                                      ? const Color(0xFF195BAC)
                                      : (isDark
                                            ? const Color(0xFF1E293B)
                                            : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: byMe
                                        ? const Color(0xFF195BAC)
                                        : (isDark
                                              ? Colors.white10
                                              : const Color(0xFFE2E8F0)),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: isDark ? 0.2 : 0.03,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  m.body,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.4,
                                    color: byMe
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.white
                                              : const Color(0xFF0F172A)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Timestamp below bubble
                        Padding(
                          padding: const EdgeInsets.only(left: 140, top: 4),
                          child: Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark
                                  ? Colors.white38
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // Bottom Bar matching Image 4
        if (isBlocked)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF7F1D1D)
                    : const Color(0xFFFECDD3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.block_rounded,
                  size: 18,
                  color: isDark
                      ? const Color(0xFFF87171)
                      : const Color(0xFFE11D48),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You have blocked this user. Unblock to send messages.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFFFECDD3)
                          : const Color(0xFF9F1239),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    await ref
                        .read(casboxBlockedContactsProvider.notifier)
                        .unblockContact(otherHandle);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Unblocked $otherHandle')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Unblock',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 20,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isDark ? BNXColors.darkSurface : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white12
                              : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _desktopChatInputController,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(
                            fontSize: 13.5,
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade400,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 11,
                          ),
                        ),
                        onSubmitted: (val) =>
                            _sendDesktopCasboxMessage(otherEmail, ''),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _sendDesktopCasboxMessage(otherEmail, ''),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFF195BAC),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _sendDesktopCasboxMessage(String to, String subject) async {
    final text = _desktopChatInputController.text.trim();
    if (text.isEmpty) return;
    _desktopChatInputController.clear();
    await ref
        .read(casboxMessagesProvider.notifier)
        .addMessage(
          to: to,
          subject: subject.isNotEmpty ? subject : 'Discussion',
          body: text,
        );
    if (to.isNotEmpty) {
      await ref.read(casboxMessagesProvider.notifier).fetchThreadMessages(to);
    }
    _scrollToBottom();
  }

  void _openCasboxThreadPage(
    BuildContext context,
    CasboxMessage initialMsg,
    bool isDark,
  ) {
    if (!initialMsg.isRead) {
      ref.read(casboxMessagesProvider.notifier).markAsRead(initialMsg.id);
    }
    setState(() {
      _selectedDesktopMessage = initialMsg;
    });
    ref.read(selectedCasboxThreadProvider.notifier).state = initialMsg.id;
    final activeAccount = ref.read(activeAccountProvider);
    final currentUserEmail = activeAccount.email.toLowerCase().trim();
    final mailboxEmails = ref.read(emailProvider).emails;
    final isSent = _checkIsSentByMe(
      initialMsg,
      currentUserEmail,
      mailboxEmails,
    );
    final other = (isSent ? initialMsg.to : initialMsg.sender).trim();
    if (other.isNotEmpty) {
      ref.read(casboxMessagesProvider.notifier).fetchThreadMessages(other);
      ref.read(casboxMessagesProvider.notifier).markThreadAsSeen(other);
    }
    _scrollToBottom();
  }
}

class CommentsSection extends StatefulWidget {
  final ColabGroup group;
  final bool isDark;
  final WidgetRef ref;

  const CommentsSection({
    super.key,
    required this.group,
    required this.isDark,
    required this.ref,
  });

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AttachmentModel> _pendingAttachments = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only fetch if messages haven't been loaded yet for this group
      if (!messagesLoadedIds.contains(widget.group.id)) {
        widget.ref
            .read(colabListProvider.notifier)
            .fetchMessagesForGroup(widget.group.id);
      }
      _scrollToBottom();
    });
  }

  @override
  void didUpdateWidget(covariant CommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.id != widget.group.id) {
      widget.ref
          .read(colabListProvider.notifier)
          .fetchMessagesForGroup(widget.group.id);
    }
    if (oldWidget.group.comments.length < widget.group.comments.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isImageAttachment(AttachmentModel att) {
    final ext = att.fileName.split('.').last.toLowerCase();
    final type = att.fileType.toLowerCase();
    final path = att.filePath?.toLowerCase() ?? '';
    return ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'svg'].contains(ext) ||
        ['image', 'png', 'jpg', 'jpeg', 'gif', 'webp'].contains(type) ||
        path.startsWith('data:image/');
  }

  String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final monthStr = months[dt.month - 1];
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    if (isToday) {
      return 'Today, $hour:$min $period';
    }
    return '$monthStr ${dt.day}, $hour:$min $period';
  }

  String _formatTimeOnly(DateTime dt) {
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          Uint8List? bytes = file.bytes;
          if (bytes == null && file.path != null && file.path!.isNotEmpty) {
            try {
              final f = File(file.path!);
              if (await f.exists()) {
                bytes = await f.readAsBytes();
              }
            } catch (_) {}
          }

          String? pathOrDataUri = file.path;
          final ext = file.extension?.toLowerCase() ?? '';
          final isImg = [
            'png',
            'jpg',
            'jpeg',
            'gif',
            'webp',
            'bmp',
            'svg',
          ].contains(ext);

          if (bytes != null && bytes.isNotEmpty) {
            if (isImg) {
              final mime = ext == 'jpg' ? 'jpeg' : ext;
              pathOrDataUri = 'data:image/$mime;base64,${base64Encode(bytes)}';
            } else if (bytes.length < 3 * 1024 * 1024) {
              pathOrDataUri =
                  'data:application/octet-stream;base64,${base64Encode(bytes)}';
            }
          }

          _pendingAttachments.add(
            AttachmentModel(
              fileName: file.name,
              fileType: file.extension?.toUpperCase() ?? 'FILE',
              fileSize: file.size > 1024 * 1024
                  ? '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB'
                  : '${(file.size / 1024).toStringAsFixed(0)} KB',
              filePath: pathOrDataUri,
            ),
          );
        }
        setState(() {});
      }
    } catch (e) {
      debugPrint('[FILE PICKER ERROR] $e');
    }
  }

  Future<void> _downloadAttachment(
    AttachmentModel att,
  ) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${att.fileName}...'),
        duration: const Duration(seconds: 1),
      ),
    );
    try {
      final savedPath = await AttachmentDownloader.downloadAndSave(att);
      if (!mounted) return;
      if (savedPath != null) {
        final displayName = savedPath.split(Platform.pathSeparator).last;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF195BAC),
            content: Text('File saved to: $displayName'),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to download ${att.fileName}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Download error: $e'),
        ),
      );
    }
  }

  void _openImagePreviewDialog(BuildContext context, AttachmentModel att) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.image_outlined,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          att.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (att.fileSize.isNotEmpty) ...[
                        Text(
                          att.fileSize,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      IconButton(
                        icon: const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: 'Download',
                        onPressed: () => _downloadAttachment(att),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),

                // Interactive zoomable image
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: Center(
                      child: SmartImageWidget(
                        attachment: att,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEmojiPicker(BuildContext context) {
    final emojis = [
      '😀',
      '😃',
      '😄',
      '😁',
      '😆',
      '😅',
      '😂',
      '🤣',
      '😊',
      '😇',
      '🙂',
      '🙃',
      '😉',
      '😌',
      '😍',
      '🥰',
      '😘',
      '😋',
      '😜',
      '🤪',
      '😎',
      '🥳',
      '😏',
      '🤔',
      '🤐',
      '🤨',
      '😐',
      '😑',
      '😶',
      '😏',
      '👍',
      '👎',
      '👏',
      '🙌',
      '👐',
      '🤝',
      '🙏',
      '✌️',
      '🤞',
      '💪',
      '🎉',
      '🔥',
      '✨',
      '💯',
      '❤️',
      '💙',
      '⭐',
      '🚀',
      '💡',
      '📌',
      '✉️',
      '📎',
      '📞',
      '📅',
      '⏳',
      '✅',
      '❌',
      '⚠️',
      '👀',
      '🎯',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? BNXColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            height: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Reactions & Emojis',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: widget.isDark
                            ? Colors.white
                            : BNXColors.lightTextPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                    itemCount: emojis.length,
                    itemBuilder: (context, i) {
                      final em = emojis[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          _commentController.text += em;
                          _commentController.selection =
                              TextSelection.fromPosition(
                                TextPosition(
                                  offset: _commentController.text.length,
                                ),
                              );
                          Navigator.pop(ctx);
                        },
                        child: Center(
                          child: Text(em, style: const TextStyle(fontSize: 24)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentBubbleItem(
    BuildContext context,
    AttachmentModel att,
    bool isMe,
  ) {
    final isImg = _isImageAttachment(att);

    if (isImg) {
      return Container(
        margin: const EdgeInsets.only(top: 6),
        width: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.isDark ? Colors.white24 : Colors.grey[300]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _openImagePreviewDialog(context, att),
                child: SizedBox(
                  height: 140,
                  width: 240,
                  child: SmartImageWidget(
                    attachment: att,
                    height: 140,
                    width: 240,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(color: Color(0xFF1E293B)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            att.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            att.fileSize.isNotEmpty
                                ? att.fileSize
                                : 'Image File',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.visibility_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 26,
                        minHeight: 26,
                      ),
                      tooltip: 'View image',
                      onPressed: () => _openImagePreviewDialog(context, att),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 26,
                        minHeight: 26,
                      ),
                      tooltip: 'Download',
                      onPressed: () => _downloadAttachment(att),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Non-image file card
    return Container(
      margin: const EdgeInsets.only(top: 6),
      width: 240,
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white10 : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isDark ? Colors.white24 : Colors.grey[300]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.attach_file_rounded,
                    size: 26,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    att.fileType.isNotEmpty ? att.fileType : 'FILE',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(9),
                bottomRight: Radius.circular(9),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        att.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        att.fileSize.isNotEmpty ? att.fileSize : 'File',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
                  ),
                  tooltip: 'Download file',
                  onPressed: () => _downloadAttachment(att),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) return;
    _commentController.clear();

    final attachmentsToSend = List<AttachmentModel>.from(_pendingAttachments);
    setState(() {
      _pendingAttachments.clear();
    });

    final active = widget.ref.read(activeAccountProvider);
    final senderEmail = active.email.isNotEmpty
        ? active.email
        : (active.name.isNotEmpty ? active.name : 'user@bnxmail.com');

    try {
      await widget.ref
          .read(colabListProvider.notifier)
          .sendChatMessage(
            widget.group.id,
            senderEmail,
            text,
            attachments: attachmentsToSend,
          );
      _scrollToBottom();
    } catch (e) {
      debugPrint('[COMMENT ERROR] Failed to send message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.ref.read(activeAccountProvider);
    final myEmail = active.email.toLowerCase().trim();
    final myName = active.name.toLowerCase().trim();

    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? BNXColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark ? BNXColors.darkBorder : BNXColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: matching image (chat bubble icon, "Comments", chevron >)
          InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Comments are synced in real-time with all active members.',
                  ),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 14.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Color(0xFF195BAC),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Comments',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: widget.isDark
                              ? Colors.white
                              : BNXColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Comments list
          Expanded(
            child:
                !messagesLoadedIds.contains(widget.group.id) &&
                    widget.group.comments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF195BAC),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Loading messages...',
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.isDark
                                ? BNXColors.darkTextSecondary
                                : BNXColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : widget.group.comments.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 8.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: widget.isDark
                                  ? Colors.white10
                                  : Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 32,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: widget.isDark
                                  ? Colors.white
                                  : BNXColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Be the first to say hello!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.isDark
                                  ? BNXColors.darkTextSecondary
                                  : BNXColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: widget.group.comments.length,
                    itemBuilder: (context, index) {
                      final c = widget.group.comments[index];
                      final s = c.sender.toLowerCase().trim();
                      final isMe =
                          s == 'me' ||
                          (myEmail.isNotEmpty && s == myEmail) ||
                          (myName.isNotEmpty && s == myName);

                      // Determine if we should show date separator above this item
                      bool showDateHeader = false;
                      if (index == 0) {
                        showDateHeader = true;
                      } else {
                        final prev = widget.group.comments[index - 1];
                        if (c.timestamp
                                    .difference(prev.timestamp)
                                    .inMinutes
                                    .abs() >
                                30 ||
                            c.timestamp.day != prev.timestamp.day) {
                          showDateHeader = true;
                        }
                      }

                      final initial = c.sender.isNotEmpty
                          ? c.sender[0].toLowerCase()
                          : '?';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDateHeader)
                            Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                child: Text(
                                  _formatDateHeader(c.timestamp),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: widget.isDark
                                        ? Colors.white54
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14.0),
                            child: Row(
                              mainAxisAlignment: isMe
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMe) ...[
                                  CircleAvatar(
                                    radius: 13,
                                    backgroundColor: const Color(0xFFDBEAFE),
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E40AF),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: isMe
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      // Sender name above bubble
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 4,
                                          right: 4,
                                          bottom: 4,
                                        ),
                                        child: Text(
                                          isMe ? '${c.sender} (Me)' : c.sender,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: widget.isDark
                                                ? Colors.white60
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                      // Message bubble (if text present)
                                      if (c.message.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isMe
                                                ? const Color(0xFF195BAC)
                                                : (widget.isDark
                                                      ? Colors.white12
                                                      : const Color(
                                                          0xFFF1F5F9,
                                                        )),
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(
                                                12,
                                              ),
                                              topRight: const Radius.circular(
                                                12,
                                              ),
                                              bottomLeft: Radius.circular(
                                                isMe ? 12 : 2,
                                              ),
                                              bottomRight: Radius.circular(
                                                isMe ? 2 : 12,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            c.message,
                                            style: TextStyle(
                                              fontSize: 13,
                                              height: 1.35,
                                              color: isMe
                                                  ? Colors.white
                                                  : (widget.isDark
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF1E293B,
                                                          )),
                                            ),
                                          ),
                                        ),

                                      // Attachments (Image cards / File cards)
                                      if (c.attachments.isNotEmpty)
                                        ...c.attachments.map(
                                          (att) => _buildAttachmentBubbleItem(
                                            context,
                                            att,
                                            isMe,
                                          ),
                                        ),

                                      // Timestamp below bubble
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 4,
                                          right: 4,
                                          top: 4,
                                        ),
                                        child: Text(
                                          _formatTimeOnly(c.timestamp),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: widget.isDark
                                                ? Colors.white38
                                                : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          const Divider(height: 1),

          // Pending attachments bar
          if (_pendingAttachments.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: widget.isDark ? Colors.white10 : const Color(0xFFF8FAFC),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _pendingAttachments.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final att = entry.value;
                  final isImg = _isImageAttachment(att);

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.white12 : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.isDark
                            ? Colors.white24
                            : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isImg
                              ? Icons.image_rounded
                              : Icons.attach_file_rounded,
                          size: 16,
                          color: const Color(0xFF195BAC),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Text(
                            att.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: widget.isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _pendingAttachments.removeAt(idx);
                            });
                          },
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          // Bottom Input bar matching Image 2 & 3:
          // Paperclip 📎, Emoji 😊, rounded "Type a message..." pill, circular send button ➤
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 10.0,
            ),
            color: widget.isDark ? BNXColors.darkSurface : Colors.white,
            child: Row(
              children: [
                // Paperclip icon
                IconButton(
                  icon: const Icon(
                    Icons.attach_file_rounded,
                    color: Color(0xFF64748B),
                    size: 22,
                  ),
                  tooltip: 'Attach file or image',
                  onPressed: _pickAttachment,
                ),

                // Emoji icon
                IconButton(
                  icon: const Icon(
                    Icons.sentiment_satisfied_alt_outlined,
                    color: Color(0xFF64748B),
                    size: 22,
                  ),
                  tooltip: 'Add emoji',
                  onPressed: () => _showEmojiPicker(context),
                ),

                // Rounded input pill
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? Colors.white10
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _commentController,
                      onSubmitted: (_) => _sendComment(),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 11),
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.isDark
                            ? Colors.white
                            : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Circular blue send button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _sendComment,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFF195BAC),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x33195BAC),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CasboxDetailPage extends ConsumerStatefulWidget {
  final CasboxMessage initialMsg;
  final bool isDark;

  const _CasboxDetailPage({required this.initialMsg, required this.isDark});

  @override
  ConsumerState<_CasboxDetailPage> createState() => _CasboxDetailPageState();
}

class _CasboxDetailPageState extends ConsumerState<_CasboxDetailPage> {
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<CasboxMessage> _sessionReplies = [];
  bool _showReplyBox = false;

  Timer? _threadPollingTimer;

  @override
  void initState() {
    super.initState();
    final initialMsg = widget.initialMsg;

    if (initialMsg.id.isNotEmpty && !initialMsg.id.startsWith('local_')) {
      CasboxRepository.markDelivered(initialMsg.id);
      CasboxRepository.updateStatus(initialMsg.id, 'SEEN');
    }
    _startThreadPolling();
  }

  void _startThreadPolling() {
    _threadPollingTimer?.cancel();
    _threadPollingTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      final initialMsg = widget.initialMsg;
      final activeAccount = ref.read(activeAccountProvider);
      final currentUserEmail = activeAccount.email.toLowerCase().trim();
      final currentHandle = currentUserEmail.contains('@')
          ? currentUserEmail.split('@').first
          : currentUserEmail;
      final s = initialMsg.sender.toLowerCase().trim();
      final sHandle = s.contains('@') ? s.split('@').first : s;
      final sentByMe = s == 'me' ||
          initialMsg.id.startsWith('local_') ||
          (currentUserEmail.isNotEmpty &&
              (s == currentUserEmail || sHandle == currentHandle));
      final contactEmail = sentByMe
          ? (initialMsg.to.isNotEmpty ? initialMsg.to : initialMsg.sender)
          : (initialMsg.sender.isNotEmpty ? initialMsg.sender : initialMsg.to);
      if (contactEmail.isNotEmpty) {
        await ref
            .read(casboxMessagesProvider.notifier)
            .fetchThreadMessages(contactEmail);
      }
    });
  }

  @override
  void dispose() {
    _threadPollingTimer?.cancel();
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatCasboxDateTime(DateTime dt) {
    final local = dt.toLocal();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final monthStr = months[local.month - 1];
    final day = local.day;
    final year = local.year;
    final hourNum = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minuteStr = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$monthStr $day, $year, $hourNum:$minuteStr $ampm';
  }

  Widget _buildDetailTickIcon(CasboxMessage msg, bool isDark) {
    final status = msg.status.trim().toUpperCase();
    if (msg.isRead ||
        status == 'READ' ||
        status == 'SEEN' ||
        status == 'ACCEPTED') {
      return const Icon(
        Icons.done_all_rounded,
        size: 14,
        color: Color(0xFF195BAC),
      );
    } else if (status == 'RESOLVED' || status == 'DELIVERED') {
      return Icon(
        Icons.done_all_rounded,
        size: 14,
        color: isDark ? Colors.white38 : Colors.grey.shade500,
      );
    } else {
      return Icon(
        Icons.check_rounded,
        size: 14,
        color: isDark ? Colors.white38 : Colors.grey.shade500,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final initialMsg = widget.initialMsg;
    final activeAccount = ref.watch(activeAccountProvider);
    final currentUserEmail = activeAccount.email.toLowerCase().trim();
    final currentHandle = currentUserEmail.contains('@')
        ? currentUserEmail.split('@').first
        : currentUserEmail;
    final s = initialMsg.sender.toLowerCase().trim();
    final sHandle = s.contains('@') ? s.split('@').first : s;
    final sentByMe = s == 'me' ||
        initialMsg.id.startsWith('local_') ||
        (currentUserEmail.isNotEmpty &&
            (s == currentUserEmail || sHandle == currentHandle));
    final contactEmail = sentByMe
        ? (initialMsg.to.isNotEmpty ? initialMsg.to : initialMsg.sender)
        : (initialMsg.sender.isNotEmpty ? initialMsg.sender : initialMsg.to);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobileDevice =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final isMobile =
        isMobileDevice ||
        (screenWidth < 800 &&
            defaultTargetPlatform != TargetPlatform.macOS &&
            defaultTargetPlatform != TargetPlatform.windows);

    final subjectText = initialMsg.subject.trim().isNotEmpty
        ? initialMsg.subject
        : '(No Subject)';
    final senderEmail = initialMsg.sender.trim();
    final toEmail = initialMsg.to.trim();

    return PopScope(
      canPop: !_showReplyBox,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() => _showReplyBox = false);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: isDark ? BNXColors.darkBg : const Color(0xFFE9F4FF),
        body: SafeArea(
          child: Column(
            children: [
              // Top Header Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                color: isDark ? BNXColors.darkSurface : Colors.white,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, size: 24),
                      tooltip: 'Back',
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        subjectText,
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 22,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        initialMsg.isStarred
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 22,
                        color: initialMsg.isStarred
                            ? const Color(0xFFF59E0B)
                            : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                      ),
                      tooltip: initialMsg.isStarred ? 'Unstar' : 'Star',
                      onPressed: () async {
                        final wasStarred = initialMsg.isStarred;
                        await ref
                            .read(casboxMessagesProvider.notifier)
                            .toggleStar(initialMsg.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                wasStarred
                                    ? 'Conversation unstarred'
                                    : 'Conversation starred',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        initialMsg.isArchived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                        size: 22,
                        color: initialMsg.isArchived
                            ? const Color(0xFF195BAC)
                            : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                      ),
                      tooltip: initialMsg.isArchived ? 'Unarchive' : 'Archive',
                      onPressed: () async {
                        final newArchived = !initialMsg.isArchived;
                        await ref
                            .read(casboxMessagesProvider.notifier)
                            .archiveMessage(initialMsg.id, newArchived);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(newArchived
                                  ? 'Conversation archived'
                                  : 'Conversation unarchived'),
                            ),
                          );
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),

              // Main Content Area Card
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 12 : 24),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? BNXColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Separate Single Message List (Not Grouped)
                        Expanded(
                          child: Consumer(
                            builder: (context, ref, child) {
                              final displayList = [
                                initialMsg,
                                ..._sessionReplies,
                              ];

                              return ListView.separated(
                                controller: _scrollController,
                                itemCount: displayList.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 24),
                                itemBuilder: (context, index) {
                                  final msg = displayList[index];
                                  final sEmail = msg.sender.trim().isNotEmpty
                                      ? msg.sender
                                      : senderEmail;
                                  final rEmail = msg.to.trim().isNotEmpty
                                      ? msg.to
                                      : toEmail;
                                  final char = sEmail.isNotEmpty
                                      ? sEmail[0].toUpperCase()
                                      : 'R';
                                  final formattedTime = _formatCasboxDateTime(
                                    msg.timestamp,
                                  );

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Sender Header Row
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFDBEAFE),
                                              shape: BoxShape.circle,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              char,
                                              style: const TextStyle(
                                                color: Color(0xFF1D4ED8),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 17,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        sEmail,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: isDark
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xFF0F172A,
                                                                ),
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      formattedTime,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: isDark
                                                            ? Colors.white38
                                                            : Colors
                                                                  .grey
                                                                  .shade500,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    _buildDetailTickIcon(
                                                      msg,
                                                      isDark,
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'To: $rEmail',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark
                                                        ? Colors.white60
                                                        : Colors.grey.shade600,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      // Message Body Text
                                      Padding(
                                        padding: EdgeInsets.only(
                                          left: isMobile ? 0 : 52,
                                        ),
                                        child: Text(
                                          msg.body,
                                          style: TextStyle(
                                            fontSize: 14,
                                            height: 1.5,
                                            color: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.87,
                                                  )
                                                : const Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Reply Button / TextField Section
                        if (_showReplyBox) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _replyController,
                                  maxLines: 3,
                                  minLines: 1,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Type your reply...',
                                    hintStyle: TextStyle(
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.grey.shade400,
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF195BAC),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.send_rounded,
                                  color: Color(0xFF195BAC),
                                ),
                                onPressed: () async {
                                  final text = _replyController.text.trim();
                                  if (text.isEmpty) return;
                                  _replyController.clear();
                                  final activeAcc = ref.read(
                                    activeAccountProvider,
                                  );
                                  final replyMsg = CasboxMessage(
                                    id: 'local_${DateTime.now().millisecondsSinceEpoch}',
                                    sender: activeAcc.email.isNotEmpty
                                        ? activeAcc.email
                                        : 'me',
                                    to: contactEmail,
                                    subject: initialMsg.subject,
                                    body: text,
                                    timestamp: DateTime.now(),
                                    status: 'PENDING',
                                  );
                                  setState(() {
                                    _sessionReplies.add(replyMsg);
                                    _showReplyBox = false;
                                  });
                                  await ref
                                      .read(casboxMessagesProvider.notifier)
                                      .addMessage(
                                        to: contactEmail,
                                        subject: initialMsg.subject,
                                        body: text,
                                      );
                                },
                              ),
                            ],
                          ),
                        ] else ...[
                          // Solid Blue Pill Reply Button matching screenshot
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() => _showReplyBox = true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF195BAC),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            icon: const Icon(
                              Icons.reply_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Reply',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
