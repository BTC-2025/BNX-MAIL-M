import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/ui_components.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/neumorphic.dart';
import '../../../data/app_state_provider.dart';
import '../../../data/account_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    if (uiState.activeFolder == 'Casbox') {
      return _buildCasboxView(context, ref, isDark, isMobile);
    }

    final selectedGroupId = ref.watch(selectedColabIdProvider);
    if (selectedGroupId != null) {
      return _buildColabDetailView(
        context,
        ref,
        selectedGroupId,
        isDark,
        isMobile,
      );
    }

    final groups = ref.watch(colabListProvider);
    final searchQuery = uiState.searchQuery.toLowerCase();
    final filteredGroups = groups.where((g) {
      return g.name.toLowerCase().contains(searchQuery) ||
          g.desc.toLowerCase().contains(searchQuery);
    }).toList();

    return Scaffold(
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
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
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
          backgroundColor: isDark
              ? BNXColors.darkSurface
              : const Color(0xFFE9F4FF),
          body: Column(
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
                          bottom: 84.0,
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
  bool _isRefreshing = false;
  bool _isLoading = true;
  String _activeTab = 'Received';
  Timer? _casboxPollingTimer;

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
    });
  }

  @override
  void dispose() {
    _casboxPollingTimer?.cancel();
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

  Widget _buildTabButton(String label, int count, bool isDark) {
    final bool isSelected = _activeTab == label;
    final Color activeColor = const Color(0xFF195BAC);

    return GestureDetector(
      onTap: () => setState(() => _activeTab = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : activeColor)
                    : (isDark ? Colors.white38 : Colors.grey.shade600),
              ),
            ),
            if (count >= 0) ...[
              const SizedBox(width: 4),
              Text(
                '($count)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                  color: isSelected
                      ? (isDark
                            ? Colors.white70
                            : activeColor.withValues(alpha: 0.7))
                      : (isDark ? Colors.white24 : Colors.grey.shade400),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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

    // ── Tab classification ──
    // fetchMessages() sets status to:
    //   ACCEPTED → old messages (before install) or locally accepted → Received
    //   PENDING  → new messages (after install) not yet accepted → Requests
    final rawReceived = filteredUserMessages
        .where((m) => !isSentByMe(m) && m.status.toUpperCase() == 'ACCEPTED')
        .toList();
    final rawRequests = filteredUserMessages
        .where(
          (m) =>
              !isSentByMe(m) &&
              (m.status.toUpperCase() == 'PENDING' ||
                  m.status.toUpperCase() == 'REQUEST'),
        )
        .toList();

    final receivedCount = rawReceived.where((m) => !m.isRead).length;
    final sentCount = -1;
    final requestsCount = rawRequests.length;

    final messages = filteredUserMessages.where((m) {
      if (_activeTab == 'Received') {
        return !isSentByMe(m) && m.status.toUpperCase() == 'ACCEPTED';
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

    final isSelectionMode = _selectedIds.isNotEmpty;
    final allSelected =
        messages.isNotEmpty && _selectedIds.length == messages.length;

    Widget headerWidget;
    if (isSelectionMode) {
      headerWidget = Container(
        key: const ValueKey('selection_header'),
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _clearSelection,
              tooltip: 'Clear selection',
            ),
            Checkbox(
              value: allSelected,
              activeColor: const Color(0xFF195BAC),
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
            const SizedBox(width: 4),
            Text(
              '${_selectedIds.length} selected',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF195BAC),
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.archive_outlined),
              onPressed: () {
                _clearSelection();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Archived casbox items.')),
                );
              },
              tooltip: 'Archive',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () {
                for (final id in _selectedIds) {
                  ref.read(casboxMessagesProvider.notifier).deleteMessage(id);
                }
                _clearSelection();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Deleted casbox items.')),
                );
              },
              tooltip: 'Delete',
            ),
            IconButton(
              icon: const Icon(Icons.mark_email_unread_outlined),
              onPressed: () {
                _clearSelection();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Marked as unread.')),
                );
              },
              tooltip: 'Mark as unread',
            ),
          ],
        ),
      );
    } else {
      headerWidget = Container(
        key: const ValueKey('normal_header'),
        color: isDark ? BNXColors.darkSurface : Colors.white,
        padding: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Open menu',
                ),
                const SizedBox(width: 4),
                Text(
                  'Casbox',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                  ),
                ),
                const Spacer(),
                if (_isRefreshing)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF195bac),
                      ),
                    ),
                  )
                else
                  IconButton(
                    onPressed: _triggerRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh',
                  ),
                GestureDetector(
                  onTap: () => context.push('/connect-settings'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF195BAC),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF195BAC,
                          ).withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_add_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Connect',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildTabButton('Received', receivedCount, isDark),
                    _buildTabButton('Sent', sentCount, isDark),
                    _buildTabButton('Requests', requestsCount, isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? BNXColors.darkBg : BNXColors.lightBg,
      body: SafeArea(
        bottom: false,
        child: Container(
          color: isDark ? BNXColors.darkBg : const Color(0xFFE9F4FF),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: headerWidget,
              ),
              Expanded(
                child: _buildMessageListContent(
                  isDark,
                  isSelectionMode,
                  messages,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageListContent(
    bool isDark,
    bool isSelectionMode,
    List<CasboxMessage> messages,
  ) {
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
                  : Icons.mail_outline_rounded,
              size: 48,
              color: isDark ? Colors.white10 : Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _activeTab == 'Requests'
                  ? 'No pending requests.'
                  : 'No Casbox secure messages.',
              style: TextStyle(color: isDark ? Colors.white30 : Colors.grey),
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

    return ListView.builder(
      itemCount: messages.length,
      padding: const EdgeInsets.only(
        left: 8.0,
        right: 8.0,
        top: 12.0,
        bottom: 88.0,
      ),
      itemBuilder: (context, idx) {
        final msg = messages[idx];
        final isChecked = _selectedIds.contains(msg.id);
        final sentByMe = isSentByMe(msg);
        String extractUsername(String email) {
          if (email.contains('@')) return email.split('@').first;
          return email;
        }

        final displayTitle = sentByMe
            ? (msg.to.isNotEmpty ? extractUsername(msg.to) : 'Support')
            : (msg.sender.isNotEmpty ? extractUsername(msg.sender) : 'Support');

        return Padding(
          padding: const EdgeInsets.only(bottom: 3.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? BNXColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
              ),
            ),
            child: InkWell(
              onTap: () {
                if (isSelectionMode) {
                  setState(() {
                    if (isChecked) {
                      _selectedIds.remove(msg.id);
                    } else {
                      _selectedIds.add(msg.id);
                    }
                  });
                } else {
                  _openCasboxThreadPage(context, msg, isDark);
                }
              },
              onLongPress: () {
                setState(() {
                  _selectedIds.add(msg.id);
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    if (isSelectionMode) ...[
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isChecked) {
                              _selectedIds.remove(msg.id);
                            } else {
                              _selectedIds.add(msg.id);
                            }
                          });
                        },
                        child: Icon(
                          isChecked
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          size: 22,
                          color: isChecked
                              ? const Color(0xFF195bac)
                              : (isDark
                                    ? Colors.white30
                                    : Colors.grey.shade400),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    GestureDetector(
                      onTap: () => ref
                          .read(casboxMessagesProvider.notifier)
                          .toggleStar(msg.id),
                      child: Icon(
                        msg.isStarred
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 22,
                        color: msg.isStarred
                            ? Colors.amber
                            : (isDark ? Colors.white38 : Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  displayTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${msg.timestamp.toLocal().hour.toString().padLeft(2, '0')}:${msg.timestamp.toLocal().minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            msg.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          if (!sentByMe &&
                              msg.status.toUpperCase() != 'ACCEPTED') ...[
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      ref
                                          .read(casboxMessagesProvider.notifier)
                                          .rejectRequest(msg.id);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Request rejected.'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.cancel_outlined,
                                      size: 14,
                                      color: Colors.red,
                                    ),
                                    label: const Text(
                                      'Reject',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Colors.red,
                                        width: 1,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      ref
                                          .read(casboxMessagesProvider.notifier)
                                          .acceptRequest(msg.id);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Request accepted! Moved to Received tab.',
                                          ),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Accept',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF195BAC),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (sentByMe) _buildDeliveryTickWidget(msg, isDark),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeliveryTickWidget(CasboxMessage msg, bool isDark) {
    final status = msg.status.trim().toUpperCase();
    if (msg.isRead ||
        status == 'READ' ||
        status == 'SEEN' ||
        status == 'ACCEPTED') {
      return const Icon(
        Icons.done_all_rounded,
        size: 16,
        color: Color(0xFF195BAC),
      );
    } else if (status == 'RESOLVED' || status == 'DELIVERED') {
      return Icon(
        Icons.done_all_rounded,
        size: 16,
        color: isDark ? Colors.white38 : Colors.grey.shade500,
      );
    } else {
      return Icon(
        Icons.check_rounded,
        size: 16,
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            _CasboxDetailPage(initialMsg: initialMsg, isDark: isDark),
      ),
    );
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
                                          return Container(
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
                  return Container(
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
      CasboxRepository.updateStatus(initialMsg.id, 'READ');
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
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 600;

    final subjectText = initialMsg.subject.trim().isNotEmpty
        ? initialMsg.subject
        : 'new enter normal';
    final senderEmail = initialMsg.sender.trim().isNotEmpty
        ? initialMsg.sender
        : 'ravinew2004@bnxmail.com';
    final toEmail = initialMsg.to.trim().isNotEmpty
        ? initialMsg.to
        : 'ravikumar123@bnxmail.com';

    return Scaffold(
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
                    icon: const Icon(Icons.close_rounded, size: 24),
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
    );
  }
}
