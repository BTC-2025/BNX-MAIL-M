import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'avatar_widget.dart';
import 'label_chip.dart';
import '../../models/email_model.dart';
import '../../data/email_provider.dart';
import '../../data/app_state_provider.dart';
import '../theme/colors.dart';
import '../theme/neumorphic.dart';
import '../constants/constants.dart';
import '../../dummy/dummy_data.dart';
import '../../features/ai/presentation/ai_smart_reply_bar.dart';
import '../../features/inbox/presentation/snooze_scheduler_dialog.dart';

class EmailBody extends ConsumerWidget {
  final String emailId;

  const EmailBody({
    super.key,
    required this.emailId,
  });

  String _formatFullDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final min = date.minute.toString().padLeft(2, '0');
    return '${months[date.month - 1]} ${date.day}, ${date.year}, $hour:$min $period';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(appUiProvider).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    final emails = ref.watch(emailProvider);
    final email = emails.firstWhere(
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

    // Action Toolbar
    Widget buildToolbar() {
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
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                context.pop();
              },
              tooltip: 'Back to list',
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.archive_outlined),
              onPressed: () {
                ref.read(emailProvider.notifier).archiveEmail(email.id);
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email archived.')),
                );
              },
              tooltip: 'Archive',
            ),
            IconButton(
              icon: Icon(email.isRead ? Icons.mark_email_unread_outlined : Icons.mark_email_read_outlined),
              onPressed: () {
                ref.read(emailProvider.notifier).toggleRead(email.id);
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(email.isRead ? 'Marked as unread.' : 'Marked as read.')),
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
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () {
                ref.read(emailProvider.notifier).deleteEmail(email.id);
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Moved to trash.')),
                );
              },
              tooltip: 'Delete',
            ),
            const VerticalDivider(width: 16, indent: 12, endIndent: 12),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'More',
              onSelected: (value) {
                if (value == 'Mark unread') {
                  ref.read(emailProvider.notifier).toggleRead(email.id, forceValue: false);
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Marked as unread.')),
                  );
                } else if (value == 'Star' || value == 'Unstar') {
                  ref.read(emailProvider.notifier).toggleStar(email.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(email.isStarred ? 'Star removed.' : 'Starred.'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } else if (value == 'Spam') {
                  ref.read(emailProvider.notifier).archiveEmail(email.id);
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
                      Icon(Icons.mark_email_unread_outlined, size: 18, color: isDark ? Colors.white70 : Colors.black87),
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
                        email.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 18,
                        color: email.isStarred ? BNXColors.starActive : (isDark ? Colors.white70 : Colors.black87),
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
                      Icon(Icons.report_gmailerrorred_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black87),
                      const SizedBox(width: 12),
                      const Text('Report spam'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'Mute',
                  child: Row(
                    children: [
                      Icon(Icons.volume_off_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black87),
                      const SizedBox(width: 12),
                      const Text('Mute'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'Print',
                  child: Row(
                    children: [
                      Icon(Icons.print_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black87),
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
                email.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                color: email.isStarred ? BNXColors.starActive : BNXColors.starInactive,
              ),
              onPressed: () {
                ref.read(emailProvider.notifier).toggleStar(email.id);
              },
              tooltip: email.isStarred ? 'Unstar' : 'Star',
            ),
          ],
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
                  Wrap(
                    spacing: 4,
                    children: email.labels.map((l) => LabelChip(labelName: l)).toList(),
                  ),
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
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            email.senderName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '<${email.senderEmail}>',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'to ${email.recipient == BNXDummyData.currentUser.email ? "me" : email.recipient}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      if (isMobile) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatFullDate(email.date),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary,
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
                          color: isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (value) {
                        if (value == 'Reply') {
                          ref.read(appUiProvider.notifier).updateComposeDraft(
                            to: email.senderEmail,
                            subject: 'Re: ${email.subject}',
                          );
                          ref.read(appUiProvider.notifier).setComposeStatus(ComposeStatus.normal);
                        } else if (value == 'Forward') {
                          ref.read(appUiProvider.notifier).updateComposeDraft(
                            subject: 'Fwd: ${email.subject}',
                            body: '\n\n---------- Forwarded message ---------\nFrom: ${email.senderName} <${email.senderEmail}>\nDate: ${_formatFullDate(email.date)}\nSubject: ${email.subject}\n\n${email.body}',
                          );
                          ref.read(appUiProvider.notifier).setComposeStatus(ComposeStatus.normal);
                        } else if (value == 'Add star' || value == 'Remove star') {
                          ref.read(emailProvider.notifier).toggleStar(email.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(email.isStarred ? 'Star removed.' : 'Starred.'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } else if (value == 'Mark unread from here') {
                          ref.read(emailProvider.notifier).toggleRead(email.id, forceValue: false);
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
                              content: Text('Translate option is not fully integrated yet.'),
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
                              content: Text('Sender "${email.senderName}" has been blocked.'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } else if (value == 'Report spam') {
                          ref.read(emailProvider.notifier).archiveEmail(email.id);
                          context.pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Email reported as spam and archived.'),
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
                                email.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                                size: 18,
                                color: email.isStarred ? BNXColors.starActive : null,
                              ),
                              const SizedBox(width: 12),
                              Text(email.isStarred ? 'Remove star' : 'Add star'),
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
                              const Icon(Icons.block_rounded, size: 18, color: Colors.red),
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
                              Icon(Icons.report_gmailerrorred_rounded, size: 18, color: Colors.red),
                              SizedBox(width: 12),
                              Text('Report spam', style: TextStyle(color: Colors.red)),
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

    // Attachments Section
    Widget buildAttachments() {
      if (email.attachments.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 32),
          Text(
            '${email.attachments.length} Attachment${email.attachments.length > 1 ? 's' : ''}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: email.attachments.map((att) {
              return NeumorphicContainer(
                width: 220,
                padding: const EdgeInsets.all(8),
                borderRadius: BNXConstants.borderRadiusS,
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            att.fileName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            att.fileSize,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_rounded, size: 18),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Downloading attachment: ${att.fileName}...')),
                        );
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
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
                ref.read(appUiProvider.notifier).updateComposeDraft(
                  to: email.senderEmail,
                  subject: 'Re: ${email.subject}',
                );
                ref.read(appUiProvider.notifier).setComposeStatus(ComposeStatus.normal);
              },
              borderRadius: 24,
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.reply, size: 16, color: isDark ? Colors.white70 : Colors.black87),
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
                ref.read(appUiProvider.notifier).updateComposeDraft(
                  subject: 'Fwd: ${email.subject}',
                  body: '\n\n---------- Forwarded message ---------\nFrom: ${email.senderName} <${email.senderEmail}>\nDate: ${_formatFullDate(email.date)}\nSubject: ${email.subject}\n\n${email.body}',
                );
                ref.read(appUiProvider.notifier).setComposeStatus(ComposeStatus.normal);
              },
              borderRadius: 24,
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.forward, size: 16, color: isDark ? Colors.white70 : Colors.black87),
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

    return Column(
      children: [
        buildToolbar(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              buildHeaderSection(),
              const Divider(),
              const SizedBox(height: 16),
              // Email Body Content
              SelectableText(
                email.body,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
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
}
