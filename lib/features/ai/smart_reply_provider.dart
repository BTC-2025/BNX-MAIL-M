import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/email_model.dart';

/// Generates 3 smart reply suggestions based on the email content/labels.
List<String> generateSmartReplies(EmailModel email) {
  final subject = email.subject.toLowerCase();
  final body = email.body.toLowerCase();
  final labels = email.labels.map((l) => l.toLowerCase()).toList();

  if (subject.contains('meet') ||
      subject.contains('call') ||
      subject.contains('schedule') ||
      body.contains('schedule')) {
    return [
      "Sounds good, I am available!",
      "Can we push it to next week?",
      "Please share the meeting link.",
    ];
  }
  if (subject.contains('review') ||
      subject.contains('feedback') ||
      body.contains('pull request') ||
      body.contains('code review')) {
    return [
      "I will review it by EOD.",
      "Looks good to me!",
      "Could you clarify this section?",
    ];
  }
  if (subject.contains('alert') ||
      subject.contains('security') ||
      subject.contains('vulnerabilit')) {
    return [
      "On it, I will fix it right away.",
      "Thanks for the heads-up!",
      "Can you share more details?",
    ];
  }
  if (subject.contains('deploy') ||
      subject.contains('launch') ||
      subject.contains('release') ||
      body.contains('deployed')) {
    return [
      "Great news! Congratulations!",
      "I will verify it on my end.",
      "Let us celebrate!",
    ];
  }
  if (subject.contains('design') ||
      subject.contains('figma') ||
      subject.contains('prototype')) {
    return [
      "Looks amazing! Great work.",
      "I will leave my comments shortly.",
      "Can we discuss in a quick call?",
    ];
  }
  if (labels.contains('personal') || email.senderEmail.contains('family')) {
    return [
      "Thanks so much!",
      "I will be there on Sunday!",
      "Miss you, talk soon!",
    ];
  }
  if (labels.contains('promotions') ||
      subject.contains('offer') ||
      subject.contains('discount')) {
    return [
      "Thanks for the offer!",
      "I will check it out later.",
      "Please unsubscribe me.",
    ];
  }
  if (labels.contains('social') ||
      subject.contains('channel') ||
      body.contains('message in')) {
    return [
      "Thanks for sharing!",
      "I will jump into the thread.",
      "Great update, keep it up!",
    ];
  }
  return [
    "Thanks, I will look into it.",
    "Got it! Will follow up soon.",
    "Could you share more details?",
  ];
}

final smartRepliesProvider = Provider.family<List<String>, EmailModel>((
  ref,
  email,
) {
  return generateSmartReplies(email);
});
