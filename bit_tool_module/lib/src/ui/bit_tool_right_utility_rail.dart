import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/bit_tool_providers.dart';
import 'calculator/bit_tool_calculator.dart';

final macosBetaAppsVisibleProvider = StateProvider<bool>((ref) => true);
typedef BitToolNavCallback = void Function(String target);
final bitToolNavigationCallbackProvider = StateProvider<BitToolNavCallback?>((ref) => null);

typedef MacOSRightUtilityRail = BitToolRightUtilityRail;

class BitToolRightUtilityRail extends ConsumerStatefulWidget {
  const BitToolRightUtilityRail({super.key});

  @override
  ConsumerState<BitToolRightUtilityRail> createState() => _BitToolRightUtilityRailState();
}

class _BitToolRightUtilityRailState extends ConsumerState<BitToolRightUtilityRail> {
  // Currently open panel: null, 'beta', 'calculator', 'calendar', 'notes', 'contacts', 'weather', 'keyboard'
  String? _activeTool;
  int _betaTab = 0; // 0 = FAVORITES, 1 = RECENT
  int _betaBaseType = 0; // 0 = PUBLIC, 1 = BUSINESS

  // In-Drawer Overlay Modal State ('add_calendar', null)
  String? _inPanelOverlay;
  int _calendarAddTab = 0; // 0 = Event, 1 = Note, 2 = Reminder

  // Calendar form controllers
  final TextEditingController _calTitleCtrl = TextEditingController();
  final TextEditingController _calDescCtrl = TextEditingController();
  final TextEditingController _calReminderTitleCtrl = TextEditingController();
  final TextEditingController _calReminderTimeCtrl = TextEditingController(text: '10:00 AM');
  TimeOfDay _calStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _calEndTime = const TimeOfDay(hour: 10, minute: 0);
  bool _calHasStartTime = false;
  bool _calHasEndTime = false;

  // Contact form controllers
  final TextEditingController _contactSearchController = TextEditingController();
  final TextEditingController _contactNameCtrl = TextEditingController();
  final TextEditingController _contactEmailCtrl = TextEditingController();
  final TextEditingController _contactPhoneCtrl = TextEditingController();
  final TextEditingController _contactRoleCtrl = TextEditingController();

  // Note form controllers
  final TextEditingController _noteInputController = TextEditingController();
  final TextEditingController _noteTitleCtrl = TextEditingController();
  final TextEditingController _noteContentCtrl = TextEditingController();

  // Weather state
  String _selectedWeatherCity = 'Tiruvallur';
  final List<String> _weatherCities = [
    'Tiruvallur',
    'Chennai',
    'Bengaluru',
    'Mumbai',
    'Delhi',
    'London',
    'New York',
  ];

  // Virtual Keyboard state
  final TextEditingController _keyboardTextController = TextEditingController();
  bool _isKeyboardShift = false;
  bool _isKeyboardSymbols = false;
  bool _isKeyboardEmoji = false;
  int _keyboardKeystrokes = 0;

  @override
  void initState() {
    super.initState();
    _activeTool = 'beta';
  }

  @override
  void dispose() {
    _contactSearchController.dispose();
    _noteInputController.dispose();
    _keyboardTextController.dispose();
    _calTitleCtrl.dispose();
    _calDescCtrl.dispose();
    _calReminderTitleCtrl.dispose();
    _calReminderTimeCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactEmailCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _contactRoleCtrl.dispose();
    _noteTitleCtrl.dispose();
    _noteContentCtrl.dispose();
    super.dispose();
  }

  Future<void> _launchWebUrl(String url) async {
    try {
      const channel = MethodChannel('com.cliks.business/url_launcher');
      final result = await channel.invokeMethod<bool>('openUrl', {'url': url});
      if (result == true) return;
    } catch (_) {}

    try {
      if (Platform.isMacOS) {
        final res = await Process.run('open', [url]);
        if (res.exitCode == 0) return;
        await Process.run('/usr/bin/open', [url]);
      }
    } catch (e) {
      debugPrint('Error launching web URL: $e');
    }
  }

