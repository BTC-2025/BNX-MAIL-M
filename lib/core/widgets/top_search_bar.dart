import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'profile_button.dart';
import '../../data/app_state_provider.dart';
import '../../data/notification_provider.dart';
import '../../data/email_provider.dart';
import 'create_label_dialog.dart';
import '../../features/inbox/presentation/snooze_scheduler_dialog.dart';
import '../../models/label_model.dart';
import '../theme/colors.dart';

class TopSearchBar extends ConsumerWidget implements PreferredSizeWidget {
  const TopSearchBar({super.key});

  // Always tall enough for search row + folder title row
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 44);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;
    final textController = TextEditingController(text: uiState.searchQuery);

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    textController.selection = TextSelection.fromPosition(
      TextPosition(offset: textController.text.length),
    );

    // Dynamic Header Switch: Selection Mode vs Search Mode
    if (uiState.isSelectionMode) {
      return _buildSelectionHeader(context, ref, uiState, isDark, isMobile);
    }

    // Determine if we should show a folder title below the search bar
    final bool showFolderTitle =
        !uiState.isSelectionMode &&
        uiState.searchQuery.isEmpty &&
        uiState.activeFolder != 'Inbox';
    final String folderTitle = uiState.activeLabel ?? uiState.activeFolder;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? BNXColors.darkBg : Colors.white,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search row ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: SizedBox(
              height: kToolbarHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () {
                        final scaffold = Scaffold.maybeOf(context);
                        if (scaffold != null && scaffold.hasDrawer) {
                          scaffold.openDrawer();
                        } else {
                          ref.read(appUiProvider.notifier).toggleSidebar();
                        }
                      },
                      tooltip: 'Main menu',
                    ),
                    SizedBox(width: isMobile ? 4 : 8),

                    Expanded(
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? BNXColors.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? BNXColors.darkBorder
                                : BNXColors.lightBorder,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.grey),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: textController,
                                onChanged: (val) {
                                  ref
                                      .read(appUiProvider.notifier)
                                      .setSearchQuery(val);
                                },
                                decoration: const InputDecoration(
                                  hintText: 'Search in emails',
                                  hintStyle: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : BNXColors.lightTextPrimary,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (uiState.searchQuery.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  ref
                                      .read(appUiProvider.notifier)
                                      .setSearchQuery('');
                                  textController.clear();
                                },
                              ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(width: isMobile ? 4 : 8),

                    // Reload icon
                    (() {
                      final activeFolder = ref.watch(appUiProvider).activeFolder;
                      final isRefreshing = ref.watch(emailProvider).isLoading;

                      return isRefreshing
                          ? const Padding(
                              padding: EdgeInsets.all(6),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF195BAC),
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.refresh_rounded,
                                size: 20,
                              ),
                              onPressed: () async {
                                final currentFolder =
                                    activeFolder.isNotEmpty ? activeFolder : 'Inbox';
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Refreshing $currentFolder...',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFF195BAC),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                await ref
                                    .read(emailProvider.notifier)
                                    .forceRefreshFolder(currentFolder);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Mailbox refreshed successfully ✓'),
                                      duration: Duration(seconds: 2),
                                      backgroundColor: Color(0xFF2E7D32),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              tooltip: 'Refresh Mailbox',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              color: isDark ? Colors.white70 : Colors.black87,
                            );
                    })(),

                    if (!isMobile) ...[
                      const SizedBox(width: 8),
                      // Bell icon with live unread badge
                      Builder(
                        builder: (ctx) {
                          final unreadCount = ref.watch(
                            unreadNotificationsCountProvider,
                          );
                          return Stack(
                            alignment: Alignment.topRight,
                            children: [
                              IconButton(
                                icon: Icon(
                                  uiState.activeRightUtility == 'Notifications'
                                      ? Icons.notifications_rounded
                                      : Icons.notifications_none_rounded,
                                  color:
                                      uiState.activeRightUtility ==
                                          'Notifications'
                                      ? (isDark
                                            ? BNXColors.darkPrimary
                                            : BNXColors.lightPrimary)
                                      : null,
                                ),
                                onPressed: () {
                                  ref
                                      .read(appUiProvider.notifier)
                                      .setActiveRightUtility('Notifications');
                                },
                                tooltip: 'Notification Centre',
                              ),
                              if (unreadCount > 0)
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: IgnorePointer(
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        unreadCount > 9 ? '9+' : '$unreadCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      const ProfileButton(),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ── Folder / Label title below search bar ────────────────────
          if (showFolderTitle)
            Padding(
              padding: EdgeInsets.only(
                left: isMobile ? 20 : 28,
                right: 16,
                top: 4,
                bottom: 8,
              ),
              child: Text(
                folderTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: 0.1,
                ),
              ),
            )
          else
            const SizedBox(height: 4), // reserve consistent height
        ],
      ),
    );
  }

  Widget _buildSelectionHeader(
    BuildContext context,
    WidgetRef ref,
    AppUiState uiState,
    bool isDark,
    bool isMobile,
  ) {
    final emails = ref.watch(emailListProvider);

    // Determine which emails are currently "visible" to select them all
    // Logic should match EmailListScreen's filtering logic for consistency
    final visibleEmailIds = emails
        .where((e) {
          if (uiState.activeLabel != null) {
            if (e.isTrash) return false;
            final labelQuery = uiState.activeLabel!.trim().toLowerCase();
            final customLabels = ref.watch(customLabelsProvider);
            final matchingLabel = customLabels.firstWhere(
              (l) =>
                  l.name.trim().toLowerCase() == labelQuery ||
                  l.id.trim().toLowerCase() == labelQuery,
              orElse: () => LabelModel(
                id: labelQuery,
                name: labelQuery,
                color: const Color(0xFF195BAC),
              ),
            );
            final targetId = matchingLabel.id.trim().toLowerCase();
            final targetName = matchingLabel.name.trim().toLowerCase();

            return e.labels.any((l) {
              final norm = l.trim().toLowerCase();
              return norm == targetId || norm == targetName;
            });
          }
          switch (uiState.activeFolder) {
            case 'Inbox':
              return !e.isTrash &&
                  !e.isDraft &&
                  !e.isSent &&
                  !e.isArchive &&
                  !e.isSpam;
            case 'Starred':
              return e.isStarred && !e.isTrash;
            case 'Sent':
              return e.isSent && !e.isTrash;
            case 'Draft':
              return e.isDraft && !e.isTrash;
            case 'Trash':
              return e.isTrash;
            case 'Archive':
              return e.isArchive && !e.isTrash;
            case 'Spam':
              return e.isSpam && !e.isTrash;
            default:
              return !e.isTrash;
          }
        })
        .map((e) => e.id)
        .toList();

    final allSelected =
        visibleEmailIds.isNotEmpty &&
        visibleEmailIds.every((id) => uiState.selectedEmailIds.contains(id));
    final isArchiveSection = uiState.activeFolder == 'Archive';
    final isTrashSection = uiState.activeFolder == 'Trash';

    return Container(
      color: isDark ? BNXColors.darkBg : const Color(0xFFF1F4F9),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () =>
                      ref.read(appUiProvider.notifier).clearSelection(),
                  tooltip: 'Clear selection',
                ),
                Checkbox(
                  value: allSelected,
                  activeColor: const Color(0xFF195BAC),
                  onChanged: (_) => ref
                      .read(appUiProvider.notifier)
                      .selectAllEmails(visibleEmailIds),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => ref
                      .read(appUiProvider.notifier)
                      .selectAllEmails(visibleEmailIds),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(
                      isMobile
                          ? '(${uiState.selectedEmailIds.length})'
                          : (allSelected
                                ? 'Unselect all (${uiState.selectedEmailIds.length})'
                                : 'Select all (${uiState.selectedEmailIds.length})'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF195BAC),
                      ),
                    ),
                  ),
                ),
                const Spacer(),

                if (isTrashSection) ...[
                  IconButton(
                    icon: const Icon(Icons.restore_from_trash_outlined),
                    onPressed: () {
                      for (final id in uiState.selectedEmailIds) {
                        ref.read(emailProvider.notifier).restoreEmail(id);
                      }
                      ref.read(appUiProvider.notifier).clearSelection();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Restored email(s) to Inbox.'),
                        ),
                      );
                    },
                    tooltip: 'Restore',
                    constraints: isMobile
                        ? const BoxConstraints(maxWidth: 36)
                        : null,
                    padding: isMobile
                        ? EdgeInsets.zero
                        : const EdgeInsets.all(8.0),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_forever_outlined),
                    onPressed: () {
                      for (final id in uiState.selectedEmailIds) {
                        ref
                            .read(emailProvider.notifier)
                            .permanentlyDeleteEmail(id, folder: uiState.activeFolder);
                      }
                      ref.read(appUiProvider.notifier).clearSelection();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Permanently deleted.'),
                        ),
                      );
                    },
                    tooltip: 'Delete Permanently',
                    constraints: isMobile
                        ? const BoxConstraints(maxWidth: 36)
                        : null,
                    padding: isMobile
                        ? EdgeInsets.zero
                        : const EdgeInsets.all(8.0),
                  ),
                ] else ...[
                  IconButton(
                    icon: Icon(
                      isArchiveSection ? Icons.unarchive_outlined : Icons.archive_outlined,
                    ),
                    onPressed: () {
                      for (final id in uiState.selectedEmailIds) {
                        if (isArchiveSection) {
                          ref.read(emailProvider.notifier).unarchiveEmail(id);
                        } else {
                          ref
                              .read(emailProvider.notifier)
                              .archiveEmail(id, uiState.activeFolder);
                        }
                      }
                      ref.read(appUiProvider.notifier).clearSelection();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isArchiveSection
                                ? 'Unarchived (Moved back to Inbox).'
                                : 'Archived.',
                          ),
                        ),
                      );
                    },
                    tooltip: isArchiveSection ? 'Unarchive' : 'Archive',
                    constraints: isMobile
                        ? const BoxConstraints(maxWidth: 36)
                        : null,
                    padding: isMobile
                        ? EdgeInsets.zero
                        : const EdgeInsets.all(8.0),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () {
                      for (final id in uiState.selectedEmailIds) {
                        ref.read(emailProvider.notifier).deleteEmail(id, uiState.activeFolder);
                      }
                      ref.read(appUiProvider.notifier).clearSelection();
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Deleted.')));
                    },
                    tooltip: 'Delete',
                    constraints: isMobile
                        ? const BoxConstraints(maxWidth: 36)
                        : null,
                    padding: isMobile
                        ? EdgeInsets.zero
                        : const EdgeInsets.all(8.0),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.mark_email_unread_outlined),
                  onPressed: () {
                    for (final id in uiState.selectedEmailIds) {
                      ref
                          .read(emailProvider.notifier)
                          .toggleRead(id, 'Inbox', forceValue: false);
                    }
                    ref.read(appUiProvider.notifier).clearSelection();
                  },
                  tooltip: 'Mark as unread',
                  constraints: isMobile
                      ? const BoxConstraints(maxWidth: 36)
                      : null,
                  padding: isMobile
                      ? EdgeInsets.zero
                      : const EdgeInsets.all(8.0),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  tooltip: 'More options',
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  offset: const Offset(0, 44),
                  onSelected: (val) {
                    if (val == 'snooze') {
                      if (uiState.selectedEmailIds.isNotEmpty) {
                        SnoozeSchedulerDialog.show(
                          context,
                          emailId: uiState.selectedEmailIds.first,
                          emailSubject:
                              '${uiState.selectedEmailIds.length} emails selected',
                        );
                      }
                    } else if (val == 'label') {
                      _showLabelAsDialog(context, ref, uiState.selectedEmailIds);
                    } else if (val == 'unsubscribe') {
                      for (final id in uiState.selectedEmailIds) {
                        ref
                            .read(emailProvider.notifier)
                            .markSpam(id, uiState.activeFolder);
                      }
                      ref.read(appUiProvider.notifier).clearSelection();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Unsubscribed and marked as spam.'),
                        ),
                      );
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem<String>(
                      value: 'snooze',
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 18),
                          SizedBox(width: 12),
                          Text('Snooze it...', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'label',
                      child: Row(
                        children: [
                          Icon(Icons.label_outlined, size: 18),
                          SizedBox(width: 12),
                          Text('Label as...', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'unsubscribe',
                      child: Row(
                        children: [
                          Icon(Icons.do_not_disturb_on_outlined, size: 18),
                          SizedBox(width: 12),
                          Text('Unsubscribe', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLabelAsDialog(
    BuildContext context,
    WidgetRef ref,
    Set<String> selectedIds,
  ) {
    final customLabels = ref.read(customLabelsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Label as...',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...customLabels.map(
              (l) => ListTile(
                leading: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: l.color,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(l.name),
                onTap: () {
                  final allLabels = ref.read(customLabelsProvider);
                  ref.read(emailProvider.notifier).bulkApplyLabel(
                        selectedIds.toList(),
                        l.name,
                        allLabels: allLabels,
                      );
                  ref.read(appUiProvider.notifier).clearSelection();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Applied label "${l.name}" to selected emails.'),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add, color: Color(0xFF2563EB)),
              title: const Text(
                'Create New Label',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                CreateLabelDialog.show(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
