import 'package:dartloom_storage/dartloom_storage.dart';

import '../domain/todo.dart';

abstract interface class TodoRepository {
  Future<List<Todo>> load();
  Future<void> save(List<Todo> todos);
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

class JsonStoreTodoRepository implements TodoRepository {
  JsonStoreTodoRepository(this._store);

  static const _todosKey = 'todos';
  final JsonStore _store;

  @override
  Future<List<Todo>> load() async {
    final value = await _store.read(_todosKey);
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((todo) => Todo.fromJson(todo.cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<void> save(List<Todo> todos) =>
      _store.write(_todosKey, todos.map((todo) => todo.toJson()).toList());
}
