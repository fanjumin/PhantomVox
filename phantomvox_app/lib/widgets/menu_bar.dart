import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'file_operations.dart';
import 'profile_dialog.dart';
import '../services/project_manager.dart';

/// PhantomVox global menu bar — shared across all workspaces.
/// Layout matches architecture doc chapter 11 with English labels.
class PhantomVoxMenuBar extends StatelessWidget implements PreferredSizeWidget {
  final int currentPageIndex;
  final ValueChanged<int> onPageSwitch;
  final VoidCallback? onOpenSettings;

  const PhantomVoxMenuBar({
    super.key,
    required this.currentPageIndex,
    required this.onPageSwitch,
    this.onOpenSettings,
  });

  @override
  Size get preferredSize => const Size.fromHeight(30);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      color: const Color(0xFF0D0D1A),
      child: Row(
        children: [
          const SizedBox(width: 8),
          // PhantomVox logo / app button
          _MenuButton(
            label: 'PhantomVox',
            children: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.info_outline, size: 14),
                child: const Text('About PhantomVox'),
                onPressed: () => _showAbout(context),
              ),
              const Divider(height: 1),
              MenuItemButton(
                leadingIcon: const Icon(Icons.update, size: 14),
                child: const Text('Check Updates'),
                onPressed: () => _showSnack(context, 'Check updates — version check coming with release pipeline'),
              ),
              const Divider(height: 1),
              MenuItemButton(
                leadingIcon: const Icon(Icons.settings, size: 14),
                child: const Text('System Info'),
                onPressed: () => onOpenSettings?.call(),
              ),
            ],
          ),
          // Current project name
          _ProjectLabel(),
          const SizedBox(width: 4),
          // AI
          _MenuButton(
            label: 'AI',
            shortcut: 'A',
            children: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.smart_toy, size: 14),
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.space,
                  control: true,
                  shift: true,
                ),
                child: const Text('AI Agent Panel'),
                onPressed: () => onPageSwitch(1),
              ),
              const Divider(height: 1),
              MenuItemButton(
                leadingIcon: const Icon(Icons.auto_awesome, size: 14),
                child: const Text('Scene Detection'),
                onPressed: () => _showSnack(context, 'Scene detection uses AI Agent — coming with ML pipeline update'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.label, size: 14),
                child: const Text('Smart Tagging'),
                onPressed: () => _showSnack(context, 'Smart tagging uses AI Agent — coming with ML pipeline update'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.colorize, size: 14),
                child: const Text('Color Match'),
                onPressed: () => _showSnack(context, 'Color match uses AI Agent — coming with ML pipeline update'),
              ),
              const Divider(height: 1),
              SubmenuButton(
                leadingIcon: const Icon(Icons.auto_fix_high, size: 14),
                menuChildren: [
                  MenuItemButton(
                    child: const Text('From Script'),
                    onPressed: () => _showSnack(context, 'Script→video uses Workflow engine — coming with template system'),
                  ),
                  MenuItemButton(
                    child: const Text('From Voice'),
                    onPressed: () => _showSnack(context, 'Voice→video uses Workflow engine — coming with template system'),
                  ),
                  MenuItemButton(
                    child: const Text('From Images'),
                    onPressed: () => _showSnack(context, 'Images→video uses Workflow engine — coming with template system'),
                  ),
                ],
                child: const Text('One-Click Creation'),
              ),
              const Divider(height: 1),
              MenuItemButton(
                leadingIcon: const Icon(Icons.tune, size: 14),
                child: const Text('AI Model Settings'),
                onPressed: () => onOpenSettings?.call(),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.block, size: 14),
                child: const Text('Disable AI'),
                onPressed: () => _showSnack(context, 'AI toggle — disable AI features in settings'),
              ),
            ],
          ),
          // File
          _MenuButton(
            label: 'File',
            shortcut: 'F',
            children: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.add, size: 14),
                shortcut: const SingleActivator(LogicalKeyboardKey.keyN, control: true),
                child: const Text('New Project'),
                onPressed: () => FileOperations.handleNewProject(context),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.folder_open, size: 14),
                shortcut: const SingleActivator(LogicalKeyboardKey.keyO, control: true),
                child: const Text('Open Project'),
                onPressed: () => FileOperations.handleOpenProject(),
              ),
              SubmenuButton(
                leadingIcon: const Icon(Icons.history, size: 14),
                menuChildren: [
                  MenuItemButton(
                    child: const Text('(recent projects)'),
                    onPressed: () {},
                  ),
                ],
                child: const Text('Recent'),
              ),
              const Divider(height: 1),
              MenuItemButton(
                leadingIcon: const Icon(Icons.save, size: 14),
                shortcut: const SingleActivator(LogicalKeyboardKey.keyS, control: true),
                child: const Text('Save'),
                onPressed: () => FileOperations.handleSave(),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.save_as, size: 14),
                shortcut: const SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true),
                child: const Text('Save As...'),
                onPressed: () => FileOperations.handleSaveAs(),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.description, size: 14),
                child: const Text('Save as Template'),
                onPressed: () => _showSnack(context, 'Template save — coming with template system'),
              ),
              const Divider(height: 1),
              SubmenuButton(
                leadingIcon: const Icon(Icons.file_download, size: 14),
                menuChildren: [
                  MenuItemButton(
                    child: const Text('Media File...'),
                    onPressed: () => FileOperations.showImportDialog(),
                  ),
                  MenuItemButton(
                    child: const Text('Media Folder...'),
                    onPressed: () => FileOperations.handleImportFolder(),
                  ),
                  MenuItemButton(
                    child: const Text('LUT / Color Preset'),
                    onPressed: () => FileOperations.handleImportLut(),
                  ),
                  MenuItemButton(
                    child: const Text('Subtitle File...'),
                    onPressed: () => FileOperations.handleImportSubtitle(),
                  ),
                  MenuItemButton(
                    child: const Text('XML / EDL Timeline'),
                    onPressed: () => FileOperations.handleImportTimeline(),
                  ),
                ],
                child: const Text('Import'),
              ),
              SubmenuButton(
                leadingIcon: const Icon(Icons.file_upload, size: 14),
                menuChildren: [
                  MenuItemButton(
                    child: const Text('Video...'),
                    onPressed: () => FileOperations.handleExport(context),
                  ),
                  MenuItemButton(
                    child: const Text('Audio Only'),
                    onPressed: () => FileOperations.handleExportAudio(context),
                  ),
                  MenuItemButton(
                    child: const Text('Current Frame'),
                    onPressed: () => FileOperations.handleExportFrame(context),
                  ),
                  MenuItemButton(
                    child: const Text('Subtitles'),
                    onPressed: () => FileOperations.handleExportSubtitles(),
                  ),
                  MenuItemButton(
                    child: const Text('Archive Project'),
                    onPressed: () => _showSnack(context, 'Archive project — coming with project management system'),
                  ),
                ],
                child: const Text('Export'),
              ),
              const Divider(height: 1),
              MenuItemButton(
                leadingIcon: const Icon(Icons.settings, size: 14),
                child: const Text('Project Settings'),
                onPressed: () => onOpenSettings?.call(),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.model_training, size: 14),
                child: const Text('Model Settings'),
                onPressed: () => onOpenSettings?.call(),
              ),
              const Divider(height: 1),
              MenuItemButton(
                leadingIcon: const Icon(Icons.exit_to_app, size: 14),
                child: const Text('Exit'),
                onPressed: () => _showSnack(context, 'Exit'),
              ),
            ],
          ),
          // Edit
          _MenuButton(
            label: 'Edit',
            shortcut: 'E',
            children: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.undo, size: 14),
                shortcut: const SingleActivator(LogicalKeyboardKey.keyZ, control: true),
                child: const Text('Undo'),
                onPressed: () => _showSnack(context, 'Undo'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.redo, size: 14),
                shortcut: const SingleActivator(LogicalKeyboardKey.keyY, control: true),
                child: const Text('Redo'),
                onPressed: () => _showSnack(context, 'Redo'),
              ),
              const Divider(height: 1),
              MenuItemButton(
                leadingIcon: const Icon(Icons.content_cut, size: 14),
                shortcut: const SingleActivator(LogicalKeyboardKey.keyX, control: true),
                child: const Text('Cut'),
                onPressed: () => _showSnack(context, 'Cut'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.content_copy, size: 14),
                shortcut: const SingleActivator(LogicalKeyboardKey.keyC, control: true),
                child: const Text('Copy'),
                onPressed: () => _showSnack(context, 'Copy'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.content_paste, size: 14),
                shortcut: const SingleActivator(LogicalKeyboardKey.keyV, control: true),
                child: const Text('Paste'),
                onPressed: () => _showSnack(context, 'Paste'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.delete, size: 14),
                shortcut: const SingleActivator(LogicalKeyboardKey.delete),
                child: const Text('Delete'),
                onPressed: () => _showSnack(context, 'Delete'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.select_all, size: 14),
                shortcut: const SingleActivator(LogicalKeyboardKey.keyA, control: true),
                child: const Text('Select All'),
                onPressed: () => _showSnack(context, 'Select All'),
              ),
              const Divider(height: 1),
              MenuItemButton(
                leadingIcon: const Icon(Icons.content_cut, size: 14),
                shortcut: const SingleActivator(LogicalKeyboardKey.keyB, control: true),
                child: const Text('Split Clip'),
                onPressed: () => _showSnack(context, 'Split clip'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.waves, size: 14),
                shortcut: const SingleActivator(LogicalKeyboardKey.delete, shift: true),
                child: const Text('Ripple Delete'),
                onPressed: () => _showSnack(context, 'Ripple delete'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.content_cut, size: 14),
                child: const Text('Trim Start'),
                shortcut: const SingleActivator(LogicalKeyboardKey.keyQ),
                onPressed: () => _showSnack(context, 'Trim start'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.content_cut, size: 14),
                child: const Text('Trim End'),
                shortcut: const SingleActivator(LogicalKeyboardKey.keyW),
                onPressed: () => _showSnack(context, 'Trim end'),
              ),
              const Divider(height: 1),
              MenuItemButton(
                leadingIcon: const Icon(Icons.info, size: 14),
                child: const Text('Clip Properties'),
                onPressed: () => _showSnack(context, 'Clip properties'),
              ),
              const Divider(height: 1),
              MenuItemButton(
                leadingIcon: const Icon(Icons.keyboard, size: 14),
                child: const Text('Keyboard Shortcuts'),
                onPressed: () => _showSnack(context, 'Keyboard shortcuts'),
              ),
            ],
          ),
          // View
          _MenuButton(
            label: 'View',
            shortcut: 'V',
            children: [
              SubmenuButton(
                leadingIcon: const Icon(Icons.dashboard, size: 14),
                menuChildren: [
                  MenuItemButton(
                    child: const Text('Default Layout'),
                    onPressed: () => _showSnack(context, 'Default layout — layout presets coming with workspace customization'),
                  ),
                  MenuItemButton(
                    child: const Text('Compact Mode'),
                    onPressed: () => _showSnack(context, 'Compact mode — layout presets coming with workspace customization'),
                  ),
                  MenuItemButton(
                    child: const Text('Dual Screen Mode'),
                    onPressed: () => _showSnack(context, 'Dual screen mode — layout presets coming with workspace customization'),
                  ),
                ],
                child: const Text('Workspace Layout'),
              ),
              const Divider(height: 1),
              MenuItemButton(
                leadingIcon: const Icon(Icons.zoom_in, size: 14),
                shortcut: const SingleActivator(LogicalKeyboardKey.equal, control: true),
                child: const Text('Zoom In'),
                onPressed: () => _showSnack(context, 'Zoom in'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.zoom_out, size: 14),
                shortcut: const SingleActivator(LogicalKeyboardKey.minus, control: true),
                child: const Text('Zoom Out'),
                onPressed: () => _showSnack(context, 'Zoom out'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.fit_screen, size: 14),
                child: const Text('Fit to Window'),
                onPressed: () => _showSnack(context, 'Fit to window'),
              ),
            ],
          ),
          // Media
          _MenuButton(
            label: 'Media',
            shortcut: 'M',
            children: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.video_library, size: 14),
                child: const Text('Media Browser'),
                onPressed: () => onPageSwitch(3), // ProEdit
              ),
              const Divider(height: 1),
              MenuItemButton(
                leadingIcon: const Icon(Icons.mic, size: 14),
                child: const Text('Voiceover Recording'),
                onPressed: () => onPageSwitch(5), // AudioForge
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.videocam, size: 14),
                child: const Text('Screen Recording'),
                onPressed: () => _showSnack(context, 'Screen recording needs system integration — coming with Rust media engine'),
              ),
              const Divider(height: 1),
              MenuItemButton(
                leadingIcon: const Icon(Icons.manage_search, size: 14),
                child: const Text('Media Management'),
                onPressed: () => onPageSwitch(2), // StoryCut
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.analytics, size: 14),
                child: const Text('Timeline Statistics'),
                onPressed: () => onPageSwitch(3), // ProEdit
              ),
            ],
          ),
          // Tools
          _MenuButton(
            label: 'Tools',
            shortcut: 'T',
            children: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.colorize, size: 14),
                child: const Text('Color Match'),
                onPressed: () {
                  onPageSwitch(4); // Go to Palette page
                },
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.audio_file, size: 14),
                child: const Text('Audio Analysis'),
                onPressed: () {
                  onPageSwitch(5); // Go to AudioForge page
                },
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.auto_awesome, size: 14),
                child: const Text('Scene Detection'),
                onPressed: () => _showSnack(context, 'Scene detection uses AI Agent — coming with ML pipeline update'),
              ),
            ],
          ),
          // Window
          _MenuButton(
            label: 'Window',
            shortcut: 'W',
            children: [
              SubmenuButton(
                leadingIcon: const Icon(Icons.swap_horiz, size: 14),
                menuChildren: [
                  _pageItem('Flow Graph', 0, LogicalKeyboardKey.digit7, currentPageIndex, onPageSwitch),
                  _pageItem('AI Agent', 1, LogicalKeyboardKey.digit6, currentPageIndex, onPageSwitch),
                  _pageItem('StoryCut', 2, LogicalKeyboardKey.digit1, currentPageIndex, onPageSwitch),
                  _pageItem('ProEdit', 3, LogicalKeyboardKey.digit2, currentPageIndex, onPageSwitch),
                  _pageItem('Palette', 4, LogicalKeyboardKey.digit3, currentPageIndex, onPageSwitch),
                  _pageItem('AudioForge', 5, LogicalKeyboardKey.digit4, currentPageIndex, onPageSwitch),
                  _pageItem('EffectLab', 6, LogicalKeyboardKey.digit5, currentPageIndex, onPageSwitch),
                  const Divider(height: 1),
                  MenuItemButton(
                    child: const Text('Dashboard'),
                    onPressed: () => onPageSwitch(7),
                  ),
                ],
                child: const Text('Workspace Switch'),
              ),
              const SizedBox(width: 0),
              SubmenuButton(
                leadingIcon: const Icon(Icons.view_sidebar, size: 14),
                menuChildren: [
                  _toggleItem('Media Pool', true, context),
                  _toggleItem('Inspector', true, context),
                  _toggleItem('Mixer', true, context),
                  _toggleItem('Flow Graph', true, context),
                  const Divider(height: 1),
                  MenuItemButton(
                    child: const Text('Reset All Panels'),
                    onPressed: () => _showSnack(context, 'Panel system — coming with UI refactor'),
                  ),
                ],
                child: const Text('Panel Management'),
              ),
            ],
          ),
          // Help
          _MenuButton(
            label: 'Help',
            shortcut: 'H',
            children: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.menu_book, size: 14),
                shortcut: const SingleActivator(LogicalKeyboardKey.f1),
                child: const Text('User Manual'),
                onPressed: () => _showSnack(context, 'User manual — content under development'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.play_circle, size: 14),
                child: const Text('Video Tutorials'),
                onPressed: () => _showSnack(context, 'Video tutorials — content under development'),
              ),
              const Divider(height: 1),
              MenuItemButton(
                leadingIcon: const Icon(Icons.keyboard, size: 14),
                child: const Text('Keyboard Shortcuts'),
                onPressed: () => _showSnack(context, 'Keyboard shortcuts reference — content under development'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.bug_report, size: 14),
                child: const Text('Report Issue'),
                onPressed: () => _showSnack(context, 'Issue reporter — content under development'),
              ),
              const Divider(height: 1),
              MenuItemButton(
                leadingIcon: const Icon(Icons.info_outline, size: 14),
                child: const Text('About PhantomVox'),
                onPressed: () => _showAbout(context),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.update, size: 14),
                child: const Text('Check Updates'),
                onPressed: () => _showSnack(context, 'Check updates — version check coming with release pipeline'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.computer, size: 14),
                child: const Text('System Info'),
                onPressed: () => _showSnack(context, 'System info coming soon'),
              ),
            ],
          ),
          const Spacer(),
          // Account / user area — opens local profile dialog
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.account_circle, size: 16),
              color: Colors.grey,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(maxWidth: 24, maxHeight: 24),
              tooltip: 'Local Profile',
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const ProfileDialog(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('PhantomVox AI'),
        content: const Text(
          'Version: 0.2.0\n\n'
          'Where AI Meets Creativity.\n'
          'Built with Flutter + Python AI Server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  MenuItemButton _pageItem(
    String label, int index, LogicalKeyboardKey key, int current, ValueChanged<int> onSwitch,
  ) {
    final isActive = index == current;
    return MenuItemButton(
      leadingIcon: isActive ? const Icon(Icons.check, size: 14) : null,
      shortcut: SingleActivator(key, control: true),
      child: Text('$label  ${isActive ? "✓" : ""}'),
      onPressed: () => onSwitch(index),
    );
  }

  MenuItemButton _toggleItem(String label, bool enabled, BuildContext context) {
    return MenuItemButton(
      leadingIcon: Icon(
        enabled ? Icons.check_box : Icons.check_box_outline_blank,
        size: 14,
      ),
      child: Text(label),
      onPressed: () => _showSnack(context, 'Panel toggle coming soon'),
    );
  }
}

/// A single menu button that opens a submenu.
class _MenuButton extends StatefulWidget {
  final String label;
  final String? shortcut;
  final List<Widget> children;

  const _MenuButton({
    required this.label,
    this.shortcut,
    required this.children,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      builder: (context, controller, child) {
        return GestureDetector(
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _hovered || controller.isOpen
                    ? const Color(0xFF2A2A3E)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: _hovered || controller.isOpen
                          ? Colors.white
                          : const Color(0xFFBBBBBB),
                    ),
                  ),
                  if (widget.shortcut != null) ...[
                    const SizedBox(width: 1),
                    Text(
                      '(${widget.shortcut})',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      menuChildren: widget.children,
    );
  }
}

/// Shows the name of the currently open project.
class _ProjectLabel extends StatelessWidget {
  const _ProjectLabel();

  @override
  Widget build(BuildContext context) {
    final pm = ProjectManager();
    if (!pm.hasProject) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 1, height: 14, color: const Color(0xFF2A2A3E)),
          const SizedBox(width: 6),
          Icon(Icons.description, size: 11, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            pm.name,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFFAAAAAA),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
