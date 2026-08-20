import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartloom_storage/dartloom_storage.dart';

import '../domain/todo.dart';

abstract interface class TodoRepository {
  Future<List<Todo>> load();
  Future<void> save(List<Todo> todos);
}

abstract final class TodoStorageKeys {
  static const legacyTodosKey = 'todos';
  static const todoPrefix = 'todo-';

  static bool isTodoKey(String key) => key.startsWith(todoPrefix);
  static String forTodo(String id) => '$todoPrefix$id';
}

class MemoryTodoRepository implements TodoRepository {
  MemoryTodoRepository([Iterable<Todo> initialTodos = const []])
    : _todos = List<Todo>.from(initialTodos);

  List<Todo> _todos;

  @override
  Future<List<Todo>> load() async => List<Todo>.from(_todos);

  @override
  Future<void> save(List<Todo> todos) async => _todos = List<Todo>.from(todos);
}

class ObjectStoreTodoRepository implements TodoRepository {
  ObjectStoreTodoRepository(this._store);

  final ObjectStore _store;

  @override
  Future<List<Todo>> load() async {
    final keys =
        (await _existingKeys()).where(TodoStorageKeys.isTodoKey).toList()
          ..sort();
    if (keys.isEmpty) return _migrateLegacyTodos();

    final storedTodos = (await Future.wait(
      keys.map(_readStoredTodo),
    )).whereType<_StoredTodo>().toList()..sort(_compareStoredTodos);
    return storedTodos.map((stored) => stored.todo).toList();
  }

  @override
  Future<void> save(List<Todo> todos) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _saveOnce(todos);
        return;
      } catch (error, stackTrace) {
        if (!_isTransientPathError(error) || attempt == 2) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        lastError = error;
        lastStackTrace = stackTrace;
        await Future<void>.delayed(Duration(milliseconds: 25 * (attempt + 1)));
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  Future<void> _saveOnce(List<Todo> todos) async {
    final allKeys = await _existingKeys();
    final existingKeys = allKeys.where(TodoStorageKeys.isTodoKey).toSet();
    final nextKeys = <String>{};

    for (final entry in todos.indexed) {
      await _writeTodo(entry.$1, entry.$2, nextKeys);
    }
    for (final key in existingKeys) {
      if (!nextKeys.contains(key)) {
        await _store.delete(key);
      }
    }
    if (allKeys.contains(TodoStorageKeys.legacyTodosKey)) {
      await _store.delete(TodoStorageKeys.legacyTodosKey);
    }
  }

  bool _isTransientPathError(Object error) =>
      error is PathNotFoundException ||
      error is FileSystemException && error.osError?.errorCode == 2;

  Future<List<String>> _existingKeys() async =>
      (await _store.scan()).map((item) => item.key).toList();

  Future<List<Todo>> _migrateLegacyTodos() async {
    final bytes = await _store.read(TodoStorageKeys.legacyTodosKey);
    if (bytes == null) return const [];
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return const [];
    }
    if (decoded is! List) return const [];
    final todos = decoded
        .whereType<Map>()
        .map((todo) => Todo.fromJson(todo.cast<String, dynamic>()))
        .toList();
    await save(todos);
    return todos;
  }

  Future<_StoredTodo?> _readStoredTodo(String key) async {
    final bytes = await _store.read(key);
    if (bytes == null) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final todo = Todo.fromJson(decoded.cast<String, dynamic>());
    final sortOrder = decoded['sortOrder'];
    return _StoredTodo(todo, sortOrder is int ? sortOrder : 0);
  }

  Future<void> _writeTodo(int sortOrder, Todo todo, Set<String> nextKeys) {
    final key = TodoStorageKeys.forTodo(todo.id);
    nextKeys.add(key);
    final bytes = Uint8List.fromList(
      utf8.encode(jsonEncode({...todo.toJson(), 'sortOrder': sortOrder})),
    );
    return _store.write(key, bytes);
  }

  static int _compareStoredTodos(_StoredTodo left, _StoredTodo right) {
    final byOrder = left.sortOrder.compareTo(right.sortOrder);
    if (byOrder != 0) return byOrder;
    final byCreatedAt = left.todo.createdAt.compareTo(right.todo.createdAt);
    if (byCreatedAt != 0) return byCreatedAt;
    return left.todo.id.compareTo(right.todo.id);
  }
}

final class _StoredTodo {
  const _StoredTodo(this.todo, this.sortOrder);

  final Todo todo;
  final int sortOrder;
}
