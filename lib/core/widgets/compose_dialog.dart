import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/app_state_provider.dart';
import '../../data/email_provider.dart';
import '../../models/attachment_model.dart';
import '../theme/colors.dart';
import '../theme/neumorphic.dart';
import '../constants/constants.dart';
import 'package:file_picker/file_picker.dart';

class ComposeDialog extends ConsumerStatefulWidget {
  const ComposeDialog({super.key});

  @override
  ConsumerState<ComposeDialog> createState() => _ComposeDialogState();
}

class _ComposeDialogState extends ConsumerState<ComposeDialog> {
  final _toController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  bool _showCcBcc = false;
  final _ccController = TextEditingController();
  final _bccController = TextEditingController();
  final List<AttachmentModel> _attachedFiles = [];

  @override
  void initState() {
    super.initState();
    // Load persisted state if any
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uiState = ref.read(appUiProvider);
      _toController.text = uiState.composeTo;
      _subjectController.text = uiState.composeSubject;
      _bodyController.text = uiState.composeBody;
    });
  }

  @override
  void dispose() {
    _toController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    _ccController.dispose();
    _bccController.dispose();
    super.dispose();
  }

  void _persistState() {
    ref.read(appUiProvider.notifier).updateComposeDraft(
          to: _toController.text,
          subject: _subjectController.text,
          body: _bodyController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(appUiProvider);
    final status = uiState.composeStatus;

    if (status == ComposeStatus.closed || uiState.activeFolder == 'Templates') {
      return const SizedBox.shrink();
    }

    final isDark = uiState.isDarkMode;

    // Determine dimensions based on status
    double width;
    double height;
    Alignment alignment;
    EdgeInsets margin;

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    // FEATURE: Force controller update if the dialog is open but the state changed (e.g. from templates)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (status != ComposeStatus.closed) {
        if (_subjectController.text != uiState.composeSubject) {
          _subjectController.text = uiState.composeSubject;
        }
        if (_bodyController.text != uiState.composeBody) {
          _bodyController.text = uiState.composeBody;
        }
        if (_toController.text != uiState.composeTo) {
          _toController.text = uiState.composeTo;
        }
      }
    });

    if (status == ComposeStatus.minimized) {
      width = isMobile ? 180 : 280;
      height = 50;
      alignment = Alignment.bottomRight;
      margin = isMobile 
          ? const EdgeInsets.only(right: 16, bottom: 0)
          : const EdgeInsets.only(right: 80, bottom: 0);
    } else if (status == ComposeStatus.maximized) {
      width = screenWidth;
      height = MediaQuery.of(context).size.height;
      alignment = Alignment.bottomCenter;
      margin = EdgeInsets.zero;
    } else if (isMobile) {
      // Minimalistic floating dialog on mobile
      width = screenWidth * 0.92;
      height = MediaQuery.of(context).size.height * 0.6;
      alignment = Alignment.bottomCenter;
      margin = const EdgeInsets.only(bottom: 16);
    } else {
      // Normal Floating Dialog
      width = 540;
      height = 500;
      alignment = Alignment.bottomRight;
      margin = const EdgeInsets.only(right: 80, bottom: 0);
    }

    // Border Radius
    final borderRadius = (status == ComposeStatus.maximized)
        ? const BorderRadius.only(
            topLeft: Radius.circular(BNXConstants.borderRadiusL),
            topRight: Radius.circular(BNXConstants.borderRadiusL),
          )
        : BorderRadius.circular(BNXConstants.borderRadiusL);

    final Widget card = Material(
      elevation: 24,
      shadowColor: Colors.black45,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: NeumorphicContainer(
        width: width,
        height: height,
        borderRadius: 16,
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: Column(
          children: [
            // Header (Blue bar)
            _buildHeader(isDark, status),

            // Form Body (if not minimized)
            if (status != ComposeStatus.minimized)
              Expanded(
                child: Column(
                  children: [
                    _buildInputField(
                      controller: _toController,
                      hint: 'To',
                      isDark: isDark,
                      suffix: GestureDetector(
                        onTap: () => setState(() => _showCcBcc = !_showCcBcc),
                        child: const Text('Cc Bcc', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ),
                    ),
                    if (_showCcBcc) ...[
                      _buildInputField(
                        controller: _ccController,
                        hint: 'Cc',
                        isDark: isDark,
                      ),
                      _buildInputField(
                        controller: _bccController,
                        hint: 'Bcc',
                        isDark: isDark,
                      ),
                    ],
                    _buildInputField(
                      controller: _subjectController,
                      hint: 'Subject',
                      isDark: isDark,
                    ),
    // Message text area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: TextField(
                          controller: _bodyController,
                          maxLines: null,
                          expands: true,
                          onChanged: (_) {
                            // Only update draft state, don't trigger listener
                            ref.read(appUiProvider.notifier).updateComposeDraft(
                              body: _bodyController.text,
                            );
                          },
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Type your message here...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    
                    if (_attachedFiles.isNotEmpty) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _attachedFiles.map((file) {
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
                                      constraints: const BoxConstraints(maxWidth: 120),
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
                                          _attachedFiles.remove(file);
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
                        ),
                      ),
                    ],
                    
                    // Bottom Toolbar
                    _buildBottomBar(isDark),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    return Align(
      alignment: alignment,
      child: Padding(
        padding: margin,
        child: (isMobile && status != ComposeStatus.minimized)
            ? SafeArea(child: card)
            : card,
      ),
    );
  }

  Widget _buildHeader(bool isDark, ComposeStatus status) {
    return Container(
      height: 50, // Fixed height
      color: BNXColors.lightPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'New Message',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13, // Reduced to save space
            ),
          ),
          const Spacer(),
          // Minimize control
          IconButton(
            icon: Icon(
              status == ComposeStatus.minimized ? Icons.maximize : Icons.remove,
              color: Colors.white,
              size: 16,
            ),
            onPressed: () {
              if (status == ComposeStatus.minimized) {
                ref.read(appUiProvider.notifier).setComposeStatus(ComposeStatus.normal);
              } else {
                _persistState();
                ref.read(appUiProvider.notifier).setComposeStatus(ComposeStatus.minimized);
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          // Maximize / Restore control
          IconButton(
            icon: Icon(
              status == ComposeStatus.maximized ? Icons.fullscreen_exit : Icons.fullscreen,
              color: Colors.white,
              size: 18,
            ),
            onPressed: () {
              _persistState();
              if (status == ComposeStatus.maximized) {
                ref.read(appUiProvider.notifier).setComposeStatus(ComposeStatus.normal);
              } else {
                ref.read(appUiProvider.notifier).setComposeStatus(ComposeStatus.maximized);
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          // Close control (saves as draft)
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 18),
            onPressed: () {
              if (_toController.text.isNotEmpty ||
                  _subjectController.text.isNotEmpty ||
                  _bodyController.text.isNotEmpty) {
                ref.read(emailProvider.notifier).composeEmail(
                      to: _toController.text,
                      subject: _subjectController.text,
                      body: _bodyController.text,
                      isDraft: true,
                      attachments: List.from(_attachedFiles),
                    );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Draft saved.')),
                );
              }
              _attachedFiles.clear();
              ref.read(appUiProvider.notifier).clearComposeDraft();
              ref.read(appUiProvider.notifier).setComposeStatus(ComposeStatus.closed);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: NeumorphicContainer(
        height: 40,
        shape: NeumorphicShape.pressed,
        borderRadius: 8,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Text(
              '$hint: ',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: (val) {
                  // Only update draft state, don't trigger listener
                  if (hint == 'To') {
                    ref.read(appUiProvider.notifier).updateComposeDraft(to: val);
                  } else if (hint == 'Subject') {
                    ref.read(appUiProvider.notifier).updateComposeDraft(subject: val);
                  }
                },
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            if (suffix != null) suffix,
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black12 : BNXColors.lightBg,
        border: Border(
          top: BorderSide(
            color: isDark ? BNXColors.darkBorder : BNXColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          // Send Button
          NeumorphicButton(
            onPressed: () {
              if (_toController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please specify a recipient.')),
                );
                return;
              }
              // Submit Email
              ref.read(emailProvider.notifier).composeEmail(
                    to: _toController.text,
                    subject: _subjectController.text,
                    body: _bodyController.text,
                    attachments: List.from(_attachedFiles),
                  );
              _attachedFiles.clear();
              ref.read(appUiProvider.notifier).clearComposeDraft();
              ref.read(appUiProvider.notifier).setComposeStatus(ComposeStatus.closed);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message sent.')),
              );
            },
            borderRadius: 20,
            color: BNXColors.lightPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.send_rounded, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Text('Send', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 12),

          IconButton(
            icon: const Icon(Icons.attachment_rounded, size: 20),
            onPressed: () => _showAttachmentOptions(context, isDark),
            tooltip: 'Attach files',
          ),

          // Templates Icon
          IconButton(
            icon: const Icon(Icons.article_outlined, size: 20),
            onPressed: () {
              // 1. Switch to Templates folder
              ref.read(appUiProvider.notifier).selectFolder('Templates');
              
              // 2. Minimize compose to let user see templates
              _persistState();
              ref.read(appUiProvider.notifier).setComposeStatus(ComposeStatus.minimized);
              
              // 3. Ensure we are on the home page where templates are shown
              if (GoRouterState.of(context).uri.toString() != '/') {
                context.go('/');
              }
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Templates view opened. Choose a template to apply.')),
              );
            },
            tooltip: 'Insert template',
          ),
          const Spacer(),

          // Discard Button
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
            onPressed: () {
              _attachedFiles.clear();
              ref.read(appUiProvider.notifier).clearComposeDraft();
              ref.read(appUiProvider.notifier).setComposeStatus(ComposeStatus.closed);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message discarded.')),
              );
            },
            tooltip: 'Discard draft',
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions(BuildContext context, bool isDark) {
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
                          _attachedFiles.add(AttachmentModel(
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
                  title: const Text('PDF Document (e.g., Specs_Draft.pdf)'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _attachedFiles.add(const AttachmentModel(
                        fileName: 'Specs_Draft.pdf',
                        fileType: 'pdf',
                        fileSize: '1.2 MB',
                      ));
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.image_rounded, color: Colors.purple),
                  title: const Text('Image Asset (e.g., Screenshot.png)'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _attachedFiles.add(const AttachmentModel(
                        fileName: 'Screenshot.png',
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
                      _attachedFiles.add(const AttachmentModel(
                        fileName: 'main.dart',
                        fileType: 'code',
                        fileSize: '12 KB',
                      ));
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
