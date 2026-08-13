import 'dart:io';

import 'package:dartloom_autostart/dartloom_autostart.dart';
import 'package:dartloom_logging/dartloom_logging.dart';
import 'package:dartloom_settings/dartloom_settings.dart';
import 'package:dartloom_storage/dartloom_storage.dart';
import 'package:dartloom_storage_json_file/dartloom_storage_json_file.dart';
import 'package:dartloom_sync/dartloom_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_todo/features/todos/application/todo_controller.dart';
import 'package:mini_todo/features/todos/data/todo_repository.dart';
import 'package:mini_todo/features/todos/domain/todo.dart';

void main() {
  final now = DateTime(2026, 8, 7);

  test('creates a trimmed todo', () {
    final todo = createTodo(
      id: 'one',
      title: '  Write docs  ',
      granularity: TodoGranularity.day,
      now: now,
    );

    expect(todo.title, 'Write docs');
    expect(todo.id, 'one');
    expect(todo.createdAt, now);
  });

  test('rejects a blank todo title', () {
    expect(
      () => createTodo(title: '  ', granularity: TodoGranularity.day),
      throwsA(isA<FormatException>()),
    );
  });

  test('filters, renames, moves, and completes todos', () {
    final todos = [
      Todo(
        id: 'one',
        title: 'First task',
        granularity: TodoGranularity.day,
        createdAt: now,
      ),
      Todo(
        id: 'two',
        title: 'Second task',
        granularity: TodoGranularity.day,
        createdAt: now,
      ),
      Todo(
        id: 'three',
        title: 'Third task',
        granularity: TodoGranularity.week,
        createdAt: now,
      ),
    ];

    expect(filterTodos(todos, TodoGranularity.week).single.id, 'three');
    expect(renameTodo(todos, 'one', 'Renamed').first.title, 'Renamed');
    expect(reorderTodos(todos, TodoGranularity.day, 0, 1).first.id, 'two');
    expect(completeTodo(todos, 'two').map((todo) => todo.id), ['one', 'three']);
  });

  test('restores the most recently completed todo', () async {
    final repository = MemoryTodoRepository([
      Todo(
        id: 'one',
        title: 'Undo me',
        granularity: TodoGranularity.day,
        createdAt: now,
      ),
    ]);
    final controller = TodoController(
      repository: repository,
      settings: MemorySettingsStore(),
      autostart: MemoryAutostartService(),
      logger: MemoryLogger(),
    );

    await controller.initialize();
    expect(await controller.completeTask('one'), isTrue);
    expect(controller.todos, isEmpty);
    expect(await controller.undoLastCompletion(), isTrue);
    expect(controller.todos.single.title, 'Undo me');
    controller.dispose();
  });

  test('stores every todo as an independent sync record', () async {
    final store = MemoryJsonStore();
    final repository = JsonStoreTodoRepository(store);
    final first = Todo(
      id: 'one',
      title: 'First task',
      granularity: TodoGranularity.day,
      createdAt: now,
    );
    final second = Todo(
      id: 'two',
      title: 'Second task',
      granularity: TodoGranularity.week,
      createdAt: now,
    );

    await repository.save([first, second]);
    expect(await store.list(), containsAll(['todo-one', 'todo-two']));
    expect(await store.read(TodoStorageKeys.legacyTodosKey), isNull);

    await repository.save([second]);
    expect(await store.read('todo-one'), isNull);
    expect((await repository.load()).single, second);
  });

  test('serializes mutations for file-backed JSON stores', () async {
    final store = _SerialOnlyJsonStore();
    final repository = JsonStoreTodoRepository(store);
    final todos = [
      Todo(
        id: 'one',
        title: 'First task',
        granularity: TodoGranularity.day,
        createdAt: now,
      ),
      Todo(
        id: 'two',
        title: 'Second task',
        granularity: TodoGranularity.week,
        createdAt: now,
      ),
    ];

    await repository.save(todos);

    expect(await repository.load(), todos);
    expect(store.maximumConcurrentMutations, 1);
  });

  test('persists one new task in the real JSON file store', () async {
    final directory = await Directory.systemTemp.createTemp('mini_todo_save');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}data.json');
    final repository = JsonStoreTodoRepository(JsonFileStore(file));
    final todo = Todo(
      id: 'one',
      title: 'Only task',
      granularity: TodoGranularity.day,
      createdAt: now,
    );

    await repository.save([todo]);

    expect(await JsonStoreTodoRepository(JsonFileStore(file)).load(), [todo]);
    expect(File('${file.path}.tmp').existsSync(), isFalse);
  });

  test('migrates the old combined todo list to independent records', () async {
    final store = MemoryJsonStore();
    final todo = Todo(
      id: 'one',
      title: 'Migrated task',
      granularity: TodoGranularity.day,
      createdAt: now,
    );
    await store.write(TodoStorageKeys.legacyTodosKey, [todo.toJson()]);

    final loaded = await JsonStoreTodoRepository(store).load();

    expect(loaded, [todo]);
    expect(await store.read(TodoStorageKeys.legacyTodosKey), isNull);
    expect(await store.read('todo-one'), isA<Map>());
  });

  test('leaves startup scheduling to Dartloom SyncService', () async {
    final settings = MemorySettingsStore();
    final service = _RecordingSyncService();
    final controller = TodoController(
      repository: MemoryTodoRepository(),
      settings: settings,
      autostart: MemoryAutostartService(),
      logger: MemoryLogger(),
      syncService: service,
    );

    await controller.initialize();

    expect(service.calls, 0);
    await controller.sync();
    expect(service.calls, 1);
    controller.dispose();
  });
}

