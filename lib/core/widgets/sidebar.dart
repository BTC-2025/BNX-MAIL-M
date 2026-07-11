import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/logo_base64.dart';
import 'sidebar_tile.dart';
import '../../data/app_state_provider.dart';
import '../../data/email_provider.dart';
import '../../data/account_provider.dart';
import '../../dummy/dummy_data.dart';
import '../constants/constants.dart';
import '../theme/colors.dart';
import '../theme/neumorphic.dart';
import 'account_switcher.dart';

class Sidebar extends ConsumerStatefulWidget {
  const Sidebar({super.key});

  @override
  ConsumerState<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<Sidebar> {
  bool _isMoreExpanded = false;
  int _utilityDisplayState = 0; // 0 = Closed (B only), 1 = First 4 + (+), 2 = All 9 + (‹)
  bool _isEditingUtilities = false;
  Set<String> _pinnedUtilityNames = {'Calculator', 'Calendar', 'Contacts', 'Shortcuts', 'Translate', 'Lens OCR', 'Weather', 'News'};

  // Expanded sliding tab states
  String? _expandedUtilityTab;
  DateTime _selectedCalendarDate = DateTime.now();

  final List<String> _keepNotes = ['Buy groceries', 'Review Flutter PR', 'Gym at 6 PM'];
  final List<Map<String, String>> _contacts = [
    {'name': 'Sarah Jenkins', 'email': 'sarah@bnx.com'},
    {'name': 'Alex Rivera', 'email': 'alex@bnx.com'},
    {'name': 'James Miller', 'email': 'james@bnx.com'}
  ];

  bool _securityScanInProgress = false;
  String _securityStatus = 'All systems secure. Threat scan active.';

  final List<Map<String, String>> _chatMessages = [
    {'sender': 'Alex', 'msg': 'Let\'s review the code.'},
    {'sender': 'Ravi', 'msg': 'Sure, looks good!'}
  ];

  final List<Map<String, String>> _shortcuts = [
    {'keys': 'C', 'action': 'Compose new mail'},
    {'keys': 'R', 'action': 'Reply to email'},
    {'keys': '/ ', 'action': 'Search mail'}
  ];

  String _targetLanguage = 'Spanish';
  String _translationResult = '';

  String _ocrOutputText = 'Mock OCR Result: Extracted bill invoice details - total due \$240.00.';
  bool _ocrScanRunning = false;

  final List<String> _cloudFiles = ['presentation_q3.pdf', 'marketing_brief.docx', 'design_logo.png'];

  late final TextEditingController _noteInputController;
  late final TextEditingController _chatInputController;
  late final TextEditingController _translateInputController;

  @override
  void initState() {
    super.initState();
    _noteInputController = TextEditingController();
    _chatInputController = TextEditingController();
    _translateInputController = TextEditingController();
  }

  @override
  void dispose() {
    _noteInputController.dispose();
    _chatInputController.dispose();
    _translateInputController.dispose();
    super.dispose();
  }

  Widget _buildUtilityToggle(String label, IconData icon, bool initialValue, bool isDark) {
    return SwitchListTile(
      title: Row(
        children: [
          Icon(icon, size: 18, color: isDark ? Colors.white70 : Colors.black87),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
      value: initialValue,
      onChanged: (val) {},
      dense: true,
      activeColor: BNXColors.lightPrimary,
    );
  }

  void _showEditUtilitiesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? BNXColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: BNXColors.lightPrimary),
              SizedBox(width: 12),
              Text('Customize BNX Utilities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select which tools appear in your quick access rail. Drag to reorder (Coming Soon).',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                _buildUtilityToggle('Calendar', Icons.calendar_today_rounded, true, isDark),
                _buildUtilityToggle('Keep Notes', Icons.lightbulb_outline_rounded, true, isDark),
                _buildUtilityToggle('Contacts', Icons.people_alt_rounded, true, isDark),
                _buildUtilityToggle('Security', Icons.shield_outlined, true, isDark),
                _buildUtilityToggle('Chat', Icons.chat_bubble_outline_rounded, true, isDark),
                _buildUtilityToggle('Translator', Icons.translate_rounded, false, isDark),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: BNXColors.lightPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(appUiProvider);
    final emails = ref.watch(emailProvider);
    final activeAccount = ref.watch(activeAccountProvider);
    final isDark = uiState.isDarkMode;
    final isCollapsed = uiState.isSidebarCollapsed;
    final customLabels = ref.watch(customLabelsProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    // Helper counts
    final int unreadInbox = emails.where((e) => !e.isRead && !e.isTrash && !e.isDraft && !e.isSent && !e.isArchive && !e.isSpam).length;
    final int draftCount = emails.where((e) => e.isDraft && !e.isTrash).length;
    final int starredCount = emails.where((e) => e.isStarred && !e.isTrash).length;
    
    final jobKeywords = activeAccount.getKeywords();
    final int jobMailsCount = emails.where((e) {
      if (e.isTrash) return false;
      final text = '${e.subject} ${e.body} ${e.senderName} ${e.senderEmail}'.toLowerCase();
      return jobKeywords.any((kw) => text.contains(kw));
    }).length;

    // Left-to-right horizontal scrollable utility icons row
    Widget buildUtilityIcons() {
      // Build the brand "B" icon representing BNX
      Widget buildBrandBIcon() {
        return Tooltip(
          message: _utilityDisplayState == 0 ? 'Open BNX Utilities' : 'Close Utilities',
          child: InkWell(
            onTap: () {
              setState(() {
                if (isCollapsed) {
                  ref.read(appUiProvider.notifier).setSidebarCollapsed(false);
                  _utilityDisplayState = 1;
                } else {
                  if (_utilityDisplayState == 0) {
                    _utilityDisplayState = 1;
                  } else {
                    _utilityDisplayState = 0;
                    _isEditingUtilities = false; // Reset editing on close
                  }
                }
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark 
                      ? [BNXColors.darkPrimary, Colors.blueAccent] 
                      : [BNXColors.lightPrimary, Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: BNXColors.lightPrimary.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                'B',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          ),
        );
      }

      if (isCollapsed) {
        return Container(
          height: 48,
          alignment: Alignment.center,
          child: buildBrandBIcon(),
        );
      }

      final List<Map<String, dynamic>> utilities = [
        {
          'icon': Icons.calculate_rounded,
          'color': const Color(0xFF27AE60),
          'label': 'Calculator',
          'onTap': () {
            setState(() {
              _expandedUtilityTab = _expandedUtilityTab == 'Calculator' ? null : 'Calculator';
            });
          }
        },
        {
          'icon': Icons.calendar_today_rounded,
          'color': const Color(0xFFF2994A),
          'label': 'Calendar',
          'onTap': () {
            setState(() {
              _expandedUtilityTab = _expandedUtilityTab == 'Calendar' ? null : 'Calendar';
            });
          }
        },
        {
          'icon': Icons.people_alt_rounded,
          'color': const Color(0xFF2F80ED),
          'label': 'Contacts',
          'onTap': () {
            setState(() {
              _expandedUtilityTab = _expandedUtilityTab == 'Contacts' ? null : 'Contacts';
            });
          }
        },
        {
          'icon': Icons.keyboard_outlined,
          'color': const Color(0xFF9B51E0),
          'label': 'Shortcuts',
          'onTap': () {
            setState(() {
              _expandedUtilityTab = _expandedUtilityTab == 'Shortcuts' ? null : 'Shortcuts';
            });
          }
        },
        {
          'icon': Icons.translate_rounded,
          'color': const Color(0xFFEB5757),
          'label': 'Translate',
          'onTap': () {
            setState(() {
              _expandedUtilityTab = _expandedUtilityTab == 'Translate' ? null : 'Translate';
            });
          }
        },
        {
          'icon': Icons.filter_center_focus_rounded,
          'color': const Color(0xFF8E44AD),
          'label': 'Lens OCR',
          'onTap': () {
            setState(() {
              _expandedUtilityTab = _expandedUtilityTab == 'Lens OCR' ? null : 'Lens OCR';
            });
          }
        },
        {
          'icon': Icons.wb_sunny_rounded,
          'color': const Color(0xFFF2C94C),
          'label': 'Weather',
          'onTap': () {
            setState(() {
              _expandedUtilityTab = _expandedUtilityTab == 'Weather' ? null : 'Weather';
            });
          }
        },
        {
          'icon': Icons.newspaper_rounded,
          'color': const Color(0xFF56CCF2),
          'label': 'News',
          'onTap': () {
            setState(() {
              _expandedUtilityTab = _expandedUtilityTab == 'News' ? null : 'News';
            });
          }
        },
      ];

      final double targetWidth;
      if (_utilityDisplayState == 0) {
        targetWidth = 96.0; // Increased width to hold both B and Arrow comfortably centered
      } else {
        // Expand width if editing to allow more icons to be seen
        targetWidth = isMobile ? (screenWidth * 0.85).clamp(310, 450) : 340.0;
      }

      List<Map<String, dynamic>> displayList = [];
      if (_utilityDisplayState > 0) {
        if (_isEditingUtilities) {
          displayList = utilities; // Show all for selection
        } else if (_utilityDisplayState == 2) {
          displayList = utilities; // Show all (expanded view)
        } else {
          // Show only pinned utilities in primary state
          displayList = utilities.where((u) => _pinnedUtilityNames.contains(u['label'])).toList();
        }
      }

      return Align(
        alignment: Alignment.centerLeft, // Left aligned as requested
        child: NeumorphicContainer(
          shape: NeumorphicShape.pressed,
          borderRadius: 24,
          height: 48,
          width: targetWidth,
          margin: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 0),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start, // Flow left to right
              children: [
                buildBrandBIcon(),
                if (_utilityDisplayState == 0) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Open Utilities',
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _utilityDisplayState = 1;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
                if (_utilityDisplayState > 0) ...[
                  const SizedBox(width: 6),
                  
                  ...displayList.map((item) {
                  final String label = item['label'] as String;
                  final bool isPinned = _pinnedUtilityNames.contains(label);
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Tooltip(
                          message: label,
                          child: NeumorphicContainer(
                            boxShape: BoxShape.circle,
                            shape: _isEditingUtilities && isPinned ? NeumorphicShape.pressed : NeumorphicShape.flat,
                            depth: 2.0,
                            width: 34,
                            height: 34,
                            color: isDark ? BNXColors.darkSurface : Colors.white,
                            child: InkWell(
                              onTap: () {
                                if (_isEditingUtilities) {
                                  setState(() {
                                    if (isPinned) {
                                      if (_pinnedUtilityNames.length > 1) {
                                        _pinnedUtilityNames.remove(label);
                                      }
                                    } else {
                                      _pinnedUtilityNames.add(label);
                                    }
                                  });
                                } else {
                                  (item['onTap'] as VoidCallback)();
                                }
                              },
                              borderRadius: BorderRadius.circular(17),
                              child: Center(
                                child: Icon(
                                  item['icon'] as IconData,
                                  size: 16,
                                  color: item['color'] as Color,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_isEditingUtilities && isPinned)
                          const IgnorePointer(
                            child: Icon(Icons.check_circle, size: 14, color: BNXColors.lightPrimary),
                          ),
                      ],
                    ),
                  );
                }),
                ],

                if (_isEditingUtilities) ...[
                  // Tick button to save
                  Tooltip(
                    message: 'Save selection',
                    child: NeumorphicContainer(
                      boxShape: BoxShape.circle,
                      shape: NeumorphicShape.flat,
                      depth: 2.0,
                      width: 34,
                      height: 34,
                      color: BNXColors.lightPrimary,
                      child: InkWell(
                        onTap: () => setState(() => _isEditingUtilities = false),
                        borderRadius: BorderRadius.circular(17),
                        child: const Center(
                          child: Icon(Icons.check_rounded, size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Normal controls
                  Tooltip(
                    message: _utilityDisplayState == 2 ? 'Show less' : 'Close rail',
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_utilityDisplayState == 2) {
                            _utilityDisplayState = 1;
                          } else {
                            _utilityDisplayState = 0;
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(17),
                      child: const Icon(Icons.keyboard_arrow_left_rounded, size: 18, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: _utilityDisplayState == 1 ? 'Edit selection' : 'Add / Show more',
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_utilityDisplayState == 1) {
                            _isEditingUtilities = true;
                          } else {
                            _utilityDisplayState = 2;
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(17),
                      child: Icon(
                        _utilityDisplayState == 1 ? Icons.tune_rounded : Icons.add_rounded,
                        size: 18,
                        color: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }



    // Logo section
    Widget buildLogo() {
      return Container(
        height: 64,
        padding: EdgeInsets.only(left: isCollapsed ? 0.0 : 18.0),
        alignment: isCollapsed ? Alignment.center : Alignment.centerLeft,
        child: Row(
          mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            // Custom drawn mail icon representing BNXMail
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: BNXColors.lightPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: BNXColors.lightPrimary.withValues(alpha: 0.2),
                  width: 0.8,
                ),
              ),
              child: Image.asset(
                'assets/logo.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.mail_outline_rounded,
                    color: BNXColors.lightPrimary,
                    size: 20,
                  );
                },
              ),
            ),
            if (!isCollapsed) ...[
              const SizedBox(width: 12),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'BNX',
                      style: TextStyle(
                        color: isDark ? BNXColors.darkPrimary : const Color(0xFF0F52BA), // Sapphire Blue
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextSpan(
                      text: 'mail',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 22,
                ),
              ),
            ]
          ],
        ),
      );
    }

    // Compose Button
    Widget buildComposeButton() {
      if (uiState.activeFolder == 'Templates') {
        return const SizedBox.shrink();
      }
      final currentRoute = GoRouterState.of(context).uri.toString();
      if (currentRoute != '/') {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
        child: NeumorphicButton(
          onPressed: () {
            ref.read(appUiProvider.notifier).setComposeStatus(ComposeStatus.normal);
          },
          height: 56,
          width: isCollapsed ? 56 : double.infinity,
          borderRadius: 16,
          color: isDark ? BNXColors.darkSurface : Colors.white,
          child: Row(
            mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              const SizedBox(width: 16),
              const Icon(
                Icons.edit_outlined,
                color: BNXColors.lightPrimary,
                size: 24,
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 12),
                const Text(
                  'Compose',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: BNXColors.lightPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    void _showCreateLabelDialog(BuildContext context) {
      final TextEditingController controller = TextEditingController();
      Color selectedColor = BNXColors.labelWork; // Default blue color
      final List<Color> colorsList = [
        BNXColors.labelWork,
        BNXColors.labelPersonal,
        BNXColors.labelImportant,
        BNXColors.labelPromotions,
        BNXColors.labelSocial,
        BNXColors.labelUpdates,
      ];

      showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setStateDialog) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;
              return AlertDialog(
                backgroundColor: isDark ? BNXColors.darkSurface : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text(
                  'New Custom Label',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Enter label name',
                        filled: true,
                        fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Select Color Theme',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: colorsList.map((color) {
                        final isSelected = selectedColor == color;
                        return GestureDetector(
                          onTap: () {
                            setStateDialog(() {
                              selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected 
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final name = controller.text.trim();
                      if (name.isNotEmpty) {
                        ref.read(customLabelsProvider.notifier).addLabel(name, selectedColor);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Custom label "$name" created successfully!')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BNXColors.lightPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text('Create'),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    void navigateToFolder(String folderName, String routePath) {
      ref.read(appUiProvider.notifier).selectFolder(folderName);
      ref.read(appUiProvider.notifier).selectEmail(null); // Clear selected email!
      
      // Close drawer if open
      final scaffold = Scaffold.maybeOf(context);
      if (scaffold != null && scaffold.isDrawerOpen) {
        Navigator.pop(context);
      }

      if (GoRouterState.of(context).uri.toString() != routePath) {
        context.go(routePath);
      }
    }

    // 5 Important Folders
    final List<Widget> importantFolderTiles = [
      SidebarTile(
        icon: Icons.all_inbox_rounded,
        selectedIcon: Icons.all_inbox_rounded,
        title: 'All inboxes',
        isSelected: uiState.activeFolder == 'All inboxes' && uiState.activeLabel == null,
        isCollapsed: isCollapsed,
        onTap: () => navigateToFolder('All inboxes', '/'),
      ),
      SidebarTile(
        icon: Icons.inbox_outlined,
        selectedIcon: Icons.inbox,
        title: 'Primary',
        isSelected: uiState.activeFolder == 'Inbox' && uiState.activeLabel == null,
        isCollapsed: isCollapsed,
        badgeText: unreadInbox > 0 ? '$unreadInbox' : null,
        onTap: () => navigateToFolder('Inbox', '/'),
      ),
      SidebarTile(
        icon: Icons.work_outline_rounded,
        selectedIcon: Icons.work_rounded,
        title: 'Job Mails',
        isSelected: uiState.activeFolder == 'Job Mails' && uiState.activeLabel == null,
        isCollapsed: isCollapsed,
        badgeText: jobMailsCount > 0 ? '$jobMailsCount' : null,
        onTap: () => navigateToFolder('Job Mails', '/'),
      ),
      SidebarTile(
        icon: Icons.star_outline_rounded,
        selectedIcon: Icons.star_rounded,
        title: 'Starred',
        isSelected: uiState.activeFolder == 'Starred' && uiState.activeLabel == null,
        isCollapsed: isCollapsed,
        badgeText: starredCount > 0 ? '$starredCount' : null,
        onTap: () => navigateToFolder('Starred', '/'),
      ),
      SidebarTile(
        icon: Icons.send_outlined,
        selectedIcon: Icons.send,
        title: 'Sent',
        isSelected: uiState.activeFolder == 'Sent' && uiState.activeLabel == null,
        isCollapsed: isCollapsed,
        onTap: () => navigateToFolder('Sent', '/'),
      ),
      SidebarTile(
        icon: Icons.file_present_outlined,
        selectedIcon: Icons.insert_drive_file,
        title: 'Drafts',
        isSelected: uiState.activeFolder == 'Draft' && uiState.activeLabel == null,
        isCollapsed: isCollapsed,
        badgeText: draftCount > 0 ? '$draftCount' : null,
        onTap: () => navigateToFolder('Draft', '/'),
      ),
    ];

    // Less / More folders
    final List<Widget> otherFolderTiles = [
      SidebarTile(
        icon: Icons.access_time_rounded,
        selectedIcon: Icons.access_time_filled_rounded,
        title: 'Snoozed',
        isSelected: uiState.activeFolder == 'Snoozed' && uiState.activeLabel == null,
        isCollapsed: isCollapsed,
        onTap: () => navigateToFolder('Snoozed', '/'),
      ),
      SidebarTile(
        icon: Icons.label_important_outline_rounded,
        selectedIcon: Icons.label_important_rounded,
        title: 'Important',
        isSelected: uiState.activeFolder == 'Important' && uiState.activeLabel == null,
        isCollapsed: isCollapsed,
        badgeText: '837',
        onTap: () => navigateToFolder('Important', '/'),
      ),
      SidebarTile(
        icon: Icons.shopping_bag_outlined,
        selectedIcon: Icons.shopping_bag,
        title: 'Purchases',
        isSelected: uiState.activeFolder == 'Purchases' && uiState.activeLabel == null,
        isCollapsed: isCollapsed,
        badgeText: '30',
        onTap: () => navigateToFolder('Purchases', '/'),
      ),
      SidebarTile(
        icon: Icons.schedule_send_outlined,
        selectedIcon: Icons.schedule_send,
        title: 'Scheduled',
        isSelected: uiState.activeFolder == 'Scheduled' && uiState.activeLabel == null,
        isCollapsed: isCollapsed,
        onTap: () => navigateToFolder('Scheduled', '/'),
      ),
      SidebarTile(
        icon: Icons.outbox_outlined,
        selectedIcon: Icons.outbox,
        title: 'Outbox',
        isSelected: uiState.activeFolder == 'Outbox' && uiState.activeLabel == null,
        isCollapsed: isCollapsed,
        onTap: () => navigateToFolder('Outbox', '/'),
      ),
      SidebarTile(
        icon: Icons.archive_outlined,
        selectedIcon: Icons.archive,
        title: 'Archive',
        isSelected: uiState.activeFolder == 'Archive' && uiState.activeLabel == null,
        isCollapsed: isCollapsed,
        onTap: () => navigateToFolder('Archive', '/'),
      ),
      SidebarTile(
        icon: Icons.mail_outline_rounded,
        selectedIcon: Icons.mail_rounded,
        title: 'All Mail',
        isSelected: uiState.activeFolder == 'All Mail' && uiState.activeLabel == null,
        isCollapsed: isCollapsed,
        onTap: () => navigateToFolder('All Mail', '/'),
      ),
      SidebarTile(
        icon: Icons.report_gmailerrorred_outlined,
        selectedIcon: Icons.report_gmailerrorred,
        title: 'Spam',
        isSelected: uiState.activeFolder == 'Spam' && uiState.activeLabel == null,
        isCollapsed: isCollapsed,
        onTap: () => navigateToFolder('Spam', '/'),
      ),
      SidebarTile(
        icon: Icons.delete_outline_rounded,
        selectedIcon: Icons.delete_rounded,
        title: 'Trash',
        isSelected: uiState.activeFolder == 'Trash' && uiState.activeLabel == null,
        isCollapsed: isCollapsed,
        onTap: () => navigateToFolder('Trash', '/'),
      ),
      SidebarTile(
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.bar_chart_rounded,
        title: 'Analytics',
        isSelected: uiState.activeFolder == 'Analytics',
        isCollapsed: isCollapsed,
        onTap: () => navigateToFolder('Analytics', '/analytics'),
      ),
      SidebarTile(
        icon: Icons.assignment_outlined,
        selectedIcon: Icons.assignment_rounded,
        title: 'Templates',
        isSelected: uiState.activeFolder == 'Templates' && uiState.activeLabel == null,
        isCollapsed: isCollapsed,
        onTap: () => navigateToFolder('Templates', '/'),
      ),
      SidebarTile(
        icon: Icons.local_offer_outlined,
        selectedIcon: Icons.local_offer,
        title: 'Promotions',
        isSelected: uiState.activeLabel == 'Promotions',
        isCollapsed: isCollapsed,
        onTap: () {
          ref.read(appUiProvider.notifier).selectLabel('Promotions');
          ref.read(appUiProvider.notifier).selectEmail(null);
          final scaffold = Scaffold.maybeOf(context);
          if (scaffold != null && scaffold.isDrawerOpen) {
            Navigator.pop(context);
          }
          if (GoRouterState.of(context).uri.toString() != '/') {
            context.go('/');
          }
        },
      ),
      SidebarTile(
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
        title: 'Social',
        isSelected: uiState.activeLabel == 'Social',
        isCollapsed: isCollapsed,
        onTap: () {
          ref.read(appUiProvider.notifier).selectLabel('Social');
          ref.read(appUiProvider.notifier).selectEmail(null);
          final scaffold = Scaffold.maybeOf(context);
          if (scaffold != null && scaffold.isDrawerOpen) {
            Navigator.pop(context);
          }
          if (GoRouterState.of(context).uri.toString() != '/') {
            context.go('/');
          }
        },
      ),
      SidebarTile(
        icon: Icons.info_outline,
        selectedIcon: Icons.info,
        title: 'Updates',
        isSelected: uiState.activeLabel == 'Updates',
        isCollapsed: isCollapsed,
        badgeText: '2 new',
        onTap: () {
          ref.read(appUiProvider.notifier).selectLabel('Updates');
          ref.read(appUiProvider.notifier).selectEmail(null);
          final scaffold = Scaffold.maybeOf(context);
          if (scaffold != null && scaffold.isDrawerOpen) {
            Navigator.pop(context);
          }
          if (GoRouterState.of(context).uri.toString() != '/') {
            context.go('/');
          }
        },
      ),
    ];

    return Drawer(
      backgroundColor: isDark ? BNXColors.darkBg : BNXColors.lightSidebarBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Column(
          children: [
            buildLogo(),
            buildUtilityIcons(),
            _buildSlidingTabPanel(isDark),
            buildComposeButton(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ...importantFolderTiles,
                  
                  if (!_isMoreExpanded)
                    SidebarTile(
                      icon: Icons.keyboard_arrow_down_rounded,
                      selectedIcon: Icons.keyboard_arrow_down_rounded,
                      title: 'Show more',
                      isSelected: false,
                      isCollapsed: isCollapsed,
                      onTap: () {
                        setState(() {
                          _isMoreExpanded = true;
                        });
                      },
                    )
                  else ...[
                    ...otherFolderTiles,
                    SidebarTile(
                      icon: Icons.keyboard_arrow_up_rounded,
                      selectedIcon: Icons.keyboard_arrow_up_rounded,
                      title: 'Show less',
                      isSelected: false,
                      isCollapsed: isCollapsed,
                      onTap: () {
                        setState(() {
                          _isMoreExpanded = false;
                        });
                      },
                    ),
                  ],

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Divider(),
                  ),

                  // Chat Section Header
                  if (!isCollapsed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Text(
                        'CHAT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white54 : BNXColors.lightTextSecondary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),

                  // Colab special button (now in CHAT section)
                  SidebarTile(
                    icon: Icons.people_outline_rounded,
                    selectedIcon: Icons.people_rounded,
                    title: 'Colab',
                    isSelected: uiState.activeFolder == 'Colab',
                    isCollapsed: isCollapsed,
                    onTap: () => navigateToFolder('Colab', '/colab'),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Divider(),
                  ),

                  // Labels Section Header
                  if (!isCollapsed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'CUSTOM LABELS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white54 : BNXColors.lightTextSecondary,
                              letterSpacing: 1.0,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showCreateLabelDialog(context),
                            child: Icon(
                              Icons.add,
                              size: 16,
                              color: isDark ? Colors.white54 : BNXColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // List Labels
                  ...customLabels.map((l) {
                    final isSelected = uiState.activeLabel == l.name;
                    return SidebarTile(
                      icon: isSelected ? Icons.label_rounded : Icons.label_outline_rounded,
                      title: l.name,
                      isSelected: isSelected,
                      isCollapsed: isCollapsed,
                      // Wrap in customized icon color
                      selectedIcon: Icons.label_rounded,
                      onTap: () {
                        ref.read(appUiProvider.notifier).selectLabel(l.name);
                        ref.read(appUiProvider.notifier).selectEmail(null); // Clear selected email!
                        
                        // Close drawer if open
                        final scaffold = Scaffold.maybeOf(context);
                        if (scaffold != null && scaffold.isDrawerOpen) {
                          Navigator.pop(context);
                        }

                        if (GoRouterState.of(context).uri.toString() != '/') {
                          context.go('/');
                        }
                      },
                    );
                  }),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Divider(),
                  ),

                  // Settings and support at the bottom
                  SidebarTile(
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    title: 'Settings',
                    isSelected: uiState.activeFolder == 'Settings',
                    isCollapsed: isCollapsed,
                    onTap: () => navigateToFolder('Settings', '/settings'),
                  ),
                  SidebarTile(
                    icon: Icons.help_outline_rounded,
                    selectedIcon: Icons.help_rounded,
                    title: 'Help & Support',
                    isSelected: uiState.activeFolder == 'Help',
                    isCollapsed: isCollapsed,
                    onTap: () => navigateToFolder('Help', '/help'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarTab(bool isDark) {
    final now = DateTime.now();
    final monthLabel = "July ${now.year}";
    final weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              monthLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            Row(
              children: [
                Icon(Icons.chevron_left_rounded, size: 16, color: isDark ? Colors.white54 : Colors.black54),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, size: 16, color: isDark ? Colors.white54 : Colors.black54),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: weekdays.map((w) => SizedBox(
            width: 24,
            child: Text(w, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          )).toList(),
        ),
        const SizedBox(height: 6),
        Column(
          children: List.generate(4, (weekIndex) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (dayIndex) {
                  final dayNumber = weekIndex * 7 + dayIndex + 1;
                  final isSelected = _selectedCalendarDate.day == dayNumber;
                  if (dayNumber > 31) return const SizedBox(width: 24);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCalendarDate = DateTime(now.year, now.month, dayNumber);
                      });
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? (isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary) 
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.transparent : (isDark ? Colors.white10 : Colors.grey.shade200),
                          width: 0.8,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$dayNumber',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected 
                              ? Colors.white 
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        const Divider(height: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              const Icon(Icons.circle, size: 8, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedCalendarDate.day % 2 == 0 
                      ? 'No events scheduled for today.' 
                      : 'Meeting with Q3 Launch Team @ 2:30 PM',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeepNotesTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 80,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _keepNotes.length,
            itemBuilder: (context, idx) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  children: [
                    Icon(Icons.label_outline_rounded, size: 10, color: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _keepNotes[idx],
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _keepNotes.removeAt(idx);
                        });
                      },
                      child: const Icon(Icons.delete_outline_rounded, size: 12, color: Colors.redAccent),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: NeumorphicContainer(
                height: 32,
                shape: NeumorphicShape.pressed,
                borderRadius: 8,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
                child: TextField(
                  controller: _noteInputController,
                  style: const TextStyle(fontSize: 11),
                  decoration: const InputDecoration(
                    hintText: 'Add new note...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            NeumorphicButton(
              onPressed: () {
                final txt = _noteInputController.text.trim();
                if (txt.isNotEmpty) {
                  setState(() {
                    _keepNotes.add(txt);
                    _noteInputController.clear();
                  });
                }
              },
              borderRadius: 8,
              padding: const EdgeInsets.all(8),
              color: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary,
              child: const Icon(Icons.add, size: 14, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactsTab(bool isDark) {
    return Column(
      children: _contacts.map((c) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: isDark ? Colors.white10 : Colors.blue.shade50,
                child: Text(
                  c['name']![0],
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : BNXColors.lightPrimary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c['name']!,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                    ),
                    Text(
                      c['email']!,
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chat_bubble_outline_rounded, size: 14, color: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSecurityTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _securityScanInProgress ? Icons.sync_rounded : Icons.shield_rounded,
              size: 20,
              color: _securityScanInProgress ? Colors.amber : Colors.green,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _securityStatus,
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: NeumorphicButton(
            onPressed: () {
              setState(() {
                _securityScanInProgress = true;
                _securityStatus = 'Scanning emails for malware/phishing...';
              });
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  setState(() {
                    _securityScanInProgress = false;
                    _securityStatus = 'Security check complete. No threats detected.';
                  });
                }
              });
            },
            borderRadius: 8,
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              _securityScanInProgress ? 'Scanning...' : 'Scan Now',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : BNXColors.lightPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatTab(bool isDark) {
    return Column(
      children: [
        SizedBox(
          height: 100,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _chatMessages.length,
            itemBuilder: (context, idx) {
              final m = _chatMessages[idx];
              final isMe = m['sender'] == 'Ravi';
              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 2.0),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isMe 
                        ? (isDark ? BNXColors.darkPrimary.withValues(alpha: 0.2) : Colors.blue.shade50)
                        : (isDark ? Colors.white10 : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${m['sender']}: ${m['msg']}",
                    style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: NeumorphicContainer(
                height: 32,
                shape: NeumorphicShape.pressed,
                borderRadius: 8,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
                child: TextField(
                  controller: _chatInputController,
                  style: const TextStyle(fontSize: 11),
                  decoration: const InputDecoration(
                    hintText: 'Type message...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            NeumorphicButton(
              onPressed: () {
                final txt = _chatInputController.text.trim();
                if (txt.isNotEmpty) {
                  setState(() {
                    _chatMessages.add({'sender': 'Ravi', 'msg': txt});
                    _chatInputController.clear();
                  });
                }
              },
              borderRadius: 8,
              padding: const EdgeInsets.all(8),
              color: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary,
              child: const Icon(Icons.send_rounded, size: 14, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShortcutsTab(bool isDark) {
    return Column(
      children: _shortcuts.map((s) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                s['action']!,
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  s['keys']!,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : BNXColors.lightPrimary),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTranslateTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Translate text to: ', style: TextStyle(fontSize: 10, color: Colors.grey)),
            DropdownButton<String>(
              value: _targetLanguage,
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white : Colors.black87),
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              underline: const SizedBox.shrink(),
              items: ['Spanish', 'French', 'German', 'Chinese'].map((lang) {
                return DropdownMenuItem<String>(value: lang, child: Text(lang));
              }).toList(),
              onChanged: (val) {
                setState(() => _targetLanguage = val!);
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        NeumorphicContainer(
          height: 32,
          shape: NeumorphicShape.pressed,
          borderRadius: 8,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
          child: TextField(
            controller: _translateInputController,
            style: const TextStyle(fontSize: 11),
            decoration: const InputDecoration(
              hintText: 'Enter text to translate...',
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        if (_translationResult.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(6),
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _translationResult,
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: NeumorphicButton(
            onPressed: () {
              final txt = _translateInputController.text.trim();
              if (txt.isNotEmpty) {
                setState(() {
                  _translationResult = "Translated ($_targetLanguage): [Mock Translation of '$txt']";
                });
              }
            },
            borderRadius: 8,
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              'Translate',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : BNXColors.lightPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOcrTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _ocrScanRunning ? 'Analyzing image details...' : _ocrOutputText,
          style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            NeumorphicButton(
              onPressed: () {
                setState(() {
                  _ocrScanRunning = true;
                });
                Future.delayed(const Duration(milliseconds: 1500), () {
                  if (mounted) {
                    setState(() {
                      _ocrScanRunning = false;
                      _ocrOutputText = "Extracted Text: 'Invoice Date: 2026-07-02. Total Paid: \$120.50.'";
                    });
                  }
                });
              },
              borderRadius: 8,
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                _ocrScanRunning ? 'Analyzing...' : 'Scan New File',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : BNXColors.lightPrimary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCloudStorageTab(bool isDark) {
    return Column(
      children: _cloudFiles.map((file) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Icon(Icons.insert_drive_file_outlined, size: 14, color: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  file,
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              Icon(Icons.download_rounded, size: 14, color: isDark ? Colors.white30 : Colors.grey),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSlidingTabPanel(bool isDark) {
    if (_expandedUtilityTab == null || ref.read(appUiProvider).isSidebarCollapsed) {
      return const SizedBox.shrink();
    }

    Widget content;
    switch (_expandedUtilityTab) {
      case 'Calculator':
        content = _buildCalculatorTab(isDark);
        break;
      case 'Calendar':
        content = _buildCalendarTab(isDark);
        break;
      case 'Contacts':
        content = _buildContactsTab(isDark);
        break;
      case 'Shortcuts':
        content = _buildShortcutsTab(isDark);
        break;
      case 'Translate':
        content = _buildTranslateTab(isDark);
        break;
      case 'Lens OCR':
        content = _buildOcrTab(isDark);
        break;
      case 'Weather':
        content = _buildWeatherTab(isDark);
        break;
      case 'News':
        content = _buildNewsTab(isDark);
        break;
      default:
        content = const SizedBox.shrink();
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.fastOutSlowIn,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: NeumorphicContainer(
          borderRadius: 16,
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _expandedUtilityTab!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white70 : BNXColors.lightPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _expandedUtilityTab = null),
                    child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                  ),
                  ],
                ),
                const Divider(height: 16),
                content,
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildCalculatorTab(bool isDark) {
    return Column(
      children: [
        Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '120 + 240 = 360',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 4,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 1.5,
          children: [
            '7', '8', '9', '/',
            '4', '5', '6', '*',
            '1', '2', '3', '-',
            'C', '0', '=', '+'
          ].map((char) {
            return NeumorphicButton(
              onPressed: () {},
              borderRadius: 6,
              padding: EdgeInsets.zero,
              color: isDark ? BNXColors.darkSurface : Colors.white,
              child: Center(
                child: Text(
                  char,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: ['/', '*', '-', '+', '='].contains(char) 
                        ? BNXColors.lightPrimary 
                        : (isDark ? Colors.white : Colors.black87)
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWeatherTab(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'San Francisco',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
            ),
            const Text(
              'Partly Cloudy',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        Row(
          children: [
            const Icon(Icons.cloud_queue_rounded, size: 24, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Text(
              '68°F',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNewsTab(bool isDark) {
    final newsList = [
      'BNXMail Beta launch scheduled next week',
      'Flutter 3.22 dynamic Impeller features',
      'Tech industry shifts towards agentic AI workflows'
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: newsList.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3.0),
                child: Icon(Icons.article_outlined, size: 10, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item,
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
