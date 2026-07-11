import '../models/email_model.dart';
import '../models/attachment_model.dart';
import '../models/user_model.dart';
import '../models/label_model.dart';
import '../core/theme/colors.dart';

class BNXDummyData {
  static const UserModel currentUser = UserModel(
    name: 'Ravi Kumar C',
    email: 'ravikumar123@bnxmail.com',
  );

  static final List<LabelModel> labels = [
    const LabelModel(id: 'work', name: 'Work', color: BNXColors.labelWork),
    const LabelModel(id: 'personal', name: 'Personal', color: BNXColors.labelPersonal),
    const LabelModel(id: 'important', name: 'Important', color: BNXColors.labelImportant),
    const LabelModel(id: 'promotions', name: 'Promotions', color: BNXColors.labelPromotions),
    const LabelModel(id: 'social', name: 'Social', color: BNXColors.labelSocial),
    const LabelModel(id: 'updates', name: 'Updates', color: BNXColors.labelUpdates),
  ];

  static List<EmailModel> generateEmails() {
    final List<EmailModel> list = [];

    // Detailed hand-crafted emails first to make sure top items look perfect!
    final List<Map<String, dynamic>> templates = [
      {
        'senderName': 'Sarah Chen',
        'senderEmail': 'sarah.chen@bnxmail.com',
        'subject': '🚀 BNXMail Platform Launch Roadmap 2026',
        'body': 'Hi Ravi,\n\nI hope you are doing well. I\'ve put together the final roadmap for the BNXMail launch in Q3. We have completed the core design overhaul and are on track for beta release next week.\n\nKey highlights:\n- Interactive Compose dialog simulation.\n- Full state management using Riverpod.\n- 100+ realistic dummy emails generated locally.\n- Responsive shell design for web, tablet, and desktop views.\n\nPlease review the attached document and let me know if you have any feedback by EOD tomorrow.\n\nBest regards,\nSarah Chen\nProduct Director, BNXMail',
        'labels': ['Work', 'Important'],
        'isStarred': true,
        'isRead': false,
        'hasAttachment': true,
        'attachments': [
          const AttachmentModel(fileName: 'BNXMail_Roadmap_2026.pdf', fileType: 'pdf', fileSize: '4.2 MB'),
          const AttachmentModel(fileName: 'Launch_Assets.zip', fileType: 'zip', fileSize: '18.5 MB'),
        ]
      },
      {
        'senderName': 'Alex Rivera',
        'senderEmail': 'alex.rivera@techcorp.com',
        'subject': 'Code Review: Core responsive layout & sidebar updates',
        'body': 'Hey Ravi,\n\nI just pushed the pull request for the new responsive dashboard shell layout. Could you take a look at `dashboard_shell.dart` and let me know if the sidebar collapse logic is correct?\n\nI tested it on desktop and tablet breakpoints. On tablet view, the sidebar collapses into a narrow rail, and on mobile it collapses fully.\n\nLet\'s discuss during the standup.\n\nCheers,\nAlex',
        'labels': ['Work'],
        'isStarred': false,
        'isRead': false,
        'hasAttachment': false,
      },
      {
        'senderName': 'Figma Team',
        'senderEmail': 'noreply@figma.com',
        'subject': 'James Wilson shared the file "BNXMail High-Fi Prototype v3"',
        'body': 'James Wilson invited you to edit the file "BNXMail High-Fi Prototype v3".\n\nOpen design workspace to view the new layout changes, side panel specs, and hover states. You can comment directly on the boards.\n\n- Figma Team',
        'labels': ['Promotions', 'Social'],
        'isStarred': false,
        'isRead': true,
        'hasAttachment': false,
      },
      {
        'senderName': 'GitHub',
        'senderEmail': 'noreply@github.com',
        'subject': '[GitHub] Security Alert: 3 vulnerabilities found in npm dependencies',
        'body': 'Dear user,\n\nWe found 3 vulnerabilities in dependencies of your repository `flutter_project_bnx`. Please run `npm audit fix` or check the Security tab for details.\n\n- package-lock.json (low)\n- tar (moderate)\n- path-to-regexp (high)\n\nReview vulnerabilities now.',
        'labels': ['Updates'],
        'isStarred': true,
        'isRead': false,
        'hasAttachment': false,
      },
      {
        'senderName': 'Mom',
        'senderEmail': 'mom@family.org',
        'subject': 'Sunday dinner plans & recipes 🍲',
        'body': 'Hi sweetie,\n\nJust checking in to see if you are coming over for dinner this Sunday. I\'m planning to make that lasagna you like. Let me know if you want me to prepare anything else.\n\nAlso, your uncle sends his regards!\n\nLove,\nMom',
        'labels': ['Personal'],
        'isStarred': true,
        'isRead': true,
        'hasAttachment': false,
      },
      {
        'senderName': 'Vercel',
        'senderEmail': 'deployments@vercel.com',
        'subject': 'Deployment Successful: bnxmail-frontend-web',
        'body': 'Project: bnxmail-frontend\nBranch: main\nCommit: [82f9d1a] Add dark mode toggle support.\nStatus: Ready (Production)\n\nYour site was deployed successfully. View the live website or inspect the build logs.',
        'labels': ['Updates'],
        'isStarred': false,
        'isRead': true,
        'hasAttachment': false,
      },
      {
        'senderName': 'Slack Notifications',
        'senderEmail': 'notification@slack.com',
        'subject': 'New message in #bnxmail-design channel from James Wilson',
        'body': 'James Wilson: "I updated the icons for Compose, Starred, Snoozed, and Sent to match Gmail V2. Let me know what you guys think about the border radius."\n\nRead message in Slack app.',
        'labels': ['Social', 'Updates'],
        'isStarred': false,
        'isRead': false,
        'hasAttachment': false,
      },
      {
        'senderName': 'LinkedIn',
        'senderEmail': 'messages-noreply@linkedin.com',
        'subject': 'Ravi, you have 5 new job alerts matching "Senior Flutter Engineer"',
        'body': 'See new jobs in Bengaluru, India matching your profile:\n\n1. Senior Flutter Specialist - Global Tech Labs (hybrid)\n2. Mobile Development Lead - Innovation Hub\n3. Staff Flutter Architect - FinTech Unicorn\n\nView details and apply easily with your profile.',
        'labels': ['Social'],
        'isStarred': false,
        'isRead': true,
        'hasAttachment': false,
      },
      {
        'senderName': 'Stripe',
        'senderEmail': 'billing@stripe.com',
        'subject': 'Your monthly billing invoice is ready [June 2026]',
        'body': 'Dear Ravi Kumar,\n\nYour invoice for subscription plan Stripe Premium API is now available. Your credit card ending in 4242 will be charged \$49.00 on July 5, 2026.\n\nDownload the attached PDF invoice for tax purposes.\n\n- Stripe Billing Team',
        'labels': ['Important', 'Updates'],
        'isStarred': false,
        'isRead': false,
        'hasAttachment': true,
        'attachments': [
          const AttachmentModel(fileName: 'Stripe_Invoice_JUN2026.pdf', fileType: 'pdf', fileSize: '145 KB')
        ]
      },
      {
        'senderName': 'David Harris',
        'senderEmail': 'david.h@friendmail.net',
        'subject': 'Weekend cycling trip details 🚲',
        'body': 'Hey Ravi, here is the map route for our weekend cycling trip. We will meet at the park entrance at 6:30 AM. Don\'t forget your water bottle and helmet!\n\nCheck the GPX coordinate attachment.\n\nBest,\nDavid',
        'labels': ['Personal'],
        'isStarred': false,
        'isRead': true,
        'hasAttachment': true,
        'attachments': [
          const AttachmentModel(fileName: 'Nandi_Hills_Route.gpx', fileType: 'gpx', fileSize: '850 KB')
        ]
      }
    ];

    // Add hand-crafted emails
    for (int i = 0; i < templates.length; i++) {
      final t = templates[i];
      final DateTime date = DateTime.now().subtract(Duration(hours: i * 3 + 1));
      list.add(EmailModel(
        id: 'email_id_${i + 1}',
        senderName: t['senderName'],
        senderEmail: t['senderEmail'],
        recipient: currentUser.email,
        subject: t['subject'],
        body: t['body'],
        date: date,
        isRead: t['isRead'],
        isStarred: t['isStarred'],
        hasAttachment: t['hasAttachment'],
        labels: List<String>.from(t['labels'] ?? []),
        avatar: t['senderName'].substring(0, 1),
        attachments: List<AttachmentModel>.from(t['attachments'] ?? []),
      ));
    }

    // Procedurally generate up to 100 emails to simulate realistic client usage
    final List<String> senders = [
      'Emily Taylor', 'James Wilson', 'Google Cloud', 'Uber India', 'AWS Alerts',
      'Spotify Premium', 'Medium Daily', 'Fly Emirates', 'HackerNews', 'Product Hunt',
      'Dribbble Digest', 'Jira Software', 'Pinterest', 'Airbnb Support', 'Grammarly',
      'GeeksForGeeks', 'Coursera', 'Udemy Tech', 'Zomato Delivery', 'Swiggy Genie'
    ];

    final List<String> domains = [
      'hr-bnxmail.com', 'design.bnxmail.com', 'google.com', 'uber.com', 'amazon.com',
      'spotify.com', 'medium.com', 'emirates.com', 'ycombinator.com', 'producthunt.com',
      'dribbble.com', 'atlassian.net', 'pinterest.com', 'airbnb.com', 'grammarly.com',
      'geeksforgeeks.org', 'coursera.org', 'udemy.com', 'zomato.com', 'swiggy.in'
    ];

    final List<String> subjects = [
      'Weekly HR updates & holiday calendar',
      'Review requested: Colab feature flow diagrams',
      'Billing warning: Quota exceeded in Storage Bucket',
      'Your ride receipt: Friday night trip details',
      'AWS Free Tier usage notification: Billing update',
      'Your personalized playlist for July 2026 is here',
      'Top articles: Why Flutter Web is perfect for admin tools',
      'Flight booked: Bengaluru to San Francisco confirmation',
      'HackerNews: What is the future of serverless containers?',
      'Featured Product: AI coding assistants built on top of IDEs',
      'Weekly Inspiration: UI clean layout & premium components',
      'Issue closed: Fix compose window resizing glitches',
      'New boards added to your feed: workspace aesthetics',
      'Your reservation in Goa is confirmed for August',
      'Monthly report: Your writing metrics have improved!',
      'New tutorial: Deep dive into Riverpod 2.0 notifier classes',
      'Earn your certificate: Mobile Architect pathways',
      'Flash Sale: 90% off on advanced Flutter masterclass',
      'Delivered: Your food order from Chef\'s Bistro',
      'Item Picked Up: Your documents are on the way'
    ];

    final List<String> bodies = [
      'Hello Team,\n\nPlease find the updated HR policies and national holiday list for 2026. Reach out if you have any questions.',
      'Hi Ravi,\n\nJames updated the design files for the Colab panel and left a few questions about how custom widgets scale. Can you please review?',
      'Alert: Your Google Cloud project is exceeding the set budget alert threshold of \$50. Review storage assets and logs.',
      'Thank you for riding with us. Your fare was \$12.40 and was automatically charged to your payment card.',
      'This is an automated alert. Your AWS account has used 85% of its free-tier EC2 hours. To avoid charges, consider scaling down.',
      'Hi there, we have updated your Release Radar with the latest tracks from your favorite electronic and ambient music artists.',
      'Explore today\'s topics: Clean Architecture patterns in Dart, why StateNotifier is still great, and how to configure custom routes.',
      'Thank you for choosing Fly Emirates. Your ticket for flight EK-568 is attached. Boarding starts at 10:15 AM.',
      'Here are the top stories this morning: 1. Show HN: Antigravity IDE Agent; 2. Inside the CPU memory subsystem; 3. Why clean interfaces matter.',
      'Top products today: 1. CodeScribe (AI reviewer); 2. NeoLayout (Tailwind dashboard scaffold); 3. BNXMail Client (Responsive email).',
      'Discover designs you\'ll love: Glassmorphism tabs, subtle shadow panels, premium hover actions, and dark mode systems.',
      'The issue "Dragging Compose Window freezes web browser" has been resolved by implementing optimized drag handlers in Flutter web.',
      'See what your friends are pinning: clean workstations, minimal tech stack layouts, and beautiful typography choices.',
      'Your host Rahul is looking forward to welcoming you! Here are the check-in details and key collection instructions.',
      'Good work! You wrote 12,000 words this month and had high clarity scores. Read your detail report in the attachment.',
      'In this tutorial, we explore Riverpod notifier classes. Learn to build reactive, type-safe states for large enterprise applications.',
      'Continue your learning journey! Complete the remaining two courses in our Mobile System Architecture track to get certified.',
      'Get 95% off on our best-selling course "Flutter for Experts: Core Architectural Patterns and Enterprise Practices".',
      'Your food order from Chef\'s Bistro has been delivered by the courier. Hope you enjoy your meal!',
      'Our courier agent has picked up the documents from your office address. Track live status using the link below.'
    ];

    final List<List<String>> labelPairs = [
      ['Work'], ['Work'], ['Updates'], ['Promotions'], ['Updates'],
      ['Personal'], ['Social'], ['Important'], ['Social'], ['Promotions'],
      ['Social'], ['Work', 'Important'], ['Personal'], ['Personal'], ['Updates'],
      ['Updates'], ['Work'], ['Promotions'], ['Personal'], ['Updates']
    ];

    for (int i = 10; i < 100; i++) {
      final int index = i % senders.length;
      final DateTime date = DateTime.now().subtract(Duration(days: i ~/ 4, hours: (i % 4) * 5));
      final bool isRead = i > 25; // First 25 are mixed, rest are read
      final bool isStarred = i % 7 == 0;
      final bool hasAttachment = i % 11 == 0;

      list.add(EmailModel(
        id: 'email_id_${i + 1}',
        senderName: senders[index],
        senderEmail: '${senders[index].toLowerCase().replaceAll(' ', '.')}@${domains[index]}',
        recipient: currentUser.email,
        subject: '${subjects[index]} #$i',
        body: '${bodies[index]}\n\nThis is a sample email body text generated programmatically to simulate around 100+ emails for testing the search, listing, and label filters in BNXMail application.',
        date: date,
        isRead: isRead,
        isStarred: isStarred,
        hasAttachment: hasAttachment,
        labels: labelPairs[index],
        avatar: senders[index].substring(0, 1),
        attachments: hasAttachment
            ? [
                AttachmentModel(
                  fileName: 'document_attachment_$i.pdf',
                  fileType: 'pdf',
                  fileSize: '${(i * 12) % 300 + 45} KB',
                )
              ]
            : const [],
      ));
    }

    return list;
  }
}
