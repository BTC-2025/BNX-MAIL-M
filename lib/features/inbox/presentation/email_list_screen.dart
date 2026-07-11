import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/email_provider.dart';
import '../../../data/app_state_provider.dart';
import '../../../core/widgets/email_tile.dart';
import '../../../core/widgets/email_body.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/neumorphic.dart';
import '../../../models/email_model.dart';
import '../../../data/account_provider.dart';
import 'templates_view.dart';

class EmailListScreen extends ConsumerWidget {
  const EmailListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(appUiProvider);
    final emails = ref.watch(emailProvider);
    final isDark = uiState.isDarkMode;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    // 1. FILTER EMAILS BY FOLDER / CATEGORY
    List<EmailModel> filtered = emails;

    if (uiState.activeLabel != null) {
      // Filter by label
      filtered = emails.where((e) => e.labels.contains(uiState.activeLabel) && !e.isTrash).toList();
    } else {
      // Filter by folder
      switch (uiState.activeFolder) {
        case 'Important':
          filtered = emails.where((e) => e.isStarred && !e.isTrash).toList();
          break;
        case 'Job Mails':
          final activeAccount = ref.watch(activeAccountProvider);
          final jobKeywords = activeAccount.getKeywords();
          filtered = emails.where((e) {
            if (e.isTrash) return false;
            final text = '${e.subject} ${e.body} ${e.senderName} ${e.senderEmail}'.toLowerCase();
            return jobKeywords.any((kw) => text.contains(kw));
          }).toList();
          break;
        case 'Purchases':
          filtered = emails.where((e) => e.labels.contains('Purchases') || e.subject.toLowerCase().contains('payment') || e.subject.toLowerCase().contains('order')).toList();
          break;
        case 'All inboxes':
          filtered = emails.where((e) => !e.isTrash && !e.isDraft).toList();
          break;
        case 'Outbox':
          filtered = emails.where((e) => e.isScheduled && !e.isTrash).toList();
          break;
        case 'Inbox':
          filtered = emails
              .where((e) => !e.isTrash && !e.isDraft && !e.isSent && !e.isArchive && !e.isSpam)
              .toList();
          break;
        case 'Starred':
          filtered = emails.where((e) => e.isStarred && !e.isTrash).toList();
          break;
        case 'Snoozed':
          filtered = emails.where((e) => e.isSnoozed && !e.isTrash).toList();
          break;
        case 'Sent':
          filtered = emails.where((e) => e.isSent && !e.isTrash).toList();
          break;
        case 'Draft':
          filtered = emails.where((e) => e.isDraft && !e.isTrash).toList();
          break;
        case 'Trash':
          filtered = emails.where((e) => e.isTrash).toList();
          break;
        case 'Archive':
          filtered = emails.where((e) => e.isArchive && !e.isTrash).toList();
          break;
        case 'Scheduled':
          filtered = emails.where((e) => e.isScheduled && !e.isTrash).toList();
          break;
        case 'Spam':
          filtered = emails.where((e) => e.isSpam && !e.isTrash).toList();
          break;
        case 'All Mail':
          filtered = emails.where((e) => !e.isTrash).toList();
          break;
        case 'Templates':
          filtered = emails.where((e) => e.isDraft && e.subject.toLowerCase().contains('template') && !e.isTrash).toList();
          break;
        case 'Subscriptions':
          filtered = emails.where((e) => e.senderEmail.contains('newsletter') || e.senderEmail.contains('digest') || e.senderEmail.contains('noreply')).toList();
          break;
        default:
          filtered = emails;
      }
    }

    // 2. FILTER EMAILS BY SEARCH QUERY
    if (uiState.searchQuery.isNotEmpty) {
      final query = uiState.searchQuery.toLowerCase();
      filtered = filtered.where((e) {
        return e.senderName.toLowerCase().contains(query) ||
            e.senderEmail.toLowerCase().contains(query) ||
            e.subject.toLowerCase().contains(query) ||
            e.body.toLowerCase().contains(query);
      }).toList();
    }

    // 3. HANDLE VIEW TOGGLING: DETAIL VIEW vs. LIST VIEW
    final Widget mainBody;

