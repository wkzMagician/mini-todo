// The public constructor names describe collaborators while fields remain
// private implementation details.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:dartloom_autostart/dartloom_autostart.dart';
import 'package:dartloom_logging/dartloom_logging.dart';
import 'package:dartloom_settings/dartloom_settings.dart';
import 'package:dartloom_sync/dartloom_sync.dart';
import 'package:flutter/foundation.dart';

import '../../../app/sync_configuration.dart';
import '../data/todo_repository.dart';
import '../domain/todo.dart';

class TodoController extends ChangeNotifier {
  TodoController({
    required TodoRepository repository,
    required SettingsStore settings,
    AutostartService? autostart,
    required AppLogger logger,
    this.syncService,
  }) : _repository = repository,
       _settings = settings,
       _autostart = autostart,
       _logger = logger;

  static const _collapsedKey = 'todo.collapsed';
  static const _granularityKey = 'todo.granularity';

  final TodoRepository _repository;
  final SettingsStore _settings;
  final AutostartService? _autostart;
  final AppLogger _logger;
  final SyncService? syncService;

  List<Todo> _todos = [];
  TodoGranularity _selectedGranularity = TodoGranularity.day;
  bool _collapsed = false;
  bool _settingsOpen = false;
  bool _openAtLogin = false;
  bool _loading = true;
  String? _error;
  SyncPhase _syncStatus = SyncPhase.idle;
  String? _syncMessage;
  String _syncUrl = '';
  String _syncUsername = '';
  String _syncPassword = '';
  Todo? _lastCompletedTodo;
  int? _lastCompletedIndex;
  StreamSubscription<SyncSnapshot>? _syncSubscription;
  String? _activeSyncProfileId;
  int _localSyncRevision = 0;

  List<Todo> get todos => List.unmodifiable(_todos);
  List<Todo> get visibleTodos => filterTodos(_todos, _selectedGranularity);
  TodoGranularity get selectedGranularity => _selectedGranularity;
  bool get collapsed => _collapsed;
  bool get settingsOpen => _settingsOpen;
  bool get openAtLogin => _openAtLogin;
  bool get autostartAvailable => _autostart != null;
  bool get loading => _loading;
  String? get error => _error;
  bool get syncAvailable => syncService != null;
  SyncPhase get syncStatus => _syncStatus;
  String? get syncMessage => _syncMessage;
  bool get syncConfigured => _syncUrl.trim().isNotEmpty;
  String get syncUrl => _syncUrl;
  String get syncUsername => _syncUsername;
  String get syncPassword => _syncPassword;

