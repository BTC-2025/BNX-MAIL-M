import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/ui_components.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/neumorphic.dart';
import '../../../data/app_state_provider.dart';
import '../../../data/account_provider.dart';
import '../../../models/account_model.dart';
import '../../../data/colab_provider.dart';
import '../../../data/email_provider.dart';
import '../../../data/repositories/casbox_repository.dart';
import '../../../models/attachment_model.dart';
import 'package:file_picker/file_picker.dart';

class ColabScreen extends ConsumerStatefulWidget {
  const ColabScreen({super.key});

  @override
  ConsumerState<ColabScreen> createState() => _ColabScreenState();
}

class _ColabScreenState extends ConsumerState<ColabScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
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
    final uiState = ref.read(appUiProvider);
    if (uiState.activeFolder == 'Casbox') {
      ref.read(appUiProvider.notifier).selectFolder('Inbox');
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
      ref.read(appUiProvider.notifier).selectFolder('Inbox');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobileDevice = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final bool isMobile = isMobileDevice ||
        (screenWidth < 800 &&
            defaultTargetPlatform != TargetPlatform.macOS &&
            defaultTargetPlatform != TargetPlatform.windows);

    Widget content;
    final selectedGroupId = ref.watch(selectedColabIdProvider);
    if (uiState.activeFolder == 'Casbox') {
      content = _buildCasboxView(context, ref, isDark, isMobile);
    } else if (selectedGroupId != null) {
      content = _buildColabDetailView(
        context,
        ref,
        selectedGroupId,
        isDark,
        isMobile,
      );
    } else {
      final groups = ref.watch(colabListProvider);
      final searchQuery = uiState.searchQuery.toLowerCase();
      final filteredGroups = groups.where((g) {
        return g.name.toLowerCase().contains(searchQuery) ||
            g.desc.toLowerCase().contains(searchQuery);
      }).toList();

      content = Scaffold(
        backgroundColor: isDark ? BNXColors.darkSurface : const Color(0xFFE9F4FF),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(colabListProvider.notifier).loadGroups();
          await ref.read(colabInvitationsProvider.notifier).loadInvitations();
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // 1. Header - clean consistent layout with expandable search
            SliverToBoxAdapter(
              child: Container(
                color: isDark ? BNXColors.darkSurface : Colors.white,
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _isSearching
                      ? Row(
                          key: const ValueKey('searching_mode'),
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_rounded),
                              onPressed: () {
                                setState(() {
                                  _isSearching = false;
                                  _searchController.clear();
                                });
                                ref
                                    .read(appUiProvider.notifier)
                                    .setSearchQuery('');
                              },
                            ),
                            Expanded(
                              child: Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? BNXColors.darkBg
                                      : const Color(0xFFE9F4FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    hintText: 'Search groups...',
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                  ),
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : BNXColors.lightTextPrimary,
                                  ),
                                  onChanged: (val) {
                                    ref
                                        .read(appUiProvider.notifier)
                                        .setSearchQuery(val);
                                  },
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(appUiProvider.notifier)
                                    .setSearchQuery('');
                              },
                            ),
                          ],
                        )
                      : Column(
                          key: const ValueKey('normal_mode'),
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.menu_rounded),
                                  onPressed: () =>
                                      Scaffold.of(context).openDrawer(),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: BNXColors.lightPrimary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.people_alt_rounded,
                                    color: BNXColors.lightPrimary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Chat',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : BNXColors.lightTextPrimary,
                                        ),
                                      ),
                                      const Text(
                                        'Collaborate with your teams',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.search_rounded),
                                  onPressed: () {
                                    setState(() {
                                      _isSearching = true;
                                    });
                                  },
                                ),
                                const SizedBox(width: 4),
                                PrimaryButton(
                                  label: isMobile ? 'New' : 'New Colab',
                                  icon: Icons.group_add_rounded,
                                  onPressed: () => _showCreateColabDialog(
                                    context,
                                    ref,
                                    isDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.only(left: 12.0),
                              child: Text(
                                'ACTIVE DISCUSSIONS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white30
                                      : Colors.grey.shade700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: Divider(height: 1, thickness: 1)),

            // Invitation banner
            SliverToBoxAdapter(
              child: _buildInvitationBanner(context, ref, isDark),
            ),

            // 3. Center Section / Colab Content List
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 2),

                  // Grouped chat groups in a single card-like container
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey.shade300,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.04,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: filteredGroups.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 32.0,
                              ),
                              child: Text(
                                'No Colab groups found.',
                                style: TextStyle(
                                  color: isDark ? Colors.white30 : Colors.grey,
                                ),
                              ),
                            ),
                          )
                        : Column(
                            children: filteredGroups.asMap().entries.map((
                              entry,
                            ) {
                              final index = entry.key;
                              final group = entry.value;
                              final isLast = index == filteredGroups.length - 1;

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildGroupCard(context, ref, group, isDark),
                                  if (!isLast)
                                    Divider(
                                      height: 1,
                                      thickness: 1.0,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : const Color(0xFFE9F4FF),
                                      indent: 0,
                                      endIndent: 0,
                                    ),
                                ],
                              );
                            }).toList(),
                          ),
                  ),

                  const SizedBox(height: 40),

                  // Bottom Graphic Mock
                  Center(
                    child: Column(
                      children: [
                        NeumorphicContainer(
                          width: 80,
                          height: 80,
                          boxShape: BoxShape.circle,
                          shape: NeumorphicShape.pressed,
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF4F7FB),
                          child: const Icon(
                            Icons.question_answer_outlined,
                            size: 32,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Need to set up a new workgroup?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Create groups to collaborate in real-time, share files,\nand edit code assets concurrently.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildGroupCard(
    BuildContext context,
    WidgetRef ref,
    ColabGroup group,
    bool isDark,
  ) {
    final bool hasUnread = group.unread;

    final avatar = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: BNXColors.lightPrimary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.groups_rounded,
        color: BNXColors.lightPrimary,
        size: 24,
      ),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                group.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasUnread) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          group.desc,
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? BNXColors.darkTextSecondary
                : BNXColors.lightTextSecondary,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Active: ',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(width: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: group.members.map((m) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? BNXColors.darkBorder
                          : BNXColors.lightBorder,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    m,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ],
    );

    return InkWell(
      onTap: () {
        ref.read(selectedColabIdProvider.notifier).state = group.id;
        ref.read(colabListProvider.notifier).markAsRead(group.id);
        ref.read(colabListProvider.notifier).fetchMessagesForGroup(group.id);
        ref.read(colabListProvider.notifier).fetchBroadcastsForGroup(group.id);
        ref.read(colabListProvider.notifier).fetchMembersForGroup(group.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: isDark ? Colors.transparent : Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(width: 12),
              Expanded(child: details),
            ],
          ),
        ),
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
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.purple,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              group.name.isNotEmpty ? group.name[0].toUpperCase() : 'P',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
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
                        size: 18,
                        color: isDark ? Colors.white38 : Colors.grey,
                      ),
                      onPressed: () =>
                          _showGroupInfoDialog(context, group, isDark),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'GROUP • ONLINE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? BNXColors.darkPrimary
                        : BNXColors.lightPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) async {
              if (value == 'info') {
                _showGroupInfoDialog(context, group, isDark);
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
              : const Color(0xFFE9F4FF),
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
                                Icon(Icons.chat_bubble_outline_rounded, size: 18),
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
      backgroundColor: isDark ? BNXColors.darkSurface : const Color(0xFFE9F4FF),
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
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: isDark ? BNXColors.darkSurface : Colors.white,
          title: Text(
            group.name,
            style: TextStyle(
              color: isDark ? Colors.white : BNXColors.lightTextPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Description:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : BNXColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(group.desc, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              Text(
                'Active Members (${group.members.length}):',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : BNXColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: group.members.map((m) {
                  return Chip(
                    label: Text(m, style: const TextStyle(fontSize: 12)),
                    backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBroadcastsPanel(
    BuildContext context,
    WidgetRef ref,
    ColabGroup group,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? BNXColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? BNXColors.darkBorder : BNXColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () =>
                _showComposeBroadcastDialog(context, ref, group.id, isDark),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.email_outlined,
                    color: Color(0xFF195BAC),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Professional Broadcasts (${group.broadcasts.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark
                            ? Colors.white
                            : BNXColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.add_comment_outlined,
                    size: 16,
                    color: isDark ? Colors.white38 : Colors.grey,
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
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? BNXColors.darkBorder
                                : BNXColors.lightBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.campaign_rounded,
                                      size: 16,
                                      color: Color(0xFF195BAC),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Broadcast #${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'By: ${b.sender}',
                                    textAlign: TextAlign.end,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            const Text(
                              'To: All Members',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Subject: ${b.subject}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : BNXColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              b.body,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : BNXColors.lightTextPrimary,
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
                                          ? Colors.white12
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.insert_drive_file_rounded,
                                          size: 14,
                                          color: Color(0xFF195BAC),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            att.fileName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (att.fileSize.isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            '(${att.fileSize})',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isDark
                                                  ? Colors.white60
                                                  : Colors.black54,
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
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? BNXColors.darkPrimary
                      : BNXColors.lightPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () =>
                    _showComposeBroadcastDialog(context, ref, group.id, isDark),
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
    String groupId,
    bool isDark,
  ) {
    final subjectController = TextEditingController();
    final bodyController = TextEditingController();
    List<AttachmentModel> attachedFiles = [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              backgroundColor: isDark ? BNXColors.darkSurface : Colors.white,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compose New Broadcast',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : BNXColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Subject',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? BNXColors.darkTextSecondary
                              : BNXColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: subjectController,
                        decoration: InputDecoration(
                          hintText: 'Enter subject...',
                          hintStyle: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                          contentPadding: const EdgeInsets.all(12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark
                                  ? BNXColors.darkBorder
                                  : BNXColors.lightBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: BNXColors.lightPrimary,
                              width: 2,
                            ),
                          ),
                        ),
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : BNXColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Broadcast Message',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? BNXColors.darkTextSecondary
                              : BNXColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: bodyController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText:
                              'Enter broadcast update for all group members...',
                          hintStyle: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                          contentPadding: const EdgeInsets.all(12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark
                                  ? BNXColors.darkBorder
                                  : BNXColors.lightBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: BNXColors.lightPrimary,
                              width: 2,
                            ),
                          ),
                        ),
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : BNXColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Attachments Section
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF195BAC),
                          side: const BorderSide(color: Color(0xFF195BAC)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          try {
                            final result = await FilePicker.platform.pickFiles(
                              allowMultiple: true,
                            );
                            if (result != null && result.files.isNotEmpty) {
                              setState(() {
                                for (final file in result.files) {
                                  attachedFiles.add(
                                    AttachmentModel(
                                      fileName: file.name,
                                      fileType:
                                          file.extension?.toUpperCase() ??
                                          'FILE',
                                      fileSize: file.size > 1024 * 1024
                                          ? '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB'
                                          : '${(file.size / 1024).toStringAsFixed(0)} KB',
                                      filePath: file.path,
                                    ),
                                  );
                                }
                              });
                            }
                          } catch (e) {
                            print('[FILE PICKER ERROR] $e');
                          }
                        },
                        icon: const Icon(Icons.attach_file_rounded, size: 18),
                        label: const Text('Attach Document / File'),
                      ),
                      if (attachedFiles.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: attachedFiles.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final att = entry.value;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white12
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.grey[300]!,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.insert_drive_file_rounded,
                                    size: 14,
                                    color: Color(0xFF195BAC),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      att.fileName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
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
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BNXColors.lightPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () async {
                              final subjectText = subjectController.text.trim();
                              final bodyText = bodyController.text.trim();
                              if (subjectText.isEmpty || bodyText.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please fill all fields'),
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
                                      groupId,
                                      sender: senderName,
                                      subject: subjectText,
                                      body: bodyText,
                                      attachments: attachedFiles,
                                    );
                                if (context.mounted) {
                                  Navigator.of(context).pop();
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
                            child: const Text(
                              'Send Broadcast',
                              style: TextStyle(color: Colors.white),
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
      },
    );
  }
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
  final Set<String> _archivedIds = {};
  String? _hoveredMessageId;
  bool _isRefreshing = false;
  bool _isLoading = true;
  String _activeTab = 'Received';
  Timer? _casboxPollingTimer;
  CasboxMessage? _selectedDesktopMessage;
  bool _showConnectionsPopup = false;
  final List<String> _blockedUsers = [];
  final Map<String, bool> _contactConnectionStatus = {
    'itsokletssee123': true,
    'ravinew2004': true,
  };
  List<String> _authorizedContacts = [];
  final TextEditingController _desktopChatInputController =
      TextEditingController();
  final ScrollController _desktopChatScrollController = ScrollController();

  String _formatMailDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(itemDate).inDays;

    if (diff == 0) {
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final period = date.hour >= 12 ? 'PM' : 'AM';
      final min = date.minute.toString().padLeft(2, '0');
      return '$hour:$min $period';
    } else if (diff == 1) {
      return 'Yesterday';
    } else if (diff < 7 && diff > 1) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[date.weekday - 1];
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final month = months[date.month - 1];
      if (date.year == now.year) {
        return '$month ${date.day}';
      }
      return '$month ${date.day}, ${date.year}';
    }
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
        final s = _selectedDesktopMessage!.sender.toLowerCase().trim();
        final isSentByMe = s == 'me' ||
            s == 'ravi' ||
            _selectedDesktopMessage!.id.startsWith('local_') ||
            (currentUserEmail.isNotEmpty && s == currentUserEmail);
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
    await ref
        .read(casboxMessagesProvider.notifier)
        .fetchMessages(mailboxEmails);
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
    await Future.delayed(const Duration(milliseconds: 350));
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
    await ref
        .read(casboxMessagesProvider.notifier)
        .fetchMessages(mailboxEmails);
    await Future.delayed(const Duration(milliseconds: 300));
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
    final activeAccount = ref.watch(activeAccountProvider);
    final currentUserEmail = activeAccount.email.toLowerCase().trim();

    bool isSentByMe(CasboxMessage m) {
      final s = m.sender.toLowerCase().trim();
      if (s == 'me' || s == 'ravi' || m.id.startsWith('local_')) return true;
      if (currentUserEmail.isEmpty) return false;
      if (s == currentUserEmail) return true;
      final sHandle = s.contains('@') ? s.split('@').first : s;
      final meHandle = currentUserEmail.contains('@')
          ? currentUserEmail.split('@').first
          : currentUserEmail;
      return sHandle.isNotEmpty && sHandle == meHandle;
    }

    final filteredUserMessages = allMessages;

    final messages = filteredUserMessages.where((m) {
      if (_activeTab == 'Archived') {
        return _archivedIds.contains(m.id);
      }
      if (_archivedIds.contains(m.id)) {
        return false;
      }
      if (_activeTab == 'Combined Chat') {
        return !isSentByMe(m);
      }
      if (_activeTab == 'Received' || _activeTab == 'Messages') {
        if (isSentByMe(m)) return true;
        final s = m.status.toUpperCase();
        return s != 'PENDING' && s != 'REQUEST';
      }
      if (_activeTab == 'Sent') {
        return isSentByMe(m);
      }
      if (_activeTab == 'Requests') {
        return !isSentByMe(m) &&
            (m.status.toUpperCase() == 'PENDING' ||
                m.status.toUpperCase() == 'REQUEST');
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
              Expanded(
                child: _activeTab == 'Combined Chat'
                    ? _buildDesktopCombinedChatMailList(
                        isDark,
                        messages,
                        isSplit: false,
                      )
                    : _buildDesktopMessageList(
                        isDark,
                        messages,
                        isSplit: false,
                      ),
              ),
            ],
          ),
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

  Widget _buildDesktopCasboxHeader(bool isDark, double screenWidth) {
    final isNarrow = screenWidth < 680;

    if (isNarrow) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                Text(
                  'Casbox',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Button 1: Connections icon button
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
                                    : (isDark ? Colors.white10 : const Color(0xFFEFF6FF)),
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
                        // Button 2: Compose button (hidden on Android and iOS mobile)
                        if (defaultTargetPlatform != TargetPlatform.android &&
                            defaultTargetPlatform != TargetPlatform.iOS) ...[
                          const SizedBox(width: 6),
                          ElevatedButton(
                            onPressed: () {
                              ref
                                  .read(appUiProvider.notifier)
                                  .setComposeStatus(ComposeStatus.normal);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF195BAC),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              'Compose',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                        const SizedBox(width: 2),
                        // Button 3: Block Users list icon
                        IconButton(
                          icon: Icon(
                            Icons.do_not_disturb_alt_outlined,
                            size: 19,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                          tooltip: 'Blocked Users',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _showBlockedUsersDialog(context, isDark),
                        ),
                        // Button 4: Refresh icon
                        IconButton(
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
                                  size: 19,
                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                                ),
                          tooltip: 'Refresh',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          visualDensity: VisualDensity.compact,
                          onPressed: _triggerRefresh,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDesktopSegment('Messages', _activeTab == 'Received' || _activeTab == 'Messages', () {
                      setState(() {
                        _activeTab = 'Received';
                        _selectedDesktopMessage = null;
                      });
                      ref.read(selectedCasboxThreadProvider.notifier).state = null;
                    }, isDark),
                    _buildDesktopSegment('Combined Chat', _activeTab == 'Combined Chat', () {
                      setState(() {
                        _activeTab = 'Combined Chat';
                        _selectedDesktopMessage = null;
                      });
                      ref.read(selectedCasboxThreadProvider.notifier).state = null;
                    }, isDark),
                    _buildDesktopSegment('Requests', _activeTab == 'Requests', () {
                      setState(() {
                        _activeTab = 'Requests';
                        _selectedDesktopMessage = null;
                      });
                      ref.read(selectedCasboxThreadProvider.notifier).state = null;
                    }, isDark),
                    _buildDesktopSegment('Archived', _activeTab == 'Archived', () {
                      setState(() {
                        _activeTab = 'Archived';
                        _selectedDesktopMessage = null;
                      });
                      ref.read(selectedCasboxThreadProvider.notifier).state = null;
                    }, isDark),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          // Segmented switcher: Messages / Combined Chat / Requests / Archived
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDesktopSegment('Messages', _activeTab == 'Received' || _activeTab == 'Messages', () {
                  setState(() {
                    _activeTab = 'Received';
                    _selectedDesktopMessage = null;
                  });
                  ref.read(selectedCasboxThreadProvider.notifier).state = null;
                }, isDark),
                _buildDesktopSegment('Combined Chat', _activeTab == 'Combined Chat', () {
                  setState(() {
                    _activeTab = 'Combined Chat';
                    _selectedDesktopMessage = null;
                  });
                  ref.read(selectedCasboxThreadProvider.notifier).state = null;
                }, isDark),
                _buildDesktopSegment('Requests', _activeTab == 'Requests', () {
                  setState(() {
                    _activeTab = 'Requests';
                    _selectedDesktopMessage = null;
                  });
                  ref.read(selectedCasboxThreadProvider.notifier).state = null;
                }, isDark),
                _buildDesktopSegment('Archived', _activeTab == 'Archived', () {
                  setState(() {
                    _activeTab = 'Archived';
                    _selectedDesktopMessage = null;
                  });
                  ref.read(selectedCasboxThreadProvider.notifier).state = null;
                }, isDark),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          const Spacer(),
          // Button 1: Connections icon button (User +)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _toggleConnectionsPopup,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _showConnectionsPopup
                      ? const Color(0xFFDBEAFE)
                      : (isDark ? Colors.white10 : const Color(0xFFEFF6FF)),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 18,
                  color: Color(0xFF195BAC),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Button 2: Compose button (blue pill with white text)
          ElevatedButton(
            onPressed: () {
              ref
                  .read(appUiProvider.notifier)
                  .setComposeStatus(ComposeStatus.normal);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF195BAC),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Compose',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          // Button 3: Block Users list icon
          IconButton(
            icon: Icon(
              Icons.do_not_disturb_alt_outlined,
              size: 20,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
            tooltip: 'Blocked Users',
            onPressed: () => _showBlockedUsersDialog(context, isDark),
          ),
          // Button 4: Refresh icon
          IconButton(
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
                    size: 20,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
            tooltip: 'Refresh',
            onPressed: _triggerRefresh,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionsPopup(bool isDark, [double? screenWidth]) {
    final isNarrow = screenWidth != null && screenWidth < 680;
    final popupWidth = isNarrow
        ? (screenWidth - 24).clamp(280.0, 430.0)
        : 430.0;

    final contacts = <Map<String, dynamic>>[];
    if (_authorizedContacts.isNotEmpty) {
      for (final email in _authorizedContacts) {
        final handle = email.contains('@') ? email.split('@').first : email;
        contacts.add({
          'id': email,
          'name': handle,
          'handle': email.contains('@') ? email : '@$handle',
          'letter': handle.isNotEmpty ? handle[0].toUpperCase() : 'U',
          'isPhoto': false,
        });
      }
    } else {
      contacts.addAll([
        {
          'id': 'itsokletssee123',
          'name': 'itsokletssee123',
          'handle': '@itsokletssee123',
          'letter': 'I',
          'isPhoto': false,
        },
        {
          'id': 'ravinew2004',
          'name': 'ravinew2004',
          'handle': '@ravinew2004',
          'letter': 'R',
          'isPhoto': true,
        },
      ]);
    }

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
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 18, vertical: 16),
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
                    '${contacts.length} accepted contacts',
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
            final id = c['id'] as String;
            final isConnected = _contactConnectionStatus[id] ?? true;
            final isPhoto = c['isPhoto'] as bool;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFDBEAFE),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: isPhoto
                        ? Image.asset(
                            'assets/bit_tool_logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Center(
                              child: Text(
                                c['letter'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF195BAC),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              c['letter'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF195BAC),
                              ),
                            ),
                          ),
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
                                c['name'] as String,
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
                          c['handle'] as String,
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
                      setState(() {
                        _contactConnectionStatus[id] = true;
                        if (!_authorizedContacts.contains(id)) {
                          _authorizedContacts.add(id);
                        }
                      });
                      await CasboxRepository.updateAuthorizedContacts(_authorizedContacts);
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
                      setState(() {
                        _contactConnectionStatus[id] = false;
                        _authorizedContacts.remove(id);
                      });
                      await CasboxRepository.updateAuthorizedContacts(_authorizedContacts);
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
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              backgroundColor: isDark ? BNXColors.darkSurface : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              elevation: 20,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header: Red block circle + Title + Close icon
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
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
                              size: 16,
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
                      const SizedBox(height: 16),
                      Divider(
                        height: 1,
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFF1F5F9),
                      ),
                      const SizedBox(height: 36),
                      if (_blockedUsers.isEmpty) ...[
                        // Green soft checkmark icon as shown in Image 2
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.check_rounded,
                            size: 38,
                            color: Color(0xFF86EFAC),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No blocked users',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 36),
                      ] else ...[
                        ListView.builder(
                          shrinkWrap: true,
                          itemCount: _blockedUsers.length,
                          itemBuilder: (c, i) {
                            final u = _blockedUsers[i];
                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(u),
                              trailing: TextButton(
                                onPressed: () {
                                  setDialogState(() => _blockedUsers.remove(u));
                                  setState(() => _blockedUsers.remove(u));
                                },
                                child: const Text('Unblock'),
                              ),
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
    bool isDark,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF334155) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
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
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? const Color(0xFF195BAC)
                : (isDark ? Colors.white70 : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopCombinedChatMailList(
    bool isDark,
    List<CasboxMessage> messages, {
    required bool isSplit,
  }) {
    if (_isLoading) {
      return _buildLoadingIndicator(isDark);
    }
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mark_email_read_outlined,
              size: 44,
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'No incoming messages in Combined Chat',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (isSplit) {
      return ListView.separated(
        itemCount: messages.length,
        padding: const EdgeInsets.symmetric(vertical: 4),
        separatorBuilder: (context, idx) => Divider(
          height: 1,
          thickness: 0.6,
          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
        ),
        itemBuilder: (context, idx) {
          final msg = messages[idx];
          final isSelected = _selectedDesktopMessage?.id == msg.id;
          final displaySender = msg.sender.contains('@')
              ? msg.sender.split('@').first
              : msg.sender;
          final avatarLetter = displaySender.isNotEmpty
              ? displaySender[0].toUpperCase()
              : 'M';
          final displaySubject = msg.subject.trim().isNotEmpty
              ? msg.subject.trim()
              : 'No subject';

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                _openCasboxThreadPage(context, msg, isDark);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark
                          ? const Color(0xFF1E3A5F)
                          : const Color(0xFFEDF5FF))
                      : Colors.transparent,
                  border: isSelected
                      ? const Border(
                          left:
                              BorderSide(color: Color(0xFF195BAC), width: 3),
                        )
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? const Color(0xFF1E3A5F)
                                : const Color(0xFFDBEAFE),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            avatarLetter,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF195BAC),
                            ),
                          ),
                        ),
                        if (!msg.isRead)
                          Positioned(
                            top: -1,
                            right: -1,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF195BAC),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  displaySender,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: !msg.isRead
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                _formatMailDate(msg.timestamp),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displaySubject,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: !msg.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            msg.body.replaceAll('\n', ' '),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
      );
    }

    // Full Width Mail List View
    final allSelected =
        messages.isNotEmpty && _selectedIds.length == messages.length;
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 600;

    return Column(
      children: [
        // Subheader bar matching BNX Mail Inbox
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 8 : 16,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? BNXColors.darkSurface
                : const Color(0xFFF8FAFC),
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: allSelected,
                activeColor: const Color(0xFF195BAC),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedIds.addAll(messages.map((m) => m.id));
                    } else {
                      _selectedIds.clear();
                    }
                  });
                },
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _selectedIds.isNotEmpty
                      ? '${_selectedIds.length} SELECTED'
                      : 'INCOMING MESSAGES (${messages.length})',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedIds.isNotEmpty) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                  tooltip: 'Mark as read',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    for (final id in _selectedIds) {
                      ref.read(casboxMessagesProvider.notifier).markAsRead(id);
                    }
                    _clearSelection();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.archive_outlined, size: 18),
                  tooltip: 'Archive',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() {
                      _archivedIds.addAll(_selectedIds);
                    });
                    _clearSelection();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  tooltip: 'Delete',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    for (final id in _selectedIds) {
                      ref
                          .read(casboxMessagesProvider.notifier)
                          .deleteMessage(id);
                    }
                    _clearSelection();
                  },
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: messages.length,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemBuilder: (context, idx) {
              final msg = messages[idx];
              final isBulkSelected = _selectedIds.contains(msg.id);
              final isHovered = _hoveredMessageId == msg.id;
              final displaySender = msg.sender.contains('@')
                  ? msg.sender.split('@').first
                  : msg.sender;
              final avatarLetter = displaySender.isNotEmpty
                  ? displaySender[0].toUpperCase()
                  : 'M';
              final displaySubject = msg.subject.trim().isNotEmpty
                  ? msg.subject.trim()
                  : 'No subject';

              return MouseRegion(
                onEnter: (_) => setState(() => _hoveredMessageId = msg.id),
                onExit: (_) => setState(() {
                  if (_hoveredMessageId == msg.id) _hoveredMessageId = null;
                }),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    if (_selectedIds.isNotEmpty) {
                      setState(() {
                        if (_selectedIds.contains(msg.id)) {
                          _selectedIds.remove(msg.id);
                        } else {
                          _selectedIds.add(msg.id);
                        }
                      });
                    } else {
                      _openCasboxThreadPage(context, msg, isDark);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isBulkSelected
                          ? (isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFEAF1FB))
                          : (isHovered
                              ? (isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFF1F5F9))
                              : (isDark
                                  ? const Color(0xFF0F172A)
                                  : Colors.white)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isBulkSelected
                            ? const Color(0xFF195BAC).withValues(alpha: 0.4)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.shade200),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: isNarrow
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Unread dot
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 6, right: 6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: !msg.isRead
                                      ? const Color(0xFF195BAC)
                                      : Colors.transparent,
                                ),
                              ),
                              // 2. Star Icon
                              IconButton(
                                icon: Icon(
                                  msg.isStarred
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: msg.isStarred
                                      ? Colors.amber
                                      : (isDark
                                          ? Colors.white30
                                          : Colors.grey.shade400),
                                  size: 18,
                                ),
                                onPressed: () {
                                  ref
                                      .read(casboxMessagesProvider.notifier)
                                      .toggleStar(msg.id);
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 24, minHeight: 24),
                              ),
                              const SizedBox(width: 6),
                              // 3. Avatar or Checkbox
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (_selectedIds.contains(msg.id)) {
                                      _selectedIds.remove(msg.id);
                                    } else {
                                      _selectedIds.add(msg.id);
                                    }
                                  });
                                },
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: _selectedIds.isNotEmpty
                                      ? Checkbox(
                                          value: isBulkSelected,
                                          activeColor: const Color(0xFF195BAC),
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedIds.add(msg.id);
                                              } else {
                                                _selectedIds.remove(msg.id);
                                              }
                                            });
                                          },
                                        )
                                      : Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isDark
                                                ? const Color(0xFF1E3A5F)
                                                : const Color(0xFFDBEAFE),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            avatarLetter,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF195BAC),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // 4. Content Column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            displaySender,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: !msg.isRead
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                              color: !msg.isRead
                                                  ? (isDark
                                                      ? Colors.white
                                                      : const Color(
                                                          0xFF0F172A))
                                                  : (isDark
                                                      ? Colors.white70
                                                      : const Color(
                                                          0xFF475569)),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatMailDate(msg.timestamp),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: !msg.isRead
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isDark
                                                ? Colors.white38
                                                : Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      displaySubject,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: !msg.isRead
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1E293B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      msg.body.replaceAll('\n', ' '),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              // 1. Unread dot
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: !msg.isRead
                                      ? const Color(0xFF195BAC)
                                      : Colors.transparent,
                                ),
                              ),
                              // 2. Star Icon
                              IconButton(
                                icon: Icon(
                                  msg.isStarred
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: msg.isStarred
                                      ? Colors.amber
                                      : (isDark
                                          ? Colors.white30
                                          : Colors.grey.shade400),
                                  size: 20,
                                ),
                                onPressed: () {
                                  ref
                                      .read(casboxMessagesProvider.notifier)
                                      .toggleStar(msg.id);
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 12),
                              // 3. Checkbox or Avatar
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (_selectedIds.contains(msg.id)) {
                                      _selectedIds.remove(msg.id);
                                    } else {
                                      _selectedIds.add(msg.id);
                                    }
                                  });
                                },
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: (isHovered || _selectedIds.isNotEmpty)
                                      ? Checkbox(
                                          value: isBulkSelected,
                                          activeColor:
                                              const Color(0xFF195BAC),
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedIds.add(msg.id);
                                              } else {
                                                _selectedIds.remove(msg.id);
                                              }
                                            });
                                          },
                                        )
                                      : Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isDark
                                                ? const Color(0xFF1E3A5F)
                                                : const Color(0xFFDBEAFE),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            avatarLetter,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF195BAC),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // 4. Sender Name (flex 3)
                              Expanded(
                                flex: 3,
                                child: Text(
                                  displaySender,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: !msg.isRead
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: !msg.isRead
                                        ? (isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A))
                                        : (isDark
                                            ? Colors.white70
                                            : const Color(0xFF475569)),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // 5. Subject & Body Preview (flex 6)
                              Expanded(
                                flex: 6,
                                child: RichText(
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: displaySubject,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: !msg.isRead
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            ' — ${msg.body.replaceAll('\n', ' ')}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.normal,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // 6. Request tag chip (if pending request)
                              if (msg.status.toUpperCase() == 'PENDING' ||
                                  msg.status.toUpperCase() == 'REQUEST') ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF195BAC)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Request',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF195BAC),
                                    ),
                                  ),
                                ),
                              ],
                              // 7. Attachment icon
                              if (msg.attachments.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.attachment_rounded,
                                  size: 15,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.grey.shade500,
                                ),
                              ],
                              const SizedBox(width: 12),
                              // 8. Date or Quick Hover Actions
                              if (isHovered) ...[
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        !msg.isRead
                                            ? Icons.mark_email_read_outlined
                                            : Icons.mark_email_unread_outlined,
                                        size: 16,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.grey.shade700,
                                      ),
                                      tooltip: !msg.isRead
                                          ? 'Mark as read'
                                          : 'Mark as unread',
                                      onPressed: () {
                                        if (!msg.isRead) {
                                          ref
                                              .read(
                                                  casboxMessagesProvider.notifier)
                                              .markAsRead(msg.id);
                                        }
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 26, minHeight: 26),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.archive_outlined,
                                        size: 16,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.grey.shade700,
                                      ),
                                      tooltip: 'Archive',
                                      onPressed: () {
                                        setState(() {
                                          _archivedIds.add(msg.id);
                                        });
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 26, minHeight: 26),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 16,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.grey.shade700,
                                      ),
                                      tooltip: 'Delete',
                                      onPressed: () {
                                        ref
                                            .read(
                                                casboxMessagesProvider.notifier)
                                            .deleteMessage(msg.id);
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 26, minHeight: 26),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Text(
                                  _formatMailDate(msg.timestamp),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: !msg.isRead
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              );
            },
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _activeTab == 'Requests'
                  ? Icons.person_add_outlined
                  : (_activeTab == 'Combined Chat'
                      ? Icons.mark_email_read_outlined
                      : (_activeTab == 'Archived'
                          ? Icons.archive_outlined
                          : Icons.mail_outline_rounded)),
              size: 40,
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              _activeTab == 'Requests'
                  ? 'No pending requests'
                  : (_activeTab == 'Combined Chat'
                      ? 'No incoming messages in Combined Chat'
                      : (_activeTab == 'Archived'
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

    bool isSentByMe(CasboxMessage m) {
      final s = m.sender.toLowerCase().trim();
      if (s == 'me' || s == 'ravi' || m.id.startsWith('local_')) return true;
      if (currentUserEmail.isEmpty) return false;
      if (s == currentUserEmail) return true;
      final sHandle = s.contains('@') ? s.split('@').first : s;
      final meHandle = currentUserEmail.contains('@')
          ? currentUserEmail.split('@').first
          : currentUserEmail;
      return sHandle.isNotEmpty && sHandle == meHandle;
    }

    String getContactEmail(CasboxMessage m) {
      final target = isSentByMe(m) ? m.to : m.sender;
      return target.trim();
    }

    // Group messages by contact account so each chat thread appears once
    final Map<String, List<CasboxMessage>> accountChats = {};
    for (final msg in messages) {
      final contactEmail = getContactEmail(msg);
      if (contactEmail.isEmpty) continue;
      final contactKey = contactEmail.contains('@')
          ? contactEmail.split('@').first.toLowerCase()
          : contactEmail.toLowerCase();
      accountChats.putIfAbsent(contactKey, () => []).add(msg);
    }

    final chatGroups = accountChats.entries.map((entry) {
      final threadMsgs = entry.value;
      threadMsgs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final latestMsg = threadMsgs.first;
      final unreadCount =
          threadMsgs.where((m) => !isSentByMe(m) && !m.isRead).length;
      final otherEmail = getContactEmail(latestMsg);
      final displayTitle = otherEmail.contains('@')
          ? otherEmail.split('@').first
          : otherEmail;
      return (
        contactKey: entry.key,
        contactEmail: otherEmail,
        displayTitle: displayTitle,
        threadMsgs: threadMsgs,
        latestMsg: latestMsg,
        unreadCount: unreadCount,
      );
    }).toList();

    // Sort accounts so the ones with the latest message appear on top
    chatGroups.sort(
      (a, b) => b.latestMsg.timestamp.compareTo(a.latestMsg.timestamp),
    );

    return ListView.separated(
      itemCount: chatGroups.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      separatorBuilder: (context, idx) => Divider(
        height: 1,
        thickness: 0.6,
        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
      ),
      itemBuilder: (context, idx) {
        final chat = chatGroups[idx];
        final latestMsg = chat.latestMsg;
        final sentByMe = isSentByMe(latestMsg);
        final isSelected = _selectedDesktopMessage?.id == latestMsg.id;
        final avatarLetter = chat.displayTitle.isNotEmpty
            ? chat.displayTitle[0].toUpperCase()
            : 'C';

        final int hour = latestMsg.timestamp.toLocal().hour;
        final int hour12 = hour % 12 == 0 ? 12 : hour % 12;
        final String ampm = hour >= 12 ? 'PM' : 'AM';
        final timeStr =
            '$hour12:${latestMsg.timestamp.toLocal().minute.toString().padLeft(2, '0')} $ampm';

        final bodySnippet = sentByMe
            ? 'You: ${latestMsg.body}'
            : latestMsg.body;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedDesktopMessage = latestMsg;
              });
              ref.read(selectedCasboxThreadProvider.notifier).state = latestMsg.id;
              if (chat.contactEmail.isNotEmpty) {
                ref
                    .read(casboxMessagesProvider.notifier)
                    .fetchThreadMessages(chat.contactEmail);
                ref
                    .read(casboxMessagesProvider.notifier)
                    .markThreadAsSeen(chat.contactEmail);
              }
              for (final m in chat.threadMsgs) {
                if (!isSentByMe(m) && !m.isRead) {
                  ref.read(casboxMessagesProvider.notifier).markAsRead(m.id);
                }
              }
              _scrollToBottom();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFEAF2FF))
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  // Circle Avatar with Letter matching Screenshot 1
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? const Color(0xFF1E3A5F)
                          : const Color(0xFFDBEAFE),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      avatarLetter,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF195BAC),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chat.displayTitle,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: chat.unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          bodySnippet,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white60
                                : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.more_vert_rounded,
                            size: 15,
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade400,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (sentByMe)
                        Builder(
                          builder: (_) {
                            final status = latestMsg.status.toUpperCase();
                            if (latestMsg.isRead ||
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
                          },
                        )
                      else if (_activeTab == 'Requests' && !sentByMe) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () {
                                ref
                                    .read(casboxMessagesProvider.notifier)
                                    .deleteMessage(latestMsg.id);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Reject',
                                  style: TextStyle(fontSize: 11.5)),
                            ),
                            const SizedBox(width: 4),
                            ElevatedButton(
                              onPressed: () {
                                ref
                                    .read(casboxMessagesProvider.notifier)
                                    .acceptRequest(latestMsg.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Request accepted!'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF195BAC),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Accept',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ] else if (chat.unreadCount > 0)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF195BAC),
                          ),
                        )
                      else
                        const SizedBox(height: 8),
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

  Widget _buildDesktopChatConversationView(
    bool isDark,
    CasboxMessage selectedMsg,
    List<CasboxMessage> allMessages,
    AccountModel activeAccount,
  ) {
    final currentUserEmail = activeAccount.email.toLowerCase().trim();
    bool isSentByMe(CasboxMessage m) {
      final s = m.sender.toLowerCase().trim();
      if (s == 'me' || s == 'ravi' || m.id.startsWith('local_')) return true;
      if (currentUserEmail.isEmpty) return false;
      if (s == currentUserEmail) return true;
      final sHandle = s.contains('@') ? s.split('@').first : s;
      final meHandle = currentUserEmail.contains('@')
          ? currentUserEmail.split('@').first
          : currentUserEmail;
      return sHandle.isNotEmpty && sHandle == meHandle;
    }

    final otherEmail = isSentByMe(selectedMsg)
        ? selectedMsg.to
        : selectedMsg.sender;
    final otherName = otherEmail.contains('@')
        ? otherEmail.split('@').first
        : otherEmail;
    final avatarLetter = otherName.isNotEmpty
        ? otherName[0].toUpperCase()
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
    final isNarrow = screenWidth < 600;

    final isPendingRequest = (_activeTab == 'Requests' ||
            selectedMsg.status.toUpperCase() == 'PENDING' ||
            selectedMsg.status.toUpperCase() == 'REQUEST') &&
        !isSentByMe(selectedMsg);

    return Column(
      children: [
        // 1. Conversation Header matching Screenshot 2
        Container(
          height: 56,
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 16),
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
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                onPressed: () {
                  setState(() => _selectedDesktopMessage = null);
                  ref.read(selectedCasboxThreadProvider.notifier).state = null;
                },
                tooltip: 'Back to full list',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? const Color(0xFF1E3A5F)
                      : const Color(0xFFDBEAFE),
                ),
                alignment: Alignment.center,
                child: Text(
                  avatarLetter,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF195BAC),
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      otherName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      otherEmail.contains('@')
                          ? otherEmail
                          : '$otherEmail@bnxmail.com',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.move_to_inbox_outlined, size: 19),
                tooltip: 'Move to Inbox',
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: const Icon(Icons.archive_outlined, size: 19),
                tooltip: 'Archive',
                onPressed: () {
                  setState(() {
                    _archivedIds.add(selectedMsg.id);
                    _selectedDesktopMessage = null;
                  });
                  ref.read(selectedCasboxThreadProvider.notifier).state = null;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Archived conversation.')),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
                tooltip: 'Delete',
                onPressed: () {
                  ref
                      .read(casboxMessagesProvider.notifier)
                      .deleteMessage(selectedMsg.id);
                  setState(() => _selectedDesktopMessage = null);
                  ref.read(selectedCasboxThreadProvider.notifier).state = null;
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, size: 19),
                tooltip: 'More options',
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),

        // Incoming Request Banner if pending
        if (isPendingRequest)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 12 : 16,
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
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref
                        .read(casboxMessagesProvider.notifier)
                        .deleteMessage(selectedMsg.id);
                    setState(() => _selectedDesktopMessage = null);
                    ref.read(selectedCasboxThreadProvider.notifier).state = null;
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Reject',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                        horizontal: 14, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Accept',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

        // 2. Chat Messages Stream matching Screenshot 2
        Expanded(
          child: threadMessages.isEmpty
              ? Center(
                  child: Text(
                    'No message history with $otherName yet.',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _desktopChatScrollController,
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 12 : 20,
                    vertical: 16,
                  ),
                  itemCount: threadMessages.length,
                  itemBuilder: (context, idx) {
                    final m = threadMessages[idx];
                    final byMe = isSentByMe(m);
                    final senderDisplayName = byMe
                        ? (currentUserEmail.contains('@')
                            ? currentUserEmail.split('@').first
                            : (currentUserEmail.isNotEmpty
                                ? currentUserEmail
                                : 'Me'))
                        : otherName;
                    final senderAvatarLetter = senderDisplayName.isNotEmpty
                        ? senderDisplayName[0].toUpperCase()
                        : (byMe ? 'R' : 'C');

                    final int hour = m.timestamp.toLocal().hour;
                    final int hour12 = hour % 12 == 0 ? 12 : hour % 12;
                    final String ampm = hour >= 12 ? 'PM' : 'AM';
                    final time =
                        '$hour12:${m.timestamp.toLocal().minute.toString().padLeft(2, '0')} $ampm';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // SENDER BADGE PILL on the left matching Screenshot 2:
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isNarrow ? 8 : 10,
                              vertical: isNarrow ? 5 : 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
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
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark
                                        ? const Color(0xFF1E3A5F)
                                        : const Color(0xFFDBEAFE),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    senderAvatarLetter,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF195BAC),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF22C55E), // green online dot
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: isNarrow ? 70 : 120,
                                  ),
                                  child: Text(
                                    senderDisplayName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white70
                                          : const Color(0xFF1E293B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: isNarrow ? 10 : 20),
                          // MESSAGE BUBBLE + TIMESTAMP COLUMN matching Screenshot 2:
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  constraints: BoxConstraints(
                                    maxWidth: isNarrow
                                        ? (screenWidth - 140).clamp(160.0, 480.0)
                                        : screenWidth * 0.55,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: byMe
                                        ? const Color(0xFF0066FF)
                                        : (isDark
                                            ? const Color(0xFF1E293B)
                                            : Colors.white),
                                    borderRadius: BorderRadius.circular(16),
                                    border: byMe
                                        ? null
                                        : Border.all(
                                            color: isDark
                                                ? Colors.white12
                                                : const Color(0xFFE2E8F0),
                                            width: 1,
                                          ),
                                    boxShadow: byMe
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: isDark ? 0.2 : 0.04,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                  ),
                                  child: Text(
                                    m.body,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: byMe
                                          ? Colors.white
                                          : (isDark
                                              ? Colors.white
                                              : const Color(0xFF1E293B)),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      time,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                    if (byMe) ...[
                                      const SizedBox(width: 4),
                                      _buildChatTick(m, isDark),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // 3. Bottom Chat Input Bar matching Screenshot 2
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 10 : 16,
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
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
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
                        contentPadding: const EdgeInsets.symmetric(vertical: 11),
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
                  onTap: () =>
                      _sendDesktopCasboxMessage(otherEmail, selectedMsg.subject),
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

  Widget _buildChatTick(CasboxMessage msg, bool isDark) {
    final status = msg.status.trim().toUpperCase();
    if (msg.isRead || status == 'SEEN' || status == 'READ') {
      return const Icon(
        Icons.done_all_rounded,
        size: 13,
        color: Color(0xFF195BAC),
      );
    } else if (status == 'DELIVERED') {
      return Icon(
        Icons.done_all_rounded,
        size: 13,
        color: isDark ? Colors.white38 : Colors.grey.shade500,
      );
    } else {
      return Icon(
        Icons.done_rounded,
        size: 13,
        color: isDark ? Colors.white38 : Colors.grey.shade500,
      );
    }
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
    final other = initialMsg.sender.toLowerCase().trim() == 'me' ||
            initialMsg.sender.toLowerCase().trim() == 'ravi' ||
            initialMsg.id.startsWith('local_')
        ? initialMsg.to
        : initialMsg.sender;
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
      print('[COMMENT ERROR] Failed to send message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
          // Header
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
              padding: const EdgeInsets.all(16.0),
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
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
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
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.group.comments.length,
                    itemBuilder: (context, index) {
                      final c = widget.group.comments[index];
                      final active = widget.ref.read(activeAccountProvider);
                      final isMe =
                          c.sender == 'Ravi' ||
                          c.sender == active.name ||
                          c.sender == active.email;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe) ...[
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: BNXColors.lightPrimary
                                    .withValues(alpha: 0.2),
                                child: Text(
                                  c.sender.isNotEmpty
                                      ? c.sender[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: widget.isDark
                                        ? Colors.white
                                        : BNXColors.lightPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? BNXColors.lightPrimary
                                      : (widget.isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.08,
                                              )
                                            : Colors.grey[100]),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(14),
                                    topRight: const Radius.circular(14),
                                    bottomLeft: Radius.circular(isMe ? 14 : 0),
                                    bottomRight: Radius.circular(isMe ? 0 : 14),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isMe ? '${c.sender} (Me)' : c.sender,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: isMe
                                            ? Colors.white.withValues(
                                                alpha: 0.8,
                                              )
                                            : (widget.isDark
                                                  ? Colors.white60
                                                  : Colors.black54),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (c.message.isNotEmpty)
                                      Text(
                                        c.message,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isMe
                                              ? Colors.white
                                              : (widget.isDark
                                                    ? Colors.white
                                                    : BNXColors
                                                          .lightTextPrimary),
                                        ),
                                      ),
                                    if (c.attachments.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Column(
                                        crossAxisAlignment: isMe
                                            ? CrossAxisAlignment.end
                                            : CrossAxisAlignment.start,
                                        children: c.attachments.map((att) {
                                          return ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth: MediaQuery.of(context).size.width * 0.65,
                                            ),
                                            child: Container(
                                              margin: const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isMe
                                                    ? Colors.white.withValues(
                                                        alpha: 0.2,
                                                      )
                                                    : (widget.isDark
                                                          ? Colors.white12
                                                          : Colors.grey[300]),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .insert_drive_file_rounded,
                                                    size: 14,
                                                    color: isMe
                                                        ? Colors.white
                                                        : const Color(0xFF195BAC),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      att.fileName,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: isMe
                                                            ? Colors.white
                                                            : (widget.isDark
                                                                  ? Colors.white
                                                                  : Colors
                                                                        .black87),
                                                      ),
                                                    ),
                                                  ),
                                                  if (att
                                                      .fileSize
                                                      .isNotEmpty) ...[
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '(${att.fileSize})',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: isMe
                                                            ? Colors.white70
                                                            : (widget.isDark
                                                                  ? Colors.white60
                                                                  : Colors
                                                                        .black54),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),

          // Pending attachments bar
          if (_pendingAttachments.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: widget.isDark ? Colors.white10 : Colors.grey[100],
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _pendingAttachments.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final att = entry.value;
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.45,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.white12 : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: widget.isDark
                              ? Colors.white24
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.insert_drive_file_rounded,
                            size: 14,
                            color: Color(0xFF195BAC),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              att.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _pendingAttachments.removeAt(idx);
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
                    ),
                  );
                }).toList(),
              ),
            ),

          // Input bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.attach_file_rounded,
                    color: Color(0xFF195BAC),
                  ),
                  onPressed: () async {
                    try {
                      final result = await FilePicker.platform.pickFiles(
                        allowMultiple: true,
                      );
                      if (result != null && result.files.isNotEmpty) {
                        setState(() {
                          for (final file in result.files) {
                            _pendingAttachments.add(
                              AttachmentModel(
                                fileName: file.name,
                                fileType:
                                    file.extension?.toUpperCase() ?? 'FILE',
                                fileSize: file.size > 1024 * 1024
                                    ? '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB'
                                    : '${(file.size / 1024).toStringAsFixed(0)} KB',
                                filePath: file.path,
                              ),
                            );
                          }
                        });
                      }
                    } catch (e) {
                      print('[FILE PICKER ERROR] $e');
                    }
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    onSubmitted: (_) => _sendComment(),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    style: TextStyle(
                      color: widget.isDark
                          ? Colors.white
                          : BNXColors.lightTextPrimary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _sendComment,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: BNXColors.lightPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
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
      final contactEmail = initialMsg.to.isNotEmpty
          ? initialMsg.to
          : initialMsg.sender;
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
    final contactEmail = initialMsg.to.isNotEmpty
        ? initialMsg.to
        : initialMsg.sender;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobileDevice = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final isMobile = isMobileDevice ||
        (screenWidth < 800 &&
            defaultTargetPlatform != TargetPlatform.macOS &&
            defaultTargetPlatform != TargetPlatform.windows);

    final subjectText = initialMsg.subject.trim().isNotEmpty
        ? initialMsg.subject
        : 'new enter normal';
    final senderEmail = initialMsg.sender.trim().isNotEmpty
        ? initialMsg.sender
        : 'ravinew2004@bnxmail.com';
    final toEmail = initialMsg.to.trim().isNotEmpty
        ? initialMsg.to
        : 'ravikumar123@bnxmail.com';

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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                                      overflow:
                                                          TextOverflow.ellipsis,
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
                                                overflow: TextOverflow.ellipsis,
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
                                  color: isDark ? Colors.white : Colors.black87,
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
