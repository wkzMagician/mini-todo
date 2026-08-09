import 'package:dartloom_autostart/dartloom_autostart.dart';
import 'package:dartloom_logging/dartloom_logging.dart';
import 'package:dartloom_settings/dartloom_settings.dart';
import 'package:dartloom_storage/dartloom_storage.dart';
import 'package:dartloom_sync/dartloom_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_todo/app/sync_configuration.dart';
import 'package:mini_todo/app/sync_factory.dart';
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

  test('fails sync clearly when WebDAV is not configured', () async {
    final engine = ConfiguredWebDavSyncEngine(
      settings: MemorySettingsStore(),
      jsonStore: MemoryJsonStore(),
      defaultRootPath: 'MiniTodo',
    );

    final result = await engine.sync();

    expect(result.status, SyncStatus.failed);
    expect(result.message, contains('WebDAV URL'));
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

  test('syncs once while opening when WebDAV has been configured', () async {
    final settings = MemorySettingsStore();
    await settings.write(syncWebDavUrlKey, 'https://dav.example.com/');
    final engine = _RecordingSyncEngine();
    final controller = TodoController(
      repository: MemoryTodoRepository(),
      settings: settings,
      autostart: MemoryAutostartService(),
      logger: MemoryLogger(),
      syncEngine: engine,
    );

    await controller.initialize();

    expect(engine.calls, 1);
    controller.dispose();
  });
}

final class _RecordingSyncEngine implements SyncEngine {
  int calls = 0;

  @override
  Future<List<SyncConflict>> conflicts() async => const [];

  @override
  Future<SyncResult> sync() async {
    calls++;
    return const SyncResult(status: SyncStatus.succeeded);
  }

  @override
  Future<SyncStatus> status() async => SyncStatus.succeeded;
}
