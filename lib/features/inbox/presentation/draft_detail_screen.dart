import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/app_state_provider.dart';
import '../../../data/email_provider.dart';
import '../../../models/email_model.dart';
import '../../../models/attachment_model.dart';

class DraftDetailScreen extends ConsumerStatefulWidget {
  final String draftId;

  const DraftDetailScreen({super.key, required this.draftId});

  @override
  ConsumerState<DraftDetailScreen> createState() => _DraftDetailScreenState();
}

class _DraftDetailScreenState extends ConsumerState<DraftDetailScreen> {
  bool _showRecipientDetails = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final emailState = ref.read(emailProvider);
      try {
        final email = emailState.emails.firstWhere((e) => e.id == widget.draftId);
        if (!email.isRead) {
          ref.read(emailProvider.notifier).toggleRead(widget.draftId, 'Draft', forceValue: true);
        }
      } catch (_) {}
    });
  }

  String _formatTime(DateTime date) {
    final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute $period';
  }

  String _formatFullDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final dayName = days[date.weekday % 7];
    final monthName = months[date.month - 1];
    return '$dayName, $monthName ${date.day}, ${date.year} ${_formatTime(date)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(appUiProvider).isDarkMode;
    final emailState = ref.watch(emailProvider);
    final email = emailState.emails.firstWhere(
      (e) => e.id == widget.draftId,
      orElse: () => EmailModel(
        id: widget.draftId,
        senderName: 'Draft',
        senderEmail: '',
        recipient: '',
        subject: 'Draft Mail',
        body: '',
        date: DateTime.now(),
        isDraft: true,
      ),
    );

    final displaySubject = email.subject.trim().isNotEmpty
        ? email.subject.trim()
        : '(No Subject)';
    final displayBody = email.body.trim().isNotEmpty
        ? email.body.trim()
        : '(No Content)';
    final displayRecipient = email.recipient.trim().isNotEmpty
        ? email.recipient.trim()
        : 'Recipient';

    final formattedTime = _formatTime(email.date);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFEBF3FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFEBF3FA),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.archive_outlined,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            tooltip: 'Archive',
            onPressed: () {
              ref.read(emailProvider.notifier).archiveEmail(email.id, 'Draft');
              context.pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Draft moved to Archive.')),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            tooltip: 'Delete draft',
            onPressed: () {
              ref.read(emailProvider.notifier).deleteEmail(email.id, 'Draft');
              context.pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Draft deleted.')),
              );
            },
          ),
          IconButton(
            icon: Icon(
              email.isRead
                  ? Icons.mark_as_unread_outlined
                  : Icons.mark_email_read_outlined,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            tooltip: email.isRead ? 'Mark as unread' : 'Mark as read',
            onPressed: () {
              ref.read(emailProvider.notifier).toggleRead(
                    email.id,
                    'Draft',
                    forceValue: !email.isRead,
                  );
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    email.isRead ? 'Marked as unread ✓' : 'Marked as read ✓',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            onSelected: (val) {
              if (val == 'star') {
                ref.read(emailProvider.notifier).toggleStar(email.id, 'Draft');
              } else if (val == 'edit') {
                _openComposeToEdit(email);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: const [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Edit Draft'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'star',
                child: Row(
                  children: [
                    Icon(email.isStarred ? Icons.star_rounded : Icons.star_outline_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(email.isStarred ? 'Remove Star' : 'Add Star'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Subject title, "Add label" pill button, Star icon
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      displaySubject,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Label options menu')),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Add label',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(
                      email.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: email.isStarred ? Colors.amber : (isDark ? Colors.white54 : Colors.grey.shade600),
                    ),
                    onPressed: () {
                      ref.read(emailProvider.notifier).toggleStar(email.id, 'Draft');
                    },
                    tooltip: 'Star',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Draft Message Container Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Header Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar Icon Circle
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFD1D5DB),
                          child: Icon(
                            Icons.mail_outline_rounded,
                            color: isDark ? Colors.white70 : Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Middle Info: Draft tag + Timestamp + Recipient dropdown
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Draft',
                                    style: TextStyle(
                                      color: Color(0xFFDC2626), // Bold Red
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    formattedTime,
                                    style: TextStyle(
                                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _showRecipientDetails = !_showRecipientDetails;
                                  });
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'to $displayRecipient',
                                        style: TextStyle(
                                          color: isDark ? Colors.white70 : Colors.grey.shade800,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      _showRecipientDetails
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                                    ),
                                  ],
                                ),
                              ),
                              if (_showRecipientDetails) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'From: ${email.senderEmail.isNotEmpty ? email.senderEmail : "Me"}',
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade700),
                                      ),
                                      Text(
                                        'To: $displayRecipient',
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade700),
                                      ),
                                      Text(
                                        'Date: ${_formatFullDate(email.date)}',
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade700),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Right Side Pencil Edit Icon to reopen Compose Screen
                        IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                            size: 20,
                          ),
                          onPressed: () => _openComposeToEdit(email),
                          tooltip: 'Edit Draft',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Draft Body Text
                    Text(
                      displayBody,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF334155),
                        height: 1.5,
                      ),
                    ),
                    if (email.attachments.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      _buildDraftAttachments(context, email.attachments, isDark),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraftAttachments(BuildContext context, List<AttachmentModel> attachments, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${attachments.length} Attachment${attachments.length > 1 ? 's' : ''}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: attachments.map((att) {
            final isImage = att.fileType == 'IMG' ||
                att.fileName.toLowerCase().endsWith('.png') ||
                att.fileName.toLowerCase().endsWith('.jpg') ||
                att.fileName.toLowerCase().endsWith('.jpeg') ||
                att.fileName.toLowerCase().endsWith('.webp') ||
                att.fileName.toLowerCase().endsWith('.gif');
            final isPdf = att.fileType == 'PDF' || att.fileName.toLowerCase().endsWith('.pdf');

            final badgeColor = isImage
                ? Colors.blue.withValues(alpha: 0.1)
                : (isPdf ? Colors.red.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1));
            final iconColor = isImage
                ? Colors.blue
                : (isPdf ? Colors.red : Colors.amber.shade800);
            final iconData = isImage
                ? Icons.image_rounded
                : (isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded);

            return InkWell(
              onTap: () => _showAttachmentPreviewDialog(context, att, isDark),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 210,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(iconData, color: iconColor, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            att.fileName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            att.fileSize,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.visibility_outlined,
                      size: 18,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showAttachmentPreviewDialog(BuildContext context, AttachmentModel att, bool isDark) {
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
              if (isImage && att.filePath != null && att.filePath!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: att.filePath!.startsWith('http')
                      ? Image.network(
                          att.filePath!,
                          height: 260,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildPlaceholderPreview(att, isDark),
                        )
                      : Image.file(
                          File(att.filePath!),
                          height: 260,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildPlaceholderPreview(att, isDark),
                        ),
                ),
              ] else ...[
                _buildPlaceholderPreview(att, isDark),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Downloading ${att.fileName}...')),
                      );
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

  Widget _buildPlaceholderPreview(AttachmentModel att, bool isDark) {
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

  void _openComposeToEdit(EmailModel email) {
    ref.read(appUiProvider.notifier).clearComposeDraft();
    ref.read(appUiProvider.notifier).updateComposeDraft(
          to: email.recipient,
          subject: email.subject,
          body: email.body,
          draftId: email.id,
        );
    context.push('/compose');
  }
}
