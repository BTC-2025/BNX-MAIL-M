import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/email_model.dart';
import '../../../data/app_state_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/neumorphic.dart';

/// Generates 3 contextual smart reply suggestions from email content keywords.
List<String> _generateReplies(EmailModel email) {
  final body = email.body.toLowerCase();
  final subject = email.subject.toLowerCase();

  // Check for common email scenarios and generate relevant replies
  if (body.contains('meeting') ||
      body.contains('schedule') ||
      subject.contains('meeting')) {
    return [
      'Sounds great! I\'ll be there.',
      'Can we reschedule to next week?',
      'Thanks for the invite — confirmed!',
    ];
  }
  if (body.contains('review') ||
      body.contains('pull request') ||
      body.contains('feedback')) {
    return [
      'I\'ll review it today.',
      'Looks good! Approved ✅',
      'A few comments — let\'s discuss.',
    ];
  }
  if (body.contains('deadline') ||
      body.contains('urgent') ||
      body.contains('asap')) {
    return [
      'On it! Will update you shortly.',
      'Working on it now.',
      'Can we extend the deadline by a day?',
    ];
  }
  if (body.contains('invoice') ||
      body.contains('payment') ||
      body.contains('billing')) {
    return [
      'Payment confirmed. Thank you!',
      'I\'ll process this by EOD.',
      'Could you resend the invoice?',
    ];
  }
  if (body.contains('thank') || body.contains('appreciate')) {
    return [
      'You\'re most welcome! 😊',
      'Happy to help anytime!',
      'Glad it worked out!',
    ];
  }
  if (body.contains('question') ||
      body.contains('clarif') ||
      body.contains('?')) {
    return [
      'Great question! Let me check.',
      'Sure, happy to clarify.',
      'I\'ll get back to you shortly.',
    ];
  }
  if (body.contains('launch') ||
      body.contains('release') ||
      body.contains('deploy')) {
    return [
      'Exciting! Looking forward to it.',
      'Ready on our end!',
      'Let me know if you need anything.',
    ];
  }
  // Default replies
  return [
    'Thanks for reaching out!',
    'Got it — I\'ll follow up.',
    'Sounds good, talk soon!',
  ];
}

class AiSmartReplyBar extends ConsumerStatefulWidget {
  final EmailModel email;

  const AiSmartReplyBar({super.key, required this.email});

  @override
  ConsumerState<AiSmartReplyBar> createState() => _AiSmartReplyBarState();
}

class _AiSmartReplyBarState extends ConsumerState<AiSmartReplyBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    // Simulate AI "thinking" delay
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() => _visible = true);
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(appUiProvider).isDarkMode;
    final replies = _generateReplies(widget.email);

    return NeumorphicContainer(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF4F7FB),
      border: Border.all(
        color: isDark
            ? BNXColors.darkPrimary.withValues(alpha: 0.3)
            : BNXColors.lightPrimary.withValues(alpha: 0.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              NeumorphicContainer(
                padding: const EdgeInsets.all(6),
                borderRadius: 8,
                shape: NeumorphicShape.pressed,
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFEAF1FB),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: isDark
                      ? BNXColors.darkPrimary
                      : BNXColors.lightPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'AI Smart Reply',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? BNXColors.darkPrimary
                      : BNXColors.lightPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (!_visible)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: isDark
                        ? BNXColors.darkPrimary
                        : BNXColors.lightPrimary,
                  ),
                ),
            ],
          ),
          if (_visible) ...[
            const SizedBox(height: 12),
            FadeTransition(
              opacity: _fadeIn,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: replies.map((reply) {
                  return _SmartReplyChip(
                    label: reply,
                    isDark: isDark,
                    email: widget.email,
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SmartReplyChip extends ConsumerWidget {
  final String label;
  final bool isDark;
  final EmailModel email;

  const _SmartReplyChip({
    required this.label,
    required this.isDark,
    required this.email,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NeumorphicButton(
      onPressed: () {
        final replyTo = (email.isSent && email.recipient.isNotEmpty)
            ? email.recipient
            : email.senderEmail;
        // Pre-fill compose with this smart reply
        ref
            .read(appUiProvider.notifier)
            .updateComposeDraft(
              to: replyTo,
              subject: 'Re: ${email.subject}',
              body: label,
            );
        ref.read(appUiProvider.notifier).setComposeStatus(ComposeStatus.normal);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reply pre-filled: "$label"'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      borderRadius: 20,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.reply_rounded,
            size: 16,
            color: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white : BNXColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