    if (uiState.activeFolder == 'Templates' && uiState.activeLabel == null) {
      mainBody = const TemplatesView();
    } else {
      // Otherwise render the Email List
      mainBody = Column(
        children: [
          // Inbox Header Toolbar (Select all, Refresh, More, Pagination)
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? BNXColors.darkBorder : BNXColors.lightBorder,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: uiState.selectedEmailIds.isEmpty
                      ? false
                      : (uiState.selectedEmailIds.length == filtered.length ? true : null),
                  tristate: true,
                  onChanged: (val) {
                    final emailIds = filtered.map((e) => e.id).toList();
                    ref.read(appUiProvider.notifier).selectAllEmails(emailIds);
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.arrow_drop_down, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (val) {
                    final emailIds = filtered.map((e) => e.id).toList();
                    if (val == 'all') {
                      ref.read(appUiProvider.notifier).selectAllEmails(emailIds);
                    } else if (val == 'none') {
                      ref.read(appUiProvider.notifier).clearSelection();
                    } else if (val == 'read') {
                      final readIds = filtered.where((e) => e.isRead).map((e) => e.id).toList();
                      ref.read(appUiProvider.notifier).selectAllEmails(readIds);
                    } else if (val == 'unread') {
                      final unreadIds = filtered.where((e) => !e.isRead).map((e) => e.id).toList();
                      ref.read(appUiProvider.notifier).selectAllEmails(unreadIds);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'all', child: Text('All')),
                    PopupMenuItem(value: 'none', child: Text('None')),
                    PopupMenuItem(value: 'read', child: Text('Read')),
                    PopupMenuItem(value: 'unread', child: Text('Unread')),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (uiState.selectedEmailIds.isNotEmpty) ...[
                          IconButton(
                            icon: const Icon(Icons.archive_outlined, size: 20),
                            tooltip: 'Archive',
                            onPressed: () {
                              for (final id in uiState.selectedEmailIds) {
                                ref.read(emailProvider.notifier).archiveEmail(id);
                              }
                              ref.read(appUiProvider.notifier).clearSelection();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Selected emails archived.')),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.report_gmailerrorred_rounded, size: 20),
                            tooltip: 'Report spam',
                            onPressed: () {
                              for (final id in uiState.selectedEmailIds) {
                                ref.read(emailProvider.notifier).archiveEmail(id);
                              }
                              ref.read(appUiProvider.notifier).clearSelection();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Selected emails marked as spam.')),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20),
                            tooltip: 'Delete',
                            onPressed: () {
                              for (final id in uiState.selectedEmailIds) {
                                ref.read(emailProvider.notifier).deleteEmail(id);
                              }
                              ref.read(appUiProvider.notifier).clearSelection();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Selected emails deleted.')),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.mark_email_read_outlined, size: 20),
                            tooltip: 'Mark as read',
                            onPressed: () {
                              for (final id in uiState.selectedEmailIds) {
                                ref.read(emailProvider.notifier).toggleRead(id, forceValue: true);
                              }
                              ref.read(appUiProvider.notifier).clearSelection();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Selected emails marked as read.')),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.mark_email_unread_outlined, size: 20),
                            tooltip: 'Mark as unread',
                            onPressed: () {
                              for (final id in uiState.selectedEmailIds) {
                                ref.read(emailProvider.notifier).toggleRead(id, forceValue: false);
                              }
                              ref.read(appUiProvider.notifier).clearSelection();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Selected emails marked as unread.')),
                              );
                            },
                          ),
                          PopupMenuButton<DateTime>(
                            icon: const Icon(Icons.access_time_rounded, size: 20),
                            tooltip: 'Snooze',
                            onSelected: (until) {
                              for (final id in uiState.selectedEmailIds) {
                                ref.read(emailProvider.notifier).snoozeEmail(id, until);
                              }
                              ref.read(appUiProvider.notifier).clearSelection();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Selected emails snoozed.')),
                              );
                            },
                            itemBuilder: (context) {
                              final now = DateTime.now();
                              return [
                                PopupMenuItem(
                                  value: DateTime(now.year, now.month, now.day, 18, 0),
                                  child: const Text('Later Today (6:00 PM)'),
                                ),
                                PopupMenuItem(
                                  value: DateTime(now.year, now.month, now.day + 1, 8, 0),
                                  child: const Text('Tomorrow Morning (8:00 AM)'),
                                ),
                                PopupMenuItem(
                                  value: DateTime(now.year, now.month, now.day + 7, 8, 0),
                                  child: const Text('Next Week (8:00 AM)'),
                                ),
                              ];
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.star_outline_rounded, size: 20),
                            tooltip: 'Star/Unstar',
                            onPressed: () {
                              for (final id in uiState.selectedEmailIds) {
                                ref.read(emailProvider.notifier).toggleStar(id);
                              }
                              ref.read(appUiProvider.notifier).clearSelection();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Toggled stars on selected emails.')),
                              );
                            },
                          ),
                        ] else ...[
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 20),
                            onPressed: () {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Checking for new emails...'),
                                    ],
                                  ),
                                  duration: Duration(milliseconds: 1500),
                                ),
                              );
                              Future.delayed(const Duration(milliseconds: 1500), () {
                                ref.read(emailProvider.notifier).receiveMockEmail();
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('New email received!')),
                                );
                              });
                            },
                            tooltip: 'Check new mail',
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            tooltip: 'More options',
                            onSelected: (value) {
                              if (value == 'Mark all as read') {
                                ref.read(emailProvider.notifier).markAllAsRead();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('All emails marked as read.')),
                                );
                              } else if (value == 'Sort by date') {
                                ref.read(emailProvider.notifier).sortByDate();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Sorted by date.')),
                                );
                              } else if (value == 'Sort by sender') {
                                ref.read(emailProvider.notifier).sortBySender();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Sorted by sender name.')),
                                );
                              } else if (value == 'Select all messages') {
                                final emailIds = filtered.map((e) => e.id).toList();
                                ref.read(appUiProvider.notifier).selectAllEmails(emailIds);
                              } else if (value == 'Filter unread only') {
                                ref.read(appUiProvider.notifier).setSearchQuery('unread');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Filtering unread emails (applied search query).')),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'Mark all as read', child: ListTile(leading: Icon(Icons.mark_email_read_outlined), title: Text('Mark all as read'), dense: true)),
                              const PopupMenuItem(value: 'Sort by date', child: ListTile(leading: Icon(Icons.sort_rounded), title: Text('Sort by date'), dense: true)),
                              const PopupMenuItem(value: 'Sort by sender', child: ListTile(leading: Icon(Icons.sort_by_alpha_rounded), title: Text('Sort by sender'), dense: true)),
                              const PopupMenuItem(value: 'Select all messages', child: ListTile(leading: Icon(Icons.select_all_rounded), title: Text('Select all messages'), dense: true)),
                              const PopupMenuItem(value: 'Filter unread only', child: ListTile(leading: Icon(Icons.filter_alt_outlined), title: Text('Filter unread only'), dense: true)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 16),
                  Text(
                    '1-${filtered.length} of ${filtered.length}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('You are on the first page.')),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No older emails available.')),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),

          // List Content
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState(uiState.activeFolder, isDark)
                : NotificationListener<UserScrollNotification>(
                    onNotification: (notification) {
                      if (notification.direction == ScrollDirection.reverse) {
                        if (ref.read(fabExtensionProvider)) {
                          ref.read(fabExtensionProvider.notifier).state = false;
                        }
                      } else if (notification.direction == ScrollDirection.forward) {
                        if (!ref.read(fabExtensionProvider)) {
                          ref.read(fabExtensionProvider.notifier).state = true;
                        }
                      }
                      return true;
                    },
                    child: ListView(
                      children: [
                        if (isMobile)
                          Padding(
                            padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
                            child: Text(
                              uiState.activeLabel != null 
                                  ? uiState.activeLabel!
                                  : (uiState.activeFolder == 'Inbox' ? 'Primary' : uiState.activeFolder),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white38 : Colors.grey.shade600,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        
                        if (uiState.activeFolder == 'Inbox' && uiState.searchQuery.isEmpty && uiState.activeLabel == null) ...[
                          _buildCategoryTile(
                            context: context,
                            icon: Icons.local_offer_outlined,
                            iconColor: Colors.green.shade700,
                            iconBgColor: isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.shade50,
                            title: 'Promotions',
                            subtitle: 'harsha — Due Diligence Analyst | ...',
                            onTap: () {
                              ref.read(appUiProvider.notifier).selectLabel('Promotions');
                            },
                            isDark: isDark,
                          ),
                          _buildCategoryTile(
                            context: context,
                            icon: Icons.info_outline,
                            iconColor: Colors.orange.shade700,
                            iconBgColor: isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange.shade50,
                            title: 'Updates',
                            subtitle: 'LinkedIn Job Alerts — Data...',
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.orange.withValues(alpha: 0.3) : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '2 new',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
                                ),
                              ),
                            ),
                            onTap: () {
                              ref.read(appUiProvider.notifier).selectLabel('Updates');
                            },
                            isDark: isDark,
                          ),
                        ],

                        ...filtered.map((email) {
                          return EmailTile(
                            email: email,
                            isSelected: uiState.selectedEmailId == email.id,
                            onTap: () {
                              context.push('/email/${email.id}');
                            },
                          );
                        }),
                      ],
                    ),
                  ),
          ),
        ],
      );
    }

    return mainBody;
  }

  Widget _buildCategoryTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: NeumorphicButton(
        onPressed: onTap,
        borderRadius: 14,
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NeumorphicContainer(
              width: 40,
              height: 40,
              boxShape: BoxShape.circle,
              shape: NeumorphicShape.pressed,
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
              child: Center(
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String folder, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : BNXColors.lightBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mail_outline_rounded,
              size: 48,
              color: isDark ? Colors.white30 : Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No emails in $folder',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Everything is clear and up to date!',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