  Widget _buildLogoImage(
    String fileName, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Color? color,
  }) {
    String cleanName = fileName.replaceAll(' ', '');
    return Image.asset(
      'packages/bit_tool_module/assets/images/$cleanName',
      width: width,
      height: height,
      fit: fit,
      color: color,
      errorBuilder: (ctx, err, stack) {
        return Image.asset(
          'assets/images/$cleanName',
          width: width,
          height: height,
          fit: fit,
          color: color,
          errorBuilder: (ctx2, err2, stack2) {
            return Image.asset(
              'assets/icons_images_reference/$cleanName',
              width: width,
              height: height,
              fit: fit,
              color: color,
              errorBuilder: (c, e, s) => Container(
                width: width ?? 32,
                height: height ?? 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.globe, size: 16, color: Color(0xFF3B82F6)),
              ),
            );
          },
        );
      },
    );
  }

  void _toggleTool(String tool) {
    setState(() {
      if (_activeTool == tool) {
        _activeTool = null;
      } else {
        _activeTool = tool;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(bitToolActiveAccountProvider, (prev, next) {
      if (prev?.email != next.email || prev?.id != next.id) {
        ref.invalidate(bitToolApiModuleProvider);
        ref.invalidate(bitToolContactsProvider);
        ref.invalidate(bitToolNotesProvider);
        ref.invalidate(bitToolCalendarProvider);
        ref.invalidate(bitToolCalculatorProvider);
        ref.invalidate(bitToolConnectionProvider);
      }
    });

    ref.listen(macosBetaAppsVisibleProvider, (prev, next) {
      if (next && _activeTool == null) {
        setState(() => _activeTool = 'beta');
      } else if (!next && _activeTool != null) {
        setState(() => _activeTool = null);
      }
    });

    final hasOpenPanel = _activeTool != null;
    final panelWidth = 390.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Slide-out Drawer Panel (only visible when a tool is selected)
        if (hasOpenPanel)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: panelWidth,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                left: BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            child: Stack(
              children: [
                _buildPanelContent(),
                if (_inPanelOverlay != null)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _inPanelOverlay = null),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.35),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        child: SingleChildScrollView(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {}, // prevent tap on card from closing
                            child: _buildInPanelOverlayContent(),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

        // Slim Pinned Vertical Utility Rail (54px width)
        Container(
          width: 54,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              left: BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // 0. Beta Apps Button ('B' Squircle matching Image 3)
              _buildBetaRailButton(),
              const SizedBox(height: 10),

              // 1. Calendar Button (Amber - Matching Image 3)
              _buildRailBoxBtn(
                tool: 'calendar',
                icon: LucideIcons.calendar,
                tooltip: 'Calendar',
                bgColor: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
              ),
              const SizedBox(height: 10),

              // 2. Calculator Button (Green - Matching Image 3)
              _buildRailBoxBtn(
                tool: 'calculator',
                icon: LucideIcons.calculator,
                tooltip: 'Calculator',
                bgColor: const Color(0xFFD1FAE5),
                iconColor: const Color(0xFF059669),
              ),
              const SizedBox(height: 10),

              // 3. Contacts Button (Blue - Matching Image 3)
              _buildRailBoxBtn(
                tool: 'contacts',
                icon: LucideIcons.contact,
                tooltip: 'Contacts',
                bgColor: const Color(0xFFDBEAFE),
                iconColor: const Color(0xFF2563EB),
              ),
              const SizedBox(height: 10),

              // 4. Keyboard Button (Purple - Matching Image 1/3)
              _buildRailBoxBtn(
                tool: 'keyboard',
                icon: LucideIcons.keyboard,
                tooltip: 'Keyboard',
                bgColor: const Color(0xFFEDE9FE),
                iconColor: const Color(0xFF6366F1),
              ),
              const SizedBox(height: 10),

              // 5. Notes Button (Pink - Matching Image 3)
              _buildRailBoxBtn(
                tool: 'notes',
                icon: LucideIcons.stickyNote,
                tooltip: 'Notes',
                bgColor: const Color(0xFFFCE7F3),
                iconColor: const Color(0xFFDB2777),
              ),
              const SizedBox(height: 10),

              // 6. Weather Button (Sky Blue)
              _buildRailBoxBtn(
                tool: 'weather',
                icon: LucideIcons.cloudSun,
                tooltip: 'Weather',
                bgColor: const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF0284C7),
              ),

              const Spacer(),

              // Quick Compose / Note Edit Button at bottom (Matching Image 3)
              _buildRailBoxBtn(
                tool: 'quick_note',
                icon: LucideIcons.squarePen,
                tooltip: 'Quick Note',
                bgColor: Colors.white,
                iconColor: const Color(0xFF6B7280),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                customTap: () {
                  setState(() => _activeTool = 'notes');
                  _showAddNoteDialog();
                },
              ),
              const SizedBox(height: 10),

              // Sliders / Toggle Drawer Button (Matching Image 3)
              _buildRailBoxBtn(
                tool: 'settings',
                icon: LucideIcons.slidersHorizontal,
                tooltip: 'Toggle Drawer',
                bgColor: Colors.white,
                iconColor: const Color(0xFF6B7280),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                customTap: () {
                  setState(() {
                    if (_activeTool != null) {
                      _activeTool = null;
                    } else {
                      _activeTool = 'beta';
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ],
    );
  }

  // --- Vertical Rail Button Builders ---

  Widget _buildBetaRailButton() {
    final isActive = _activeTool == 'beta';
    return Tooltip(
      message: 'Beta Apps',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _toggleTool('beta'),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive ? const Color(0xFF059669) : const Color(0xFF34D399),
                width: isActive ? 2.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              'B',
              style: TextStyle(
                color: Color(0xFF065F46),
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'sans-serif',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRailBoxBtn({
    required String tool,
    required IconData icon,
    required String tooltip,
    required Color bgColor,
    required Color iconColor,
    Border? border,
    VoidCallback? customTap,
    int badgeCount = 0,
  }) {
    final isActive = _activeTool == tool;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: customTap ?? () => _toggleTool(tool),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isActive ? bgColor.withValues(alpha: 0.9) : bgColor,
                borderRadius: BorderRadius.circular(10),
                border: border ??
                    Border.all(
                      color: isActive ? iconColor : Colors.transparent,
                      width: 1.5,
                    ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: iconColor.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 18),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  alignment: Alignment.center,
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Main Panel Content Switcher ---

  Widget _buildPanelContent() {
    final activeAccount = ref.watch(bitToolActiveAccountProvider);
    return KeyedSubtree(
      key: ValueKey('rail_panel_${_activeTool}_${activeAccount.email}'),
      child: _buildPanelContentForTool(),
    );
  }

  Widget _buildPanelContentForTool() {
    switch (_activeTool) {
      case 'beta':
        return _buildBetaPanel();
      case 'calculator':
        return _buildCalculatorPanel();
      case 'calendar':
        return _buildCalendarPanel();
      case 'notes':
        return _buildNotesPanel();
      case 'contacts':
        return _buildContactsPanel();
      case 'weather':
        return _buildWeatherPanel();
      case 'keyboard':
        return _buildKeyboardPanel();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- Beta Drawer Panel (Matching Image 3 Target Design) ---

  Widget _buildBetaPanel() {
    return Column(
      children: [
        // 1. Header: BETA (bold royal blue), Edit pill button, X close button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
          child: Row(
            children: [
              const Text(
                'BETA',
                style: TextStyle(
                  color: Color(0xFF1D4ED8),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              // Edit pill button
              InkWell(
                onTap: () {
                  final navCb = ref.read(bitToolNavigationCallbackProvider);
                  if (navCb != null) {
                    navCb('settings');
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.pencil, size: 12, color: Color(0xFF374151)),
                      SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Close X button
              IconButton(
                icon: const Icon(LucideIcons.x, size: 18, color: Color(0xFF6B7280)),
                onPressed: () {
                  setState(() => _activeTool = null);
                  ref.read(macosBetaAppsVisibleProvider.notifier).state = false;
                },
                tooltip: 'Close panel',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFF3F4F6)),

        // 2. Scrollable Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tabs: FAVORITES | RECENT
                Row(
                  children: [
                    _buildBetaUnderlineTab('FAVORITES', 0),
                    const SizedBox(width: 24),
                    _buildBetaUnderlineTab('RECENT', 1),
                  ],
                ),
                const SizedBox(height: 12),

                // Card under tabs
                if (_betaTab == 0)
                  Container(
                    height: 64,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'No favorites',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else
                  // Recent tools
                  Row(
                    children: [
                      _buildBaseAppTile(
                        name: 'Calculator',
                        iconWidget: const Icon(LucideIcons.calculator, color: Color(0xFF059669), size: 24),
                        onTap: () => setState(() => _activeTool = 'calculator'),
                      ),
                      const SizedBox(width: 12),
                      _buildBaseAppTile(
                        name: 'Notes',
                        iconWidget: const Icon(LucideIcons.stickyNote, color: Color(0xFFDB2777), size: 24),
                        onTap: () => setState(() => _activeTool = 'notes'),
                      ),
                      const SizedBox(width: 12),
                      _buildBaseAppTile(
                        name: 'Calendar',
                        iconWidget: const Icon(LucideIcons.calendar, color: Color(0xFFD97706), size: 24),
                        onTap: () => setState(() => _activeTool = 'calendar'),
                      ),
                      const SizedBox(width: 12),
                      _buildBaseAppTile(
                        name: 'Contacts',
                        iconWidget: const Icon(LucideIcons.contact, color: Color(0xFF2563EB), size: 24),
                        onTap: () => setState(() => _activeTool = 'contacts'),
                      ),
                    ],
                  ),

                const SizedBox(height: 22),

                // Section: BASE with PUBLIC | BUSINESS switcher
                Row(
                  children: [
                    const Text(
                      'BASE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => setState(() => _betaBaseType = 0),
                      child: Text(
                        'PUBLIC',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: _betaBaseType == 0 ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('|', style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 11)),
                    ),
                    InkWell(
                      onTap: () => setState(() => _betaBaseType = 1),
                      child: Text(
                        'BUSINESS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: _betaBaseType == 1 ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Base Apps Grid (Matching Image 3)
                Wrap(
                  spacing: 12,
                  runSpacing: 14,
                  children: [
                    _buildBaseAppTile(
                      name: 'Cliks',
                      iconWidget: _buildLogoImage(
                        'cliks_logo.png',
                        width: 32,
                        height: 32,
                      ),
                      onTap: () => _launchWebUrl('https://cliks.co.in'),
                    ),
                    _buildBaseAppTile(
                      name: 'BNXmail',
                      iconWidget: _buildLogoImage(
                        'bnx_mail_logo.png',
                        width: 32,
                        height: 32,
                      ),
                      onTap: () => _launchWebUrl('https://mail.bnxmail.com'),
                    ),
                    _buildBaseAppTile(
                      name: 'Bit-Tool',
                      iconWidget: _buildLogoImage(
                        'bit_tool_logo.png',
                        width: 32,
                        height: 32,
                      ),
                      onTap: () => setState(() => _activeTool = 'calculator'),
                    ),
                    _buildBaseAppTile(
                      name: 'B2Auth',
                      iconWidget: const Icon(LucideIcons.shieldCheck, color: Color(0xFF1E293B), size: 26),
                      onTap: () => _launchWebUrl('https://b2auth.com'),
                    ),
                    _buildBaseAppTile(
                      name: 'CliksBus...',
                      iconWidget: _buildLogoImage(
                        'cliks_business_img.png',
                        width: 32,
                        height: 32,
                      ),
                      onTap: () {
                        final nav = ref.read(bitToolNavigationCallbackProvider);
                        if (nav != null) {
                          nav('dashboard');
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // BETA LABS RELEASE / COMING SOON Card (Matching Image 3)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEDE9FE), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF5FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE9D5FF)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.sparkles, size: 11, color: Color(0xFF9333EA)),
                            SizedBox(width: 5),
                            Text(
                              'BETA LABS RELEASE',
                              style: TextStyle(
                                color: Color(0xFF9333EA),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'COMING SOON',
                        style: TextStyle(
                          color: Color(0xFF7C3AED),
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Building the next generation of Beta applications.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),

        // 3. Footer (Matching Image 3)
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Text(
            'BETA ECOSYSTEM   •   FUTURE READY',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBetaUnderlineTab(String title, int index) {
    final isSelected = _betaTab == index;
    return InkWell(
      onTap: () => setState(() => _betaTab = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isSelected ? const Color(0xFF111827) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2.5,
            width: isSelected ? 28 : 0,
            color: isSelected ? const Color(0xFF059669) : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _buildBaseAppTile({
    required String name,
    required Widget iconWidget,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: iconWidget,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. Calculator Panel (Integrated with Bit Tool Calculator API & BetaCalculator)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildCalculatorPanel() {
    return Column(
      children: [
        _buildPanelHeader(
          'Calculator',
          LucideIcons.calculator,
          const Color(0xFF059669),
          onRefresh: () => ref.read(bitToolCalculatorProvider.notifier).loadSessions(),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: BetaCalculator(
              onClose: () => setState(() => _activeTool = null),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. Calendar Panel (Integrated with Bit Tool Calendar API)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildCalendarPanel() {
    final calendarState = ref.watch(bitToolCalendarProvider);

    return Column(
      children: [
        // Top Header: CALENDAR in bold uppercase + X close button (Matching Image 1)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
          child: Row(
            children: [
              const Text(
                'CALENDAR',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(LucideIcons.plus, size: 18, color: Color(0xFF2563EB)),
                onPressed: () => _showAddNewCalendarDialog(initialTab: 0),
                tooltip: 'Add New',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 18, color: Color(0xFF6B7280)),
                onPressed: () {
                  setState(() => _activeTool = null);
                  ref.read(macosBetaAppsVisibleProvider.notifier).state = false;
                },
                tooltip: 'Close panel',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CalendarDatePicker(
                  initialDate: calendarState.selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  onDateChanged: (date) {
                    ref.read(bitToolCalendarProvider.notifier).selectDate(date);
                  },
                ),
                const Divider(height: 20),

                // Reminders
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Reminders & Tasks',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937)),
                    ),
                    TextButton.icon(
                      icon: const Icon(LucideIcons.plus, size: 12),
                      label: const Text('Add', style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _showAddNewCalendarDialog(initialTab: 2),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                if (calendarState.reminders.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Text(
                      'No reminders for selected day.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                    ),
                  )
                else
                  ...calendarState.reminders.map((r) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: r.isCompleted ? const Color(0xFFF3F4F6) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: r.isCompleted ? const Color(0xFFE5E7EB) : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => ref
                                .read(bitToolCalendarProvider.notifier)
                                .toggleReminderComplete(r.id, r.isCompleted),
                            child: Icon(
                              r.isCompleted ? LucideIcons.circleCheck : LucideIcons.circle,
                              size: 16,
                              color: r.isCompleted ? const Color(0xFF10B981) : const Color(0xFFD97706),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.title,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    decoration: r.isCompleted ? TextDecoration.lineThrough : null,
                                    color: r.isCompleted ? const Color(0xFF9CA3AF) : const Color(0xFF1F2937),
                                  ),
                                ),
                                if (r.time.isNotEmpty)
                                  Text(
                                    r.time,
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 14),
                const Text(
                  'Upcoming Deadlines & Events',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937)),
                ),
                const SizedBox(height: 8),

                ...calendarState.events.map((ev) {
                  final catColor = _parseColor(ev.category?.color, const Color(0xFF2563EB));
                  return _buildEventTile(
                    ev.title,
                    '${ev.startTime.day}/${ev.startTime.month} ${ev.startTime.hour}:${ev.startTime.minute.toString().padLeft(2, '0')}',
                    catColor,
                    description: ev.description,
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventTile(String title, String date, Color color, {String? description}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                ),
              ),
              Text(date, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(description, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
          ],
        ],
      ),
    );
  }

  void _showAddNewCalendarDialog({int initialTab = 0}) {
    setState(() {
      _calendarAddTab = initialTab;
      _calTitleCtrl.clear();
      _calDescCtrl.clear();
      _calReminderTitleCtrl.clear();
      _calReminderTimeCtrl.text = '10:00 AM';
      _calHasStartTime = false;
      _calHasEndTime = false;
      _inPanelOverlay = 'add_calendar';
    });
  }

  Widget _buildAddSegmentTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. Contacts Panel (Integrated with Bit Tool Contacts API)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildContactsPanel() {
    final contactsState = ref.watch(bitToolContactsProvider);

    return Column(
      children: [
        // Top Header: "GLOBAL CONTACTS" in bold uppercase + X close icon (Matching Image 4)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
          child: Row(
            children: [
              const Text(
                'GLOBAL CONTACTS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 18, color: Color(0xFF6B7280)),
                onPressed: () {
                  setState(() => _activeTool = null);
                  ref.read(macosBetaAppsVisibleProvider.notifier).state = false;
                },
                tooltip: 'Close panel',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFF3F4F6)),

        // Subheader: "Global Contacts" + "+ Add Contact" blue pill button (Matching Image 4)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Global Contacts',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showAddContactDialog(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.plus, size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Add Contact',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Search Bar (Matching Image 4)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _contactSearchController,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Search global contacts...',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              prefixIcon: const Icon(LucideIcons.search, size: 15, color: Color(0xFF9CA3AF)),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
              ),
              suffixIcon: _contactSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 14),
                      onPressed: () {
                        _contactSearchController.clear();
                        ref.read(bitToolContactsProvider.notifier).setSearchQuery('');
                      },
                    )
                  : null,
            ),
            onChanged: (val) {
              ref.read(bitToolContactsProvider.notifier).setSearchQuery(val);
            },
          ),
        ),

        const Divider(height: 1, color: Color(0xFFF3F4F6)),

        // Contacts List (Matching Image 4)
        Expanded(
          child: contactsState.isLoading && contactsState.contacts.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : contactsState.filteredContacts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.users, size: 36, color: Color(0xFF9CA3AF)),
                          const SizedBox(height: 8),
                          const Text(
                            'No contacts found',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: () => _showAddContactDialog(),
                            child: const Text('Add your first contact', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      itemCount: contactsState.filteredContacts.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      itemBuilder: (ctx, i) {
                        final c = contactsState.filteredContacts[i];
                        final initial = c.initial.isNotEmpty ? c.initial : 'C';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFFDBEAFE),
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.fullName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3F4F6),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFFE5E7EB)),
                                          ),
                                          child: Text(
                                            c.company.isNotEmpty ? c.company.toUpperCase() : 'CLIK BUSINESS',
                                            style: const TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF4B5563),
                                            ),
                                          ),
                                        ),
                                        if (c.email.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              c.email,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (c.email.isNotEmpty)
                                IconButton(
                                  icon: const Icon(LucideIcons.mail, size: 14, color: Color(0xFF9CA3AF)),
                                  onPressed: () => _launchWebUrl('mailto:${c.email}'),
                                  tooltip: c.email,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                ),
                              IconButton(
                                icon: const Icon(LucideIcons.trash2, size: 14, color: Color(0xFFEF4444)),
                                onPressed: () {
                                  ref.read(bitToolContactsProvider.notifier).deleteContact(c.id);
                                },
                                tooltip: 'Delete contact',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _showAddContactDialog() {
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final compCtrl = TextEditingController(text: 'CLIK BUSINESS');
    final roleCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Create New Contact',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 18, color: Color(0xFF6B7280)),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('First Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: firstCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'First Name',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Last Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: lastCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Last Name',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Email Address *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
              const SizedBox(height: 6),
              TextField(
                controller: emailCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'user@example.com',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Phone Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
              const SizedBox(height: 6),
              TextField(
                controller: phoneCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '+91 9876543210',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Company', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: compCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: roleCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'e.g. Supplier',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final first = firstCtrl.text.trim();
                      if (first.isNotEmpty) {
                        ref.read(bitToolContactsProvider.notifier).addContact(
                              firstName: first,
                              lastName: lastCtrl.text.trim(),
                              email: emailCtrl.text.trim(),
                              phone: phoneCtrl.text.trim(),
                              company: compCtrl.text.trim().isNotEmpty ? compCtrl.text.trim() : 'CLIK BUSINESS',
                              role: roleCtrl.text.trim(),
                            );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Contact created successfully')),
                        );
                      }
                    },
                    child: const Text('Save Contact', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. Quick Notes Panel (Integrated with Bit Tool Notes API)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildNotesPanel() {
    final notesState = ref.watch(bitToolNotesProvider);

    // List of pastel themes to cycle through (Matching Image 5)
    final pastelThemes = [
      {'bg': const Color(0xFFE6F9F0), 'border': const Color(0xFFA7F3D0)}, // Mint
      {'bg': const Color(0xFFEBF5FF), 'border': const Color(0xFFBFDBFE)}, // Blue
      {'bg': const Color(0xFFFFF8E1), 'border': const Color(0xFFFDE68A)}, // Yellow
      {'bg': const Color(0xFFFFF3E0), 'border': const Color(0xFFFED7AA)}, // Peach
    ];

    return Column(
      children: [
        // Top Header: "NOTES" in bold uppercase + X close icon (Matching Image 5)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
          child: Row(
            children: [
              const Text(
                'NOTES',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 18, color: Color(0xFF6B7280)),
                onPressed: () {
                  setState(() => _activeTool = null);
                  ref.read(macosBetaAppsVisibleProvider.notifier).state = false;
                },
                tooltip: 'Close panel',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFF3F4F6)),

        // Subheader: "My Notes" + "+ New Note" blue pill button (Matching Image 5)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              const Text(
                'My Notes',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _showAddNoteDialog(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.plus, size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'New Note',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Section Heading: ALL NOTES (Matching Image 5)
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ALL NOTES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
        ),

        // Notes List (Pastel Cards Matching Image 5)
        Expanded(
          child: notesState.isLoading && notesState.notes.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : notesState.notes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.fileText, size: 36, color: Color(0xFF9CA3AF)),
                          const SizedBox(height: 8),
                          const Text(
                            'No notes created yet',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: () => _showAddNoteDialog(),
                            child: const Text('Add your first note', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      itemCount: notesState.notes.length,
                      itemBuilder: (ctx, i) {
                        final n = notesState.notes[i];
                        final theme = pastelThemes[i % pastelThemes.length];
                        final cardBg = n.color.isNotEmpty ? _parseColor(n.color, theme['bg']!) : theme['bg']!;
                        final cardBorder = theme['border']!;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row: Title + Pin icon
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      n.title.isNotEmpty ? n.title : 'Quick Note',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    LucideIcons.pin,
                                    size: 14,
                                    color: n.isPinned ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Content Text
                              Text(
                                n.content,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF374151),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Bottom Row: "BNX MAIL" badge on left, Edit & Trash on right
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFE5E7EB)),
                                    ),
                                    child: const Text(
                                      'BNX MAIL',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  InkWell(
                                    onTap: () => _showEditNoteDialog(n),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(LucideIcons.pencil, size: 14, color: Color(0xFF6B7280)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () {
                                      ref.read(bitToolNotesProvider.notifier).deleteNote(n.id);
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(LucideIcons.trash2, size: 14, color: Color(0xFFEF4444)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _showAddNoteDialog() => _openNoteModal(isEdit: false);
  void _showEditNoteDialog(NoteModel note) => _openNoteModal(isEdit: true, note: note);

  void _openNoteModal({required bool isEdit, NoteModel? note}) {
    final titleCtrl = TextEditingController(text: note?.title ?? '');
    final contentCtrl = TextEditingController(text: note?.content ?? '');
    String modalColor = (note?.color.isNotEmpty ?? false) ? note!.color : '#FED7D7';
    bool modalPinned = note?.isPinned ?? false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final bgColor = _parseColor(modalColor, const Color(0xFFFED7D7));
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: bgColor,
            child: Container(
              width: 460,
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit ? 'Edit Note' : 'New Note',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 18, color: Color(0xFF6B7280)),
                        onPressed: () => Navigator.pop(ctx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Title',
                      hintStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 4,
                    minLines: 3,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                    decoration: const InputDecoration(
                      hintText: 'Take a note...',
                      hintStyle: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ...[
                        '#FFFFFF',
                        '#FED7D7',
                        '#FED7AA',
                        '#FEF08A',
                        '#D1FAE5',
                        '#CFFAFE',
                        '#BFDBFE',
                        '#E9D5FF',
                      ].map((hex) {
                        final c = _parseColor(hex, Colors.grey);
                        final isSelected = modalColor == hex;
                        return GestureDetector(
                          onTap: () => setModalState(() => modalColor = hex),
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB),
                                width: isSelected ? 2.5 : 1,
                              ),
                            ),
                          ),
                        );
                      }),
                      const Spacer(),
                      InkWell(
                        onTap: () => setModalState(() => modalPinned = !modalPinned),
                        child: Row(
                          children: [
                            Icon(
                              modalPinned ? LucideIcons.pin : LucideIcons.pinOff,
                              size: 14,
                              color: modalPinned ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Pinned',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: modalPinned ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final text = contentCtrl.text.trim();
                          if (text.isNotEmpty) {
                            if (isEdit && note != null) {
                              ref.read(bitToolNotesProvider.notifier).updateNote(
                                    id: note.id,
                                    title: titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : 'Quick Note',
                                    content: text,
                                    color: modalColor,
                                    isPinned: modalPinned,
                                  );
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note updated')));
                            } else {
                              ref.read(bitToolNotesProvider.notifier).createNote(
                                    title: titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : 'Quick Note',
                                    content: text,
                                    color: modalColor,
                                    isPinned: modalPinned,
                                  );
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note saved to My Notes')));
                            }
                            Navigator.pop(ctx);
                          }
                        },
                        child: Text(isEdit ? 'Save Changes' : 'Save Note', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // In-Drawer Overlays (Rendered strictly INSIDE the Right Utility Bar)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildInPanelOverlayContent() {
    if (_inPanelOverlay == 'add_calendar') {
      return _buildInPanelCalendarCard();
    }
    return const SizedBox.shrink();
  }

  Widget _buildInPanelCalendarCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Add New',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 18, color: Color(0xFF6B7280)),
                onPressed: () => setState(() => _inPanelOverlay = null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildAddSegmentTab(
                  label: 'Event',
                  isSelected: _calendarAddTab == 0,
                  onTap: () => setState(() => _calendarAddTab = 0),
                ),
                _buildAddSegmentTab(
                  label: 'Note',
                  isSelected: _calendarAddTab == 1,
                  onTap: () => setState(() => _calendarAddTab = 1),
                ),
                _buildAddSegmentTab(
                  label: 'Reminder',
                  isSelected: _calendarAddTab == 2,
                  onTap: () => setState(() => _calendarAddTab = 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_calendarAddTab == 0) ...[
            const Text('Title *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            const SizedBox(height: 6),
            TextField(
              controller: _calTitleCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            const SizedBox(height: 6),
            TextField(
              controller: _calDescCtrl,
              maxLines: 2,
              minLines: 2,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Start Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final p = await showTimePicker(context: context, initialTime: _calStartTime);
                          if (p != null) {
                            setState(() {
                              _calStartTime = p;
                              _calHasStartTime = true;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _calHasStartTime ? _calStartTime.format(context) : '--:-- --',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _calHasStartTime ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                                ),
                              ),
                              const Spacer(),
                              const Icon(LucideIcons.clock, size: 13, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('End Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final p = await showTimePicker(context: context, initialTime: _calEndTime);
                          if (p != null) {
                            setState(() {
                              _calEndTime = p;
                              _calHasEndTime = true;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _calHasEndTime ? _calEndTime.format(context) : '--:-- --',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _calHasEndTime ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                                ),
                              ),
                              const Spacer(),
                              const Icon(LucideIcons.clock, size: 13, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () {
                  if (_calTitleCtrl.text.trim().isNotEmpty) {
                    final sel = ref.read(bitToolCalendarProvider).selectedDate;
                    final startDt = DateTime(
                      sel.year,
                      sel.month,
                      sel.day,
                      _calHasStartTime ? _calStartTime.hour : 9,
                      _calHasStartTime ? _calStartTime.minute : 0,
                    );
                    final endDt = DateTime(
                      sel.year,
                      sel.month,
                      sel.day,
                      _calHasEndTime ? _calEndTime.hour : 10,
                      _calHasEndTime ? _calEndTime.minute : 0,
                    );
                    ref.read(bitToolCalendarProvider.notifier).createEvent(
                          title: _calTitleCtrl.text.trim(),
                          description: _calDescCtrl.text.trim(),
                          start: startDt,
                          end: endDt,
                        );
                    setState(() => _inPanelOverlay = null);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Event saved to Calendar')),
                    );
                  }
                },
                child: const Text('Save event', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ] else if (_calendarAddTab == 1) ...[
            const Text('Title *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            const SizedBox(height: 6),
            TextField(
              controller: _noteTitleCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Content', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            const SizedBox(height: 6),
            TextField(
              controller: _noteContentCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () {
                  if (_noteContentCtrl.text.trim().isNotEmpty) {
                    ref.read(bitToolNotesProvider.notifier).createNote(
                          title: _noteTitleCtrl.text.trim().isNotEmpty ? _noteTitleCtrl.text.trim() : 'Quick Note',
                          content: _noteContentCtrl.text.trim(),
                        );
                    setState(() => _inPanelOverlay = null);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Note saved to My Notes')),
                    );
                  }
                },
                child: const Text('Save Note', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ] else ...[
            const Text('Reminder Title *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            const SizedBox(height: 6),
            TextField(
              controller: _calReminderTitleCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            const SizedBox(height: 6),
            TextField(
              controller: _calReminderTimeCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () {
                  if (_calReminderTitleCtrl.text.trim().isNotEmpty) {
                    final sel = ref.read(bitToolCalendarProvider).selectedDate;
                    final dateStr = '${sel.year}-${sel.month.toString().padLeft(2, '0')}-${sel.day.toString().padLeft(2, '0')}';
                    ref.read(bitToolCalendarProvider.notifier).createReminder(
                          title: _calReminderTitleCtrl.text.trim(),
                          date: dateStr,
                          time: _calReminderTimeCtrl.text.trim(),
                        );
                    setState(() => _inPanelOverlay = null);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reminder added to Calendar')),
                    );
                  }
                },
                child: const Text('Save Reminder', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 5. Weather Panel (Integrated with Bit Tool Weather & Open-Meteo API)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildWeatherPanel() {
    final weatherAsync = ref.watch(bitToolCityWeatherProvider(_selectedWeatherCity));

    return Column(
      children: [
        // Top Header: WEATHER in bold uppercase + X close button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
          child: Row(
            children: [
              const Text(
                'WEATHER',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(LucideIcons.refreshCw, size: 16, color: Color(0xFF6B7280)),
                onPressed: () => ref.refresh(bitToolCityWeatherProvider(_selectedWeatherCity)),
                tooltip: 'Refresh Weather',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 18, color: Color(0xFF6B7280)),
                onPressed: () {
                  setState(() => _activeTool = null);
                  ref.read(macosBetaAppsVisibleProvider.notifier).state = false;
                },
                tooltip: 'Close panel',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),

        // Quick City Selector Horizontal Scroll
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFF9FAFB),
            border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _weatherCities.map((city) {
                final isSelected = city.toLowerCase() == _selectedWeatherCity.toLowerCase();
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedWeatherCity = city);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0284C7) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Text(
                        city,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF374151),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Weather Content
        Expanded(
          child: weatherAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFF0284C7)),
            ),
            error: (err, _) => Center(
              child: Text('Unable to load weather: $err', style: const TextStyle(fontSize: 12)),
            ),
            data: (weather) {
              if (weather == null) {
                return const Center(child: Text('No weather data available.'));
              }

              final current = weather.current;
              final emoji = _getWeatherEmoji(current.weatherCode);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Weather Card with Gradient
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      weather.city,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Text(
                                      weather.country,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(emoji, style: const TextStyle(fontSize: 32)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${current.temperature.toStringAsFixed(1)}°',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 34,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Text(
                                    current.condition,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(LucideIcons.droplets, size: 12, color: Colors.white70),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Hum: ${current.humidity.toStringAsFixed(0)}%',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white, fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(LucideIcons.wind, size: 12, color: Colors.white70),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Wind: ${current.windSpeed.toStringAsFixed(1)} km/h',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white, fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 24-Hour Forecast Strip
                    const Text(
                      '24-Hour Forecast',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 72,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: weather.hourly.length.clamp(0, 12),
                        itemBuilder: (context, index) {
                          final h = weather.hourly[index];
                          final timeStr = '${h.time.hour.toString().padLeft(2, '0')}:00';
                          return Container(
                            width: 58,
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  timeStr,
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                                ),
                                const Icon(LucideIcons.sun, size: 14, color: Color(0xFFF59E0B)),
                                Text(
                                  '${h.temperature.toStringAsFixed(0)}°',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 7-Day Forecast Section
                    const Text(
                      '7-Day Forecast',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        children: weather.daily.map((d) {
                          final dayName = _formatDayOfWeek(d.date);
                          final dEmoji = _getWeatherEmoji(d.weatherCode);

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 48,
                                  child: Text(
                                    dayName,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(dEmoji, style: const TextStyle(fontSize: 13)),
                                const SizedBox(width: 8),
                                Text(
                                  '${d.minTemp.toStringAsFixed(0)}°',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Container(
                                    height: 4,
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF93C5FD), Color(0xFFF97316)],
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${d.maxTemp.toStringAsFixed(0)}°',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDayOfWeek(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  String _getWeatherEmoji(int code) {
    if (code == 0) return '☀️';
    if (code <= 3) return '⛅';
    if (code <= 48) return '🌫️';
    if (code <= 65) return '🌧️';
    if (code <= 75) return '❄️';
    if (code >= 95) return '⛈️';
    return '☁️';
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 6. Virtual Keyboard Panel (Interactive On-Screen Typing & Buffer)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildKeyboardPanel() {
    return Column(
      children: [
        // Top Header: KEYBOARD in bold uppercase + X close button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
          child: Row(
            children: [
              const Text(
                'KEYBOARD',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 18, color: Color(0xFF6B7280)),
                onPressed: () {
                  setState(() => _activeTool = null);
                  ref.read(macosBetaAppsVisibleProvider.notifier).state = false;
                },
                tooltip: 'Close panel',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),

        // Live Text Buffer Screen / Area
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar of buffer with stats and action buttons
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                    border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${_keyboardTextController.text.length} ch',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_keyboardKeystrokes taps',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                      ),
                      const Spacer(),
                      // Copy Button
                      InkWell(
                        onTap: () {
                          if (_keyboardTextController.text.isNotEmpty) {
                            Clipboard.setData(ClipboardData(text: _keyboardTextController.text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied text to clipboard!'),
                                duration: Duration(milliseconds: 1200),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(LucideIcons.copy, size: 13, color: Color(0xFF4B5563)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Clear Button
                      InkWell(
                        onTap: () {
                          setState(() {
                            _keyboardTextController.clear();
                            _keyboardKeystrokes = 0;
                          });
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Clear',
                            style: TextStyle(fontSize: 10, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Text Area
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _keyboardTextController,
                    maxLines: 4,
                    minLines: 3,
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Type with on-screen keys below or physical keyboard...',
                      hintStyle: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Mode Selector: [ ABC | 123 | Emojis ]
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: _buildKeyboardModeBtn(
                  title: 'ABC',
                  isSelected: !_isKeyboardSymbols && !_isKeyboardEmoji,
                  onTap: () {
                    setState(() {
                      _isKeyboardSymbols = false;
                      _isKeyboardEmoji = false;
                    });
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildKeyboardModeBtn(
                  title: '123 & Symbols',
                  isSelected: _isKeyboardSymbols,
                  onTap: () {
                    setState(() {
                      _isKeyboardSymbols = true;
                      _isKeyboardEmoji = false;
                    });
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildKeyboardModeBtn(
                  title: '😊 Emojis',
                  isSelected: _isKeyboardEmoji,
                  onTap: () {
                    setState(() {
                      _isKeyboardEmoji = true;
                      _isKeyboardSymbols = false;
                    });
                  },
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 12, color: Color(0xFFF3F4F6)),

        // Keyboard Surface
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: _isKeyboardEmoji
                ? _buildEmojiGrid()
                : (_isKeyboardSymbols ? _buildSymbolsKeypad() : _buildQwertyKeypad()),
          ),
        ),
      ],
    );
  }

  Widget _buildKeyboardModeBtn({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }

  Widget _buildQwertyKeypad() {
    final row1 = ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'];
    final row2 = ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'];
    final row3 = ['Z', 'X', 'C', 'V', 'B', 'N', 'M'];

    return Column(
      children: [
        // Row 1
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row1.map((char) {
            final letter = _isKeyboardShift ? char : char.toLowerCase();
            return Expanded(
              child: _buildKeyCap(
                label: letter,
                onTap: () => _handleKeyPress(letter),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),

        // Row 2
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row2.map((char) {
            final letter = _isKeyboardShift ? char : char.toLowerCase();
            return Expanded(
              child: _buildKeyCap(
                label: letter,
                onTap: () => _handleKeyPress(letter),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),

        // Row 3: Shift, letters, Backspace
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              flex: 14,
              child: _buildKeyCap(
                label: '⇧',
                isSpecial: true,
                isActive: _isKeyboardShift,
                onTap: () {
                  setState(() => _isKeyboardShift = !_isKeyboardShift);
                },
              ),
            ),
            ...row3.map((char) {
              final letter = _isKeyboardShift ? char : char.toLowerCase();
              return Expanded(
                flex: 10,
                child: _buildKeyCap(
                  label: letter,
                  onTap: () => _handleKeyPress(letter),
                ),
              );
            }),
            Expanded(
              flex: 14,
              child: _buildKeyCap(
                label: '⌫',
                isSpecial: true,
                onTap: _handleBackspace,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Row 4: 123, Space, Return
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              flex: 15,
              child: _buildKeyCap(
                label: '123',
                isSpecial: true,
                onTap: () {
                  setState(() => _isKeyboardSymbols = true);
                },
              ),
            ),
            Expanded(
              flex: 50,
              child: _buildKeyCap(
                label: 'Space',
                isSpecial: false,
                onTap: () => _handleKeyPress(' '),
              ),
            ),
            Expanded(
              flex: 20,
              child: _buildKeyCap(
                label: '↵',
                isSpecial: true,
                onTap: () => _handleKeyPress('\n'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSymbolsKeypad() {
    final row1 = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
    final row2 = ['@', '#', '\$', '%', '&', '-', '+', '(', ')', '/'];
    final row3 = ['=', '*', '"', '\'', ':', ';', '!', '?'];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row1.map((char) {
            return Expanded(
              child: _buildKeyCap(label: char, onTap: () => _handleKeyPress(char)),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row2.map((char) {
            return Expanded(
              child: _buildKeyCap(label: char, onTap: () => _handleKeyPress(char)),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ...row3.map((char) {
              return Expanded(
                flex: 10,
                child: _buildKeyCap(label: char, onTap: () => _handleKeyPress(char)),
              );
            }),
            Expanded(
              flex: 15,
              child: _buildKeyCap(label: '⌫', isSpecial: true, onTap: _handleBackspace),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              flex: 15,
              child: _buildKeyCap(
                label: 'ABC',
                isSpecial: true,
                onTap: () {
                  setState(() => _isKeyboardSymbols = false);
                },
              ),
            ),
            Expanded(
              flex: 50,
              child: _buildKeyCap(
                label: 'Space',
                onTap: () => _handleKeyPress(' '),
              ),
            ),
            Expanded(
              flex: 20,
              child: _buildKeyCap(
                label: '↵',
                isSpecial: true,
                onTap: () => _handleKeyPress('\n'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmojiGrid() {
    const emojis = [
      '😀', '😃', '😄', '😁', '😅', '😂', '🤣', '😊', '😍', '🥰',
      '😘', '😋', '😎', '🥳', '🤩', '🤔', '🤫', '🤗', '🫡', '🤤',
      '👍', '👎', '👏', '🙌', '🫶', '✌️', '🤞', '🤝', '🙏', '💪',
      '❤️', '🧡', '💛', '💚', '💙', '💜', '🔥', '✨', '🎉', '💯',
      '💼', '📊', '📈', '💰', '💳', '📱', '💻', '🚀', '⭐', '✅',
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: emojis.map((e) {
        return InkWell(
          onTap: () => _handleKeyPress(e),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            alignment: Alignment.center,
            child: Text(e, style: const TextStyle(fontSize: 16)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKeyCap({
    required String label,
    required VoidCallback onTap,
    double? width,
    bool isSpecial = false,
    bool isActive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            width: width,
            height: 34,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF6366F1)
                  : (isSpecial ? const Color(0xFFE5E7EB) : Colors.white),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: isActive ? const Color(0xFF6366F1) : const Color(0xFFD1D5DB),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 1,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: label.length > 2 ? 10 : 13,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? Colors.white
                    : (isSpecial ? const Color(0xFF374151) : const Color(0xFF1F2937)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleKeyPress(String char) {
    final text = _keyboardTextController.text;
    final selection = _keyboardTextController.selection;

    if (selection.isValid && selection.start >= 0 && selection.end >= selection.start) {
      final newText = text.replaceRange(selection.start, selection.end, char);
      _keyboardTextController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + char.length),
      );
    } else {
      _keyboardTextController.text = text + char;
      _keyboardTextController.selection = TextSelection.collapsed(offset: _keyboardTextController.text.length);
    }

    setState(() {
      _keyboardKeystrokes++;
    });
  }

  void _handleBackspace() {
    final text = _keyboardTextController.text;
    if (text.isEmpty) return;

    final selection = _keyboardTextController.selection;
    if (selection.isValid && selection.start >= 0 && selection.end > selection.start) {
      final newText = text.replaceRange(selection.start, selection.end, '');
      _keyboardTextController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start),
      );
    } else if (text.isNotEmpty) {
      final newText = text.substring(0, text.length - 1);
      _keyboardTextController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }

    setState(() {
      _keyboardKeystrokes++;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Generic Panel Header Helper
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildPanelHeader(
    String title,
    IconData icon,
    Color color, {
    VoidCallback? onRefresh,
    Widget? trailingAction,
    String? subtitle,
  }) {
    final connection = ref.watch(bitToolConnectionProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                      ),
                  ],
                ),
              ),
              if (onRefresh != null) ...[
                IconButton(
                  icon: const Icon(LucideIcons.refreshCw, size: 15, color: Color(0xFF6B7280)),
                  onPressed: onRefresh,
                  tooltip: 'Sync with Bit Tool API',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
                const SizedBox(width: 4),
              ],
              if (trailingAction != null) ...[
                trailingAction,
                const SizedBox(width: 4),
              ],
              IconButton(
                icon: const Icon(LucideIcons.x, size: 16, color: Color(0xFF6B7280)),
                onPressed: () {
                  setState(() => _activeTool = null);
                  ref.read(macosBetaAppsVisibleProvider.notifier).state = false;
                },
                tooltip: 'Close panel',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Connection status pill reflecting active user login credentials
          Builder(
            builder: (context) {
              final activeAcc = ref.watch(bitToolActiveAccountProvider);
              final displayEmail = activeAcc.email.isNotEmpty
                  ? activeAcc.email
                  : (connection.accountEmail.isNotEmpty ? connection.accountEmail : 'Synced');
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: connection.isConnected ? const Color(0xFFECFDF5) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: connection.isConnected ? const Color(0xFFA7F3D0) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: connection.isConnected ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        connection.isConnected
                            ? (displayEmail.isNotEmpty
                                ? 'Bit Tool Cloud: $displayEmail'
                                : 'Bit Tool Cloud: Synced')
                            : 'Bit Tool API: Local Session',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: connection.isConnected ? const Color(0xFF065F46) : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _parseColor(String? hexString, Color fallback) {
    if (hexString == null || hexString.isEmpty) return fallback;
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return fallback;
    }
  }
}