  Future<void> initialize() async {
    try {
      _todos = await _repository.load();
      _collapsed = await _settings.read(_collapsedKey) as bool? ?? false;
      final savedGranularity = await _settings.read(_granularityKey) as String?;
      if (savedGranularity != null) {
        _selectedGranularity = TodoGranularityX.fromStorage(savedGranularity);
      }
      _openAtLogin = await _autostart?.isEnabled() ?? false;
      await _initializeSyncProfile();
      _logger.info('Todo data loaded.');
    } catch (error, stackTrace) {
      _error = 'Failed to load tasks.';
      _logger.error('Failed to load todo data.', error, stackTrace);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _initializeSyncProfile() async {
    final service = syncService;
    if (service == null) return;
    _syncSubscription = service.states.listen(_handleSyncSnapshot);
    _localSyncRevision = service.snapshot.localRevision;
    var active = (await service.listProfiles())
        .where((profile) => profile.isActive)
        .firstOrNull;
    final legacyUrl = await _readSetting(syncWebDavUrlKey);
    final legacyUsername = await _readSetting(syncWebDavUsernameKey);
    final legacyPassword = await _readSetting(syncWebDavPasswordKey);
    final hasLegacyConfig =
        legacyUrl.isNotEmpty ||
        legacyUsername.isNotEmpty ||
        legacyPassword.isNotEmpty;
    if ((active == null || active.backend.isEmpty) && legacyUrl.isNotEmpty) {
      active = await service.saveProfile(
        SyncProfileDraft(
          id: active?.id ?? 'default',
          label: 'Default',
          backend: 'webdav',
          options: {'base_url': legacyUrl, 'username': legacyUsername},
          secrets: {if (legacyPassword.isNotEmpty) 'password': legacyPassword},
        ),
      );
      await service.activateProfile(active.id);
    } else if (active?.backend == 'webdav' && hasLegacyConfig) {
      // Older builds kept WebDAV credentials in shared preferences. Move the
      // legacy password into the secure profile even when a profile already
      // exists, then remove every legacy key so it cannot remain plaintext.
      final options = <String, Object?>{...active!.options};
      if (legacyUrl.isNotEmpty) options['base_url'] = legacyUrl;
      if (legacyUsername.isNotEmpty) options['username'] = legacyUsername;
      active = await service.saveProfile(
        SyncProfileDraft(
          id: active.id,
          label: active.label,
          backend: active.backend,
          options: options,
          secrets: {if (legacyPassword.isNotEmpty) 'password': legacyPassword},
        ),
      );
    }
    if (hasLegacyConfig) {
      await Future.wait([
        _settings.remove(syncWebDavUrlKey),
        _settings.remove('sync.webdav.root_path'),
        _settings.remove(syncWebDavUsernameKey),
        _settings.remove(syncWebDavPasswordKey),
      ]);
    }
    if (active != null) {
      _applyProfile(active);
      if (active.backend == 'webdav' && _todos.isNotEmpty) {
        await _repository.save(_todos);
      }
    }
  }

  void _applyProfile(SyncProfile profile) {
    _activeSyncProfileId = profile.id;
    _syncUrl = profile.options['base_url'] as String? ?? '';
    _syncUsername = profile.options['username'] as String? ?? '';
    _syncPassword = '';
  }

  void _handleSyncSnapshot(SyncSnapshot snapshot) {
    _syncStatus = snapshot.phase;
    _syncMessage = snapshot.lastReport?.failure?.message;
    if (snapshot.localRevision != _localSyncRevision) {
      _localSyncRevision = snapshot.localRevision;
      unawaited(_reloadAfterSync());
    }
    notifyListeners();
  }

  Future<void> _reloadAfterSync() async {
    try {
      _todos = await _repository.load();
      notifyListeners();
    } catch (error, stackTrace) {
      _logger.error('Failed to reload tasks after sync.', error, stackTrace);
    }
  }

  void selectGranularity(TodoGranularity granularity) {
    _selectedGranularity = granularity;
    _settings.write(_granularityKey, granularity.storageValue);
    notifyListeners();
  }

  void toggleSettings() {
    _settingsOpen = !_settingsOpen;
    notifyListeners();
  }

  Future<void> toggleCollapsed() async {
    _collapsed = !_collapsed;
    await _settings.write(_collapsedKey, _collapsed);
    notifyListeners();
  }

  Future<bool> addTask(String title, TodoGranularity granularity) async {
    _clearError();
    try {
      final nextTodos = [
        ..._todos,
        createTodo(title: title, granularity: granularity),
      ];
      await _save(nextTodos);
      _selectedGranularity = granularity;
      notifyListeners();
      return true;
    } on FormatException catch (error) {
      _error = error.message;
      notifyListeners();
      return false;
    } catch (error, stackTrace) {
      _fail('Failed to save tasks.', error, stackTrace);
      return false;
    }
  }

  Future<bool> completeTask(String id) async {
    _clearError();
    try {
      final index = _todos.indexWhere((todo) => todo.id == id);
      if (index < 0) return false;
      _lastCompletedTodo = _todos[index];
      _lastCompletedIndex = index;
      await _save(completeTodo(_todos, id));
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      _fail('Failed to complete task.', error, stackTrace);
      return false;
    }
  }

  Future<bool> undoLastCompletion() async {
    final todo = _lastCompletedTodo;
    final index = _lastCompletedIndex;
    if (todo == null || index == null) return false;

    try {
      final nextTodos = List<Todo>.from(_todos);
      nextTodos.insert(index.clamp(0, nextTodos.length), todo);
      await _save(nextTodos);
      _lastCompletedTodo = null;
      _lastCompletedIndex = null;
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      _fail('Failed to undo completion.', error, stackTrace);
      return false;
    }
  }

  Future<void> changeTaskGranularity(
    String id,
    TodoGranularity granularity,
  ) async {
    _clearError();
    try {
      await _save(updateTodoGranularity(_todos, id, granularity));
      _selectedGranularity = granularity;
      notifyListeners();
    } catch (error, stackTrace) {
      _fail('Failed to update task period.', error, stackTrace);
    }
  }

  Future<bool> renameTask(String id, String title) async {
    _clearError();
    try {
      await _save(renameTodo(_todos, id, title));
      notifyListeners();
      return true;
    } on FormatException catch (error) {
      _error = error.message;
      notifyListeners();
      return false;
    } catch (error, stackTrace) {
      _fail('Failed to rename task.', error, stackTrace);
      return false;
    }
  }

  Future<void> reorderTask(int fromIndex, int toIndex) async {
    _clearError();
    try {
      await _save(
        reorderTodos(_todos, _selectedGranularity, fromIndex, toIndex),
      );
      notifyListeners();
    } catch (error, stackTrace) {
      _fail('Failed to reorder tasks.', error, stackTrace);
    }
  }

  Future<void> setOpenAtLogin(bool enabled) async {
    final autostart = _autostart;
    if (autostart == null) return;
    _clearError();
    try {
      if (enabled) {
        await autostart.enable();
      } else {
        await autostart.disable();
      }
      _openAtLogin = await autostart.isEnabled();
      notifyListeners();
    } catch (error, stackTrace) {
      _fail('Failed to update launch-at-login.', error, stackTrace);
    }
  }

  Future<void> saveSyncConfiguration({
    required String url,
    required String username,
    required String password,
  }) async {
    final service = syncService;
    if (service == null) return;
    try {
      final saved = await service.saveProfile(
        SyncProfileDraft(
          id: _activeSyncProfileId ?? 'default',
          label: 'Default',
          backend: 'webdav',
          options: {'base_url': url.trim(), 'username': username},
          secrets: {if (password.isNotEmpty) 'password': password},
        ),
      );
      if (_todos.isNotEmpty) {
        await _repository.save(_todos);
      }
      // Re-open the profile unconditionally. The default profile is already
      // active (id 'default'), so relying on saved.isActive would skip this
      // step, leave the coordinator holding the previously-opened (empty)
      // replica, and make every sync fail with "No configured active sync
      // profile." Re-opening also triggers the sync-on-activate policy.
      await service.activateProfile(saved.id);
      _applyProfile(saved);
      _syncStatus = SyncPhase.syncing;
      _syncMessage = null;
      notifyListeners();
    } on FormatException catch (error, stackTrace) {
      _logger.error('Invalid sync configuration.', error, stackTrace);
      _syncStatus = SyncPhase.failed;
      _syncMessage = error.message.toString();
      notifyListeners();
    }
  }

  Future<SyncRunReport?> sync() async {
    final service = syncService;
    if (service == null) return null;

    _syncStatus = SyncPhase.syncing;
    _syncMessage = null;
    notifyListeners();
    final result = await service.syncNow();
    if (result.failure == null) {
      try {
        _todos = await _repository.load();
      } catch (error, stackTrace) {
        _logger.error('Failed to reload tasks after sync.', error, stackTrace);
      }
    }
    _syncStatus = result.failure != null
        ? SyncPhase.failed
        : result.conflicts > 0
        ? SyncPhase.conflicted
        : SyncPhase.succeeded;
    _syncMessage = result.failure?.message;
    notifyListeners();
    return result;
  }

  Future<void> _save(List<Todo> todos) async {
    await _repository.save(todos);
    _todos = todos;
  }

  void _clearError() => _error = null;

  Future<String> _readSetting(String key) async {
    final value = await _settings.read(key);
    return value is String ? value : '';
  }

  void _fail(String message, Object error, StackTrace stackTrace) {
    _error = message;
    _logger.error(message, error, stackTrace);
    notifyListeners();
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }
}
