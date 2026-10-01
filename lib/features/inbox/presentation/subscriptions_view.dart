import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/app_state_provider.dart';
import '../../../data/email_provider.dart';
import '../../../data/subscription_provider.dart';
import '../../../models/email_model.dart';
import '../../../models/blocked_contact_model.dart';

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

  @override
  void initState() {
    super.initState();
    _refreshAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(subscriptionProvider.notifier).loadBlockedContacts();
      }
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
    ref.read(subscriptionProvider.notifier).loadBlockedContacts(force: true);
  }

  Future<void> _toggleSubscription(SubscriptionSender sender) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final isUnsubscribing = sender.isSubscribed;

    scaffoldMessenger.hideCurrentSnackBar();

    final result = isUnsubscribing
        ? await ref
            .read(subscriptionProvider.notifier)
            .unsubscribe(sender.email)
        : await ref
            .read(subscriptionProvider.notifier)
            .subscribe(sender.email);

    if (!mounted) return;

    if (result.success) {
      final actionText =
          isUnsubscribing ? 'Unsubscribed from' : 'Resubscribed to';
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('$actionText ${sender.name}'),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.amberAccent,
            onPressed: () {
              _toggleSubscription(
                sender.copyWith(isSubscribed: !isUnsubscribing),
              );
            },
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            result.message ??
                'Failed to ${isUnsubscribing ? 'unsubscribe from' : 'resubscribe to'} ${sender.name}',
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<SubscriptionSender> _deriveAllSenders(
    List<EmailModel> emails,
    Set<String> blockedEmails,
    List<BlockedContact> blockedContacts,
  ) {
    final Map<String, ({String name, String email, int inboxCount})> senderMap =
        {};

    for (final e in emails) {
      final senderEmail = e.senderEmail.trim();
      final emailKey = senderEmail.toLowerCase();
      if (emailKey.isEmpty) continue;

      final bool isInbox = e.memberOfFolders.contains('Inbox') ||
          (!e.isTrash && !e.isDraft && !e.isSpam && !e.isArchive && !e.isSent);

      final current = senderMap[emailKey];
      if (current == null) {
        final senderName = e.senderName.trim();
        final displayName =
            senderName.isNotEmpty ? senderName : emailKey.split('@').first;
        senderMap[emailKey] = (
          name: displayName,
          email: senderEmail,
          inboxCount: isInbox ? 1 : 0,
        );
      } else {
        final existingName = current.name;
        final senderName = e.senderName.trim();
        final resolvedName =
            existingName.isNotEmpty ? existingName : senderName;
        senderMap[emailKey] = (
          name: resolvedName.isNotEmpty ? resolvedName : current.email,
          email: current.email,
          inboxCount: current.inboxCount + (isInbox ? 1 : 0),
        );
      }
    }

    // Also include any blocked contacts from GET /api/blocked-contacts not in loaded emails
    for (final b in blockedContacts) {
      final contactEmail = b.email.trim();
      final emailKey = contactEmail.toLowerCase();
      if (emailKey.isEmpty) continue;

      if (!senderMap.containsKey(emailKey)) {
        senderMap[emailKey] = (
          name: emailKey.split('@').first,
          email: contactEmail,
          inboxCount: 0,
        );
      }
    }

    return senderMap.values.map((s) {
      final isSubscribed = !blockedEmails.contains(s.email.toLowerCase().trim());
      return SubscriptionSender(
        id: s.email.toLowerCase().trim(),
        name: s.name,
        email: s.email,
        emailCount: s.inboxCount,
        isSubscribed: isSubscribed,
        avatarColor: const Color(0xFF1E60B8),
      );
    }).toList();
  }

  List<SubscriptionSender> _getFilteredSenders(
    List<SubscriptionSender> allSenders,
  ) {
    List<SubscriptionSender> list = allSenders;

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

    final emailState = ref.watch(emailProvider);
    final subscriptionState = ref.watch(subscriptionProvider);
    final blockedEmails = subscriptionState.blockedEmailsSet;

    final allSenders = _deriveAllSenders(
      emailState.emails,
      blockedEmails,
      subscriptionState.blockedContacts,
    );
    final filteredSenders = _getFilteredSenders(allSenders);
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

              // ── 3. SENDERS LIST, LOADING, ERROR, OR EMPTY STATE ─────────────
              Expanded(
                child: subscriptionState.isLoading && allSenders.isEmpty
                    ? Center(
                        child: CircularProgressIndicator(
                          color: const Color(0xFF195BAC),
                        ),
                      )
                    : subscriptionState.error != null && allSenders.isEmpty
                        ? _buildErrorState(isDark, subscriptionState.error!)
                        : filteredSenders.isEmpty
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
                                  final isPending = subscriptionState
                                      .pendingEmails
                                      .contains(sender.email.toLowerCase().trim());
                                  return _buildSenderCard(
                                    sender: sender,
                                    isDark: isDark,
                                    screenWidth: screenWidth,
                                    isPending: isPending,
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
    required bool isPending,
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
          cursor: isPending ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isPending ? null : () => _toggleSubscription(sender),
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
              child: isPending
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: sender.isSubscribed
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                      ),
                    )
                  : Text(
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

  // ── ERROR STATE ─────────────────────────────────────────────────────────────

  Widget _buildErrorState(bool isDark, String error) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 14),
            Text(
              'Failed to load subscriptions',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _triggerRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF195BAC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
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
