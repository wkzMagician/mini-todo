import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartloom_autostart/dartloom_autostart.dart';
import 'package:dartloom_logging/dartloom_logging.dart';
import 'package:dartloom_settings/dartloom_settings.dart';
import 'package:dartloom_storage/dartloom_storage.dart';
import 'package:dartloom_storage_file/dartloom_storage_file.dart';
import 'package:dartloom_sync/dartloom_sync.dart';
import 'package:dartloom_sync_storage/dartloom_sync_storage.dart';
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
    final store = MemoryObjectStore();
    final repository = ObjectStoreTodoRepository(store);
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
    expect(
      (await store.scan()).map((item) => item.key),
      containsAll(['todo-one', 'todo-two']),
    );
    expect(await store.read(TodoStorageKeys.legacyTodosKey), isNull);

    await repository.save([second]);
    expect(await store.read('todo-one'), isNull);
    expect((await repository.load()).single, second);
  });

  test('serializes mutations for object stores', () async {
    final store = _SerialOnlyObjectStore();
    final repository = ObjectStoreTodoRepository(store);
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

  test(
    'persists one new task in the file object store',
    () async {
      final sandbox = await Directory.systemTemp.createTemp('mini_todo_save');
      addTearDown(() => sandbox.delete(recursive: true));
      final business = Directory(
        '${sandbox.path}${Platform.pathSeparator}MiniTodo',
      );
      final repository = ObjectStoreTodoRepository(await _openStore(business));
      final todo = Todo(
        id: 'one',
        title: 'Only task',
        granularity: TodoGranularity.day,
        createdAt: now,
      );

      await repository.save([todo]);

      final reopened = await _openStore(business);
      expect(await ObjectStoreTodoRepository(reopened).load(), [todo]);
      expect(
        business.listSync().where((entity) => entity.path.endsWith('.tmp')),
        isEmpty,
      );
    },
    skip: Platform.isWindows
        ? 'File-system watch is unavailable in this test sandbox.'
        : false,
  );

  test('migrates the old combined todo list to independent records', () async {
    final store = MemoryObjectStore();
    final todo = Todo(
      id: 'one',
      title: 'Migrated task',
      granularity: TodoGranularity.day,
      createdAt: now,
    );
    await store.write(
      TodoStorageKeys.legacyTodosKey,
      Uint8List.fromList(utf8.encode(jsonEncode([todo.toJson()]))),
    );

    final loaded = await ObjectStoreTodoRepository(store).load();

    expect(loaded, [todo]);
    expect(await store.read(TodoStorageKeys.legacyTodosKey), isNull);
    expect(await store.read('todo-one'), isNotNull);
  });

  test('leaves startup scheduling to the composed SyncService', () async {
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
    await controller.saveSyncConfiguration(
      url: 'https://example.test/dav/',
      username: 'user',
      password: 'secret',
    );
    expect(service.lastDraft?.options, isNot(contains('root_path')));
    await controller.sync();
    expect(service.calls, 1);
    controller.dispose();
  });

  test(
    'migrates legacy plaintext credentials when a profile already exists',
    () async {
      final settings = MemorySettingsStore();
      await settings.write('sync.webdav.url', 'https://example.test/dav/');
      await settings.write('sync.webdav.username', 'user');
      await settings.write('sync.webdav.password', 'legacy-secret');
      final service = _RecordingSyncService(
        profiles: [
          const SyncProfile(
            id: 'default',
            label: 'Default',
            backend: 'webdav',
            options: {
              'base_url': 'https://example.test/dav/',
              'username': 'user',
            },
            isActive: true,
          ),
        ],
      );
      final controller = TodoController(
        repository: MemoryTodoRepository(),
        settings: settings,
        logger: MemoryLogger(),
        syncService: service,
      );

      await controller.initialize();

      expect(service.lastDraft?.secrets, {'password': 'legacy-secret'});
      expect(await settings.read('sync.webdav.password'), isNull);
      expect(await settings.read('sync.webdav.url'), isNull);
      controller.dispose();
    },
  );

  test(
    'journaled repository records intents for local mutations and sync',
    () async {
      final objects = MemoryObjectStore();
      final metadata = MemoryObjectStore();
      final journaled = await JournaledObjectStore.open(
        objects: objects,
        metadata: metadata,
      );
      final repository = ObjectStoreTodoRepository(journaled);
      final settings = MemorySettingsStore();
      final service = _RecordingSyncService();
      final controller = TodoController(
        repository: repository,
        settings: settings,
        logger: MemoryLogger(),
        syncService: service,
      );

      await controller.initialize();
      await controller.addTask('Write unit test', TodoGranularity.day);

      final intents = await journaled.intents();
      expect(intents, isNotEmpty);
      expect(intents.first.key, startsWith('todo-'));
      expect(intents.first.kind, LocalMutationKind.create);

      await controller.saveSyncConfiguration(
        url: 'https://dav.jianguoyun.com/dav/',
        username: 'user@example.com',
        password: 'app-password',
      );
      expect(service.lastDraft?.secrets, {'password': 'app-password'});

      controller.dispose();
      await journaled.close();
    },
  );
}

final class _RecordingSyncService implements SyncService {
  _RecordingSyncService({List<SyncProfile>? profiles})
    : _profiles =
          profiles ??
          [
            const SyncProfile(
              id: 'default',
              label: 'Local',
              backend: '',
              isActive: true,
            ),
          ];

  int calls = 0;
  SyncProfileDraft? lastDraft;
  final List<SyncProfile> _profiles;

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
  Future<SyncProfile> saveProfile(SyncProfileDraft draft) async {
    lastDraft = draft;
    return _profiles.first;
  }

  @override
  Future<void> start() async {}
}

Future<FileObjectStore> _openStore(Directory business) =>
    FileObjectStore.open(root: business.absolute, hierarchical: false);

final class _SerialOnlyObjectStore implements ObjectStore {
  final _values = <String, Uint8List>{};
  var _activeMutations = 0;
  var maximumConcurrentMutations = 0;

  @override
  String get identity => 'serial-only';

  @override
  Stream<StorageChange> get changes => const Stream.empty();

  @override
  bool acceptsKey(String key) => true;

  @override
  Future<void> delete(String key) => _mutate(() => _values.remove(key));

  @override
  Future<List<StoredObject>> scan() async => [
    for (final entry in _values.entries)
      StoredObject(key: entry.key, size: entry.value.length),
  ];

  @override
  Future<Uint8List?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, Uint8List data) =>
      _mutate(() => _values[key] = data);

  @override
  Future<void> close() async {}

  Future<void> _mutate(void Function() mutation) async {
    _activeMutations++;
    maximumConcurrentMutations = maximumConcurrentMutations < _activeMutations
        ? _activeMutations
        : maximumConcurrentMutations;
    if (_activeMutations > 1) {
      _activeMutations--;
      throw StateError('Concurrent replica mutation');
    }
    try {
      await Future<void>.delayed(Duration.zero);
      mutation();
    } finally {
      _activeMutations--;
    }
  }
}
