import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/app_state_provider.dart';
import '../../../data/email_provider.dart';

/// Model representing a newsletter or mailing list sender subscription.
class SubscriptionSender {
  final String id;
  final String name;
  final String email;
  final int emailCount;
  final bool isSubscribed;
  final Color? avatarColor;

  const SubscriptionSender({
    required this.id,
    required this.name,
    required this.email,
    required this.emailCount,
    this.isSubscribed = true,
    this.avatarColor,
  });

  SubscriptionSender copyWith({
    String? id,
    String? name,
    String? email,
    int? emailCount,
    bool? isSubscribed,
    Color? avatarColor,
  }) {
    return SubscriptionSender(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      emailCount: emailCount ?? this.emailCount,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      avatarColor: avatarColor ?? this.avatarColor,
    );
  }
}

/// Dedicated Subscriptions Screen View.
/// Displays mail subscriptions with filter tabs (All Senders, Subscribed, Unsubscribed),
/// search capabilities, and subscribe/unsubscribe actions.
/// Fully responsive across macOS, Windows, Linux, Android, iOS, and Web without any overflow.
class SubscriptionsView extends ConsumerStatefulWidget {
  const SubscriptionsView({super.key});

  @override
  ConsumerState<SubscriptionsView> createState() => _SubscriptionsViewState();
}

