import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/email_provider.dart';
import '../../../data/app_state_provider.dart';
import '../../../core/widgets/email_tile.dart';
import '../../../core/theme/colors.dart';
import '../../../models/email_model.dart';
import '../../../models/label_model.dart';
import '../../../models/account_model.dart';
import '../../../data/account_provider.dart';
import '../../../data/all_inboxes_provider.dart';
import '../../../data/repositories/mail_repository.dart';
import 'templates_view.dart';
import 'subscriptions_view.dart';

class EmailListScreen extends ConsumerStatefulWidget {
  const EmailListScreen({super.key});

  @override
  ConsumerState<EmailListScreen> createState() => _EmailListScreenState();
}

class _EmailListScreenState extends ConsumerState<EmailListScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _tabs = ['Primary', 'Unread', 'Sent', 'Draft'];
  late TabController _tabController;
  final ScrollController _desktopScrollController = ScrollController();
  int _desktopCurrentPage = 1;
  String? _lastTrackedFolder;
  String? _lastTrackedLabel;
  String? _lastTrackedSearch;
  int? _lastTrackedTab;

  bool _isCustomizeTabsOpen = false;
  final Set<String> _enabledTabs = {'All', 'Important', 'Promotions', 'Social'};
  String _selectedDesktopTab = 'All';

  static const List<Map<String, dynamic>> _allAvailableTabs = [
    {
      'key': 'All',
      'label': 'All',
      'icon': Icons.check_box_outlined,
      'color': Color(0xFF64748B),
    },
    {
      'key': 'Important',
      'label': 'Important',
      'icon': Icons.play_arrow_rounded,
      'color': Color(0xFFF59E0B),
    },
    {
      'key': 'Promotions',
      'label': 'Promotions',
      'icon': Icons.local_offer_rounded,
      'color': Color(0xFF10B981),
    },
    {
      'key': 'Social',
      'label': 'Social',
      'icon': Icons.people_rounded,
      'color': Color(0xFF2563EB),
    },
    {
      'key': 'Updates',
      'label': 'Updates',
      'icon': Icons.info_rounded,
      'color': Color(0xFFF97316),
    },
    {
      'key': 'Job',
      'label': 'Job',
      'icon': Icons.work_rounded,
      'color': Color(0xFF0D9488),
    },
    {
      'key': 'Sent',
      'label': 'Sent',
      'icon': Icons.send_rounded,
      'color': Color(0xFF8B5CF6),
    },
    {
      'key': 'Drafts',
      'label': 'Drafts',
      'icon': Icons.folder_rounded,
      'color': Color(0xFF64748B),
    },
    {
      'key': 'Starred',
      'label': 'Starred',
      'icon': Icons.star_rounded,
      'color': Color(0xFFEAB308),
    },
    {
      'key': 'Trash',
      'label': 'Trash',
      'icon': Icons.delete_rounded,
      'color': Color(0xFFEF4444),
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (mounted && !_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final initialFolder = ref.read(appUiProvider).activeFolder;
        if (initialFolder != 'Subscriptions' &&
            initialFolder != 'Templates' &&
            initialFolder != 'Storage') {
          ref.read(emailProvider.notifier).loadFolder(initialFolder);
        }
      }
    });
  }

  @override
  void dispose() {
    _desktopScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  bool _isSentEmail(EmailModel e, AccountModel activeAccount) {
    if (e.isTrash || e.memberOfFolders.contains('Trash')) return false;
    if (e.isDraft || e.memberOfFolders.contains('Draft')) return false;

    final userEmail = activeAccount.email.trim().toLowerCase();
    final userName = activeAccount.name.trim().toLowerCase();
    final senderEmail = e.senderEmail.trim().toLowerCase();
    final senderName = e.senderName.trim().toLowerCase();

    final isSenderMatch =
        (userEmail.isNotEmpty && senderEmail == userEmail) ||
        (userName.isNotEmpty && senderName == userName);

    if (e.isSent) {
      if (senderEmail.isNotEmpty && userEmail.isNotEmpty && !isSenderMatch) {
        return false;
      }
      return true;
    }

    if (e.memberOfFolders.contains('Sent')) {
      if (senderEmail.isNotEmpty && userEmail.isNotEmpty && !isSenderMatch) {
        return false;
      }
      return true;
    }

    return isSenderMatch;
  }

  bool _isIncomingOrSelf(EmailModel e, AccountModel activeAccount) {
    final userEmail = activeAccount.email.trim().toLowerCase();
    if (userEmail.isEmpty) return true;
    final senderEmail = e.senderEmail.trim().toLowerCase();
    final recipient = e.recipient.trim().toLowerCase();
    if (recipient == userEmail) return true;
    if (senderEmail != userEmail) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(appUiProvider);
    final emails = ref.watch(emailListProvider);
    final activeAccount = ref.watch(activeAccountProvider);
    final isDark = uiState.isDarkMode;
    final bool isDesktopOS =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows);

    // Reactively load folder or category only when activeFolder changes
    ref.listen<String>(appUiProvider.select((s) => s.activeFolder), (
      previous,
      next,
    ) {
      if (previous != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          if (next == 'All Inboxes' || next == 'All inboxes') {
            ref.read(allInboxesProvider.notifier).loadAllInboxes();
          } else if ([
            'Promotions',
            'Social',
            'Updates',
            'Primary',
          ].contains(next)) {
            ref.read(emailProvider.notifier).fetchCategory(next.toLowerCase());
          } else if (next == 'Subscriptions' || next == 'Templates') {
            // Frontend views do not trigger mailbox folder loads
          } else {
            ref.read(emailProvider.notifier).loadFolder(next);
          }
        });
      }
    });

    final int currentTabIndex = _tabController.index;

    // 1. FILTER EMAILS BY FOLDER / CATEGORY
    List<EmailModel> filtered = emails;

    if (uiState.activeLabel != null) {
      // Filter by label accurately (matching both label ID and label name)
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

      filtered = emails
          .where(
            (e) =>
                !e.isTrash &&
                e.labels.any((l) {
                  final norm = l.trim().toLowerCase();
                  return norm == targetId || norm == targetName;
                }),
          )
          .toList();
    } else {
      // Filter by folder
      switch (uiState.activeFolder) {
        case 'Important':
          filtered = emails.where((e) => e.isStarred && !e.isTrash).toList();
          break;
        case 'Job Mails':
          final jobKeywords = activeAccount.getKeywords();
          filtered = emails.where((e) {
            if (e.isTrash) return false;
            final text =
                '${e.subject} ${e.body} ${e.senderName} ${e.senderEmail}'
                    .toLowerCase();
            return jobKeywords.any((kw) => text.contains(kw));
          }).toList();
          break;
        case 'Purchases':
          filtered = emails
              .where(
                (e) =>
                    e.labels.contains('Purchases') ||
                    e.subject.toLowerCase().contains('payment') ||
                    e.subject.toLowerCase().contains('order'),
              )
              .toList();
          break;
        case 'Promotions':
          filtered = emails
              .where(
                (e) =>
                    !e.isTrash &&
                    (e.labels.contains('Promotions') ||
                        e.subject.toLowerCase().contains('promo') ||
                        e.subject.toLowerCase().contains('offer') ||
                        e.subject.toLowerCase().contains('discount') ||
                        e.subject.toLowerCase().contains('sale') ||
                        e.subject.toLowerCase().contains('deal')),
              )
              .toList();
          break;
        case 'Social':
          filtered = emails
              .where(
                (e) =>
                    !e.isTrash &&
                    (e.labels.contains('Social') ||
                        e.subject.toLowerCase().contains('social') ||
                        e.subject.toLowerCase().contains('facebook') ||
                        e.subject.toLowerCase().contains('linkedin') ||
                        e.subject.toLowerCase().contains('twitter') ||
                        e.subject.toLowerCase().contains('instagram') ||
                        e.subject.toLowerCase().contains('invite') ||
                        e.subject.toLowerCase().contains('friend')),
              )
              .toList();
          break;
        case 'Updates':
          filtered = emails
              .where(
                (e) =>
                    !e.isTrash &&
                    (e.labels.contains('Updates') ||
                        e.subject.toLowerCase().contains('update') ||
                        e.subject.toLowerCase().contains('alert') ||
                        e.subject.toLowerCase().contains('notification') ||
                        e.subject.toLowerCase().contains('security') ||
                        e.subject.toLowerCase().contains('billing') ||
                        e.subject.toLowerCase().contains('confirm')),
              )
              .toList();
          break;
        case 'All Inboxes':
        case 'All inboxes':
          final allInboxesState = ref.watch(allInboxesProvider);
          if (allInboxesState.emails.isEmpty && !allInboxesState.isLoading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ref.read(allInboxesProvider.notifier).loadAllInboxes();
              }
            });
          }
          filtered = allInboxesState.emails
              .where(
                (e) => !e.isTrash && !e.isDraft && !e.isArchive && !e.isSpam,
              )
              .toList();
          break;
        case 'Outbox':
          filtered = emails.where((e) => e.isScheduled && !e.isTrash).toList();
          break;
        case 'Inbox':
        case 'Primary':
          // Apply tab sub-filter
          if (currentTabIndex == 0) {
            // Primary inbox: received or self-sent emails
            filtered = emails
                .where(
                  (e) =>
                      !e.isTrash &&
                      !e.isDraft &&
                      !e.isScheduled &&
                      !e.isArchive &&
                      !e.isSpam &&
                      !e.memberOfFolders.contains('Trash') &&
                      !e.memberOfFolders.contains('Archive') &&
                      !e.memberOfFolders.contains('Draft') &&
                      !e.memberOfFolders.contains('Scheduled') &&
                      !e.memberOfFolders.contains('Spam') &&
                      _isIncomingOrSelf(e, activeAccount),
                )
                .toList();
          } else if (currentTabIndex == 1) {
            // Unread inbox: unread received or self-sent emails
            filtered = emails
                .where(
                  (e) =>
                      !e.isRead &&
                      !e.isTrash &&
                      !e.isDraft &&
                      !e.isScheduled &&
                      !e.isArchive &&
                      !e.isSpam &&
                      !e.memberOfFolders.contains('Trash') &&
                      !e.memberOfFolders.contains('Archive') &&
                      !e.memberOfFolders.contains('Draft') &&
                      !e.memberOfFolders.contains('Scheduled') &&
                      !e.memberOfFolders.contains('Spam') &&
                      _isIncomingOrSelf(e, activeAccount),
                )
                .toList();
          } else if (currentTabIndex == 2) {
            // Sent
            filtered = emails
                .where((e) => _isSentEmail(e, activeAccount))
                .toList();
          } else if (currentTabIndex == 3) {
            // Draft
            filtered = emails
                .where(
                  (e) =>
                      (e.isDraft || e.memberOfFolders.contains('Draft')) &&
                      !e.isScheduled &&
                      !e.memberOfFolders.contains('Scheduled') &&
                      !e.isTrash &&
                      !e.memberOfFolders.contains('Trash'),
                )
                .toList();
          }
          break;
        case 'Starred':
          filtered = emails
              .where(
                (e) =>
                    (e.isStarred || e.memberOfFolders.contains('Starred')) &&
                    !e.isTrash &&
                    !e.memberOfFolders.contains('Trash'),
              )
              .toList();
          break;
        case 'Snoozed':
          filtered = emails
              .where(
                (e) =>
                    (e.isSnoozed || e.memberOfFolders.contains('Snoozed')) &&
                    !e.isTrash &&
                    !e.memberOfFolders.contains('Trash'),
              )
              .toList();
          break;
        case 'Sent':
          filtered = emails
              .where((e) => _isSentEmail(e, activeAccount))
              .toList();
          break;
        case 'Draft':
          filtered = emails
              .where(
                (e) =>
                    (e.isDraft || e.memberOfFolders.contains('Draft')) &&
                    !e.isScheduled &&
                    !e.memberOfFolders.contains('Scheduled') &&
                    !e.isTrash &&
                    !e.memberOfFolders.contains('Trash'),
              )
              .toList();
          break;
        case 'Trash':
          filtered = emails
              .where((e) => e.isTrash || e.memberOfFolders.contains('Trash'))
              .toList();
          break;
        case 'Archive':
          filtered = emails
              .where(
                (e) =>
                    (e.isArchive || e.memberOfFolders.contains('Archive')) &&
                    !e.isTrash &&
                    !e.memberOfFolders.contains('Trash'),
              )
              .toList();
          break;
        case 'Scheduled':
          filtered = emails
              .where(
                (e) =>
                    (e.isScheduled ||
                        e.memberOfFolders.contains('Scheduled')) &&
                    !e.isTrash &&
                    !e.memberOfFolders.contains('Trash'),
              )
              .toList();
          break;
        case 'Spam':
          filtered = emails
              .where(
                (e) =>
                    (e.isSpam || e.memberOfFolders.contains('Spam')) &&
                    !e.isTrash &&
                    !e.memberOfFolders.contains('Trash'),
              )
              .toList();
          break;
        case 'All Mail':
          filtered = emails.where((e) => !e.isTrash).toList();
          break;
        case 'Templates':
          filtered = emails
              .where(
                (e) =>
                    e.labels.contains('Templates') ||
                    e.subject.toLowerCase().contains('template'),
              )
              .toList();
          break;
        case 'Subscriptions':
          filtered = emails
              .where(
                (e) =>
                    e.senderEmail.contains('newsletter') ||
                    e.senderEmail.contains('digest') ||
                    e.senderEmail.contains('noreply'),
              )
              .toList();
          break;
        default:
          filtered = emails;
      }
    }

    // Filter out Casbox secure messages from regular email folders (Primary, Starred, Sent, etc.)
    if (uiState.activeFolder != 'All Mail' &&
        uiState.activeFolder != 'Trash' &&
        uiState.activeFolder != 'Starred') {
      filtered = filtered
          .where((e) => !e.labels.any((l) => l.toLowerCase() == 'casbox'))
          .toList();
    }

    print(
      '[STAGE 6: UI FILTERED] ActiveFolder: "${uiState.activeFolder}" | SubTab: $currentTabIndex | Total State Emails: ${emails.length} | Rendered Count: ${filtered.length}',
    );

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

    // 3. SORT EMAILS CHRONOLOGICALLY (Newest at top)
    filtered = List<EmailModel>.from(filtered)
      ..sort((a, b) => b.date.compareTo(a.date));

    // 4. DEDUPLICATE BY EMAIL ID TO PREVENT DUPLICATE KEY RED SCREEN CRASHES
    final seenIds = <String>{};
    filtered = filtered.where((e) => seenIds.add(e.id)).toList();

    // Reset desktop pagination to page 1 if folder, label, search, or subtab changes
    final String currentFolder = uiState.activeFolder;
    final String? currentLabel = uiState.activeLabel;
    final String currentSearch = uiState.searchQuery;
    if (_lastTrackedFolder != currentFolder ||
        _lastTrackedLabel != currentLabel ||
        _lastTrackedSearch != currentSearch ||
        _lastTrackedTab != currentTabIndex) {
      _lastTrackedFolder = currentFolder;
      _lastTrackedLabel = currentLabel;
      _lastTrackedSearch = currentSearch;
      _lastTrackedTab = currentTabIndex;
      _desktopCurrentPage = 1;
    }

    // Desktop pagination: 20 emails per page
    const int pageSize = 20;
    final int serverReported =
        MailRepository.serverFolderCounts[uiState.activeFolder] ?? 0;
    final int totalEmailCount = (serverReported > filtered.length &&
            uiState.searchQuery.isEmpty &&
            uiState.activeLabel == null)
        ? serverReported
        : filtered.length;
    final int maxAvailablePages = filtered.isEmpty
        ? 1
        : ((filtered.length + pageSize - 1) ~/ pageSize);
    final int totalPages = maxAvailablePages;
    final int safePage = _desktopCurrentPage.clamp(1, totalPages);
    if (_desktopCurrentPage != safePage) {
      _desktopCurrentPage = safePage;
    }
    final int startIndex = filtered.isEmpty ? 0 : (safePage - 1) * pageSize;
    final int safeSliceStart = startIndex.clamp(0, filtered.length);
    final int safeSliceEnd =
        (safeSliceStart + pageSize).clamp(safeSliceStart, filtered.length);
    final int startItem = filtered.isEmpty ? 0 : (safeSliceStart + 1);
    final int endItem = safeSliceEnd;

    final List<EmailModel> desktopPagedList = isDesktopOS
        ? (filtered.isEmpty
              ? <EmailModel>[]
              : filtered.sublist(safeSliceStart, safeSliceEnd))
        : filtered;

    print(
      '[UI RENDER DIAGNOSTIC] Active Folder: ${uiState.activeFolder} | SubTab: $currentTabIndex | Total Provider State Emails: ${emails.length} | UI Filtered Rendered Count: ${filtered.length} | Page: $safePage/$totalPages (Showing $startItem-$endItem)',
    );

    // 4. HANDLE VIEW TOGGLING: DETAIL VIEW vs. LIST VIEW
    final Widget mainBody;

    if (uiState.activeFolder == 'Templates' && uiState.activeLabel == null) {
      mainBody = const TemplatesView();
    } else if (uiState.activeFolder == 'Subscriptions' &&
        uiState.activeLabel == null) {
      mainBody = const SubscriptionsView();
    } else {
      // Otherwise render the Email List
      mainBody = Column(
        children: [
          // --- INBOX TAB / ACTION BAR ---
          if (isDesktopOS)
            _buildDesktopEmailHeaderBar(context, ref, uiState, isDark, filtered)
          else if ((uiState.activeFolder == 'Inbox' ||
                  uiState.activeFolder == 'Primary') &&
              uiState.activeLabel == null &&
              uiState.searchQuery.isEmpty)
            Container(
              color: isDark ? BNXColors.darkBg : Colors.white,
              child: TabBar(
                controller: _tabController,
                onTap: (index) => setState(() {}),
                isScrollable: false,
                indicatorColor: const Color(0xFF195bac),
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: const Color(0xFF195bac),
                unselectedLabelColor: isDark
                    ? Colors.white54
                    : Colors.grey.shade500,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                dividerColor: isDark
                    ? BNXColors.darkBorder
                    : BNXColors.lightBorder,
                padding: EdgeInsets.zero,
                labelPadding: EdgeInsets.zero,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.inbox_rounded, size: 20),
                    text: 'Primary',
                    iconMargin: EdgeInsets.only(bottom: 3),
                  ),
                  Tab(
                    icon: Icon(Icons.mark_email_unread_rounded, size: 20),
                    text: 'Unread',
                    iconMargin: EdgeInsets.only(bottom: 3),
                  ),
                  Tab(
                    icon: Icon(Icons.send_rounded, size: 20),
                    text: 'Sent',
                    iconMargin: EdgeInsets.only(bottom: 3),
                  ),
                  Tab(
                    icon: Icon(Icons.drafts_rounded, size: 20),
                    text: 'Draft',
                    iconMargin: EdgeInsets.only(bottom: 3),
                  ),
                ],
              ),
            ),

          // List Content
          Expanded(
            child: isDesktopOS
                ? (filtered.isEmpty
                      ? _buildEmptyState(
                          (uiState.activeFolder == 'Inbox' ||
                                      uiState.activeFolder == 'Primary') &&
                                  uiState.activeLabel == null
                              ? _tabs[currentTabIndex]
                              : uiState.activeFolder,
                          isDark,
                        )
                      : ListView.separated(
                          controller: _desktopScrollController,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: desktopPagedList.length,
                          separatorBuilder: (context, idx) => Divider(
                            height: 1,
                            thickness: 0.6,
                            color: isDark
                                ? BNXColors.darkBorder
                                : const Color(0xFFF1F5F9),
                          ),
                          itemBuilder: (context, idx) {
                            final email = desktopPagedList[idx];
                            return EmailTile(
                              email: email,
                              isSelected: uiState.selectedEmailIds.contains(
                                email.id,
                              ),
                              onTap: () {
                                if (uiState.isSelectionMode) {
                                  ref
                                      .read(appUiProvider.notifier)
                                      .toggleEmailSelection(email.id);
                                } else if (email.isDraft ||
                                    email.memberOfFolders.contains('Draft') ||
                                    uiState.activeFolder == 'Draft') {
                                  if (!email.isRead) {
                                    ref
                                        .read(emailProvider.notifier)
                                        .toggleRead(
                                          email.id,
                                          'Draft',
                                          forceValue: true,
                                        );
                                  }
                                  context.push('/draft/${email.id}');
                                } else {
                                  if (!email.isRead &&
                                      uiState.activeFolder != 'All Inboxes' &&
                                      uiState.activeFolder != 'All inboxes') {
                                    ref
                                        .read(emailProvider.notifier)
                                        .toggleRead(
                                          email.id,
                                          uiState.activeFolder,
                                          forceValue: true,
                                        );
                                  }
                                  context.push('/email/${email.id}');
                                }
                              },
                            );
                          },
                        ))
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: KeyedSubtree(
                      key: ValueKey(
                        '${uiState.activeFolder}_${uiState.activeLabel}_$currentTabIndex',
                      ),
                      child: () {
                        final isFolderLoading =
                            (uiState.activeFolder == 'All Inboxes' ||
                                uiState.activeFolder == 'All inboxes')
                            ? ref.watch(allInboxesProvider).isLoading
                            : ref.watch(emailProvider).isLoading;

                        if (filtered.isEmpty && isFolderLoading) {
                          return _buildLoadingState(isDark);
                        }

                        if (filtered.isEmpty) {
                          return _buildEmptyState(
                            (uiState.activeFolder == 'Inbox' ||
                                        uiState.activeFolder == 'Primary') &&
                                    uiState.activeLabel == null
                                ? _tabs[currentTabIndex]
                                : uiState.activeFolder,
                            isDark,
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () async {
                            if (uiState.activeFolder == 'All Inboxes' ||
                                uiState.activeFolder == 'All inboxes') {
                              await ref
                                  .read(allInboxesProvider.notifier)
                                  .loadAllInboxes(forceRefresh: true);
                            } else {
                              await ref
                                  .read(emailProvider.notifier)
                                  .initialLoad();
                            }
                          },
                          child: NotificationListener<UserScrollNotification>(
                            onNotification: (notification) {
                              if (notification.direction ==
                                  ScrollDirection.reverse) {
                                if (ref.read(fabExtensionProvider)) {
                                  ref
                                          .read(fabExtensionProvider.notifier)
                                          .state =
                                      false;
                                }
                              } else if (notification.direction ==
                                  ScrollDirection.forward) {
                                if (!ref.read(fabExtensionProvider)) {
                                  ref
                                          .read(fabExtensionProvider.notifier)
                                          .state =
                                      true;
                                }
                              }
                              return true;
                            },
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 8,
                              ),
                              itemCount: filtered.length + 1,
                              itemBuilder: (context, idx) {
                                if (idx == filtered.length) {
                                  return const SizedBox(
                                    height: 80,
                                  ); // Space for FAB
                                }
                                final email = filtered[idx];
                                final isFirst = idx == 0;
                                final isLast = idx == filtered.length - 1;

                                final borderColor = isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.grey.shade300;

                                return Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1E293B)
                                        : Colors.white,
                                    borderRadius: BorderRadius.vertical(
                                      top: isFirst
                                          ? const Radius.circular(16)
                                          : Radius.zero,
                                      bottom: isLast
                                          ? const Radius.circular(16)
                                          : Radius.zero,
                                    ),
                                    border: Border(
                                      top: isFirst
                                          ? BorderSide(color: borderColor)
                                          : BorderSide.none,
                                      bottom: isLast
                                          ? BorderSide(color: borderColor)
                                          : BorderSide.none,
                                      left: BorderSide(color: borderColor),
                                      right: BorderSide(color: borderColor),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: isDark ? 0.1 : 0.02,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.vertical(
                                      top: isFirst
                                          ? const Radius.circular(16)
                                          : Radius.zero,
                                      bottom: isLast
                                          ? const Radius.circular(16)
                                          : Radius.zero,
                                    ),
                                    child: Column(
                                      key: ValueKey(
                                        'email_item_${email.id}_$idx',
                                      ),
                                      children: [
                                        EmailTile(
                                          email: email,
                                          isSelected: uiState.selectedEmailIds
                                              .contains(email.id),
                                          onTap: () {
                                            if (uiState.isSelectionMode) {
                                              ref
                                                  .read(appUiProvider.notifier)
                                                  .toggleEmailSelection(
                                                    email.id,
                                                  );
                                            } else if (email.isDraft ||
                                                email.memberOfFolders.contains(
                                                  'Draft',
                                                ) ||
                                                uiState.activeFolder ==
                                                    'Draft') {
                                              if (!email.isRead) {
                                                ref
                                                    .read(
                                                      emailProvider.notifier,
                                                    )
                                                    .toggleRead(
                                                      email.id,
                                                      'Draft',
                                                      forceValue: true,
                                                    );
                                              }
                                              context.push(
                                                '/draft/${email.id}',
                                              );
                                            } else {
                                              if (!email.isRead &&
                                                  uiState.activeFolder !=
                                                      'All Inboxes' &&
                                                  uiState.activeFolder !=
                                                      'All inboxes') {
                                                ref
                                                    .read(
                                                      emailProvider.notifier,
                                                    )
                                                    .toggleRead(
                                                      email.id,
                                                      uiState.activeFolder,
                                                      forceValue: true,
                                                    );
                                              }
                                              context.push(
                                                '/email/${email.id}',
                                              );
                                            }
                                          },
                                        ),
                                        if (!isLast)
                                          Divider(
                                            height: 1,
                                            thickness: 0.8,
                                            color: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.08,
                                                  )
                                                : Colors.grey.shade200,
                                            indent: 0,
                                            endIndent: 0,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }(),
                    ),
                  ),
          ),
          if (isDesktopOS)
            _buildDesktopPaginationBar(
              isDark: isDark,
              startItem: startItem,
              endItem: endItem,
              totalCount: totalEmailCount,
              currentPage: safePage,
              totalPages: totalPages,
            ),
        ],
      );
    }

    final Widget finalBody = isDesktopOS
        ? Stack(
            children: [
              mainBody,
              if (_isCustomizeTabsOpen) ...[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _isCustomizeTabsOpen = false;
                      });
                    },
                    child: Container(color: Colors.transparent),
                  ),
                ),
                Positioned(
                  top: 48,
                  left: 14,
                  child: _buildCustomizeTabsPopup(isDark),
                ),
              ],
            ],
          )
        : mainBody;

    return Container(
      color: isDark
          ? Colors.transparent
          : (isDesktopOS ? Colors.white : const Color(0xFFE9F4FF)),
      child: finalBody,
    );
  }

  Widget _buildEmptyState(String folder, bool isDark) {
    final bool isDesktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows);
    if (isDesktop) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📬', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(
              'Your folder is empty',
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
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

  Widget _buildLoadingState(bool isDark) {
    return ListView.builder(
      itemCount: 6,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 72,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 140,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 200,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopEmailHeaderBar(
    BuildContext context,
    WidgetRef ref,
    AppUiState uiState,
    bool isDark,
    List<EmailModel> currentEmails,
  ) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? BNXColors.darkBg : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? BNXColors.darkBorder : const Color(0xFFF1F5F9),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              size: 18,
              color: _isCustomizeTabsOpen
                  ? const Color(0xFF195BAC)
                  : (isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
            tooltip: 'Customize tabs',
            onPressed: () {
              setState(() {
                _isCustomizeTabsOpen = !_isCustomizeTabsOpen;
              });
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: isDark ? Colors.white70 : const Color(0xFF475569),
            tooltip: 'Refresh',
            onPressed: () {
              ref.read(emailProvider.notifier).forceRefreshFolder(uiState.activeFolder);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 14),
          // Enabled tabs list (All, Important, Promotions, Social, etc.)
          ..._allAvailableTabs
              .where((t) => _enabledTabs.contains(t['key']))
              .map((tab) {
                final String key = tab['key'];
                final String label = tab['label'];
                final IconData icon = tab['icon'];
                final bool isSelected = _selectedDesktopTab == key;
                final Color tabColor = isSelected
                    ? const Color(0xFF195BAC)
                    : (isDark ? Colors.white70 : const Color(0xFF475569));

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDesktopTab = key;
                    });
                    if (key == 'All') {
                      ref.read(appUiProvider.notifier).selectFolder('Inbox');
                    } else if (key == 'Drafts') {
                      ref.read(appUiProvider.notifier).selectFolder('Draft');
                    } else {
                      ref.read(appUiProvider.notifier).selectFolder(key);
                    }
                  },
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected
                              ? const Color(0xFF195BAC)
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (key == 'All') ...[
                          Icon(
                            Icons.check_box_outlined,
                            size: 16,
                            color: tabColor,
                          ),
                          const SizedBox(width: 6),
                        ] else ...[
                          Icon(icon, size: 16, color: tabColor),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          label,
                          style: TextStyle(
                            color: tabColor,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
        ],
      ),
    );
  }

  Widget _buildCustomizeTabsPopup(bool isDark) {
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(16),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: Container(
        width: 195,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? BNXColors.darkBorder : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 8),
              child: Text(
                'CUSTOMIZE TABS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
            ),
            ..._allAvailableTabs.map((tab) {
              final String key = tab['key'];
              final String label = tab['label'];
              final IconData icon = tab['icon'];
              final Color color = tab['color'];
              final bool isChecked = _enabledTabs.contains(key);
              final bool isHighlighted = isChecked && key == 'Social';

              return InkWell(
                onTap: () {
                  setState(() {
                    if (key == 'All') return;
                    if (_enabledTabs.contains(key)) {
                      _enabledTabs.remove(key);
                    } else {
                      _enabledTabs.add(key);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  margin: const EdgeInsets.symmetric(vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? const Color(0xFFEBF5FF)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isHighlighted
                        ? Border.all(color: const Color(0xFF2563EB), width: 1.2)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isChecked
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      if (isChecked)
                        const Icon(
                          Icons.check,
                          size: 15,
                          color: Color(0xFF2563EB),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopPaginationBar({
    required bool isDark,
    required int startItem,
    required int endItem,
    required int totalCount,
    required int currentPage,
    required int totalPages,
  }) {
    final bool canPrev = currentPage > 1;
    final bool canNext = currentPage < totalPages;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? BNXColors.darkBg : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? BNXColors.darkBorder : const Color(0xFFF1F5F9),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startItem to $endItem of $totalCount emails',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                color: canPrev
                    ? (isDark ? Colors.white70 : Colors.black87)
                    : (isDark ? Colors.white24 : Colors.grey.shade300),
                onPressed: canPrev
                    ? () {
                        setState(() {
                          _desktopCurrentPage = currentPage - 1;
                        });
                        if (_desktopScrollController.hasClients) {
                          _desktopScrollController.jumpTo(0);
                        }
                      }
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: canPrev ? 'Previous page' : null,
              ),
              const SizedBox(width: 6),
              Text(
                '$currentPage/$totalPages',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                color: canNext
                    ? (isDark ? Colors.white70 : Colors.black87)
                    : (isDark ? Colors.white24 : Colors.grey.shade300),
                onPressed: canNext
                    ? () {
                        setState(() {
                          _desktopCurrentPage = currentPage + 1;
                        });
                        if (_desktopScrollController.hasClients) {
                          _desktopScrollController.jumpTo(0);
                        }
                      }
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: canNext ? 'Next page' : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
