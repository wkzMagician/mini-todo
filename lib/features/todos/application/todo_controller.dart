// The public constructor names describe collaborators while fields remain
// private implementation details.
// ignore_for_file: prefer_initializing_formals

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
    required AutostartService autostart,
    required AppLogger logger,
    this.syncEngine,
  }) : _repository = repository,
       _settings = settings,
       _autostart = autostart,
       _logger = logger;

  static const _collapsedKey = 'todo.collapsed';
  static const _granularityKey = 'todo.granularity';

  final TodoRepository _repository;
  final SettingsStore _settings;
  final AutostartService _autostart;
  final AppLogger _logger;
  final SyncEngine? syncEngine;

  List<Todo> _todos = [];
  TodoGranularity _selectedGranularity = TodoGranularity.day;
  bool _collapsed = false;
  bool _settingsOpen = false;
  bool _openAtLogin = false;
  bool _loading = true;
  String? _error;
  SyncStatus _syncStatus = SyncStatus.idle;
  String? _syncMessage;
  String _syncUrl = '';
  String _syncRootPath = '';
  String _syncUsername = '';
  String _syncPassword = '';
  Todo? _lastCompletedTodo;
  int? _lastCompletedIndex;

  List<Todo> get todos => List.unmodifiable(_todos);
  List<Todo> get visibleTodos => filterTodos(_todos, _selectedGranularity);
  TodoGranularity get selectedGranularity => _selectedGranularity;
  bool get collapsed => _collapsed;
  bool get settingsOpen => _settingsOpen;
  bool get openAtLogin => _openAtLogin;
  bool get loading => _loading;
  String? get error => _error;
  bool get syncAvailable => syncEngine != null;
  SyncStatus get syncStatus => _syncStatus;
  String? get syncMessage => _syncMessage;
  bool get syncConfigured => _syncUrl.trim().isNotEmpty;
  String get syncUrl => _syncUrl;
  String get syncRootPath => _syncRootPath;
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
      _openAtLogin = await _autostart.isEnabled();
      _syncUrl = await _readSetting(syncWebDavUrlKey);
      _syncRootPath = await _readSetting(syncWebDavRootPathKey);
      _syncUsername = await _readSetting(syncWebDavUsernameKey);
      _syncPassword = await _readSetting(syncWebDavPasswordKey);
      _logger.info('Todo data loaded.');
    } catch (error, stackTrace) {
      _error = 'Failed to load tasks.';
      _logger.error('Failed to load todo data.', error, stackTrace);
    } finally {
      _loading = false;
      notifyListeners();
    }
    if (syncAvailable && syncConfigured) await sync();
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
    _clearError();
    try {
      if (enabled) {
        await _autostart.enable();
      } else {
        await _autostart.disable();
      }
      _openAtLogin = await _autostart.isEnabled();
      notifyListeners();
    } catch (error, stackTrace) {
      _fail('Failed to update launch-at-login.', error, stackTrace);
    }
  }

  Future<void> saveSyncConfiguration({
    required String url,
    required String rootPath,
    required String username,
    required String password,
  }) async {
    _syncUrl = url.trim();
    _syncRootPath = rootPath.trim();
    _syncUsername = username;
    _syncPassword = password;
    await Future.wait([
      _settings.write(syncWebDavUrlKey, _syncUrl),
      _settings.write(syncWebDavRootPathKey, _syncRootPath),
      _settings.write(syncWebDavUsernameKey, _syncUsername),
      _settings.write(syncWebDavPasswordKey, _syncPassword),
    ]);
    _syncMessage = null;
    notifyListeners();
  }

  Future<SyncResult?> sync() async {
    final engine = syncEngine;
    if (engine == null) return null;

    _syncStatus = SyncStatus.syncing;
    _syncMessage = null;
    notifyListeners();
    final result = await engine.sync();
    if (result.status != SyncStatus.failed) {
      try {
        _todos = await _repository.load();
      } catch (error, stackTrace) {
        _logger.error('Failed to reload tasks after sync.', error, stackTrace);
      }
    }
    _syncStatus = result.status;
    _syncMessage = result.message;
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
}