class _SubscriptionsViewState extends ConsumerState<SubscriptionsView>
    with SingleTickerProviderStateMixin {
  String _activeTab = 'All Senders'; // 'All Senders', 'Subscribed', 'Unsubscribed'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late AnimationController _refreshAnimController;
  late List<SubscriptionSender> _senders;

  static const List<SubscriptionSender> _defaultSenders = [
    SubscriptionSender(
      id: 'sub_1',
      name: 'Ravi Kumar',
      email: 'connectwithravi2004@gmail.com',
      emailCount: 30,
      isSubscribed: true,
      avatarColor: Color(0xFF1E60B8),
    ),
    SubscriptionSender(
      id: 'sub_2',
      name: 'chandran123',
      email: 'chandran123@bnxmail.com',
      emailCount: 10,
      isSubscribed: true,
      avatarColor: Color(0xFF1E60B8),
    ),
    SubscriptionSender(
      id: 'sub_3',
      name: 'ICAI - Trace a Member',
      email: 'info@traceamember.icai.org',
      emailCount: 1,
      isSubscribed: true,
      avatarColor: Color(0xFF1E60B8),
    ),
    SubscriptionSender(
      id: 'sub_4',
      name: 'Persona',
      email: 'no-reply@withpersona.com',
      emailCount: 7,
      isSubscribed: true,
      avatarColor: Color(0xFF1E60B8),
    ),
    SubscriptionSender(
      id: 'sub_5',
      name: 'Arthur Tan',
      email: 'arthur.tan@withpersona.com',
      emailCount: 1,
      isSubscribed: true,
      avatarColor: Color(0xFF1E60B8),
    ),
    SubscriptionSender(
      id: 'sub_6',
      name: 'Team Signzy',
      email: 'support@signzy.com,hubspot_inbox.com',
      emailCount: 4,
      isSubscribed: true,
      avatarColor: Color(0xFF1E60B8),
    ),
    SubscriptionSender(
      id: 'sub_7',
      name: 'GitHub',
      email: 'notifications@github.com',
      emailCount: 12,
      isSubscribed: true,
      avatarColor: Color(0xFF1E60B8),
    ),
    SubscriptionSender(
      id: 'sub_8',
      name: 'LinkedIn',
      email: 'updates@linkedin.com',
      emailCount: 15,
      isSubscribed: true,
      avatarColor: Color(0xFF1E60B8),
    ),
    SubscriptionSender(
      id: 'sub_9',
      name: 'Google Alerts',
      email: 'googlealerts-noreply@google.com',
      emailCount: 8,
      isSubscribed: true,
      avatarColor: Color(0xFF1E60B8),
    ),
    SubscriptionSender(
      id: 'sub_10',
      name: 'Medium Daily Digest',
      email: 'noreply@medium.com',
      emailCount: 5,
      isSubscribed: true,
      avatarColor: Color(0xFF1E60B8),
    ),
    SubscriptionSender(
      id: 'sub_11',
      name: 'Twitter / X',
      email: 'info@x.com',
      emailCount: 14,
      isSubscribed: true,
      avatarColor: Color(0xFF1E60B8),
    ),
    SubscriptionSender(
      id: 'sub_12',
      name: 'Substack Reads',
      email: 'digest@substack.com',
      emailCount: 6,
      isSubscribed: true,
      avatarColor: Color(0xFF1E60B8),
    ),
    SubscriptionSender(
      id: 'sub_13',
      name: 'Figma Updates',
      email: 'news@figma.com',
      emailCount: 3,
      isSubscribed: true,
      avatarColor: Color(0xFF1E60B8),
    ),
    SubscriptionSender(
      id: 'sub_14',
      name: 'Notion',
      email: 'team@notion.so',
      emailCount: 9,
      isSubscribed: true,
      avatarColor: Color(0xFF1E60B8),
    ),
    SubscriptionSender(
      id: 'sub_15',
      name: 'Stripe',
      email: 'notices@stripe.com',
      emailCount: 2,
      isSubscribed: true,
      avatarColor: Color(0xFF1E60B8),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _refreshAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _senders = List.from(_defaultSenders);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _refreshAnimController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _triggerRefresh() {
    _refreshAnimController.forward(from: 0.0);
    // Reload senders from emails in emailProvider if available, preserving any unsubscribed states
    final emails = ref.read(emailProvider).emails;
    if (emails.isNotEmpty) {
      final senderEmailCount = <String, int>{};
      final senderNameMap = <String, String>{};
      for (final e in emails) {
        final emailKey = e.senderEmail.toLowerCase().trim();
        if (emailKey.isEmpty) continue;
        senderEmailCount[emailKey] = (senderEmailCount[emailKey] ?? 0) + 1;
        if (!senderNameMap.containsKey(emailKey) && e.senderName.isNotEmpty) {
          senderNameMap[emailKey] = e.senderName;
        }
      }

      // Check existing unsubscribed set
      final unsubscribedEmails = _senders
          .where((s) => !s.isSubscribed)
          .map((s) => s.email.toLowerCase())
          .toSet();

      final updatedList = <SubscriptionSender>[];
      for (final s in _defaultSenders) {
        final sEmail = s.email.toLowerCase();
        final actualCount = senderEmailCount[sEmail] ?? s.emailCount;
        updatedList.add(
          s.copyWith(
            emailCount: actualCount,
            isSubscribed: !unsubscribedEmails.contains(sEmail),
          ),
        );
      }
      setState(() {
        _senders = updatedList;
      });
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Subscriptions updated'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleSubscription(SubscriptionSender sender) {
    final nextState = !sender.isSubscribed;
    setState(() {
      _senders = _senders.map((s) {
        if (s.id == sender.id) {
          return s.copyWith(isSubscribed: nextState);
        }
        return s;
      }).toList();
    });

    final actionText = nextState ? 'Resubscribed to' : 'Unsubscribed from';
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$actionText ${sender.name}'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.amberAccent,
          onPressed: () {
            setState(() {
              _senders = _senders.map((s) {
                if (s.id == sender.id) {
                  return s.copyWith(isSubscribed: !nextState);
                }
                return s;
              }).toList();
            });
          },
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<SubscriptionSender> _getFilteredSenders() {
    List<SubscriptionSender> list = _senders;

    if (_activeTab == 'Subscribed') {
      list = list.where((s) => s.isSubscribed).toList();
    } else if (_activeTab == 'Unsubscribed') {
      list = list.where((s) => !s.isSubscribed).toList();
    }

    if (_searchQuery.isNotEmpty) {
      list = list.where((s) {
        return s.name.toLowerCase().contains(_searchQuery) ||
            s.email.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;
    final filteredSenders = _getFilteredSenders();
    final int currentTabBadgeCount = filteredSenders.length;

    return Container(
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double screenWidth = constraints.maxWidth;
          final bool isNarrow = screenWidth < 680;
          final double horizontalPadding = screenWidth < 500 ? 12 : 24;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. TOP HEADER ROW (PILL & REFRESH) ──────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  18,
                  horizontalPadding,
                  12,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      // Blue pill: SUBSCRIPTIONS (Count)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF195BAC),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF195BAC).withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.notifications_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'SUBSCRIPTIONS ($currentTabBadgeCount)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Refresh circular button
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _triggerRefresh,
                          child: RotationTransition(
                            turns: _refreshAnimController,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.transparent,
                              ),
                              child: Icon(
                                Icons.refresh_rounded,
                                size: 20,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── 2. SUB-HEADER: TABS & SEARCH BAR (RESPONSIVE) ───────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  4,
                  horizontalPadding,
                  14,
                ),
                child: isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTabsRow(isDark),
                          const SizedBox(height: 12),
                          _buildSearchBar(isDark, isFullWidth: true),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: _buildTabsRow(isDark)),
                          const SizedBox(width: 16),
                          _buildSearchBar(isDark, isFullWidth: false),
                        ],
                      ),
              ),

              const SizedBox(height: 4),

              // ── 3. SENDERS LIST OR EMPTY STATE ──────────────────────────────
              Expanded(
                child: filteredSenders.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          4,
                          horizontalPadding,
                          32,
                        ),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        itemCount: filteredSenders.length,
                        itemBuilder: (context, index) {
                          final sender = filteredSenders[index];
                          return _buildSenderCard(
                            sender: sender,
                            isDark: isDark,
                            screenWidth: screenWidth,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── FILTER TABS ROW ─────────────────────────────────────────────────────────

  Widget _buildTabsRow(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabPill(
            title: 'All Senders',
            isSelected: _activeTab == 'All Senders',
            isDark: isDark,
            selectedBorderColor: Colors.transparent,
            selectedBgColor:
                isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            selectedTextColor:
                isDark ? Colors.white : const Color(0xFF1E293B),
            onTap: () => setState(() => _activeTab = 'All Senders'),
          ),
          const SizedBox(width: 8),
          _buildTabPill(
            title: 'Subscribed',
            isSelected: _activeTab == 'Subscribed',
            isDark: isDark,
            selectedBorderColor: const Color(0xFF10B981),
            selectedBgColor: isDark
                ? const Color(0xFF064E3B).withValues(alpha: 0.2)
                : Colors.white,
            selectedTextColor: const Color(0xFF10B981),
            onTap: () => setState(() => _activeTab = 'Subscribed'),
          ),
          const SizedBox(width: 8),
          _buildTabPill(
            title: 'Unsubscribed',
            isSelected: _activeTab == 'Unsubscribed',
            isDark: isDark,
            selectedBorderColor: const Color(0xFF195BAC),
            selectedBgColor: isDark
                ? const Color(0xFF1E3A8A).withValues(alpha: 0.2)
                : Colors.white,
            selectedTextColor: const Color(0xFFEF4444),
            onTap: () => setState(() => _activeTab = 'Unsubscribed'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPill({
    required String title,
    required bool isSelected,
    required bool isDark,
    required Color selectedBorderColor,
    required Color selectedBgColor,
    required Color selectedTextColor,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? selectedBgColor : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: isSelected && selectedBorderColor != Colors.transparent
                ? Border.all(color: selectedBorderColor, width: 1.5)
                : null,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? selectedTextColor
                  : (isDark ? Colors.white60 : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }

  // ── SEARCH BAR ──────────────────────────────────────────────────────────────

  Widget _buildSearchBar(bool isDark, {required bool isFullWidth}) {
    return Container(
      width: isFullWidth ? double.infinity : 240,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 18,
            color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
              decoration: InputDecoration(
                hintText: 'Search senders...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _searchController.clear();
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── SENDER CARD ─────────────────────────────────────────────────────────────

  Widget _buildSenderCard({
    required SubscriptionSender sender,
    required bool isDark,
    required double screenWidth,
  }) {
    final bool isCompact = screenWidth < 580;
    final String initial = sender.name.isNotEmpty
        ? sender.name.trim()[0].toUpperCase()
        : (sender.email.isNotEmpty ? sender.email[0].toUpperCase() : 'S');

    final Widget avatarWidget = CircleAvatar(
      radius: 20,
      backgroundColor: sender.avatarColor ?? const Color(0xFF1E60B8),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    final Widget textInfoWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          sender.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          sender.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? Colors.white70 : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${sender.emailCount} ${sender.emailCount == 1 ? 'email' : 'emails'} in inbox',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontStyle: FontStyle.italic,
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );

    final Widget actionsWidget = Wrap(
      spacing: 10,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Subscribed / Unsubscribed Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: sender.isSubscribed
                ? (isDark
                    ? const Color(0xFF064E3B).withValues(alpha: 0.3)
                    : const Color(0xFFF0FDF4))
                : (isDark
                    ? const Color(0xFF451A1A).withValues(alpha: 0.3)
                    : const Color(0xFFFEF2F2)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: sender.isSubscribed
                  ? (isDark
                      ? const Color(0xFF047857).withValues(alpha: 0.5)
                      : const Color(0xFFBBF7D0))
                  : (isDark
                      ? const Color(0xFF991B1B).withValues(alpha: 0.5)
                      : const Color(0xFFFECACA)),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                sender.isSubscribed
                    ? Icons.mail_rounded
                    : Icons.mail_outline_rounded,
                size: 13,
                color: sender.isSubscribed
                    ? const Color(0xFF10B981)
                    : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 5),
              Text(
                sender.isSubscribed ? 'Subscribed' : 'Unsubscribed',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sender.isSubscribed
                      ? const Color(0xFF10B981)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        // Action Button: Unsubscribe / Resubscribe
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleSubscription(sender),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: sender.isSubscribed
                      ? const Color(0xFFFECACA)
                      : const Color(0xFF86EFAC),
                  width: 1,
                ),
              ),
              child: Text(
                sender.isSubscribed ? 'Unsubscribe' : 'Resubscribe',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sender.isSubscribed
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF10B981),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    avatarWidget,
                    const SizedBox(width: 14),
                    Expanded(child: textInfoWidget),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: actionsWidget,
                ),
              ],
            )
          : Row(
              children: [
                avatarWidget,
                const SizedBox(width: 16),
                Expanded(child: textInfoWidget),
                const SizedBox(width: 12),
                actionsWidget,
              ],
            ),
    );
  }

  // ── EMPTY STATE ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState(bool isDark) {
    final bool isSearch = _searchQuery.isNotEmpty;
    final String title = isSearch
        ? 'No senders matching "$_searchQuery"'
        : (_activeTab == 'Unsubscribed'
            ? 'No unsubscribed senders found'
            : 'No senders found');
    final String subtitle = isSearch
        ? 'Try clearing the search query or search by another keyword'
        : 'Check other tabs or refresh to view senders';

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF8FAFC),
              ),
              child: Center(
                child: Icon(
                  isSearch
                      ? Icons.search_off_rounded
                      : Icons.notifications_off_outlined,
                  size: 42,
                  color: isDark
                      ? Colors.white24
                      : const Color(0xFFCBD5E1),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ),
            if (isSearch) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _searchController.clear(),
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text('Clear search'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF195BAC),
                  side: const BorderSide(color: Color(0xFF195BAC)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
