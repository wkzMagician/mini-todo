import 'package:dartloom_autostart/dartloom_autostart.dart';
import 'package:dartloom_logging/dartloom_logging.dart';
import 'package:dartloom_runtime/dartloom_runtime.dart';
import 'package:dartloom_settings/dartloom_settings.dart';
import 'package:dartloom_storage/dartloom_storage.dart';
import 'package:dartloom_sync/dartloom_sync.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/window_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../application/todo_controller.dart';
import '../data/todo_repository.dart';
import '../domain/todo.dart';

bool get _usesDesktopWindowChrome =>
    !kIsWeb &&
    const {
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    }.contains(defaultTargetPlatform);

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({
    this.repository,
    this.settings,
    this.autostart,
    this.logger,
    this.syncService,
    required this.locale,
    required this.onLocaleChanged,
    super.key,
  });

  final TodoRepository? repository;
  final SettingsStore? settings;
  final AutostartService? autostart;
  final AppLogger? logger;
  final SyncService? syncService;
  final Locale locale;
  final Future<void> Function(Locale locale) onLocaleChanged;

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  late final TodoController _controller;
  final _windowController = DesktopWindowController();
  final _newTitleController = TextEditingController();
  final _editTitleController = TextEditingController();
  final _syncUrlController = TextEditingController();
  final _syncRootPathController = TextEditingController();
  final _syncUsernameController = TextEditingController();
  final _syncPasswordController = TextEditingController();
  TodoGranularity _newGranularity = TodoGranularity.day;
  String? _editingTodoId;

  @override
  void initState() {
    super.initState();
    _controller = TodoController(
      repository:
          widget.repository ??
          JsonStoreTodoRepository(Dartloom.get<JsonStore>(name: 'json')),
      settings: widget.settings ?? Dartloom.get<SettingsStore>(),
      autostart:
          widget.autostart ??
          (Dartloom.contains<AutostartService>()
              ? Dartloom.get<AutostartService>()
              : null),
      logger: widget.logger ?? Dartloom.get<AppLogger>(),
      syncService:
          widget.syncService ??
          (Dartloom.contains<SyncService>()
              ? Dartloom.get<SyncService>()
              : null),
    );
    _controller.initialize().then((_) {
      if (!mounted) return;
      _syncUrlController.text = _controller.syncUrl;
      _syncRootPathController.text = _controller.syncRootPath;
      _syncUsernameController.text = _controller.syncUsername;
      _syncPasswordController.text = _controller.syncPassword;
      if (_usesDesktopWindowChrome) {
        _windowController.setCollapsed(_controller.collapsed);
      }
    });
  }

  @override
  void dispose() {
    _newTitleController.dispose();
    _editTitleController.dispose();
    _syncUrlController.dispose();
    _syncRootPathController.dispose();
    _syncUsernameController.dispose();
    _syncPasswordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final strings = AppLocalizations.of(context)!;
      return Scaffold(body: SafeArea(child: _buildShell(context, strings)));
    },
  );

  Widget _buildShell(BuildContext context, AppLocalizations strings) =>
      Container(
        decoration: BoxDecoration(
          color: const Color(0xfff8fafc),
          border: Border.all(color: const Color(0xffcbd7df)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _buildHeader(context, strings),
            if (!_controller.collapsed)
              Expanded(child: _buildPanel(context, strings)),
          ],
        ),
      );

  Widget _buildHeader(BuildContext context, AppLocalizations strings) =>
      Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xffd8e2e8))),
        ),
        child: Row(
          children: [
            if (_usesDesktopWindowChrome) ...[
              _HeaderButton(
                icon: _controller.collapsed
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_up,
                tooltip: _controller.collapsed
                    ? strings.expand
                    : strings.collapse,
                onPressed: _toggleCollapsed,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => _windowController.startDragging(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.appTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      strings.taskSummary(
                        _controller.selectedGranularity.localizedLabel(strings),
                        _controller.visibleTodos.length,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xff60717c),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _HeaderButton(
              icon: Icons.settings_outlined,
              tooltip: strings.settings,
              active: _controller.settingsOpen,
              onPressed: _controller.toggleSettings,
            ),
            if (_usesDesktopWindowChrome) ...[
              const SizedBox(width: 4),
              _HeaderButton(
                icon: Icons.close,
                tooltip: strings.closeApp,
                danger: true,
                onPressed: _hide,
              ),
            ],
          ],
        ),
      );

  Widget _buildPanel(BuildContext context, AppLocalizations strings) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      children: [
        if (_controller.settingsOpen) _buildSettings(context, strings),
        _buildTabs(context, strings),
        const SizedBox(height: 10),
        Expanded(child: _buildTaskList(context, strings)),
        const SizedBox(height: 10),
        _buildNewTaskForm(context, strings),
        if (_controller.error != null)
          _MessageText(text: _controller.error!, isError: true),
      ],
    ),
  );

  Widget _buildSettings(BuildContext context, AppLocalizations strings) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: _panelDecoration(),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(strings.language)),
                DropdownButton<Locale>(
                  value: widget.locale,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(
                      value: const Locale('zh'),
                      child: Text(strings.chinese),
                    ),
                    DropdownMenuItem(
                      value: const Locale('en'),
                      child: Text(strings.english),
                    ),
                  ],
                  onChanged: (locale) {
                    if (locale != null) widget.onLocaleChanged(locale);
                  },
                ),
              ],
            ),
            if (_controller.autostartAvailable) ...[
              const Divider(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(strings.autoStart),
                subtitle: Text(strings.autoStartHint),
                value: _controller.openAtLogin,
                onChanged: _controller.setOpenAtLogin,
              ),
            ],
            if (_controller.syncAvailable) ...[
              const Divider(height: 20),
              _buildSyncSettings(context, strings),
            ],
          ],
        ),
      );

  Widget _buildSyncSettings(BuildContext context, AppLocalizations strings) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.sync,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _syncUrlController,
            decoration: InputDecoration(
              labelText: strings.syncWebDavUrl,
              isDense: true,
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _syncRootPathController,
                  decoration: InputDecoration(
                    labelText: strings.syncWebDavRootPath,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _syncUsernameController,
                  decoration: InputDecoration(
                    labelText: strings.syncWebDavUsername,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _syncPasswordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: strings.syncWebDavPassword,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saveSyncSettings,
                  child: Text(strings.saveSync),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _controller.syncStatus == SyncPhase.syncing
                      ? null
                      : _syncNow,
                  icon: const Icon(Icons.sync, size: 16),
                  label: Text(strings.syncNow),
                ),
              ),
            ],
          ),
          if (_controller.syncStatus != SyncPhase.idle) ...[
            const SizedBox(height: 6),
            Text(
              _syncStatusLabel(strings),
              style: TextStyle(
                color: _controller.syncStatus == SyncPhase.failed
                    ? const Color(0xff9e1f33)
                    : const Color(0xff0f766e),
                fontSize: 12,
              ),
            ),
          ],
        ],
      );

  Widget _buildTabs(BuildContext context, AppLocalizations strings) => SizedBox(
    width: double.infinity,
    child: Row(
      children: [
        for (final granularity in TodoGranularity.values) ...[
          if (granularity != TodoGranularity.day) const SizedBox(width: 6),
          Expanded(
            child: _TabButton(
              label: granularity.localizedLabel(strings),
              selected: granularity == _controller.selectedGranularity,
              onPressed: () => _controller.selectGranularity(granularity),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _buildTaskList(BuildContext context, AppLocalizations strings) {
    if (_controller.loading) {
      return Center(child: Text(strings.loading));
    }
    if (_controller.visibleTodos.isEmpty) {
      return _EmptyState(
        text: strings.noTasks(
          _controller.selectedGranularity.localizedLabel(strings),
        ),
      );
    }

    return ListView.builder(
      itemCount: _controller.visibleTodos.length,
      itemBuilder: (context, index) =>
          _buildTaskCard(context, strings, _controller.visibleTodos[index]),
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    AppLocalizations strings,
    Todo todo,
  ) {
    final editing = _editingTodoId == todo.id;
    return Container(
      key: ValueKey(todo.id),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Expanded(
            child: editing
                ? TextField(
                    autofocus: true,
                    controller: _editTitleController,
                    onSubmitted: (_) => _saveEditing(),
                    decoration: const InputDecoration(isDense: true),
                  )
                : InkWell(
                    onTap: () => _startEditing(todo),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            todo.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            todo.granularity.localizedLabel(strings),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          if (editing) ...[
            IconButton(
              tooltip: strings.saveEdit,
              onPressed: _saveEditing,
              icon: const Icon(Icons.check),
            ),
            IconButton(
              tooltip: strings.cancelEdit,
              onPressed: _cancelEditing,
              icon: const Icon(Icons.close),
            ),
          ] else ...[
            _GranularityDropdown(
              value: todo.granularity,
              strings: strings,
              onChanged: (granularity) {
                if (granularity != null) {
                  _controller.changeTaskGranularity(todo.id, granularity);
                }
              },
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: strings.completeTask,
              onPressed: () => _completeTask(todo),
              icon: const Icon(Icons.check, size: 18),
              color: const Color(0xff0f766e),
              style: IconButton.styleFrom(
                minimumSize: const Size(30, 30),
                maximumSize: const Size(30, 30),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: const BorderSide(color: Color(0xffcbd7df)),
                shape: const CircleBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNewTaskForm(
    BuildContext context,
    AppLocalizations strings,
  ) => Row(
    children: [
      Expanded(
        child: TextField(
          controller: _newTitleController,
          onSubmitted: (_) => _createTask(),
          decoration: InputDecoration(hintText: strings.newTask, isDense: true),
        ),
      ),
      const SizedBox(width: 8),
      _GranularityDropdown(
        value: _newGranularity,
        strings: strings,
        onChanged: (value) {
          if (value != null) setState(() => _newGranularity = value);
        },
      ),
      const SizedBox(width: 8),
      IconButton(
        tooltip: strings.addTask,
        onPressed: _createTask,
        icon: const Icon(Icons.add),
        color: const Color(0xff0f766e),
        style: IconButton.styleFrom(
          minimumSize: const Size(36, 36),
          maximumSize: const Size(36, 36),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: const BorderSide(color: Color(0xffcbd7df)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    ],
  );

  Future<void> _toggleCollapsed() async {
    await _controller.toggleCollapsed();
    await _windowController.setCollapsed(_controller.collapsed);
  }

  Future<void> _hide() => _windowController.hide();

  void _startEditing(Todo todo) {
    setState(() {
      _editingTodoId = todo.id;
      _editTitleController.text = todo.title;
    });
  }

  Future<void> _saveEditing() async {
    final id = _editingTodoId;
    if (id == null) return;
    if (await _controller.renameTask(id, _editTitleController.text) &&
        mounted) {
      setState(() => _editingTodoId = null);
    }
  }

  void _cancelEditing() => setState(() => _editingTodoId = null);

  Future<void> _createTask() async {
    if (await _controller.addTask(_newTitleController.text, _newGranularity) &&
        mounted) {
      _newTitleController.clear();
    }
  }

  Future<void> _saveSyncSettings() => _controller.saveSyncConfiguration(
    url: _syncUrlController.text,
    rootPath: _syncRootPathController.text,
    username: _syncUsernameController.text,
    password: _syncPasswordController.text,
  );

  Future<void> _syncNow() async {
    await _saveSyncSettings();
    await _controller.sync();
  }

  String _syncStatusLabel(AppLocalizations strings) {
    if (_controller.syncStatus == SyncPhase.syncing) return strings.syncNow;
    if (!_controller.syncConfigured) return strings.syncNotConfigured;
    return switch (_controller.syncStatus) {
      SyncPhase.succeeded => strings.syncSucceeded,
      SyncPhase.conflicted => strings.syncConflicted,
      SyncPhase.failed ||
      SyncPhase.offline => _controller.syncMessage ?? strings.syncFailed,
      SyncPhase.idle => '',
      SyncPhase.syncing || SyncPhase.scheduled => strings.syncNow,
    };
  }

  Future<void> _completeTask(Todo todo) async {
    await _controller.completeTask(todo.id);
  }

  BoxDecoration _panelDecoration() => BoxDecoration(
    color: Colors.white,
    border: Border.all(color: const Color(0xffd8e2e8)),
    borderRadius: BorderRadius.circular(8),
  );
}

extension _TodoGranularityLocalization on TodoGranularity {
  String localizedLabel(AppLocalizations strings) => switch (this) {
    TodoGranularity.day => strings.today,
    TodoGranularity.week => strings.thisWeek,
    TodoGranularity.month => strings.thisMonth,
    TodoGranularity.year => strings.thisYear,
  };
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 34,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: selected ? Colors.white : const Color(0xff4f606b),
        backgroundColor: selected ? const Color(0xff0f766e) : Colors.white,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: selected ? const Color(0xff0f766e) : const Color(0xffcbd7df),
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : null,
        ),
      ),
    ),
  );
}

class _GranularityDropdown extends StatelessWidget {
  const _GranularityDropdown({
    required this.value,
    required this.strings,
    required this.onChanged,
  });

  final TodoGranularity value;
  final AppLocalizations strings;
  final ValueChanged<TodoGranularity?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    width: 78,
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xffcbd7df)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<TodoGranularity>(
        value: value,
        isExpanded: true,
        isDense: true,
        iconSize: 18,
        items: TodoGranularity.values
            .map(
              (granularity) => DropdownMenuItem(
                value: granularity,
                child: Text(
                  granularity.localizedLabel(strings),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;
  final bool danger;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon),
    color: danger ? const Color(0xff9e1f33) : null,
    style: IconButton.styleFrom(
      minimumSize: const Size(30, 30),
      maximumSize: const Size(30, 30),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: active
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.white,
      side: BorderSide(
        color: danger ? const Color(0xffe0909b) : const Color(0xffcbd7df),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xffcbd7df)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: const TextStyle(color: Color(0xff7a8a95))),
  );
}

class _MessageText extends StatelessWidget {
  const _MessageText({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: TextStyle(color: isError ? const Color(0xff9e1f33) : null),
      ),
    ),
  );
}
