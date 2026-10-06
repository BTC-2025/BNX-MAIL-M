import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'avatar_widget.dart';
import 'bnx_animations.dart';
import 'label_chip.dart';
import '../../models/email_model.dart';
import '../../models/label_model.dart';
import '../../data/email_provider.dart';
import '../../data/app_state_provider.dart';
import '../constants/constants.dart';
import '../theme/colors.dart';

class EmailTile extends ConsumerStatefulWidget {
  final EmailModel email;
  final bool isSelected;
  final VoidCallback onTap;

  const EmailTile({
    super.key,
    required this.email,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  ConsumerState<EmailTile> createState() => _EmailTileState();
}

class _EmailTileState extends ConsumerState<EmailTile> {
  bool _isHovered = false;

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final emailDate = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(emailDate).inDays;

    if (diffDays == 0) {
      final hour = date.hour > 12
          ? date.hour - 12
          : (date.hour == 0 ? 12 : date.hour);
      final period = date.hour >= 12 ? 'PM' : 'AM';
      final min = date.minute.toString().padLeft(2, '0');
      return '$hour:$min $period';
    } else if (diffDays == 1) {
      return 'Yesterday';
    } else if (diffDays > 1 && diffDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[date.weekday - 1];
    } else {
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
      final monthStr = months[date.month - 1];
      if (date.year == now.year) {
        return '$monthStr ${date.day}';
      } else {
        return '$monthStr ${date.day}, ${date.year}';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;
    final email = widget.email;
    final isSelectedForBulk = uiState.selectedEmailIds.contains(email.id);

    final FontWeight textWeight = email.isRead
        ? FontWeight.normal
        : FontWeight.bold;
    final Color textColor = email.isRead
        ? (isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary)
        : (isDark ? Colors.white : BNXColors.lightTextPrimary);

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    final bool isDraftItem = email.isDraft || email.memberOfFolders.contains('Draft');
    final bool isScheduledItem = email.isScheduled || email.memberOfFolders.contains('Scheduled');
    final bool isSentFolderView = uiState.activeFolder == 'Sent';
    final bool isSentItem = isSentFolderView || (email.isSent && !email.memberOfFolders.contains('Inbox'));

    final String tileSenderName = isScheduledItem
        ? (email.recipient.trim().isNotEmpty
            ? 'Scheduled: ${email.recipient.trim()}'
            : 'Scheduled Mail')
        : isDraftItem
            ? (email.recipient.trim().isNotEmpty
                ? 'Draft: ${email.recipient.trim()}'
                : 'Draft')
            : isSentItem
                ? (email.recipient.isNotEmpty ? 'To: ${email.recipient}' : email.senderName)
                : (email.senderName.isNotEmpty && email.senderName != 'BNX Mail'
                    ? email.senderName
                    : (email.senderEmail.isNotEmpty ? email.senderEmail : 'BNX Mail'));

    final String avatarName = isScheduledItem
        ? (email.recipient.trim().isNotEmpty ? email.recipient.trim() : 'Scheduled')
        : isDraftItem
            ? (email.recipient.trim().isNotEmpty ? email.recipient.trim() : 'Draft')
            : isSentItem
                ? (email.recipient.isNotEmpty ? email.recipient : email.senderName)
                : (email.senderName.isNotEmpty && email.senderName != 'BNX Mail'
                    ? email.senderName
                    : (email.senderEmail.isNotEmpty ? email.senderEmail : 'BNX Mail'));

    if (isMobile) {
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            if (uiState.selectedEmailIds.isNotEmpty) {
              ref.read(appUiProvider.notifier).toggleEmailSelection(email.id);
            } else {
              widget.onTap();
            }
          },
          onLongPress: () {
            ref.read(appUiProvider.notifier).toggleEmailSelection(email.id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEAF1FB))
                  : (_isHovered
                        ? (isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFF1F5F9))
                        : Colors.transparent),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. LEFT SIDE: AVATAR
                GestureDetector(
                  onTap: () {
                    ref
                        .read(appUiProvider.notifier)
                        .toggleEmailSelection(email.id);
                  },
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: isSelectedForBulk
                        ? Container(
                            decoration: const BoxDecoration(
                              color: BNXColors.lightPrimary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            ),
                          )
                        : AvatarWidget(
                            name: avatarName,
                            size: 36,
                            fontSize: 13,
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // 2. CENTER: EMAIL CONTENTS
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sender + Date row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              tileSenderName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: textWeight,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(email.date),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: textWeight,
                              color: isDark
                                  ? BNXColors.darkTextSecondary
                                  : BNXColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Subject
                      Text(
                        email.subject,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: textWeight,
                          color: isDark
                              ? Colors.white
                              : BNXColors.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),

                      // Body / Snippet + Labels + Star / Unread dot
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  email.body,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? BNXColors.darkTextSecondary
                                        : BNXColors.lightTextSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (email.labels.isNotEmpty) ...[
                                  () {
                                    final customLabels = ref.watch(customLabelsProvider);
                                    final activeChips = email.labels.where((l) {
                                      final norm = l.trim().toLowerCase();
                                      const system = {
                                        'work',
                                        'personal',
                                        'important',
                                        'promotions',
                                        'social',
                                        'updates',
                                        'purchases',
                                      };
                                      if (system.contains(norm)) return true;
                                      return customLabels.any(
                                        (cl) =>
                                            cl.name.trim().toLowerCase() == norm ||
                                            cl.id.trim().toLowerCase() == norm,
                                      );
                                    }).map((l) {
                                      final matched = customLabels.firstWhere(
                                        (cl) =>
                                            cl.name.trim().toLowerCase() ==
                                                l.trim().toLowerCase() ||
                                            cl.id.trim().toLowerCase() ==
                                                l.trim().toLowerCase(),
                                        orElse: () => LabelModel(
                                          id: l,
                                          name: l,
                                          color: Colors.blueGrey,
                                        ),
                                      );
                                      return LabelChip(
                                        labelName: matched.name,
                                        customColor: matched.color,
                                      );
                                    }).toList();

                                    if (activeChips.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: activeChips,
                                      ),
                                    );
                                  }(),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Attachment Icon
                          if (email.hasAttachment) ...[
                            Icon(
                              Icons.attachment_rounded,
                              size: 15,
                              color: isDark
                                  ? BNXColors.darkTextSecondary
                                  : BNXColors.lightTextSecondary,
                            ),
                            const SizedBox(width: 8),
                          ],

                          // Unread Dot (never show for Drafts or Scheduled items)
                          if (!email.isRead && !isDraftItem && !isScheduledItem) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: BNXColors.lightPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],

                          // Open Button (Only visible if selected for bulk / selection mode active)
                          if (isSelectedForBulk) ...[
                            GestureDetector(
                              onTap: widget.onTap,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF195BAC),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Open',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],

                          // Star Icon
                          GestureDetector(
                            onTap: () {
                              ref
                                  .read(emailProvider.notifier)
                                  .toggleStar(email.id, 'Inbox');
                            },
                            child: AnimatedStarIcon(
                              isStarred: email.isStarred,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bool isDesktopOS = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows);

    if (isDesktopOS) {
      return _buildDesktopEmailTile(
        context: context,
        ref: ref,
        uiState: uiState,
        email: email,
        isDark: isDark,
        textWeight: textWeight,
        textColor: textColor,
        isSelectedForBulk: isSelectedForBulk,
        tileSenderName: tileSenderName,
        isDraftItem: isDraftItem,
        isScheduledItem: isScheduledItem,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (uiState.selectedEmailIds.isNotEmpty) {
            ref.read(appUiProvider.notifier).toggleEmailSelection(email.id);
          } else {
            widget.onTap();
          }
        },
        onLongPress: () {
          ref.read(appUiProvider.notifier).toggleEmailSelection(email.id);
        },
        child: AnimatedContainer(
          duration: defaultTargetPlatform == TargetPlatform.macOS
              ? Duration.zero
              : const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEAF1FB))
                : (_isHovered
                      ? (isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFF1F5F9))
                      : (isDark ? const Color(0xFF0F172A) : Colors.white)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected
                  ? BNXColors.lightPrimary.withValues(alpha: 0.4)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade200),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: !email.isRead
                      ? (isDark
                            ? BNXColors.darkPrimary
                            : BNXColors.lightPrimary)
                      : Colors.transparent,
                ),
              ),
              IconButton(
                icon: AnimatedStarIcon(
                  isStarred: email.isStarred,
                  size: 20,
                ),
                onPressed: () {
                  ref
                      .read(emailProvider.notifier)
                      .toggleStar(email.id, 'Inbox');
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  ref
                      .read(appUiProvider.notifier)
                      .toggleEmailSelection(email.id);
                },
                child: MouseRegion(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: isSelectedForBulk
                        ? const BoxDecoration(
                            color: BNXColors.lightPrimary,
                            shape: BoxShape.circle,
                          )
                        : null,
                    alignment: Alignment.center,
                    child: isSelectedForBulk
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : (_isHovered
                              ? Transform.scale(
                                  scale: 0.7,
                                  child: Checkbox(
                                    value: isSelectedForBulk,
                                    activeColor: BNXColors.lightPrimary,
                                    onChanged: (val) {
                                      ref
                                          .read(appUiProvider.notifier)
                                          .toggleEmailSelection(email.id);
                                    },
                                  ),
                                )
                              : AvatarWidget(
                                  name: email.senderName,
                                  size: 28,
                                  fontSize: 11,
                                )),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        tileSenderName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: textWeight,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 6,
                      child: RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white
                                : BNXColors.lightTextPrimary,
                          ),
                          children: [
                            TextSpan(
                              text: email.subject,
                              style: TextStyle(fontWeight: textWeight),
                            ),
                            TextSpan(
                              text: ' — ${email.body}',
                              style: TextStyle(
                                color: isDark
                                    ? BNXColors.darkTextSecondary
                                    : BNXColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ── Trailing: attachment + bulk + date/actions ──────
                    // Kept inside the Expanded Row so everything participates
                    // in flex layout — no rigid width outside causes overflow.
                    if (email.hasAttachment) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.attachment_rounded,
                        size: 15,
                        color: isDark
                            ? BNXColors.darkTextSecondary
                            : BNXColors.lightTextSecondary,
                      ),
                    ],
                    if (isSelectedForBulk) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: widget.onTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF195BAC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Open',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 112,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AnimatedCrossFade(
                          duration: defaultTargetPlatform == TargetPlatform.macOS
                              ? Duration.zero
                              : BNXConstants.animationDurationFast,
                          crossFadeState: _isHovered
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          firstChild: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              _formatDate(email.date),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: textWeight,
                                color: isDark
                                    ? BNXColors.darkTextSecondary
                                    : BNXColors.lightTextSecondary,
                              ),
                            ),
                          ),
                          secondChild: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: isScheduledItem
                                ? [
                                    _buildQuickAction(
                                      icon: Icons.send_rounded,
                                      tooltip: 'Send now',
                                      onTap: () {
                                        ref
                                            .read(emailProvider.notifier)
                                            .sendScheduledEmailNow(email);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Sending scheduled mail now...'),
                                          ),
                                        );
                                      },
                                    ),
                                    _buildQuickAction(
                                      icon: Icons.delete_outline_rounded,
                                      tooltip: 'Cancel schedule',
                                      onTap: () {
                                        ref
                                            .read(emailProvider.notifier)
                                            .cancelScheduledEmail(email.id);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Schedule cancelled.'),
                                          ),
                                        );
                                      },
                                    ),
                                  ]
                                : (email.isTrash || email.memberOfFolders.contains('Trash') || uiState.activeFolder == 'Trash')
                                    ? [
                                        _buildQuickAction(
                                          icon: Icons.restore_from_trash_outlined,
                                          tooltip: 'Restore',
                                          onTap: () {
                                            ref
                                                .read(emailProvider.notifier)
                                                .restoreEmail(email.id);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Restored email to Inbox.'),
                                              ),
                                            );
                                          },
                                        ),
                                        _buildQuickAction(
                                          icon: Icons.delete_forever_outlined,
                                          tooltip: 'Delete permanently',
                                          onTap: () {
                                            ref
                                                .read(emailProvider.notifier)
                                                .permanentlyDeleteEmail(email.id, folder: uiState.activeFolder);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Permanently deleted.'),
                                              ),
                                            );
                                          },
                                        ),
                                      ]
                                    : [
                                        _buildQuickAction(
                                          icon: (email.isArchive ||
                                                  email.memberOfFolders.contains('Archive'))
                                              ? Icons.unarchive_outlined
                                              : Icons.archive_outlined,
                                          tooltip: (email.isArchive ||
                                                  email.memberOfFolders.contains('Archive'))
                                              ? 'Unarchive'
                                              : 'Archive',
                                          onTap: () {
                                            if (email.isArchive ||
                                                email.memberOfFolders.contains('Archive')) {
                                              ref
                                                  .read(emailProvider.notifier)
                                                  .unarchiveEmail(email.id);
                                            } else {
                                              ref
                                                  .read(emailProvider.notifier)
                                                  .archiveEmail(email.id, uiState.activeFolder);
                                            }
                                          },
                                        ),
                                        _buildQuickAction(
                                          icon: Icons.delete_outline_rounded,
                                          tooltip: 'Delete',
                                          onTap: () {
                                            ref
                                                .read(emailProvider.notifier)
                                                .deleteEmail(
                                                  email.id,
                                                  uiState.activeFolder,
                                                );
                                          },
                                        ),
                                        _buildQuickAction(
                                          icon: email.isRead
                                              ? Icons.mark_email_unread_outlined
                                              : Icons.mark_email_read_outlined,
                                          tooltip: email.isRead
                                              ? 'Mark as unread'
                                              : 'Mark as read',
                                          onTap: () {
                                            ref
                                                .read(emailProvider.notifier)
                                                .toggleRead(email.id, uiState.activeFolder);
                                          },
                                        ),
                                      ],
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
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 4.0),
          child: Icon(icon, size: 18, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildDesktopEmailTile({
    required BuildContext context,
    required WidgetRef ref,
    required AppUiState uiState,
    required EmailModel email,
    required bool isDark,
    required FontWeight textWeight,
    required Color textColor,
    required bool isSelectedForBulk,
    required String tileSenderName,
    required bool isDraftItem,
    required bool isScheduledItem,
  }) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (uiState.selectedEmailIds.isNotEmpty) {
            ref.read(appUiProvider.notifier).toggleEmailSelection(email.id);
          } else {
            widget.onTap();
          }
        },
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: widget.isSelected || isSelectedForBulk
                ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEAF2FF))
                : (_isHovered
                    ? (isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC))
                    : Colors.transparent),
          ),
          child: Row(
            children: [
              // 1. Checkbox
              GestureDetector(
                onTap: () {
                  ref
                      .read(appUiProvider.notifier)
                      .toggleEmailSelection(email.id);
                },
                child: Icon(
                  isSelectedForBulk
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 18,
                  color: isSelectedForBulk
                      ? const Color(0xFF195BAC)
                      : (isDark ? Colors.white38 : Colors.grey.shade400),
                ),
              ),
              const SizedBox(width: 14),

              // 2. Star
              GestureDetector(
                onTap: () {
                  ref
                      .read(emailProvider.notifier)
                      .toggleStar(email.id, 'Inbox');
                },
                child: Icon(
                  email.isStarred
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: email.isStarred
                      ? const Color(0xFFF59E0B)
                      : (isDark ? Colors.white38 : Colors.grey.shade400),
                  size: 19,
                ),
              ),
              const SizedBox(width: 16),

              // 3. Sender Name
              SizedBox(
                width: 150,
                child: Text(
                  tileSenderName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: textWeight,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),

              // 4. Subject + Body snippet
              Expanded(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                    ),
                    children: [
                      TextSpan(
                        text: email.subject,
                        style: TextStyle(
                          fontWeight: textWeight,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      TextSpan(
                        text: ' — ${email.body}',
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: isDark
                              ? BNXColors.darkTextSecondary
                              : BNXColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Attachment icon (if any)
              if (email.hasAttachment) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.attach_file_rounded,
                  size: 16,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ],

              const SizedBox(width: 16),

              // 6. Right side: Date or Quick Actions on Hover
              SizedBox(
                width: 110,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _isHovered
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildQuickAction(
                              icon: Icons.archive_outlined,
                              tooltip: 'Archive',
                              onTap: () {
                                ref.read(emailProvider.notifier).archiveEmail(
                                      email.id,
                                      uiState.activeFolder,
                                    );
                              },
                            ),
                            _buildQuickAction(
                              icon: Icons.delete_outline_rounded,
                              tooltip: 'Delete',
                              onTap: () {
                                ref.read(emailProvider.notifier).deleteEmail(
                                      email.id,
                                      uiState.activeFolder,
                                    );
                              },
                            ),
                            _buildQuickAction(
                              icon: Icons.access_time_rounded,
                              tooltip: 'Snooze',
                              onTap: () {
                                ref.read(emailProvider.notifier).snoozeEmail(
                                      email.id,
                                      DateTime.now().add(const Duration(hours: 4)),
                                      uiState.activeFolder,
                                    );
                              },
                            ),
                          ],
                        )
                      : Text(
                          _formatDate(email.date),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: textWeight,
                            color: isDark
                                ? BNXColors.darkTextSecondary
                                : Colors.grey.shade600,
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
