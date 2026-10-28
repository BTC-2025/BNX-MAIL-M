import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'avatar_widget.dart';
import 'label_chip.dart';
import '../../models/email_model.dart';
import '../../models/attachment_model.dart';
import '../../models/label_model.dart';
import '../../data/email_provider.dart';
import '../../data/all_inboxes_provider.dart';
import '../../data/app_state_provider.dart';
import '../../data/repositories/mail_repository.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../network/token_service.dart';
import '../theme/colors.dart';
import '../theme/neumorphic.dart';

import 'create_label_dialog.dart';
import '../../features/ai/presentation/ai_smart_reply_bar.dart';
import '../../features/inbox/presentation/snooze_scheduler_dialog.dart';
import 'email_html_view.dart';
import '../../data/account_provider.dart';
import '../../data/subscription_provider.dart';

class EmailBody extends ConsumerWidget {
  final String emailId;

  static final Set<String> _handledDetailIds = {};

  const EmailBody({super.key, required this.emailId});

  String _formatFullDate(DateTime date) {
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
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final min = date.minute.toString().padLeft(2, '0');
    return '${months[date.month - 1]} ${date.day}, ${date.year}, $hour:$min $period';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    final emails = ref.watch(emailListProvider);
    final allInboxes = ref.watch(allInboxesProvider).emails;
    final combined = [...emails, ...allInboxes];
    final email = combined.firstWhere(
      (e) => e.id == emailId,
      orElse: () => EmailModel(
        id: 'error',
        senderName: 'System',
        senderEmail: 'system@bnxmail.com',
        recipient: 'user@bnxmail.com',
        subject: 'Email Not Found',
        body: 'The requested email was not found or was permanently deleted.',
        date: DateTime.now(),
      ),
    );

    final activeAccount = ref.watch(activeAccountProvider);
    final subscriptionState = ref.watch(subscriptionProvider);
    final senderEmailClean = email.senderEmail.trim().toLowerCase();
    final isUnsubscribed =
        subscriptionState.blockedEmailsSet.contains(senderEmailClean);
    final isPending =
        subscriptionState.pendingEmails.contains(senderEmailClean);
    final isOwnEmail = email.isSent ||
        senderEmailClean == activeAccount.email.trim().toLowerCase();

    final bool needsFullDetails = email.id != 'error' &&
        !_handledDetailIds.contains(email.id) &&
        (email.htmlBody.isEmpty ||
            !EmailHtmlView.looksLikeHtml(email.htmlBody));

    if (needsFullDetails) {
      _handledDetailIds.add(email.id);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final currentFolder = (email.memberOfFolders.isNotEmpty &&
                email.memberOfFolders.first != 'All Inboxes' &&
                email.memberOfFolders.first != 'All inboxes')
            ? email.memberOfFolders.first
            : (uiState.activeFolder != 'All Inboxes' &&
                    uiState.activeFolder != 'All inboxes'
                ? uiState.activeFolder
                : 'Inbox');

        String? ownerToken;
        final ownerEmail = email.ownerEmail;
        if (ownerEmail != null && ownerEmail.isNotEmpty) {
          final registry = await TokenService.getSavedAccountsFromRegistry();
          for (final item in registry) {
            final regEmail = item['email']?.toString().trim().toLowerCase() ?? '';
            if (regEmail == ownerEmail.trim().toLowerCase()) {
              ownerToken = item['accessToken']?.toString();
              break;
            }
          }
        }

        if (ownerToken != null && ownerToken.isNotEmpty) {
          try {
            final detail = await MailRepository.fetchEmail(
              email.id,
              folder: currentFolder,
              tempToken: ownerToken,
            );
            if (detail != null) {
              ref.read(allInboxesProvider.notifier).updateEmail(detail);
            }
          } on ApiException catch (e) {
            if (e.isNotFound) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'This email is no longer available. Refreshing $currentFolder...',
                    ),
                    duration: const Duration(seconds: 4),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                if (email.body.isEmpty && email.htmlBody.isEmpty) {
                  Navigator.of(context).maybePop();
                }
              }
              ref.read(emailProvider.notifier).forceRefreshFolder(currentFolder);
            }
          } catch (_) {}
        } else {
          ref.read(emailProvider.notifier).fetchFullEmailDetails(
            email.id,
            currentFolder,
            onStaleEmail: (msg) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(msg),
                    duration: const Duration(seconds: 4),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                if (email.body.isEmpty && email.htmlBody.isEmpty) {
                  Navigator.of(context).maybePop();
                }
              }
            },
          );
        }
      });
    }

    // Action Toolbar
    Widget buildToolbar() {
      final isCurrentlyArchived =
          email.isArchive || email.memberOfFolders.contains('Archive');
      final isCurrentlyTrash =
          email.isTrash || email.memberOfFolders.contains('Trash') || uiState.activeFolder == 'Trash';
      return Container(
        height: 48,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? BNXColors.darkBorder : BNXColors.lightBorder,
              width: 1,
            ),
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            iconButtonTheme: IconButtonThemeData(
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  context.pop();
                },
                tooltip: 'Back to list',
              ),
              if (isCurrentlyTrash) ...[
                IconButton(
                  icon: const Icon(Icons.restore_from_trash_outlined),
                  onPressed: () {
                    ref.read(emailProvider.notifier).restoreEmail(email.id);
                    context.pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Restored email to Inbox.'),
                      ),
                    );
                  },
                  tooltip: 'Restore',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_forever_outlined),
                  onPressed: () {
                    ref
                        .read(emailProvider.notifier)
                        .permanentlyDeleteEmail(email.id, folder: uiState.activeFolder);
                    context.pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Permanently deleted.'),
                      ),
                    );
                  },
                  tooltip: 'Delete permanently',
                ),
              ] else ...[
                IconButton(
                  icon: Icon(
                    isCurrentlyArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  onPressed: () {
                    if (isCurrentlyArchived) {
                      ref.read(emailProvider.notifier).unarchiveEmail(email.id);
                    } else {
                      ref
                          .read(emailProvider.notifier)
                          .archiveEmail(email.id, uiState.activeFolder);
                    }
                    context.pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isCurrentlyArchived
                              ? 'Email unarchived (moved to Inbox).'
                              : 'Email archived.',
                        ),
                      ),
                    );
                  },
                  tooltip: isCurrentlyArchived ? 'Unarchive' : 'Archive',
                ),
                if (uiState.activeFolder != 'All Inboxes' && uiState.activeFolder != 'All inboxes')
                  IconButton(
                    icon: Icon(
                      email.isRead
                          ? Icons.mark_email_unread_outlined
                          : Icons.mark_email_read_outlined,
                    ),
                    onPressed: () {
                      ref.read(emailProvider.notifier).toggleRead(email.id, uiState.activeFolder);
                      context.pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            email.isRead ? 'Marked as unread.' : 'Marked as read.',
                          ),
                        ),
                      );
                    },
                    tooltip: email.isRead ? 'Mark as unread' : 'Mark as read',
                  ),
                IconButton(
                  icon: const Icon(Icons.access_time_rounded),
                  onPressed: () {
                    SnoozeSchedulerDialog.show(
                      context,
                      emailId: email.id,
                      emailSubject: email.subject,
                    );
                  },
                  tooltip: 'Snooze',
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.label_outlined),
                  tooltip: 'Labels',
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  offset: const Offset(0, 44),
                  onSelected: (value) {
                    if (value == '__create_new_label__') {
                      CreateLabelDialog.show(context);
                    } else {
                      ref
                          .read(emailProvider.notifier)
                          .toggleEmailLabel(email.id, value);
                    }
                  },
                  itemBuilder: (context) {
                    final customLabels = ref.read(customLabelsProvider);
                    final List<PopupMenuEntry<String>> items = [];

                    for (final l in customLabels) {
                      final isApplied = email.labels.contains(l.name);
                      items.add(
                        PopupMenuItem<String>(
                          value: l.name,
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: l.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  l.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              if (isApplied)
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

                    items.add(const PopupMenuDivider(height: 8));
                    items.add(
                      PopupMenuItem<String>(
                        value: '__create_new_label__',
                        child: const Row(
                          children: [
                            Icon(Icons.add, size: 18, color: Color(0xFF2563EB)),
                            SizedBox(width: 10),
                            Text(
                              'Create New Label',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    return items;
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () {
                    ref.read(emailProvider.notifier).deleteEmail(email.id, uiState.activeFolder);
                    context.pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Moved to trash.')),
                    );
                  },
                  tooltip: 'Delete',
                ),
              ],
              const VerticalDivider(width: 12, indent: 12, endIndent: 12),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'More',
              onSelected: (value) {
                if (value == 'Mark unread') {
                  ref
                      .read(emailProvider.notifier)
                      .toggleRead(email.id, 'Inbox', forceValue: false);
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Marked as unread.')),
                  );
                } else if (value == 'Star' || value == 'Unstar') {
                  ref
                      .read(emailProvider.notifier)
                      .toggleStar(email.id, 'Inbox');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        email.isStarred ? 'Star removed.' : 'Starred.',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } else if (value == 'Spam') {
                  ref
                      .read(emailProvider.notifier)
                      .markSpam(email.id, uiState.activeFolder);
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reported as spam.')),
                  );
                } else if (value == 'Mute') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Muted conversation.')),
                  );
                } else if (value == 'Print') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Print setup initialized.')),
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'Mark unread',
                  child: Row(
                    children: [
                      Icon(
                        Icons.mark_email_unread_outlined,
                        size: 18,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      const SizedBox(width: 12),
                      const Text('Mark as unread'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: email.isStarred ? 'Unstar' : 'Star',
                  child: Row(
                    children: [
                      Icon(
                        email.isStarred
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 18,
                        color: email.isStarred
                            ? BNXColors.starActive
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      const SizedBox(width: 12),
                      Text(email.isStarred ? 'Remove star' : 'Add star'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'Spam',
                  child: Row(
                    children: [
                      Icon(
                        Icons.report_gmailerrorred_rounded,
                        size: 18,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      const SizedBox(width: 12),
                      const Text('Report spam'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'Mute',
                  child: Row(
                    children: [
                      Icon(
                        Icons.volume_off_rounded,
                        size: 18,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      const SizedBox(width: 12),
                      const Text('Mute'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'Print',
                  child: Row(
                    children: [
                      Icon(
                        Icons.print_rounded,
                        size: 18,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      const SizedBox(width: 12),
                      const Text('Print'),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Unread count status indicator
            IconButton(
              icon: Icon(
                email.isStarred
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: email.isStarred
                    ? BNXColors.starActive
                    : BNXColors.starInactive,
              ),
              onPressed: () {
                ref.read(emailProvider.notifier).toggleStar(email.id, 'Inbox');
              },
              tooltip: email.isStarred ? 'Unstar' : 'Star',
            ),
          ],
        ),
      ),
    );
  }
    // Email Headers
    Widget buildHeaderSection() {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (email.isScheduled || email.memberOfFolders.contains('Scheduled')) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF195BAC).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_send_rounded,
                      color: Color(0xFF195BAC),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Scheduled to send at ${email.date.day.toString().padLeft(2, '0')}-${email.date.month.toString().padLeft(2, '0')}-${email.date.year} ${email.date.hour.toString().padLeft(2, '0')}:${email.date.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Color(0xFF195BAC),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        ref
                            .read(emailProvider.notifier)
                            .sendScheduledEmailNow(email);
                        context.pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sending scheduled mail now...'),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.send_rounded,
                        size: 14,
                        color: Color(0xFF195BAC),
                      ),
                      label: const Text(
                        'Send Now',
                        style: TextStyle(
                          color: Color(0xFF195BAC),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Colors.red,
                      ),
                      tooltip: 'Cancel Schedule',
                      onPressed: () {
                        ref
                            .read(emailProvider.notifier)
                            .cancelScheduledEmail(email.id);
                        context.pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Schedule cancelled.'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    email.subject,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                if (email.labels.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  () {
                    final customLabels = ref.watch(customLabelsProvider);
                    return Wrap(
                      spacing: 4,
                      children: email.labels.map((l) {
                        final matched = customLabels.firstWhere(
                          (cl) =>
                              cl.name.trim().toLowerCase() == l.trim().toLowerCase() ||
                              cl.id.trim().toLowerCase() == l.trim().toLowerCase(),
                          orElse: () => LabelModel(
                            id: l,
                            name: l,
                            color: const Color(0xFF195BAC),
                          ),
                        );
                        return LabelChip(
                          labelName: matched.name,
                          customColor: matched.color,
                        );
                      }).toList(),
                    );
                  }(),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AvatarWidget(name: email.senderName, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              email.senderName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '<${email.senderEmail}>',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? BNXColors.darkTextSecondary
                                    : BNXColors.lightTextSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isOwnEmail &&
                              email.senderEmail.trim().isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _buildUnsubscribeBadge(
                              context: context,
                              ref: ref,
                              email: email,
                              isUnsubscribed: isUnsubscribed,
                              isPending: isPending,
                              isDark: isDark,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'to ${email.recipient.isEmpty ? "me" : email.recipient}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isMobile) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatFullDate(email.date),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? BNXColors.darkTextSecondary
                                : BNXColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isMobile) ...[
                      Text(
                        _formatFullDate(email.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? BNXColors.darkTextSecondary
                              : BNXColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (value) {
                        if (value == 'Reply') {
                          ref
                              .read(appUiProvider.notifier)
                              .updateComposeDraft(
                                to: email.senderEmail,
                                subject: 'Re: ${email.subject}',
                              );
                          ref
                              .read(appUiProvider.notifier)
                              .setComposeStatus(ComposeStatus.normal);
                        } else if (value == 'Forward') {
                          ref
                              .read(appUiProvider.notifier)
                              .updateComposeDraft(
                                subject: 'Fwd: ${email.subject}',
                                body:
                                    '\n\n---------- Forwarded message ---------\nFrom: ${email.senderName} <${email.senderEmail}>\nDate: ${_formatFullDate(email.date)}\nSubject: ${email.subject}\n\n${email.body}',
                              );
                          ref
                              .read(appUiProvider.notifier)
                              .setComposeStatus(ComposeStatus.normal);
                        } else if (value == 'Add star' ||
                            value == 'Remove star') {
                          ref
                              .read(emailProvider.notifier)
                              .toggleStar(email.id, 'Inbox');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                email.isStarred ? 'Star removed.' : 'Starred.',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } else if (value == 'Mark unread from here') {
                          ref
                              .read(emailProvider.notifier)
                              .toggleRead(email.id, 'Inbox', forceValue: false);
                          context.pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Marked as unread.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        } else if (value == 'Translate') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Translate option is not fully integrated yet.',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        } else if (value == 'Print') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Print layout generated.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        } else if (value == 'Block') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Sender "${email.senderName}" has been blocked.',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } else if (value == 'Report spam') {
                          ref
                              .read(emailProvider.notifier)
                              .markSpam(email.id, uiState.activeFolder);
                          context.pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Email reported as spam and archived.',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'Reply',
                          child: Row(
                            children: [
                              Icon(Icons.reply_rounded, size: 18),
                              SizedBox(width: 12),
                              Text('Reply'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'Forward',
                          child: Row(
                            children: [
                              Icon(Icons.forward_rounded, size: 18),
                              SizedBox(width: 12),
                              Text('Forward'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: email.isStarred ? 'Remove star' : 'Add star',
                          child: Row(
                            children: [
                              Icon(
                                email.isStarred
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 18,
                                color: email.isStarred
                                    ? BNXColors.starActive
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                email.isStarred ? 'Remove star' : 'Add star',
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'Mark unread from here',
                          child: Row(
                            children: [
                              Icon(Icons.mark_as_unread_rounded, size: 18),
                              SizedBox(width: 12),
                              Text('Mark unread from here'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'Translate',
                          child: Row(
                            children: [
                              Icon(Icons.g_translate_rounded, size: 18),
                              SizedBox(width: 12),
                              Text('Translate'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'Print',
                          child: Row(
                            children: [
                              Icon(Icons.print_rounded, size: 18),
                              SizedBox(width: 12),
                              Text('Print'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'Block',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.block_rounded,
                                size: 18,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Block "${email.senderName}"',
                                  style: const TextStyle(color: Colors.red),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'Report spam',
                          child: Row(
                            children: [
                              Icon(
                                Icons.report_gmailerrorred_rounded,
                                size: 18,
                                color: Colors.red,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Report spam',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget buildPlaceholderPreview(AttachmentModel att, bool isDark) {
      final isPdf = att.fileType == 'PDF' || att.fileName.toLowerCase().endsWith('.pdf');
      return Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPdf ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
              size: 48,
              color: isPdf ? Colors.red : const Color(0xFF195BAC),
            ),
            const SizedBox(height: 8),
            Text(
              att.fileName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            Text(
              att.fileType,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    final attachmentFolder = email.isSent
        ? 'Sent'
        : email.isTrash
            ? 'Trash'
            : email.isArchive
                ? 'Archive'
                : email.isDraft
                    ? 'Drafts'
                    : 'INBOX';

    Future<void> triggerAttachmentDownload(BuildContext context, AttachmentModel att) async {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Downloading "${att.fileName}"...')),
            ],
          ),
          duration: const Duration(seconds: 15),
        ),
      );

      final savedPath = await AttachmentDownloader.downloadAndSave(
        att,
        emailId: email.id,
        folder: attachmentFolder,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (savedPath != null) {
        final displayName = savedPath.split(Platform.pathSeparator).last;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✓ Downloaded $displayName', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(savedPath, style: const TextStyle(fontSize: 11, color: Colors.white70), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Failed to download ${att.fileName}. Please check connection.'),
          ),
        );
      }
    }

    void showAttachmentPreviewDialog(BuildContext context, AttachmentModel att, bool isDark) {
      final isImage = att.fileType == 'IMG' ||
          att.fileName.toLowerCase().endsWith('.png') ||
          att.fileName.toLowerCase().endsWith('.jpg') ||
          att.fileName.toLowerCase().endsWith('.jpeg') ||
          att.fileName.toLowerCase().endsWith('.webp') ||
          att.fileName.toLowerCase().endsWith('.gif');
      final isPdf = att.fileType == 'PDF' || att.fileName.toLowerCase().endsWith('.pdf');

      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 550),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isImage
                          ? Icons.image_rounded
                          : (isPdf ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded),
                      color: isImage ? Colors.blue : (isPdf ? Colors.red : Colors.amber.shade700),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        att.fileName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SmartImageWidget(
                      attachment: att,
                      emailId: email.id,
                      folder: attachmentFolder,
                      height: 320,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
                ] else ...[
                  buildPlaceholderPreview(att, isDark),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Size: ${att.fileSize}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.grey.shade700,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        triggerAttachmentDownload(context, att);
                      },
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF195BAC),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Attachments Section
    Widget buildAttachments() {
      if (email.attachments.isEmpty) return const SizedBox.shrink();

      final isMobile = screenWidth < 600;
      final cardWidth = isMobile
          ? (screenWidth < 420 ? (screenWidth - 48) / 2 : 180.0)
          : 210.0;

      return Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ATTACHMENTS (${email.attachments.length})',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
                color: isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: email.attachments.map((att) {
                final isImage = att.fileType == 'IMG' ||
                    att.fileName.toLowerCase().endsWith('.png') ||
                    att.fileName.toLowerCase().endsWith('.jpg') ||
                    att.fileName.toLowerCase().endsWith('.jpeg') ||
                    att.fileName.toLowerCase().endsWith('.webp') ||
                    att.fileName.toLowerCase().endsWith('.gif');

                return Container(
                  width: cardWidth,
                  height: 152,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Half: Preview Area (Thumbnail or File Icon with Badge)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => showAttachmentPreviewDialog(context, att, isDark),
                          child: Container(
                            width: double.infinity,
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            child: isImage
                                ? SmartImageWidget(
                                    attachment: att,
                                    emailId: email.id,
                                    folder: attachmentFolder,
                                    height: double.infinity,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Transform.rotate(
                                          angle: -0.5,
                                          child: Icon(
                                            Icons.attach_file_rounded,
                                            size: 28,
                                            color: isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF334155)
                                                : const Color(0xFFE2E8F0),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            att.fileType.isNotEmpty
                                                ? att.fileType.toUpperCase()
                                                : 'FILE',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                              color: isDark
                                                  ? Colors.white70
                                                  : const Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      // Bottom Half: File Name, Subtitle and Action Icons
                      Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          border: Border(
                            top: BorderSide(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                              width: 0.8,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    att.fileName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isImage
                                        ? 'Image File'
                                        : (att.fileType.isNotEmpty && att.fileType != 'FILE'
                                            ? '${att.fileType} File'
                                            : 'File File'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                          ? BNXColors.darkTextSecondary
                                          : BNXColors.lightTextSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Preview / Eye Button
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => showAttachmentPreviewDialog(context, att, isDark),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: Icon(
                                    Icons.visibility_outlined,
                                    size: 16,
                                    color: isDark
                                        ? BNXColors.darkTextSecondary
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                            // Download Button
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => triggerAttachmentDownload(context, att),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: Icon(
                                    Icons.download_rounded,
                                    size: 16,
                                    color: isDark
                                        ? BNXColors.darkTextSecondary
                                        : const Color(0xFF64748B),
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
              }).toList(),
            ),
          ],
        ),
      );
    }

    // Bottom Reply/Forward buttons
    Widget buildBottomActions() {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Row(
          children: [
            NeumorphicButton(
              onPressed: () {
                ref
                    .read(appUiProvider.notifier)
                    .updateComposeDraft(
                      to: email.senderEmail,
                      subject: 'Re: ${email.subject}',
                    );
                ref
                    .read(appUiProvider.notifier)
                    .setComposeStatus(ComposeStatus.normal);
              },
              borderRadius: 24,
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    size: 16,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reply',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            NeumorphicButton(
              onPressed: () {
                ref
                    .read(appUiProvider.notifier)
                    .updateComposeDraft(
                      subject: 'Fwd: ${email.subject}',
                      body:
                          '\n\n---------- Forwarded message ---------\nFrom: ${email.senderName} <${email.senderEmail}>\nDate: ${_formatFullDate(email.date)}\nSubject: ${email.subject}\n\n${email.body}',
                    );
                ref
                    .read(appUiProvider.notifier)
                    .setComposeStatus(ComposeStatus.normal);
              },
              borderRadius: 24,
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.forward,
                    size: 16,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Forward',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── build the widget tree ─────────────────────────────────────────

    return Column(
      children: [
        buildToolbar(),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(isMobile ? 12 : 24, 0, isMobile ? 12 : 24, isMobile ? 110 : 24),
            children: [
              buildHeaderSection(),
              const SizedBox(height: 12),
              // Email Body Content
              EmailHtmlView(
                html: email.htmlBody,
                text: email.body,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              buildAttachments(),
              // Feature 1: AI Smart Reply bar
              AiSmartReplyBar(email: email),
              buildBottomActions(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnsubscribeBadge({
    required BuildContext context,
    required WidgetRef ref,
    required EmailModel email,
    required bool isUnsubscribed,
    required bool isPending,
    required bool isDark,
  }) {
    final bgColor = isUnsubscribed
        ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
        : (isDark
            ? const Color(0xFF451A1A).withValues(alpha: 0.6)
            : const Color(0xFFFDE8E8));
    final textColor = isUnsubscribed
        ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
        : (isDark ? const Color(0xFFF87171) : const Color(0xFFE53935));
    final labelText = isUnsubscribed ? 'Unsubscribed' : 'Unsubscribe';

    return Tooltip(
      message: isUnsubscribed
          ? 'Sender is unsubscribed. Click to resubscribe.'
          : 'Unsubscribe from this sender',
      child: MouseRegion(
        cursor: isPending ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isPending
              ? null
              : () => _handleSubscriptionAction(
                    context,
                    ref,
                    email: email,
                    isUnsubscribed: isUnsubscribed,
                  ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: isUnsubscribed
                  ? Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                      width: 0.5,
                    )
                  : null,
            ),
            child: isPending
                ? SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  )
                : Text(
                    labelText,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubscriptionAction(
    BuildContext context,
    WidgetRef ref, {
    required EmailModel email,
    required bool isUnsubscribed,
  }) async {
    final senderEmail = email.senderEmail.trim();
    if (senderEmail.isEmpty) return;
    final displayName = email.senderName.trim().isNotEmpty
        ? email.senderName.trim()
        : senderEmail;

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (!isUnsubscribed) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Unsubscribe from $displayName?',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Text(
            'Are you sure you want to unsubscribe from $senderEmail?\n\nYou can manage your subscriptions at any time in the Subscriptions section.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Unsubscribe'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      scaffoldMessenger.hideCurrentSnackBar();
      final res = await ref
          .read(subscriptionProvider.notifier)
          .unsubscribe(senderEmail);

      if (res.success) {
        final messenger = scaffoldMessenger;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Unsubscribed from $displayName'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            persist: false,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.amberAccent,
              onPressed: () {
                ref
                    .read(subscriptionProvider.notifier)
                    .subscribe(senderEmail);
              },
            ),
          ),
        );
        Future.delayed(const Duration(seconds: 4, milliseconds: 200), () {
          if (context.mounted) {
            try {
              messenger.hideCurrentSnackBar();
            } catch (_) {}
          }
        });
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              res.message ?? 'Failed to unsubscribe from $displayName',
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Resubscribe to $displayName?',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Text(
            'Do you want to resubscribe to $senderEmail and receive messages again?',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Resubscribe'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      scaffoldMessenger.hideCurrentSnackBar();
      final res = await ref
          .read(subscriptionProvider.notifier)
          .subscribe(senderEmail);

      if (res.success) {
        final messenger = scaffoldMessenger;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Resubscribed to $displayName'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            persist: false,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.amberAccent,
              onPressed: () {
                ref
                    .read(subscriptionProvider.notifier)
                    .unsubscribe(senderEmail);
              },
            ),
          ),
        );
        Future.delayed(const Duration(seconds: 4, milliseconds: 200), () {
          if (context.mounted) {
            try {
              messenger.hideCurrentSnackBar();
            } catch (_) {}
          }
        });
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              res.message ?? 'Failed to resubscribe to $displayName',
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class SmartImageWidget extends StatefulWidget {
  final AttachmentModel attachment;
  final String? emailId;
  final String? folder;
  final double? height;
  final double? width;
  final BoxFit fit;

  const SmartImageWidget({
    super.key,
    required this.attachment,
    this.emailId,
    this.folder,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  @override
  State<SmartImageWidget> createState() => _SmartImageWidgetState();
}

class _SmartImageWidgetState extends State<SmartImageWidget> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SmartImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.fileName != widget.attachment.fileName ||
        oldWidget.attachment.filePath != widget.attachment.filePath) {
      _load();
    }
  }

  Future<void> _load() async {
    final b = await AttachmentDownloader.getAttachmentBytes(
      widget.attachment,
      emailId: widget.emailId,
      folder: widget.folder,
    );
    if (mounted) {
      setState(() {
        _bytes = b;
        _loading = false;
      });
    }
  }

  Widget _errorPlaceholder() {
    return Container(
      height: widget.height ?? 240,
      width: widget.width ?? double.infinity,
      color: const Color(0xFFF1F5F9),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_size_select_actual_outlined, size: 44, color: Colors.grey),
          SizedBox(height: 8),
          Text('Image Attachment', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: widget.height ?? 240,
        width: widget.width ?? double.infinity,
        color: const Color(0xFFF1F5F9),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF195BAC)),
        ),
      );
    }

    if (_bytes == null || _bytes!.isEmpty) {
      return _errorPlaceholder();
    }

    return Image.memory(
      _bytes!,
      height: widget.height,
      width: widget.width,
      fit: widget.fit,
      errorBuilder: (_, _, _) => _errorPlaceholder(),
    );
  }
}

class AttachmentDownloader {
  static final Map<String, Uint8List> _memoryCache = {};

  static Future<Uint8List?> getAttachmentBytes(
    AttachmentModel att, {
    String? emailId,
    String? folder,
  }) async {
    final cacheKey = '${att.fileName}_${att.filePath}_$emailId';
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey];
    }

    final rawPath = att.filePath?.trim() ?? '';
    Uint8List? bytes;

    // 1. Base64
    if (rawPath.startsWith('data:image/') || _looksLikeBase64(rawPath)) {
      try {
        final cleanBase64 = rawPath.contains(',') ? rawPath.split(',').last : rawPath;
        final decoded = base64Decode(cleanBase64.replaceAll(RegExp(r'\s+'), ''));
        if (decoded.isNotEmpty) {
          bytes = decoded;
        }
      } catch (_) {}
    }

    // 2. Local File
    if (bytes == null && rawPath.isNotEmpty && !rawPath.startsWith('http')) {
      try {
        final file = File(rawPath);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      } catch (_) {}
    }

    // 3. Network API URLs using GET /api/mail/{uid}/attachments/{fileName}?folder={folder}
    if (bytes == null) {
      final token = await TokenService.getAccessToken();
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final cleanName = att.fileName.split('/').last.split('\\').last;
      final cleanUid = emailId != null ? MailRepository.cleanUid(emailId) : '';

      // Try the caller's folder first, then the common IMAP folders.
      final folders = <String>{
        if (folder != null && folder.isNotEmpty) folder,
        'INBOX',
        'Sent',
        'Archive',
        'Trash',
        'Drafts',
      }.toList();

      final candidateUrls = <String>[
        // Direct raw path if provided
        if (rawPath.startsWith('http://') || rawPath.startsWith('https://')) rawPath,
        if (rawPath.isNotEmpty && !rawPath.startsWith('http'))
          '${ApiClient.baseUrl}/${rawPath.startsWith('/') ? rawPath.substring(1) : rawPath}',

        // Primary email UID endpoints with folder query
        if (cleanUid.isNotEmpty)
          for (final f in folders) ...[
            '${ApiClient.baseUrl}/api/mail/$cleanUid/attachments/${Uri.encodeComponent(cleanName)}?folder=${Uri.encodeQueryComponent(f)}',
            '${ApiClient.baseUrl}/api/mail/$cleanUid/attachment/${Uri.encodeComponent(cleanName)}?folder=${Uri.encodeQueryComponent(f)}',
            '${ApiClient.baseUrl}/api/mail/$cleanUid/attachments/$cleanName?folder=${Uri.encodeQueryComponent(f)}',
          ],

        // Fallback email UID endpoints without folder query
        if (cleanUid.isNotEmpty) ...[
          '${ApiClient.baseUrl}/api/mail/$cleanUid/attachments/${Uri.encodeComponent(cleanName)}',
          '${ApiClient.baseUrl}/api/mail/$cleanUid/attachment/${Uri.encodeComponent(cleanName)}',
          '${ApiClient.baseUrl}/api/mail/$cleanUid/attachments/$cleanName',
        ],

        // General attachment endpoints
        '${ApiClient.baseUrl}/api/mail/attachments/${Uri.encodeComponent(cleanName)}',
        '${ApiClient.baseUrl}/api/mail/attachments/$cleanName',
      ];

      for (final url in candidateUrls) {
        try {
          final res = await http
              .get(Uri.parse(url), headers: headers)
              .timeout(const Duration(seconds: 60));
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            bytes = res.bodyBytes;
            break;
          }
        } catch (_) {}
      }
    }

    // Never fabricate bytes: a failed fetch must surface as a failed download.
    if (bytes != null && bytes.isNotEmpty) {
      _memoryCache[cacheKey] = bytes;
    }
    return bytes;
  }

  static bool _looksLikeBase64(String str) {
    if (str.length < 40) return false;
    final clean = str.replaceAll(RegExp(r'\s+'), '');
    return RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(clean);
  }

  static Future<List<Directory>> _resolveDownloadDirs() async {
    final dirs = <Directory>[];
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        // 1. Try public Download folder
        for (final p in const ['/storage/emulated/0/Download', '/sdcard/Download']) {
          dirs.add(Directory(p));
        }
        // 2. Try app-specific external Downloads folder (always accessible on Android without storage permissions)
        try {
          final appExtDownloads = await getExternalStorageDirectories(type: StorageDirectory.downloads);
          if (appExtDownloads != null && appExtDownloads.isNotEmpty) {
            dirs.addAll(appExtDownloads);
          }
        } catch (_) {}
        // 3. Try app-specific external files folder
        try {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            dirs.add(Directory('${extDir.path}/Download'));
            dirs.add(extDir);
          }
        } catch (_) {}
      } else if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
        try {
          final d = await getDownloadsDirectory();
          if (d != null) dirs.add(d);
        } catch (_) {}
        final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
        if (home != null) {
          dirs.add(Directory('$home${Platform.pathSeparator}Downloads'));
        }
      } else if (Platform.isIOS) {
        try {
          final docs = await getApplicationDocumentsDirectory();
          dirs.add(Directory('${docs.path}/Downloads'));
          dirs.add(docs);
        } catch (_) {}
      }

      // Universal fallbacks
      try {
        final docs = await getApplicationDocumentsDirectory();
        dirs.add(docs);
      } catch (_) {}
      dirs.add(Directory.systemTemp);
    }
    return dirs;
  }

  static Future<String?> downloadAndSave(
    AttachmentModel att, {
    String? emailId,
    String? folder,
  }) async {
    try {
      final bytes = await getAttachmentBytes(att, emailId: emailId, folder: folder);
      if (bytes == null || bytes.isEmpty) {
        debugPrint('[DOWNLOAD ATTACHMENT ERROR] No bytes retrieved for ${att.fileName}');
        return null;
      }

      final candidateDirs = await _resolveDownloadDirs();

      // Keep spaces/unicode; only strip characters illegal on any OS.
      var name = att.fileName
          .split('/')
          .last
          .split('\\')
          .last
          .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
          .trim();
      if (name.isEmpty) name = 'attachment';

      // Never overwrite an existing file: report (1), (2), ...
      final dot = name.lastIndexOf('.');
      final stem = dot > 0 ? name.substring(0, dot) : name;
      final ext = dot > 0 ? name.substring(dot) : '';

      // Try writing to each candidate directory in order until one succeeds!
      for (final downloadDir in candidateDirs) {
        try {
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }

          var savePath = '${downloadDir.path}${Platform.pathSeparator}$name';
          var n = 1;
          while (await File(savePath).exists()) {
            savePath = '${downloadDir.path}${Platform.pathSeparator}$stem ($n)$ext';
            n++;
          }

          final file = File(savePath);
          await file.writeAsBytes(bytes, flush: true);
          debugPrint('[DOWNLOAD ATTACHMENT SUCCESS] Saved to $savePath');
          return savePath;
        } catch (e) {
          debugPrint('[DOWNLOAD CANDIDATE ATTEMPT FAILED] ${downloadDir.path}: $e');
          // Proceed to next directory candidate
        }
      }

      return null;
    } catch (e) {
      debugPrint('[DOWNLOAD ATTACHMENT ERROR] $e');
      return null;
    }
  }
}