final class _RecordingSyncService implements SyncService {
  int calls = 0;
  final _profiles = <SyncProfile>[
    const SyncProfile(
      id: 'default',
      label: 'Local',
      backend: '',
      isActive: true,
    ),
  ];

  @override
  SyncSnapshot get snapshot => const SyncSnapshot.initial();
  @override
  Stream<SyncSnapshot> get states => const Stream.empty();

  @override
  Future<SyncRunReport> syncNow() async {
    calls++;
    return const SyncRunReport(trigger: SyncTrigger.manual);
  }

  @override
  Future<void> activateProfile(String profileId) async {}
  @override
  Future<void> deleteProfile(
    String profileId, {
    required bool deleteLocalData,
  }) async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<List<SyncConflict>> listConflicts() async => const [];
  @override
  Future<List<SyncProfile>> listProfiles() async => _profiles;
  @override
  Future<void> resolveConflict(
    String conflictId,
    SyncConflictResolution resolution,
  ) async {}
  @override
  Future<SyncProfile> saveProfile(SyncProfileDraft draft) async =>
      _profiles.first;
  @override
  Future<void> start() async {}
}

final class _SerialOnlyJsonStore implements JsonStore {
  final _values = <String, Object?>{};
  var _activeMutations = 0;
  var maximumConcurrentMutations = 0;

  @override
  Future<void> delete(String key) => _mutate(() => _values.remove(key));

  @override
  Future<List<String>> list({String prefix = ''}) async =>
      (_values.keys.where((key) => key.startsWith(prefix)).toList()..sort());

  @override
  Future<Object?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, Object? value) =>
      _mutate(() => _values[key] = value);

  Future<void> _mutate(void Function() mutation) async {
    _activeMutations++;
    maximumConcurrentMutations = maximumConcurrentMutations < _activeMutations
        ? _activeMutations
        : maximumConcurrentMutations;
    if (_activeMutations > 1) {
      _activeMutations--;
      throw StateError('Concurrent JSON mutation');
    }
    try {
      await Future<void>.delayed(Duration.zero);
      mutation();
    } finally {
      _activeMutations--;
    }
  }
}
