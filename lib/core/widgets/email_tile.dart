import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'avatar_widget.dart';
import 'label_chip.dart';
import '../../models/email_model.dart';
import '../../data/email_provider.dart';
import '../../data/app_state_provider.dart';
import '../constants/constants.dart';
import '../theme/colors.dart';
import '../theme/neumorphic.dart';

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
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final period = date.hour >= 12 ? 'PM' : 'AM';
      final min = date.minute.toString().padLeft(2, '0');
      return '$hour:$min $period';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}';
    }
  }

  String _formatSnoozeDate(DateTime date) {
    final now = DateTime.now();
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final min = date.minute.toString().padLeft(2, '0');
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return '$hour:$min $period';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;
    final email = widget.email;
    final isSelectedForBulk = uiState.selectedEmailIds.contains(email.id);

    final Color bgColor = widget.isSelected
        ? (isDark ? BNXColors.darkSidebarSelected : BNXColors.lightSidebarSelected)
        : (_isHovered
            ? (isDark ? BNXColors.darkSidebarHover.withValues(alpha: 0.5) : BNXColors.lightSidebarHover.withValues(alpha: 0.5))
            : Colors.transparent);

    final FontWeight textWeight = email.isRead ? FontWeight.normal : FontWeight.bold;
    final Color textColor = email.isRead 
        ? (isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary)
        : (isDark ? Colors.white : BNXColors.lightTextPrimary);

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    if (isMobile) {
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: NeumorphicContainer(
            shape: widget.isSelected 
                ? NeumorphicShape.pressed 
                : (_isHovered ? NeumorphicShape.convex : NeumorphicShape.flat),
            borderRadius: 14,
            depth: widget.isSelected ? 0 : (_isHovered ? 3.0 : 1.5),
            color: widget.isSelected
                ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB))
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. LEFT SIDE: AVATAR
                GestureDetector(
                  onTap: () {
                    ref.read(appUiProvider.notifier).toggleEmailSelection(email.id);
                  },
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: isSelectedForBulk
                        ? Container(
                            decoration: const BoxDecoration(
                              color: BNXColors.lightPrimary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 20),
                          )
                        : AvatarWidget(
                            name: email.senderName,
                            size: 40,
                            fontSize: 15,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                
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
                              email.senderName,
                              style: TextStyle(
                                fontSize: 15,
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
                              fontSize: 12,
                              fontWeight: textWeight,
                              color: isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      
                      // Subject
                      Text(
                        email.subject,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: textWeight,
                          color: isDark ? Colors.white : BNXColors.lightTextPrimary,
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
                                    fontSize: 13,
                                    color: isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (email.labels.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: email.labels.map((l) => LabelChip(labelName: l)).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          
                          // Attachment Icon
                          if (email.hasAttachment) ...[
                            Icon(
                              Icons.attachment_rounded,
                              size: 16,
                              color: isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary,
                            ),
                            const SizedBox(width: 8),
                          ],
                          
                          // Unread Dot
                          if (!email.isRead) ...[
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
                          
                          // Star Icon
                          GestureDetector(
                            onTap: () {
                              ref.read(emailProvider.notifier).toggleStar(email.id);
                            },
                            child: Icon(
                              email.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                              color: email.isStarred ? BNXColors.starActive : BNXColors.starInactive,
                              size: 22,
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

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: NeumorphicContainer(
          shape: widget.isSelected 
              ? NeumorphicShape.pressed 
              : (_isHovered ? NeumorphicShape.convex : NeumorphicShape.flat),
          borderRadius: 14,
          depth: widget.isSelected ? 0 : (_isHovered ? 3.0 : 1.5),
          color: widget.isSelected
              ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: !email.isRead
                      ? (isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary)
                      : Colors.transparent,
                ),
              ),
              IconButton(
                icon: Icon(
                  email.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                  color: email.isStarred ? BNXColors.starActive : BNXColors.starInactive,
                  size: 22,
                ),
                onPressed: () {
                  ref.read(emailProvider.notifier).toggleStar(email.id);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  ref.read(appUiProvider.notifier).toggleEmailSelection(email.id);
                },
                child: MouseRegion(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: isSelectedForBulk
                        ? const BoxDecoration(
                            color: BNXColors.lightPrimary,
                            shape: BoxShape.circle,
                          )
                        : null,
                    alignment: Alignment.center,
                    child: isSelectedForBulk
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : (_isHovered
                            ? Transform.scale(
                                scale: 0.85,
                                child: Checkbox(
                                  value: isSelectedForBulk,
                                  activeColor: BNXColors.lightPrimary,
                                  onChanged: (val) {
                                    ref.read(appUiProvider.notifier).toggleEmailSelection(email.id);
                                  },
                                ),
                              )
                            : AvatarWidget(
                                name: email.senderName,
                                size: 32,
                                fontSize: 13,
                              )),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            email.senderName,
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
                        if (email.labels.isNotEmpty) ...[
                          Wrap(
                            spacing: 4,
                            children: email.labels.map((l) => LabelChip(labelName: l)).toList(),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (email.isSnoozed && email.snoozeUntil != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.amber.withOpacity(0.15) : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.amber.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time_rounded, size: 10, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  _formatSnoozeDate(email.snoozeUntil!),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.amber : Colors.amber.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email.subject,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: textWeight,
                        color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email.body,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (email.hasAttachment)
                Icon(
                  Icons.attachment_rounded,
                  size: 16,
                  color: isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary,
                ),
              const SizedBox(width: 12),
              Container(
                width: 100,
                alignment: Alignment.centerRight,
                child: AnimatedCrossFade(
                  duration: BNXConstants.animationDurationFast,
                  crossFadeState: _isHovered ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  firstChild: Text(
                    _formatDate(email.date),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: textWeight,
                      color: isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary,
                    ),
                  ),
                  secondChild: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildQuickAction(
                        icon: Icons.archive_outlined,
                        tooltip: 'Archive',
                        onTap: () {
                          ref.read(emailProvider.notifier).archiveEmail(email.id);
                        },
                      ),
                      _buildQuickAction(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Delete',
                        onTap: () {
                          ref.read(emailProvider.notifier).deleteEmail(email.id);
                        },
                      ),
                      _buildQuickAction(
                        icon: email.isRead ? Icons.mark_email_unread_outlined : Icons.mark_email_read_outlined,
                        tooltip: email.isRead ? 'Mark as unread' : 'Mark as read',
                        onTap: () {
                          ref.read(emailProvider.notifier).toggleRead(email.id);
                        },
                      ),
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
          padding: const EdgeInsets.all(6.0),
          child: Icon(
            icon,
            size: 18,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}
