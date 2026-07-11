import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/ui_components.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/neumorphic.dart';
import '../../../data/app_state_provider.dart';
import '../../../data/colab_provider.dart';
import '../../../models/attachment_model.dart';
import 'package:file_picker/file_picker.dart';

class ColabScreen extends ConsumerWidget {
  const ColabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    final selectedGroupId = ref.watch(selectedColabIdProvider);
    if (selectedGroupId != null) {
      return _buildColabDetailView(context, ref, selectedGroupId, isDark, isMobile);
    }

    final groups = ref.watch(colabListProvider);
    final searchQuery = uiState.searchQuery.toLowerCase();
    final filteredGroups = groups.where((g) {
      return g.name.toLowerCase().contains(searchQuery) ||
          g.desc.toLowerCase().contains(searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? BNXColors.darkSurface : Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header (Group Icon, Colab, Collaborate with your teams, "New Colab" Button)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            onPressed: () {
                              ref.read(appUiProvider.notifier).selectFolder('Inbox');
                              context.go('/');
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: BNXColors.lightPrimary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.people_alt_rounded,
                              color: BNXColors.lightPrimary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Colab',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Collaborate with your teams',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'New Colab',
                        icon: Icons.group_add_rounded,
                        onPressed: () => _showCreateColabDialog(context, ref, isDark),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            onPressed: () {
                              ref.read(appUiProvider.notifier).selectFolder('Inbox');
                              context.go('/');
                            },
                            padding: const EdgeInsets.only(top: 12),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: BNXColors.lightPrimary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.people_alt_rounded,
                              color: BNXColors.lightPrimary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Colab',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Collaborate with your teams',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      PrimaryButton(
                        label: 'New Colab',
                        icon: Icons.group_add_rounded,
                        onPressed: () => _showCreateColabDialog(context, ref, isDark),
                      ),
                    ],
                  ),
          ),

          const Divider(),

          // 2. Colab Group search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: SizedBox(
              width: isMobile ? double.infinity : 320,
              child: SearchBox(
                hintText: 'Search colab groups...',
                onChanged: (val) {
                  ref.read(appUiProvider.notifier).setSearchQuery(val);
                },
              ),
            ),
          ),

          // 3. Center Section / Colab Content List
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'ACTIVE DISCUSSIONS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white30 : Colors.grey,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Render active group cards
                  if (filteredGroups.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        child: Text(
                          'No Colab groups found.',
                          style: TextStyle(color: isDark ? Colors.white30 : Colors.grey),
                        ),
                      ),
                    )
                  else
                    ...filteredGroups.map((g) => _buildGroupCard(context, ref, g, isDark)),

                  const SizedBox(height: 40),

                  // Bottom Graphic Mock
                  Center(
                    child: Column(
                      children: [
                        NeumorphicContainer(
                          width: 80,
                          height: 80,
                          boxShape: BoxShape.circle,
                          shape: NeumorphicShape.pressed,
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
                          child: const Icon(
                            Icons.question_answer_outlined,
                            size: 32,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Need to set up a new workgroup?',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Create groups to collaborate in real-time, share files,\nand edit code assets concurrently.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, WidgetRef ref, ColabGroup group, bool isDark) {
    final bool hasUnread = group.unread;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    final avatar = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: BNXColors.lightPrimary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.groups_rounded,
        color: BNXColors.lightPrimary,
        size: 24,
      ),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                group.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasUnread) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          group.desc,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Active: ',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(width: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: group.members.map((m) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? BNXColors.darkBorder : BNXColors.lightBorder,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    m,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ],
    );

    final chatButton = NeumorphicButton(
      onPressed: () {
        ref.read(selectedColabIdProvider.notifier).state = group.id;
        ref.read(colabListProvider.notifier).markAsRead(group.id);
      },
      borderRadius: 18,
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Text(
        'Open Chat',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white70 : BNXColors.lightPrimary,
        ),
      ),
    );

    return InkWell(
      onTap: () {
        ref.read(selectedColabIdProvider.notifier).state = group.id;
        ref.read(colabListProvider.notifier).markAsRead(group.id);
      },
      child: NeumorphicContainer(
        margin: const EdgeInsets.only(bottom: 16),
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: 14,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        avatar,
                        const SizedBox(width: 12),
                        Expanded(child: details),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: chatButton,
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    avatar,
                    const SizedBox(width: 16),
                    Expanded(child: details),
                    const SizedBox(width: 16),
                    chatButton,
                  ],
                ),
        ),
      ),
    );
  }

  void _showCreateColabDialog(BuildContext context, WidgetRef ref, bool isDark) {
    final nameController = TextEditingController();
    final membersController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          backgroundColor: isDark ? BNXColors.darkSurface : Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(28.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(
                  'Create Colab Group',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Colab Group Name',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Project Alpha',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? BNXColors.darkBorder : BNXColors.lightBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: BNXColors.lightPrimary,
                        width: 2,
                      ),
                    ),
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Member Emails (comma separated)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: membersController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'user1@bnxmail.com, user2@bnxmail.com',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? BNXColors.darkBorder : BNXColors.lightBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: BNXColors.lightPrimary,
                        width: 2,
                      ),
                    ),
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    // Create Colab button on the left
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BNXColors.lightPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final name = nameController.text.trim();
                          final membersText = membersController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a group name')),
                            );
                            return;
                          }
                          final membersList = membersText.isEmpty
                              ? <String>[]
                              : membersText.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  
                          // Add to state provider
                          final newGroup = ref.read(colabListProvider.notifier).addGroup(
                                name: name,
                                members: membersList,
                              );
  
                          // Select the new group
                          ref.read(selectedColabIdProvider.notifier).state = newGroup.id;
  
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          'Create Colab',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Cancel button on the right
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white70 : BNXColors.lightTextPrimary,
                          side: BorderSide(
                            color: isDark ? BNXColors.darkBorder : BNXColors.lightBorder,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          'Cancel',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  Widget _buildColabDetailView(
      BuildContext context, WidgetRef ref, String groupId, bool isDark, bool isMobile) {
    final groups = ref.watch(colabListProvider);
    final group = groups.firstWhere((g) => g.id == groupId,
        orElse: () => ColabGroup(id: '', name: 'Not Found', desc: '', members: []));

    if (group.id.isEmpty) {
      return Scaffold(
        backgroundColor: isDark ? BNXColors.darkSurface : Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Colab Group not found'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(selectedColabIdProvider.notifier).state = null,
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final headerRow = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => ref.read(selectedColabIdProvider.notifier).state = null,
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.purple,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              group.name.isNotEmpty ? group.name[0].toUpperCase() : 'P',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        group.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: isDark ? Colors.white38 : Colors.grey,
                      ),
                      onPressed: () => _showGroupInfoDialog(context, group, isDark),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'GROUP • ONLINE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'info') {
                _showGroupInfoDialog(context, group, isDark);
              } else if (value == 'leave') {
                final updatedMembers = List<String>.from(group.members)..remove('Ravi');
                ref.read(colabListProvider.notifier).updateGroupMembers(group.id, updatedMembers);
                ref.read(selectedColabIdProvider.notifier).state = null;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('You left the group "${group.name}".')),
                );
              } else if (value == 'delete') {
                ref.read(colabListProvider.notifier).deleteGroup(group.id);
                ref.read(selectedColabIdProvider.notifier).state = null;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Group "${group.name}" has been deleted.')),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Group Info'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'leave',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Leave Group', style: TextStyle(color: Colors.orange)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text('Delete Group', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (isMobile) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: isDark ? BNXColors.darkSurface : Colors.white,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerRow,
              const Divider(height: 1),
              TabBar(
                labelColor: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.email_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Broadcasts'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Comments'),
                      ],
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TabBarView(
                    children: [
                      _buildBroadcastsPanel(context, ref, group, isDark),
                      CommentsSection(group: group, isDark: isDark, ref: ref),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? BNXColors.darkSurface : Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headerRow,
          const Divider(height: 1),

          // Two Panels (Professional Broadcasts & Comments)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 11,
                    child: _buildBroadcastsPanel(context, ref, group, isDark),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 9,
                    child: CommentsSection(group: group, isDark: isDark, ref: ref),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBroadcastsPanel(
      BuildContext context, WidgetRef ref, ColabGroup group, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? BNXColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? BNXColors.darkBorder : BNXColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => _showComposeBroadcastDialog(context, ref, group.id, isDark),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.email_outlined, color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Professional Broadcasts (${group.broadcasts.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.add_comment_outlined,
                    size: 16,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child: group.broadcasts.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mail_outline_rounded,
                              size: 32,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No Broadcasts Sent',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Send professional email updates to all group members. Click the button below to compose.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: group.broadcasts.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final b = group.broadcasts[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? BNXColors.darkBorder : BNXColors.lightBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.campaign_rounded, size: 16, color: Colors.blueAccent),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Broadcast #${index + 1}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ],
                                ),
                                Text(
                                  'By: ${b.sender}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            const Text(
                              'To: All Members',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Subject: ${b.subject}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              b.body,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white.withOpacity(0.9) : BNXColors.lightTextPrimary,
                              ),
                            ),
                            if (b.attachments.isNotEmpty) ...[
                              const Divider(height: 24),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: b.attachments.map((att) {
                                  IconData iconData = Icons.insert_drive_file_rounded;
                                  Color iconColor = Colors.blue;
                                  if (att.fileType == 'pdf') {
                                    iconData = Icons.picture_as_pdf_rounded;
                                    iconColor = Colors.red;
                                  } else if (att.fileType == 'image') {
                                    iconData = Icons.image_rounded;
                                    iconColor = Colors.purple;
                                  } else if (att.fileType == 'code') {
                                    iconData = Icons.code_rounded;
                                    iconColor = Colors.green;
                                  }
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(iconData, size: 14, color: iconColor),
                                        const SizedBox(width: 6),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 120),
                                          child: Text(
                                            att.fileName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '(${att.fileSize})',
                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Compose button at bottom
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () => _showComposeBroadcastDialog(context, ref, group.id, isDark),
                icon: const Icon(Icons.mail_outline_rounded, color: Colors.white, size: 18),
                label: const Text(
                  'Compose New Broadcast',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupInfoDialog(BuildContext context, ColabGroup group, bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? BNXColors.darkSurface : Colors.white,
          title: Text(
            group.name,
            style: TextStyle(color: isDark ? Colors.white : BNXColors.lightTextPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Description:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : BNXColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                group.desc,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Text(
                'Active Members (${group.members.length}):',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : BNXColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: group.members.map((m) {
                  return Chip(
                    label: Text(m, style: const TextStyle(fontSize: 12)),
                    backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showComposeBroadcastDialog(
      BuildContext context, WidgetRef ref, String groupId, bool isDark) {
    final subjectController = TextEditingController();
    final bodyController = TextEditingController();
    List<AttachmentModel> attachedFiles = [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              backgroundColor: isDark ? BNXColors.darkSurface : Colors.white,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compose New Broadcast',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Subject',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: subjectController,
                        decoration: InputDecoration(
                          hintText: 'Enter subject...',
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                          contentPadding: const EdgeInsets.all(12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark ? BNXColors.darkBorder : BNXColors.lightBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: BNXColors.lightPrimary,
                              width: 2,
                            ),
                          ),
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Broadcast Message',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: bodyController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Enter broadcast update for all group members...',
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                          contentPadding: const EdgeInsets.all(12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark ? BNXColors.darkBorder : BNXColors.lightBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: BNXColors.lightPrimary,
                              width: 2,
                            ),
                          ),
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (attachedFiles.isNotEmpty) ...[
                        Text(
                          'Attachments (${attachedFiles.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: attachedFiles.map((file) {
                            IconData iconData = Icons.insert_drive_file_rounded;
                            Color iconColor = Colors.blue;
                            if (file.fileType == 'pdf') {
                              iconData = Icons.picture_as_pdf_rounded;
                              iconColor = Colors.red;
                            } else if (file.fileType == 'image') {
                              iconData = Icons.image_rounded;
                              iconColor = Colors.purple;
                            } else if (file.fileType == 'code') {
                              iconData = Icons.code_rounded;
                              iconColor = Colors.green;
                            }
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(iconData, size: 14, color: iconColor),
                                  const SizedBox(width: 6),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 150),
                                    child: Text(
                                      file.fileName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        attachedFiles.remove(file);
                                      });
                                    },
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: isDark ? Colors.white54 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: isDark ? BNXColors.darkSurface : Colors.white,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                builder: (context) {
                                  return SafeArea(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Attach File',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          ListTile(
                                            leading: const Icon(Icons.upload_file_rounded, color: Colors.blue),
                                            title: const Text('Choose from device...'),
                                            onTap: () async {
                                              Navigator.pop(context);
                                              try {
                                                final result = await FilePicker.platform.pickFiles();
                                                if (result != null && result.files.isNotEmpty) {
                                                  final file = result.files.first;
                                                  setState(() {
                                                    attachedFiles.add(AttachmentModel(
                                                      fileName: file.name,
                                                      fileType: file.extension ?? 'bin',
                                                      fileSize: file.size > 1024 * 1024
                                                          ? '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB'
                                                          : '${(file.size / 1024).toStringAsFixed(0)} KB',
                                                    ));
                                                  });
                                                }
                                              } catch (e) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Failed to pick file: $e')),
                                                );
                                              }
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                                            title: const Text('PDF Document (e.g., BNXMail_Specs_Draft.pdf)'),
                                            onTap: () {
                                              Navigator.pop(context);
                                              setState(() {
                                                attachedFiles.add(const AttachmentModel(
                                                  fileName: 'BNXMail_Specs_Draft.pdf',
                                                  fileType: 'pdf',
                                                  fileSize: '1.2 MB',
                                                ));
                                              });
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.image_rounded, color: Colors.purple),
                                            title: const Text('Image Asset (e.g., App_Screenshot.png)'),
                                            onTap: () {
                                              Navigator.pop(context);
                                              setState(() {
                                                attachedFiles.add(const AttachmentModel(
                                                  fileName: 'App_Screenshot.png',
                                                  fileType: 'image',
                                                  fileSize: '850 KB',
                                                ));
                                              });
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.code_rounded, color: Colors.green),
                                            title: const Text('Source Code File (e.g., main.dart)'),
                                            onTap: () {
                                              Navigator.pop(context);
                                              setState(() {
                                                attachedFiles.add(const AttachmentModel(
                                                  fileName: 'main.dart',
                                                  fileType: 'code',
                                                  fileSize: '12 KB',
                                                ));
                                              });
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.add_circle_outline_rounded, color: Colors.blue),
                                            title: const Text('Custom Attachment...'),
                                            onTap: () {
                                              Navigator.pop(context);
                                              final customController = TextEditingController();
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  backgroundColor: isDark ? BNXColors.darkSurface : Colors.white,
                                                  title: Text('Custom File Name', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                                                  content: TextField(
                                                    controller: customController,
                                                    decoration: const InputDecoration(hintText: 'Enter file name with extension...'),
                                                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(ctx),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        final name = customController.text.trim();
                                                        if (name.isNotEmpty) {
                                                          setState(() {
                                                            attachedFiles.add(AttachmentModel(
                                                              fileName: name,
                                                              fileType: name.split('.').last.toLowerCase(),
                                                              fileSize: '250 KB',
                                                            ));
                                                          });
                                                        }
                                                        Navigator.pop(ctx);
                                                      },
                                                      child: const Text('Add'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                            icon: const Icon(Icons.attach_file_rounded, size: 16),
                            label: const Text('Attach File'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BNXColors.lightPrimary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              final subjectText = subjectController.text.trim();
                              final bodyText = bodyController.text.trim();
                              if (subjectText.isEmpty || bodyText.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please fill all fields')),
                                );
                                return;
                              }

                              ref.read(colabListProvider.notifier).addBroadcast(
                                    groupId,
                                    sender: 'Ravi',
                                    subject: subjectText,
                                    body: bodyText,
                                    attachments: attachedFiles,
                                  );

                              Navigator.of(context).pop();
                            },
                            child: const Text('Send Broadcast', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class CommentsSection extends StatefulWidget {
  final ColabGroup group;
  final bool isDark;
  final WidgetRef ref;

  const CommentsSection({
    super.key,
    required this.group,
    required this.isDark,
    required this.ref,
  });

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void didUpdateWidget(covariant CommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.comments.length < widget.group.comments.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    widget.ref.read(colabListProvider.notifier).addComment(widget.group.id, 'Ravi', text);
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? BNXColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.isDark ? BNXColors.darkBorder : BNXColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Comments are synced in real-time with all active members.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, color: Colors.blueAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Comments',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: widget.isDark ? Colors.white : BNXColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Comments list
          Expanded(
            child: widget.group.comments.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: widget.isDark ? Colors.white10 : Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 32,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: widget.isDark ? Colors.white : BNXColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Be the first to say hello!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.isDark ? BNXColors.darkTextSecondary : BNXColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.group.comments.length,
                    itemBuilder: (context, index) {
                      final c = widget.group.comments[index];
                      final isMe = c.sender == 'Ravi';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe) ...[
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: BNXColors.lightPrimary.withOpacity(0.2),
                                child: Text(
                                  c.sender.isNotEmpty ? c.sender[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: widget.isDark ? Colors.white : BNXColors.lightPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? BNXColors.lightPrimary
                                      : (widget.isDark
                                          ? Colors.white.withOpacity(0.08)
                                          : Colors.grey[100]),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(14),
                                    topRight: const Radius.circular(14),
                                    bottomLeft: Radius.circular(isMe ? 14 : 0),
                                    bottomRight: Radius.circular(isMe ? 0 : 14),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isMe ? '${c.sender} (Me)' : c.sender,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: isMe
                                            ? Colors.white.withOpacity(0.8)
                                            : (widget.isDark ? Colors.white60 : Colors.black54),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      c.message,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isMe
                                            ? Colors.white
                                            : (widget.isDark
                                                ? Colors.white
                                                : BNXColors.lightTextPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),

          // Input bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file_rounded, color: Colors.grey),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: widget.isDark ? BNXColors.darkSurface : Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (context) {
                        return SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Attach File',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: widget.isDark ? Colors.white : BNXColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ListTile(
                                  leading: const Icon(Icons.photo_rounded, color: Colors.purple),
                                  title: const Text('Photo or Video'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    widget.ref.read(colabListProvider.notifier).addComment(
                                      widget.group.id,
                                      'Ravi',
                                      '📎 Ravi attached a Photo: UI_Design_draft.png',
                                    );
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.insert_drive_file_rounded, color: Colors.blue),
                                  title: const Text('Document'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    widget.ref.read(colabListProvider.notifier).addComment(
                                      widget.group.id,
                                      'Ravi',
                                      '📎 Ravi attached a Document: Q3_Marketing_Plan.pdf',
                                    );
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.code_rounded, color: Colors.green),
                                  title: const Text('Code Snippet'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    widget.ref.read(colabListProvider.notifier).addComment(
                                      widget.group.id,
                                      'Ravi',
                                      '📎 Ravi attached a Code Snippet: colab_provider.dart',
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    onSubmitted: (_) => _sendComment(),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : BNXColors.lightTextPrimary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _sendComment,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: BNXColors.lightPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
